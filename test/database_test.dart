import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noto_box/data/database/app_database.dart';

/// 数据库层单元测试 —— 使用内存 SQLite，验证真实 CRUD 与业务规则。
void main() {
  late AppDatabase db;

  setUp(() {
    // 使用 drift 的 NativeDatabase 内存模式
    db = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('新建笔记默认未删除、未置顶、未收藏', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.noteDao.insertNote(
      NotesCompanion.insert(
        title: const Value('测试标题'),
        content: const Value('内容'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    final note = (await db.noteDao.findById(id))!;
    expect(note.title, '测试标题');
    expect(note.deleted, isFalse);
    expect(note.pinned, isFalse);
    expect(note.favorite, isFalse);
  });

  test('软删除后不出现在活跃列表，但出现在回收站', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.noteDao.insertNote(
      NotesCompanion.insert(
        title: const Value('待删除'),
        content: const Value('x'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.noteDao.softDelete(id);

    final active = await db.noteDao.selectAllActive().get();
    expect(active.any((n) => n.id == id), isFalse);

    final trash = await db.noteDao.selectTrash().get();
    expect(trash.any((n) => n.id == id), isTrue);
  });

  test('恢复后重新出现在活跃列表', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.noteDao.insertNote(
      NotesCompanion.insert(
        title: const Value('待恢复'),
        content: const Value('x'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.noteDao.softDelete(id);
    await db.noteDao.restore(id);
    final active = await db.noteDao.selectAllActive().get();
    expect(active.any((n) => n.id == id), isTrue);
  });

  test('收藏与置顶切换生效', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.noteDao.insertNote(
      NotesCompanion.insert(
        title: const Value('标记测试'),
        content: const Value('x'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    var note = (await db.noteDao.findById(id))!;
    await db.noteDao.toggleFavorite(note);
    await db.noteDao.togglePin(note);
    note = (await db.noteDao.findById(id))!;
    expect(note.favorite, isTrue);
    expect(note.pinned, isTrue);

    final favs = await db.noteDao.selectFavorites().get();
    expect(favs.any((n) => n.id == id), isTrue);
  });

  test('关键词搜索命中标题和正文', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.noteDao.insertNote(
      NotesCompanion.insert(
        title: const Value(' Flutter 学习笔记'),
        content: const Value('Riverpod 状态管理'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.noteDao.insertNote(
      NotesCompanion.insert(
        title: const Value('购物清单'),
        content: const Value('牛奶 鸡蛋'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    final byTitle = await db.noteDao.search('Flutter').get();
    expect(byTitle.length, 1);
    final byContent = await db.noteDao.search('Riverpod').get();
    expect(byContent.length, 1);
    final none = await db.noteDao.search('不存在').get();
    expect(none, isEmpty);
  });

  test('笔记 / 待办两种类型互不干扰，转换后归位', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final noteId = await db.noteDao.insertNote(
      NotesCompanion.insert(
        title: const Value('普通笔记'),
        content: const Value('x'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    final todoId = await db.noteDao.insertNote(
      NotesCompanion.insert(
        title: const Value('一件待办'),
        content: const Value('z'),
        kind: const Value(2),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final notes = await db.noteDao.selectByKind(0).get();
    final todos = await db.noteDao.selectByKind(2).get();
    expect(notes.map((n) => n.id), [noteId]);
    expect(todos.map((n) => n.id), [todoId]);

    // 把笔记转成待办后应从笔记列表消失
    await db.noteDao.setKind(noteId, 2);
    final notesAfter = await db.noteDao.selectByKind(0).get();
    final todosAfter = await db.noteDao.selectByKind(2).get();
    expect(notesAfter.any((n) => n.id == noteId), isFalse);
    expect(todosAfter.length, 2);
    expect(await db.noteDao.countByKind(2), 2);
  });

  test('待办勾选生效，未完成计数正确且完成项沉底', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    Future<int> add(String title, {bool done = false, int offset = 0}) =>
        db.noteDao.insertNote(
          NotesCompanion.insert(
            title: Value(title),
            content: const Value(''),
            kind: const Value(2),
            done: Value(done),
            createdAt: now,
            updatedAt: now + offset,
          ),
        );

    final doneId = await add('已完成的事', done: true);
    final openId = await add('未完成的事', offset: 1000);

    expect(await db.noteDao.countTodoOpen(), 1);
    expect(await db.noteDao.countByKind(2), 2);

    // 未完成项排在完成项之前
    final list = await db.noteDao.selectByKind(2).get();
    expect(list.first.id, openId);
    expect(list.last.id, doneId);

    // 勾选后计入完成，未完成计数归零
    await db.noteDao.setDone(openId, true);
    expect(await db.noteDao.countTodoOpen(), 0);
    final after = await db.noteDao.selectByKind(2).get();
    expect(after.every((n) => n.done), isTrue);

    // 取消勾选恢复
    await db.noteDao.setDone(openId, false);
    expect(await db.noteDao.countTodoOpen(), 1);
  });

  test('文件夹 CRUD 与笔记归类', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final folderId = await db.folderDao.insertFolder(
      FoldersCompanion.insert(name: '工作', createdAt: now),
    );
    final noteId = await db.noteDao.insertNote(
      NotesCompanion.insert(
        title: const Value('工作笔记'),
        content: const Value('x'),
        folderId: Value(folderId),
        createdAt: now,
        updatedAt: now,
      ),
    );
    final inFolder = await db.noteDao.selectByFolder(folderId).get();
    expect(inFolder.any((n) => n.id == noteId), isTrue);
    final count = await db.noteDao.countNotesInFolder(folderId);
    expect(count, 1);
  });
}
