import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../images/image_store.dart';
import 'snapshot.dart';

/// 一次导入的结果，用于界面回显
class ImportOutcome {
  final int added;
  final int updated;
  final int skipped;
  final bool replaced;

  const ImportOutcome({
    required this.added,
    required this.updated,
    required this.skipped,
    required this.replaced,
  });

  int get total => added + updated;

  String get message {
    if (replaced) return '已覆盖本地：写入 $added 条';
    if (total == 0) return '本地已是最新，无需写入';
    return '新增 $added 条，更新 $updated 条，跳过 $skipped 条';
  }
}

/// 本地备份文件信息
class SnapshotFile {
  final File file;
  final DateTime time;
  final int size;

  const SnapshotFile({
    required this.file,
    required this.time,
    required this.size,
  });

  String get name => file.uri.pathSegments.last;

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// 解包结果：数据 + 图片文件
class _Package {
  final String json;
  final Map<String, Uint8List> images;

  const _Package(this.json, this.images);
}

/// 本地备份服务：快照生成、打包、导出、导入合并、自动快照与轮转。
///
/// 备份格式为 zip（`data.json` + `images/`），图片随数据一起走，
/// 换机后不会只剩文字。导入仍兼容早期版本的纯 JSON 文件。
class BackupService {
  final AppDatabase db;

  /// 测试时可注入临时目录
  final Directory? _dirOverride;

  BackupService(this.db, {Directory? directory}) : _dirOverride = directory;

  /// 自动快照保留份数
  static const int keepSnapshots = 7;

  static const String _dataEntry = 'data.json';
  static const String _imagePrefix = 'images/';

