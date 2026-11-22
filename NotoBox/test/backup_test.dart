import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noto_box/data/database/app_database.dart';
import 'package:noto_box/data/images/image_store.dart';
import 'package:noto_box/data/sync/backup_service.dart';
import 'package:noto_box/data/sync/snapshot.dart';

/// 备份 / 快照 / 合并逻辑测试 —— 全部走内存 SQLite 与真实文件读写。
void main() {
  late AppDatabase db;
  late Directory tmp;
  late BackupService backup;

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('notobox_backup_test');
    backup = BackupService(db, directory: tmp);
  });

  tearDown(() async {
    await db.close();
    ImageStore.resetForTest();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<int> addNote({
    String title = '测试',
    int kind = 0,
    bool done = false,
    bool deleted = false,
    int updatedAt = 1000,
    int? folderId,
  }) {
    return db.noteDao.insertNote(
      NotesCompanion.insert(
        title: Value(title),
        content: const Value('内容'),
        kind: Value(kind),
        done: Value(done),
        deleted: Value(deleted),
        folderId: Value(folderId),
        createdAt: 1000,
        updatedAt: updatedAt,
      ),
    );
  }

  test('快照包含全部字段并可往返解析', () async {
    final folderId = await db.folderDao.insertFolder(
      FoldersCompanion.insert(
        name: '工程',
        createdAt: 500,
        colorIndex: const Value(2),
      ),
    );
    await addNote(
      title: '待办一',
      kind: 2,
      done: true,
      updatedAt: 2000,
      folderId: folderId,
    );

    final json = await backup.buildJson();
    final snap = Snapshot.decode(json);

    expect(snap.folders.length, 1);
    expect(snap.folders.first.name, '工程');
    expect(snap.folders.first.colorIndex, 2);
    expect(snap.notes.length, 1);
    final n = snap.notes.first;
    expect(n.title, '待办一');
    expect(n.kind, 2);
    expect(n.done, isTrue);
    expect(n.folderId, folderId);
    expect(n.updatedAt, 2000);
  });

  test('软删除的内容也会进入快照（回收站要能跨设备恢复）', () async {
    await addNote(title: '已删除', deleted: true);
    final snap = Snapshot.decode(await backup.buildJson());
    expect(snap.notes.length, 1);
    expect(snap.notes.first.deleted, isTrue);
  });

  test('合并导入：远端较新的覆盖本地，较早的跳过，新条目补齐', () async {
    final localId = await addNote(title: '本地旧', updatedAt: 100);
    final keepId = await addNote(title: '本地新', updatedAt: 900);

    // 构造远端快照：同 id 但更新；另一条比本地旧；再补一条新 id
    final remoteId = localId + 100;
    final remote = Snapshot(
      exportedAt: 1,
      folders: const [],
      notes: [
        SnapshotNote(
          id: localId,
          title: '远端新',
          content: '远端内容',
          folderId: null,
          pinned: false,
          favorite: false,
          kind: 0,
          done: false,
          deleted: false,
          createdAt: 100,
          updatedAt: 500,
        ),
        SnapshotNote(
          id: keepId,
          title: '远端旧',
          content: '',
          folderId: null,
          pinned: false,
          favorite: false,
          kind: 0,
          done: false,
          deleted: false,
          createdAt: 900,
          updatedAt: 50,
        ),
        SnapshotNote(
          id: remoteId,
          title: '远端独有',
          content: '',
          folderId: null,
          pinned: false,
          favorite: false,
          kind: 2,
          done: false,
          deleted: false,
          createdAt: 600,
          updatedAt: 600,
        ),
      ],
    );

    final outcome = await backup.importRaw(remote.encode());

    expect(outcome.added, 1);
    expect(outcome.updated, 1);
    expect(outcome.skipped, 1);

    expect((await db.noteDao.findById(localId))!.title, '远端新');
    expect((await db.noteDao.findById(keepId))!.title, '本地新');
    expect((await db.noteDao.findById(remoteId))!.title, '远端独有');
  });

  test('覆盖导入会清空本地再写入，且先自动留一份快照', () async {
    await addNote(title: '会被清掉', updatedAt: 100);
    final remote = Snapshot(
      exportedAt: 1,
      folders: const [],
      notes: [
        const SnapshotNote(
          id: 42,
          title: '只剩这条',
          content: '',
          folderId: null,
          pinned: false,
          favorite: false,
          kind: 0,
          done: false,
          deleted: false,
          createdAt: 1,
          updatedAt: 1,
        ),
      ],
    );

    final outcome = await backup.importRaw(remote.encode(), replace: true);
    expect(outcome.replaced, isTrue);

    final all = await db.noteDao.allRaw();
    expect(all.length, 1);
    expect(all.first.id, 42);

    // 覆盖前自动生成了一份 before-restore 快照
    final files = await backup.listSnapshots();
    expect(files.any((f) => f.name.contains('before-restore')), isTrue);
  });

  test('非法备份被拒绝且不写库', () async {
    await addNote(title: '原有数据');

    expect(() => backup.importRaw('这不是 json'), throwsA(isA<FormatException>()));
    expect(
      () => backup.importRaw(
        '{"app":"OtherApp","version":1,"folders":[],"notes":[]}',
      ),
      throwsA(isA<FormatException>()),
    );

    final all = await db.noteDao.allRaw();
    expect(all.length, 1);
    expect(all.first.title, '原有数据');
  });

  test('自动快照只保留最近 7 份', () async {
    await addNote(title: '有数据');
    for (int i = 0; i < 10; i++) {
      await backup.writeSnapshot(suffix: 'round$i');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final files = await backup.listSnapshots();
    expect(files.length, BackupService.keepSnapshots);
  });

  test('previewOf 不写库，只返回摘要', () async {
    await addNote(title: '本地原有');
    final remote = Snapshot(
      exportedAt: 123,
      folders: const [],
      notes: [
        const SnapshotNote(
          id: 999,
          title: '远端条目',
          content: '',
          folderId: null,
          pinned: false,
          favorite: false,
          kind: 2,
          done: false,
          deleted: false,
          createdAt: 1,
          updatedAt: 1,
        ),
      ],
    );

    final preview = await backup.previewOf(remote.encode());
    expect(preview.notes.length, 1);
    expect(preview.summary.contains('待办 1'), isTrue);

    final all = await db.noteDao.allRaw();
    expect(all.length, 1);
    expect(all.first.title, '本地原有');
  });

  test('zip 备份包含图片，导入后图片文件与记录都还原', () async {
    ImageStore.overrideDir('${tmp.path}/images');
    final bytes = Uint8List.fromList(List<int>.filled(64, 7));
    await ImageStore.writeRaw('pic1.jpg', bytes);

    final noteId = await addNote(title: '带图笔记');
    await db.attachmentDao.insertOne(
      AttachmentsCompanion.insert(
        noteId: noteId,
        fileName: 'pic1.jpg',
        createdAt: 1,
      ),
    );

    final pkg = await backup.buildPackage();
    expect(pkg.length, greaterThan(0));
    // zip 魔数 PK
    expect(pkg[0], 0x50);
    expect(pkg[1], 0x4B);

    // 清空本地数据与图片文件，模拟换机
    await db.noteDao.clearAll();
    await db.attachmentDao.clearAll();
    await ImageStore.delete('pic1.jpg');
    expect(await ImageStore.readBytes('pic1.jpg'), isNull);

    final outcome = await backup.importPackage(pkg);
    expect(outcome.added, 1);

    final rows = await db.attachmentDao.selectByNote(noteId).get();
    expect(rows.length, 1);
    expect(rows.first.fileName, 'pic1.jpg');

    final restored = await ImageStore.readBytes('pic1.jpg');
    expect(restored, isNotNull);
    expect(restored!.length, 64);
  });

  test('旧版纯 JSON 备份仍可导入（不含图片字段）', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final legacy =
        '{"app":"NotoBox","version":1,"exportedAt":$now,'
        '"folders":[],"notes":[{"id":7,"title":"旧备份","content":"x",'
        '"folderId":null,"pinned":false,"favorite":false,"kind":0,'
        '"done":false,"deleted":false,"createdAt":1,"updatedAt":1}]}';

    final outcome = await backup.importRaw(legacy);
    expect(outcome.added, 1);
    expect((await db.noteDao.findById(7))!.title, '旧备份');
  });

  test('附件表缺失时启动会自动补建（历史库自愈）', () async {
    final File dbFile = File('${tmp.path}/self_heal.sqlite');

    final AppDatabase first = AppDatabase.test(NativeDatabase(dbFile));
    await first.customStatement('DROP TABLE IF EXISTS attachments');
    await first.close();

    final AppDatabase second = AppDatabase.test(NativeDatabase(dbFile));
    // 任意查询触发打开 → beforeOpen 中补建表
    final rows = await second.attachmentDao.allRaw();
    expect(rows, isEmpty);
    await second.close();
  });

  test('旧版 kind=1（便签）导入后归一化为笔记', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final legacy =
        '{"app":"NotoBox","version":1,"exportedAt":$now,'
        '"folders":[],"notes":[{"id":8,"title":"旧便签","content":"x",'
        '"folderId":null,"pinned":false,"favorite":false,"kind":1,'
        '"done":false,"deleted":false,"createdAt":1,"updatedAt":1}]}';

    final outcome = await backup.importRaw(legacy);
    expect(outcome.added, 1);

    final n = await db.noteDao.findById(8);
    expect(n!.kind, 0, reason: '旧便签 kind=1 应归一化为笔记 kind=0');
  });
}
