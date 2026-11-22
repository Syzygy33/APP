import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';
part 'app_database.g.dart';

@DriftDatabase(
  tables: [Folders, Notes, Attachments],
  daos: [NoteDao, FolderDao, AttachmentDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 测试专用构造：注入自定义执行器（如内存数据库）。
  AppDatabase.test(super.executor);

  @override
  int get schemaVersion => 5;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'notobox_db');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2：新增「便签」标记列
      if (from < 2) {
        await m.addColumn(notes, notes.isSticky);
      }
      // v3：引入统一的 kind（0 笔记 / 1 便签 / 2 待办）与待办完成态 done。
      // 旧库里的 is_sticky 数据搬到 kind 上，之后该列只作为结构遗留存在。
      if (from < 3) {
        await m.addColumn(notes, notes.kind);
        await m.addColumn(notes, notes.done);
        await customStatement('UPDATE notes SET kind = 1 WHERE is_sticky = 1');
      }
      // v5：移除「便签」类型。直接删除 kind=1 的内容及其图片附件。
      if (from < 5) {
        await customStatement(
          'DELETE FROM attachments WHERE note_id IN '
          '(SELECT id FROM notes WHERE kind = 1)',
        );
        await customStatement('DELETE FROM notes WHERE kind = 1');
      }
    },
    beforeOpen: (details) async {
      // 兜底自愈：历史上出现过「版本号已升到 4 但附件表未创建」的库，
      // 这里每次打开都确保表存在，避免同步/图片查询直接报 no such table。
      await customStatement('''
        CREATE TABLE IF NOT EXISTS attachments (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          note_id INTEGER NOT NULL REFERENCES notes (id),
          file_name TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');
    },
  );
}

/// 笔记 DAO —— 所有查询均排除软删除项，除非显式查询回收站。
@DriftAccessor(tables: [Notes])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(super.db);

  /// 活跃笔记（未删除），按置顶优先 + 更新时间倒序
  Selectable<Note> selectAllActive() => select(notes)
    ..where((n) => n.deleted.equals(false))
    ..orderBy([
      (n) => OrderingTerm(expression: n.pinned, mode: OrderingMode.desc),
      (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
    ]);

  /// 按类型取活跃列表（0 笔记 / 1 便签 / 2 待办）。
  /// 待办额外把未完成项排在前面，完成项沉底。
  Selectable<Note> selectByKind(int kind) {
    final query = select(notes)
      ..where((n) => n.deleted.equals(false) & n.kind.equals(kind));
    if (kind == 2) {
      query.orderBy([
        (n) => OrderingTerm(expression: n.done, mode: OrderingMode.asc),
        (n) => OrderingTerm(expression: n.pinned, mode: OrderingMode.desc),
        (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
      ]);
    } else {
      query.orderBy([
        (n) => OrderingTerm(expression: n.pinned, mode: OrderingMode.desc),
        (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
      ]);
    }
    return query;
  }

  /// 某文件夹下的活跃笔记
  Selectable<Note> selectByFolder(int folderId) => select(notes)
    ..where((n) => n.deleted.equals(false) & n.folderId.equals(folderId))
    ..orderBy([
      (n) => OrderingTerm(expression: n.pinned, mode: OrderingMode.desc),
      (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
    ]);

  /// 收藏笔记
  Selectable<Note> selectFavorites() => select(notes)
    ..where((n) => n.deleted.equals(false) & n.favorite.equals(true))
    ..orderBy([
      (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
    ]);

  /// 回收站
  Selectable<Note> selectTrash() => select(notes)
    ..where((n) => n.deleted.equals(true))
    ..orderBy([
      (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
    ]);

  /// 关键词搜索（标题或正文，未删除）
  Selectable<Note> search(String keyword) {
    final kw = '%$keyword%';
    return select(notes)
      ..where(
        (n) =>
            n.deleted.equals(false) & (n.title.like(kw) | n.content.like(kw)),
      )
      ..orderBy([
        (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
      ]);
  }

  Future<Note?> findById(int id) =>
      (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<int> insertNote(NotesCompanion note) => into(notes).insert(note);

  Future<bool> updateNote(Note note) => update(notes).replace(note);

  Future<int> softDelete(int id) async =>
      (update(notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(deleted: const Value(true)),
      );

  Future<int> restore(int id) async =>
      (update(notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(deleted: const Value(false)),
      );

  Future<int> permanentlyDelete(int id) =>
      (delete(notes)..where((n) => n.id.equals(id))).go();

  Future<int> togglePin(Note note) =>
      (update(notes)..where((n) => n.id.equals(note.id))).write(
        NotesCompanion(pinned: Value(!note.pinned)),
      );

  Future<int> toggleFavorite(Note note) =>
      (update(notes)..where((n) => n.id.equals(note.id))).write(
        NotesCompanion(favorite: Value(!note.favorite)),
      );

  Future<int> moveToFolder(int noteId, int? folderId) =>
      (update(notes)..where((n) => n.id.equals(noteId))).write(
        NotesCompanion(folderId: Value(folderId)),
      );

  /// 统计
  Future<int> countActive() {
    final query = selectOnly(notes)
      ..where(notes.deleted.equals(false))
      ..addColumns([notes.id.count()]);
    return query.map((row) => row.read(notes.id.count()) ?? 0).getSingle();
  }

  Future<int> countFavorites() {
    final query = selectOnly(notes)
      ..where(notes.deleted.equals(false) & notes.favorite.equals(true))
      ..addColumns([notes.id.count()]);
    return query.map((row) => row.read(notes.id.count()) ?? 0).getSingle();
  }

  /// 某类型的数量
  Future<int> countByKind(int kind) {
    final query = selectOnly(notes)
      ..where(notes.deleted.equals(false) & notes.kind.equals(kind))
      ..addColumns([notes.id.count()]);
    return query.map((row) => row.read(notes.id.count()) ?? 0).getSingle();
  }

  /// 未完成的待办数量
  Future<int> countTodoOpen() {
    final query = selectOnly(notes)
      ..where(
        notes.deleted.equals(false) &
            notes.kind.equals(2) &
            notes.done.equals(false),
      )
      ..addColumns([notes.id.count()]);
    return query.map((row) => row.read(notes.id.count()) ?? 0).getSingle();
  }

  /// 切换内容类型（笔记 / 便签 / 待办）
  Future<int> setKind(int id, int kind) => (update(
    notes,
  )..where((n) => n.id.equals(id))).write(NotesCompanion(kind: Value(kind)));

  /// 勾选 / 取消勾选待办
  Future<int> setDone(int id, bool done) => (update(
    notes,
  )..where((n) => n.id.equals(id))).write(NotesCompanion(done: Value(done)));

  /// 某文件夹的活跃笔记数
  Future<int> countNotesInFolder(int folderId) {
    final query = selectOnly(notes)
      ..where(notes.deleted.equals(false) & notes.folderId.equals(folderId))
      ..addColumns([notes.id.count()]);
    return query.map((row) => row.read(notes.id.count()) ?? 0).getSingle();
  }

  // ---- 备份 / 同步专用：需要覆盖回收站内容 ----

  /// 全部笔记，包含已软删除的（备份与同步要求完整快照）
  Future<List<Note>> allRaw() => select(notes).get();

  /// 按主键写入或更新（保留原 id，供导入/同步使用）
  Future<int> upsertRaw(NotesCompanion note) =>
      into(notes).insertOnConflictUpdate(note);

  /// 清空全部笔记（仅用于「覆盖式恢复」，调用前须先自动备份）
  Future<void> clearAll() => delete(notes).go();
}

/// 文件夹 DAO
@DriftAccessor(tables: [Folders])
class FolderDao extends DatabaseAccessor<AppDatabase> with _$FolderDaoMixin {
  FolderDao(super.db);

  Selectable<Folder> selectAll() => select(folders)
    ..orderBy([
      (f) => OrderingTerm(expression: f.sortOrder, mode: OrderingMode.asc),
      (f) => OrderingTerm(expression: f.createdAt, mode: OrderingMode.asc),
    ]);

  Future<Folder?> findById(int id) =>
      (select(folders)..where((f) => f.id.equals(id))).getSingleOrNull();

  Future<int> insertFolder(FoldersCompanion folder) =>
      into(folders).insert(folder);

  Future<bool> updateFolder(Folder folder) => update(folders).replace(folder);

  Future<int> deleteFolder(int id) =>
      (delete(folders)..where((f) => f.id.equals(id))).go();

  /// 全部分类（备份 / 同步用）
  Future<List<Folder>> allRaw() => select(folders).get();

  /// 按主键写入或更新
  Future<int> upsertRaw(FoldersCompanion folder) =>
      into(folders).insertOnConflictUpdate(folder);

  /// 清空全部分类（仅用于「覆盖式恢复」）
  Future<void> clearAll() => delete(folders).go();
}

/// 图片附件 DAO
@DriftAccessor(tables: [Attachments])
class AttachmentDao extends DatabaseAccessor<AppDatabase>
    with _$AttachmentDaoMixin {
  AttachmentDao(super.db);

  Selectable<Attachment> selectByNote(int noteId) => select(attachments)
    ..where((a) => a.noteId.equals(noteId))
    ..orderBy([
      (a) => OrderingTerm(expression: a.sortOrder, mode: OrderingMode.asc),
      (a) => OrderingTerm(expression: a.id, mode: OrderingMode.asc),
    ]);

  Future<int> insertOne(AttachmentsCompanion item) =>
      into(attachments).insert(item);

  Future<Attachment?> findById(int id) =>
      (select(attachments)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<void> deleteById(int id) =>
      (delete(attachments)..where((a) => a.id.equals(id))).go();

  Future<void> deleteByNote(int noteId) =>
      (delete(attachments)..where((a) => a.noteId.equals(noteId))).go();

  Future<int> countByNote(int noteId) {
    final query = selectOnly(attachments)
      ..where(attachments.noteId.equals(noteId))
      ..addColumns([attachments.id.count()]);
    return query
        .map((row) => row.read(attachments.id.count()) ?? 0)
        .getSingle();
  }

  // ---- 备份 / 同步 ----

  Future<List<Attachment>> allRaw() => select(attachments).get();

  Future<int> upsertRaw(AttachmentsCompanion item) =>
      into(attachments).insertOnConflictUpdate(item);

  Future<void> clearAll() => delete(attachments).go();
}