  Future<Directory> backupDir() async {
    final Directory dir;
    if (_dirOverride != null) {
      dir = _dirOverride;
    } else {
      final base = await getApplicationDocumentsDirectory();
      dir = Directory('${base.path}/backups');
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 抓取当前库的完整快照
  Future<Snapshot> capture() async {
    final folders = await db.folderDao.allRaw();
    final notes = await db.noteDao.allRaw();
    final attachments = await db.attachmentDao.allRaw();
    return Snapshot.capture(
      folders: folders,
      notes: notes,
      attachments: attachments,
    );
  }

  Future<String> buildJson() async => (await capture()).encode();

  /// 打出带图片的备份包（zip）
  Future<Uint8List> buildPackage() async {
    final Snapshot snap = await capture();
    final Archive archive = Archive();
    archive.add(ArchiveFile.bytes(_dataEntry, utf8.encode(snap.encode())));

    for (final a in snap.attachments) {
      final Uint8List? bytes = await ImageStore.readBytes(a.fileName);
      if (bytes == null) continue;
      archive.add(ArchiveFile.bytes('$_imagePrefix${a.fileName}', bytes));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// 兼容旧调用：返回备份包的字节
  Future<List<int>> buildBytes() => buildPackage();

  /// 解包：zip 或早期的纯 JSON
  Future<_Package> _decode(Uint8List bytes) async {
    final bool looksZip =
        bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    if (!looksZip) {
      return _Package(utf8.decode(bytes, allowMalformed: true), const {});
    }

    final Archive archive = ZipDecoder().decodeBytes(bytes);
    String? json;
    final Map<String, Uint8List> images = {};
    for (final file in archive) {
      if (file.name == _dataEntry) {
        json = utf8.decode(file.content, allowMalformed: true);
      } else if (file.name.startsWith(_imagePrefix)) {
        final String name = file.name.substring(_imagePrefix.length);
        if (name.isEmpty) continue;
        images[name] = file.content;
      }
    }
    if (json == null) {
      throw const FormatException('备份包缺少 data.json');
    }
    return _Package(json, images);
  }

  /// 解包并预览（不写库）
  Future<Snapshot> previewPackage(Uint8List bytes) async {
    final pkg = await _decode(bytes);
    final snap = Snapshot.decode(pkg.json);
    snap.validate();
    return snap;
  }

  /// 兼容旧的文本预览入口
  Future<Snapshot> previewOf(String raw) async {
    final snap = Snapshot.decode(raw);
    snap.validate();
    return snap;
  }

  /// 导入备份包（zip 或旧 JSON 文本）
  Future<ImportOutcome> importPackage(
    Uint8List bytes, {
    bool replace = false,
  }) async {
    final pkg = await _decode(bytes);
    return importRaw(pkg.json, replace: replace, images: pkg.images);
  }

  /// 导入快照文本。
  /// [replace] 为 true 时先自动备份当前数据，再清空并写入（覆盖式恢复）；
  /// 为 false 时按 id 合并，同一条目以 updatedAt 较新的为准。
  Future<ImportOutcome> importRaw(
    String raw, {
    bool replace = false,
    Map<String, Uint8List> images = const {},
  }) async {
    final Snapshot snap = Snapshot.decode(raw);
    snap.validate();

    // 覆盖前先留一份当前数据的快照，出错可回退
    if (replace) {
      await writeSnapshot(suffix: 'before-restore');
    }

    // 图片文件先落盘（记录后写，避免出现「有记录没文件」）
    if (ImageStore.isReady && images.isNotEmpty) {
      for (final entry in images.entries) {
        final File target = ImageStore.fileOf(entry.key);
        if (await target.exists()) continue;
        await ImageStore.writeRaw(entry.key, entry.value);
      }
    }

    int added = 0;
    int updated = 0;
    int skipped = 0;

    await db.transaction(() async {
      if (replace) {
        await db.noteDao.clearAll();
        await db.folderDao.clearAll();
        await db.attachmentDao.clearAll();
      }

      // 分类先写，保证 notes.folderId 的引用有效
      for (final f in snap.folders) {
        await db.folderDao.upsertRaw(f.toCompanion());
      }

      final Map<int, Note> local = {
        for (final n in await db.noteDao.allRaw()) n.id: n,
      };
      final Set<int> written = {};

      for (final n in snap.notes) {
        final Note? existing = local[n.id];
        final bool shouldWrite =
            replace || existing == null || n.updatedAt > existing.updatedAt;
        if (!shouldWrite) {
          skipped++;
          continue;
        }
        await db.noteDao.upsertRaw(n.toCompanion());
        written.add(n.id);
        if (existing == null) {
          added++;
        } else {
          updated++;
        }
      }

      // 附件按「被写入的笔记」整组替换：附件 id 由本地重新分配，
      // 避免不同设备间自增 id 冲突把别的笔记的附件顶掉。
      for (final noteId in written) {
        await db.attachmentDao.deleteByNote(noteId);
      }
      for (final a in snap.attachments) {
        if (!written.contains(a.noteId)) continue;
        await db.attachmentDao.insertOne(
          AttachmentsCompanion.insert(
            noteId: a.noteId,
            fileName: a.fileName,
            sortOrder: Value(a.sortOrder),
            createdAt: a.createdAt,
          ),
        );
      }
    });

    return ImportOutcome(
      added: added,
      updated: updated,
      skipped: skipped,
      replaced: replace,
    );
  }

  /// 写入一份本地快照（zip），返回文件
  Future<SnapshotFile> writeSnapshot({String? suffix}) async {
    final Directory dir = await backupDir();
    final DateTime now = DateTime.now();
    final String stamp = _stamp(now);
    final String name = suffix == null
        ? 'notobox-$stamp.zip'
        : 'notobox-$stamp-$suffix.zip';
    final File file = File('${dir.path}/$name');
    final Uint8List bytes = await buildPackage();
    await file.writeAsBytes(bytes, flush: true);
    await prune();
    final stat = await file.stat();
    return SnapshotFile(file: file, time: stat.modified, size: stat.size);
  }

  /// 按修改时间倒序列出本地快照（含早期 .json）
  Future<List<SnapshotFile>> listSnapshots() async {
    final Directory dir = await backupDir();
    final List<SnapshotFile> files = [];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.zip') && !entity.path.endsWith('.json')) {
        continue;
      }
      final stat = await entity.stat();
      files.add(
        SnapshotFile(file: entity, time: stat.modified, size: stat.size),
      );
    }
    files.sort((a, b) => b.time.compareTo(a.time));
    return files;
  }

  /// 只保留最近 [keepSnapshots] 份
  Future<void> prune() async {
    final Directory dir = await backupDir();
    final List<File> files = [];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (entity.path.endsWith('.zip') || entity.path.endsWith('.json')) {
        files.add(entity);
      }
    }
    if (files.length <= keepSnapshots) return;

    final List<MapEntry<File, DateTime>> stats = [];
    for (final f in files) {
      final stat = await f.stat();
      stats.add(MapEntry(f, stat.modified));
    }
    stats.sort((a, b) => b.value.compareTo(a.value));
    for (final entry in stats.skip(keepSnapshots)) {
      try {
        await entry.key.delete();
      } on FileSystemException {
        // 单个文件删除失败不影响其余轮转
      }
    }
  }

  /// 从本地快照文件恢复（自动识别 zip / 旧 json）
  Future<ImportOutcome> restoreFile(File file, {bool replace = false}) async {
    final Uint8List bytes = await file.readAsBytes();
    return importPackage(bytes, replace: replace);
  }

  Future<void> deleteSnapshot(File file) async {
    if (await file.exists()) await file.delete();
  }

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  /// 默认导出文件名
  static String suggestedFileName() =>
      'NotoBox-backup-${_stamp(DateTime.now())}.zip';
}
