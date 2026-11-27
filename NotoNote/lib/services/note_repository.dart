import '../models/attachment.dart';
import '../models/category.dart';
import '../models/note.dart';
import 'id.dart';
import 'notes_revision.dart';

/// 笔记读写接口。
///
/// 第一版只有内存实现；接本地数据库（sqflite / drift）或远端时，
/// 新增一个实现即可，页面层不用改。
abstract interface class NoteRepository {
  Future<List<Note>> load();

  Future<Note> create({
    required String title,
    required String body,
    String category = NoteCategory.fallbackName,
    List<NoteAttachment> attachments = const [],
  });

  /// 按传入值原样保存并返回。
  ///
  /// **不自动刷新 `updatedAt`**：置顶之类的操作不该改变"更新时间"。
  /// 正文改动时由调用方自己带上 `updatedAt: DateTime.now()`。
  Future<Note?> update(Note note);

  /// 软删除：标记 [Note.deletedAt]，笔记进入「最近删除」。
  Future<void> delete(String id);

  /// 回收站列表，按删除时间从近到远。
  Future<List<Note>> loadTrash();

  /// 从回收站恢复到正常列表。
  Future<void> restore(String id);

  /// 彻底删除单条，不可恢复。
  Future<void> purge(String id);

  /// 清空回收站。
  Future<void> purgeAll();

  /// 把 [from] 分类下的所有笔记改到 [to] 分类。
  /// 删除分类但保留内容时用（内容转为「未分类」）。
  Future<void> reassignCategory(String from, String to);

  /// 软删除 [category] 分类下的所有笔记。
  /// 「删除分类及其中所有内容」时用。
  Future<void> deleteByCategory(String category);
}

/// 内存实现：几条不同长度的假数据，用来验证列表的变高行与滚动。
class MemoryNoteRepository implements NoteRepository {
  MemoryNoteRepository({List<Note>? seed})
    : _notes = List<Note>.of(seed ?? _seedNotes());

  final List<Note> _notes;

  @override
  Future<List<Note>> load() async {
    // 留一点延迟，让加载态真实出现一次，避免 NullStatusSwitcher 从未被验证
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final sorted = [
      for (final note in _notes)
        if (!note.isDeleted) note,
    ]..sort((a, b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return List<Note>.unmodifiable(sorted);
  }

  @override
  Future<Note> create({
    required String title,
    required String body,
    String category = NoteCategory.fallbackName,
    List<NoteAttachment> attachments = const [],
  }) async {
    final now = DateTime.now();
    final note = Note(
      id: newId('local'),
      title: normalizeTitle(title),
      body: body,
      category: category,
      attachments: attachments,
      updatedAt: now,
      createdAt: now,
    );
    _notes.add(note);
    bumpNotesRevision();
    return note;
  }

  @override
  Future<Note?> update(Note note) async {
    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index == -1) {
      return null;
    }
    _notes[index] = note;
    bumpNotesRevision();
    return note;
  }

  @override
  Future<void> delete(String id) async {
    final index = _notes.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    _notes[index] = _notes[index].copyWith(deletedAt: DateTime.now());
    bumpNotesRevision();
  }

  @override
  Future<List<Note>> loadTrash() async {
    final trashed = [
      for (final note in _notes)
        if (note.isDeleted) note,
    ]..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return List<Note>.unmodifiable(trashed);
  }

  @override
  Future<void> restore(String id) async {
    final index = _notes.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    _notes[index] = _notes[index].copyWith(deletedAt: null);
    bumpNotesRevision();
  }

  @override
  Future<void> purge(String id) async {
    _notes.removeWhere((item) => item.id == id);
    bumpNotesRevision();
  }

  @override
  Future<void> purgeAll() async {
    _notes.removeWhere((item) => item.isDeleted);
    bumpNotesRevision();
  }

  @override
  Future<void> reassignCategory(String from, String to) async {
    for (var i = 0; i < _notes.length; i++) {
      if (_notes[i].category == from) {
        _notes[i] = _notes[i].copyWith(category: to);
      }
    }
    bumpNotesRevision();
  }

  @override
  Future<void> deleteByCategory(String category) async {
    final now = DateTime.now();
    for (var i = 0; i < _notes.length; i++) {
      if (_notes[i].category == category) {
        _notes[i] = _notes[i].copyWith(deletedAt: now);
      }
    }
    bumpNotesRevision();
  }

  static List<Note> _seedNotes() {
    final now = DateTime.now();
    return [
      Note(
        id: 'n1',
        title: 'prism_ui 接入记录',
        body:
            '把设计系统整包复制进 plugins/prism_ui，改色只动 app_theme.dart 一处。'
            '注意 PrismScaffold 要 PreferredSizeWidget，AppBar 没实现，得自己包一层。',
        updatedAt: now.subtract(const Duration(minutes: 12)),
        pinned: true,
      ),
      Note(
        id: 'n2',
        title: '圆角与超椭圆',
        body:
            '不要用 BorderRadius.circular，统一走 AppShape。'
            '普通圆角和超椭圆混用，曲线接缝会露出来，整页看起来就"脏"了。',
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
      Note(
        id: 'n3',
        title: '短的一行',
        body: '标题只有一行、正文只有一行的行高基准。',
        updatedAt: now.subtract(const Duration(hours: 20)),
      ),
      Note(
        id: 'n4',
        title: '长正文用来验证两行截断',
        body:
            '这一段故意写得很长，目的是让列表副标题超过两行，看省略号是否正常工作，'
            '同时确认行高会随内容变化而不是被固定成单一高度。'
            '如果这里显示正常，说明变高行与滚动估算都没问题。',
        updatedAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      Note(
        id: 'n5',
        title: '空状态设计',
        body: '等数据清空时应该走 NullStatusSwitcher，而不是自己写一个空白页。',
        updatedAt: now.subtract(const Duration(days: 4)),
      ),
      Note(
        id: 'n6',
        title: '更早的一条',
        body: '超过 7 天之后，时间显示换成具体日期。',
        updatedAt: now.subtract(const Duration(days: 15)),
      ),
    ];
  }
}

/// 标题留空时给一个默认名，避免列表里出现空行。
String normalizeTitle(String raw) {
  final title = raw.trim();
  return title.isEmpty ? '无标题' : title;
}
