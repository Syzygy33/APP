import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// 备份 / 同步使用的全量快照。
///
/// 只承载业务字段，不包含 v2 遗留的 `is_sticky` 列——类型统一由 [SnapshotNote.kind]
/// 表达，这样快照格式与表结构的遗留细节解耦。
class Snapshot {
  static const String appId = 'NotoBox';
  static const int formatVersion = 1;

  final int exportedAt;
  final List<SnapshotFolder> folders;
  final List<SnapshotNote> notes;

  /// 图片附件元数据（文件本体在 zip 的 images/ 目录里）
  final List<SnapshotAttachment> attachments;

  const Snapshot({
    required this.exportedAt,
    required this.folders,
    required this.notes,
    this.attachments = const [],
  });

  /// 从数据库当前内容生成快照
  factory Snapshot.capture({
    required List<Folder> folders,
    required List<Note> notes,
    List<Attachment> attachments = const [],
    DateTime? at,
  }) {
    return Snapshot(
      exportedAt: (at ?? DateTime.now()).millisecondsSinceEpoch,
      folders: folders.map(SnapshotFolder.fromRow).toList(),
      notes: notes.map(SnapshotNote.fromRow).toList(),
      attachments: attachments.map(SnapshotAttachment.fromRow).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'app': appId,
    'version': formatVersion,
    'exportedAt': exportedAt,
    'folders': folders.map((f) => f.toJson()).toList(),
    'notes': notes.map((n) => n.toJson()).toList(),
    'attachments': attachments.map((a) => a.toJson()).toList(),
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// 解析并做基本校验，格式不对时抛 [FormatException]（由调用方转为用户提示）
  factory Snapshot.decode(String raw) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('不是有效的 JSON 文件');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份文件结构不正确');
    }
    if (decoded['app'] != appId) {
      throw const FormatException('这不是 NotoBox 的备份文件');
    }
    final int version = (decoded['version'] as num?)?.toInt() ?? 0;
    if (version > formatVersion) {
      throw const FormatException('备份文件来自更新版本的 App，请先升级');
    }
    final notesRaw = decoded['notes'];
    final foldersRaw = decoded['folders'];
    if (notesRaw is! List || foldersRaw is! List) {
      throw const FormatException('备份文件缺少必要字段');
    }
    final attachmentsRaw = decoded['attachments'];
    return Snapshot(
      exportedAt: (decoded['exportedAt'] as num?)?.toInt() ?? 0,
      folders: foldersRaw
          .whereType<Map<String, dynamic>>()
          .map(SnapshotFolder.fromJson)
          .toList(),
      notes: notesRaw
          .whereType<Map<String, dynamic>>()
          .map(SnapshotNote.fromJson)
          .toList(),
      // 旧版备份没有该字段，按空处理
      attachments: attachmentsRaw is List
          ? attachmentsRaw
                .whereType<Map<String, dynamic>>()
                .map(SnapshotAttachment.fromJson)
                .toList()
          : const [],
    );
  }

  /// 快照里的时间，用于界面展示
  DateTime get exportedTime => DateTime.fromMillisecondsSinceEpoch(exportedAt);

  /// 内容摘要，用于导入前确认
  String get summary {
    final int todo = notes.where((n) => n.kind == 2).length;
    final int note = notes.length - todo;
    final String base = '笔记 $note · 待办 $todo · 分类 ${folders.length}';
    return attachments.isEmpty ? base : '$base · 图片 ${attachments.length}';
  }

  /// 校验数据可用性：条目 id 必须唯一
  void validate() {
    final ids = notes.map((n) => n.id).toSet();
    if (ids.length != notes.length) {
      throw const FormatException('备份文件中存在重复的笔记 id');
    }
    final folderIds = folders.map((f) => f.id).toSet();
    if (folderIds.length != folders.length) {
      throw const FormatException('备份文件中存在重复的分类 id');
    }
  }
}

class SnapshotFolder {
  final int id;
  final String name;
  final int colorIndex;
  final int createdAt;
  final int sortOrder;

  const SnapshotFolder({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.createdAt,
    required this.sortOrder,
  });

  factory SnapshotFolder.fromRow(Folder f) => SnapshotFolder(
    id: f.id,
    name: f.name,
    colorIndex: f.colorIndex,
    createdAt: f.createdAt,
    sortOrder: f.sortOrder,
  );

