import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../images/image_store.dart';
import '../models/note_kind.dart';

/// 仓储层：对上层屏蔽 drift 细节，提供面向业务的 API。
/// 上层（Provider/UI）只依赖此类，不直接触碰 DAO。
class NoteRepository {
  final AppDatabase _db;

  NoteRepository(this._db);

  AppDatabase get raw => _db;

  // ---- 查询流（响应式，数据库变化自动推送） ----
  Stream<List<Note>> watchAllActive() => _db.noteDao.selectAllActive().watch();
  Stream<List<Note>> watchKind(NoteKind kind) =>
      _db.noteDao.selectByKind(kind.value).watch();
  Stream<List<Note>> watchByFolder(int folderId) =>
      _db.noteDao.selectByFolder(folderId).watch();
  Stream<List<Note>> watchFavorites() => _db.noteDao.selectFavorites().watch();
  Stream<List<Note>> watchTrash() => _db.noteDao.selectTrash().watch();
  Stream<List<Note>> watchSearch(String keyword) =>
      _db.noteDao.search(keyword).watch();

  Stream<List<Folder>> watchFolders() => _db.folderDao.selectAll().watch();

  Future<Note?> findNote(int id) => _db.noteDao.findById(id);
  Future<Folder?> findFolder(int id) => _db.folderDao.findById(id);

  // ---- 笔记操作 ----
  Future<int> createNote({
    String title = '',
    String content = '',
    int? folderId,
    NoteKind kind = NoteKind.note,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.noteDao.insertNote(
      NotesCompanion.insert(
        title: Value(title),
        content: Value(content),
        folderId: Value(folderId),
        kind: Value(kind.value),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updateNote({
    required int id,
    required String title,
    required String content,
    int? folderId,
  }) async {
    final existing = await _db.noteDao.findById(id);
    if (existing == null) return;
    await _db.noteDao.updateNote(
      existing.copyWith(
        title: title,
        content: content,
        folderId: Value(folderId),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> softDelete(int id) => _db.noteDao.softDelete(id);
  Future<void> restore(int id) => _db.noteDao.restore(id);
  Future<void> permanentlyDelete(int id) => _db.noteDao.permanentlyDelete(id);
  Future<void> togglePin(int id) async {
    final n = await _db.noteDao.findById(id);
    if (n != null) await _db.noteDao.togglePin(n);
  }

  Future<void> toggleFavorite(int id) async {
    final n = await _db.noteDao.findById(id);
    if (n != null) await _db.noteDao.toggleFavorite(n);
  }

  Future<void> moveToFolder(int noteId, int? folderId) =>
      _db.noteDao.moveToFolder(noteId, folderId);

  /// 切换内容类型（笔记 / 待办）
  Future<void> setKind(int id, NoteKind kind) =>
      _db.noteDao.setKind(id, kind.value);

  /// 勾选 / 取消勾选待办
  Future<void> setDone(int id, bool done) => _db.noteDao.setDone(id, done);

  /// 待办勾选状态取反
  Future<void> toggleDone(int id) async {
    final n = await _db.noteDao.findById(id);
    if (n != null) await _db.noteDao.setDone(id, !n.done);
  }

  Future<void> emptyTrash() async {
    final trashed = await _db.noteDao.selectTrash().get();
    for (final n in trashed) {
      await permanentlyDelete(n.id);
    }
    // 顺带清掉没有任何归属的图片文件
    final keep = (await _db.attachmentDao.allRaw())
        .map((a) => a.fileName)
        .toSet();
    await ImageStore.pruneOrphans(keep);
  }

  // ---- 图片附件 ----
  Stream<List<Attachment>> watchAttachments(int noteId) =>
      _db.attachmentDao.selectByNote(noteId).watch();

  Future<List<Attachment>> attachmentsOf(int noteId) =>
      _db.attachmentDao.selectByNote(noteId).get();

  Future<int> addAttachment(int noteId, String fileName) async {
    final existing = await _db.attachmentDao.selectByNote(noteId).get();
    return _db.attachmentDao.insertOne(
      AttachmentsCompanion.insert(
        noteId: noteId,
        fileName: fileName,
        sortOrder: Value(existing.length),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// 移除一张图片：先删记录，再删文件
  Future<void> removeAttachment(int attachmentId) async {
    final row = await _db.attachmentDao.findById(attachmentId);
    if (row == null) return;
    await _db.attachmentDao.deleteById(attachmentId);
    await ImageStore.delete(row.fileName);
  }

  /// 列表缩略图用：noteId → 首图文件名
  Stream<Map<int, String>> watchFirstImage() {
    final query = _db.select(_db.attachments)
      ..orderBy([
        (a) => OrderingTerm(expression: a.sortOrder, mode: OrderingMode.asc),
        (a) => OrderingTerm(expression: a.id, mode: OrderingMode.asc),
      ]);
    return query.watch().map((rows) {
      final map = <int, String>{};
      for (final a in rows) {
        map.putIfAbsent(a.noteId, () => a.fileName);
      }
      return map;
    });
  }

  Future<Map<int, String>> firstImageMap() async {
    final rows = await _db.attachmentDao.allRaw();
    rows.sort((a, b) {
      if (a.noteId != b.noteId) return a.noteId.compareTo(b.noteId);
      if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
      return a.id.compareTo(b.id);
    });
    final map = <int, String>{};
    for (final a in rows) {
      map.putIfAbsent(a.noteId, () => a.fileName);
    }
    return map;
  }

  // ---- 文件夹操作 ----
  Future<int> createFolder(String name, int colorIndex) async {
    final maxOrder = await _db.folderDao.selectAll().get();
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.folderDao.insertFolder(
      FoldersCompanion.insert(
        name: name,
        colorIndex: Value(colorIndex),
        createdAt: now,
        sortOrder: Value(maxOrder.length),
      ),
    );
  }

  Future<void> renameFolder(int id, String name) async {
    final f = await _db.folderDao.findById(id);
    if (f != null) await _db.folderDao.updateFolder(f.copyWith(name: name));
  }

  Future<void> deleteFolder(int id) async {
    // 将该文件夹下的笔记移出（folderId=null），再删文件夹
    final notesInFolder = await _db.noteDao.selectByFolder(id).get();
    for (final n in notesInFolder) {
      await _db.noteDao.moveToFolder(n.id, null);
    }
    await _db.folderDao.deleteFolder(id);
  }

  Future<int> countNotesInFolder(int folderId) =>
      _db.noteDao.countNotesInFolder(folderId);

  Future<int> countActiveNotes() => _db.noteDao.countActive();
  Future<int> countFavorites() => _db.noteDao.countFavorites();
  Future<int> countByKind(NoteKind kind) => _db.noteDao.countByKind(kind.value);
  Future<int> countTodoOpen() => _db.noteDao.countTodoOpen();
}