  factory SnapshotFolder.fromJson(Map<String, dynamic> j) => SnapshotFolder(
    id: (j['id'] as num).toInt(),
    name: (j['name'] as String?) ?? '未命名分类',
    colorIndex: (j['colorIndex'] as num?)?.toInt() ?? 0,
    createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
    sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorIndex': colorIndex,
    'createdAt': createdAt,
    'sortOrder': sortOrder,
  };

  FoldersCompanion toCompanion() => FoldersCompanion(
    id: Value(id),
    name: Value(name),
    colorIndex: Value(colorIndex),
    createdAt: Value(createdAt),
    sortOrder: Value(sortOrder),
  );
}

class SnapshotNote {
  final int id;
  final String title;
  final String content;
  final int? folderId;
  final bool pinned;
  final bool favorite;

  /// 0 笔记 / 2 待办（旧值 1 便签已移除，导入时归一化为笔记）
  final int kind;
  final bool done;
  final bool deleted;
  final int createdAt;
  final int updatedAt;

  const SnapshotNote({
    required this.id,
    required this.title,
    required this.content,
    required this.folderId,
    required this.pinned,
    required this.favorite,
    required this.kind,
    required this.done,
    required this.deleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SnapshotNote.fromRow(Note n) => SnapshotNote(
    id: n.id,
    title: n.title,
    content: n.content,
    folderId: n.folderId,
    pinned: n.pinned,
    favorite: n.favorite,
    kind: n.kind,
    done: n.done,
    deleted: n.deleted,
    createdAt: n.createdAt,
    updatedAt: n.updatedAt,
  );

  factory SnapshotNote.fromJson(Map<String, dynamic> j) => SnapshotNote(
    id: (j['id'] as num).toInt(),
    title: (j['title'] as String?) ?? '',
    content: (j['content'] as String?) ?? '',
    folderId: (j['folderId'] as num?)?.toInt(),
    pinned: (j['pinned'] as bool?) ?? false,
    favorite: (j['favorite'] as bool?) ?? false,
    // 旧备份/远端里的 kind=1（便签）统一归一化为笔记，避免孤儿类型
    kind: switch ((j['kind'] as num?)?.toInt() ?? 0) {
      2 => 2,
      _ => 0,
    },
    done: (j['done'] as bool?) ?? false,
    deleted: (j['deleted'] as bool?) ?? false,
    createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
    updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'folderId': folderId,
    'pinned': pinned,
    'favorite': favorite,
    'kind': kind,
    'done': done,
    'deleted': deleted,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  NotesCompanion toCompanion() => NotesCompanion(
    id: Value(id),
    title: Value(title),
    content: Value(content),
    folderId: Value(folderId),
    pinned: Value(pinned),
    favorite: Value(favorite),
    kind: Value(kind),
    done: Value(done),
    deleted: Value(deleted),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
  );

  /// 合并时判断谁更新
  bool isNewerThan(SnapshotNote other) => updatedAt > other.updatedAt;
}

/// 图片附件在快照里的元数据；文件本体放在 zip 的 images/ 下
class SnapshotAttachment {
  final int id;
  final int noteId;
  final String fileName;
  final int sortOrder;
  final int createdAt;

  const SnapshotAttachment({
    required this.id,
    required this.noteId,
    required this.fileName,
    required this.sortOrder,
    required this.createdAt,
  });

  factory SnapshotAttachment.fromRow(Attachment a) => SnapshotAttachment(
    id: a.id,
    noteId: a.noteId,
    fileName: a.fileName,
    sortOrder: a.sortOrder,
    createdAt: a.createdAt,
  );

  factory SnapshotAttachment.fromJson(Map<String, dynamic> j) =>
      SnapshotAttachment(
        id: (j['id'] as num?)?.toInt() ?? 0,
        noteId: (j['noteId'] as num?)?.toInt() ?? 0,
        fileName: (j['fileName'] as String?) ?? '',
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'noteId': noteId,
    'fileName': fileName,
    'sortOrder': sortOrder,
    'createdAt': createdAt,
  };

  AttachmentsCompanion toCompanion() => AttachmentsCompanion(
    id: Value(id),
    noteId: Value(noteId),
    fileName: Value(fileName),
    sortOrder: Value(sortOrder),
    createdAt: Value(createdAt),
  );
}
