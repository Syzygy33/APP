import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../ui/bar_clearance.dart';
import '../models/category.dart';
import '../models/note.dart';
import '../models/todo.dart';
import '../services/note_repository.dart';
import '../services/notes_revision.dart';
import '../services/todo_repository.dart';
import '../services/todo_revision.dart';
import '../ui/app_page_bar.dart';
import '../ui/confirm.dart';
import '../ui/list_stats_header.dart';
import '../ui/note_card.dart';
import '../ui/nested_sheet.dart';
import '../ui/searchable_page_bar.dart';
import '../ui/selection_action_bar.dart';
import '../ui/selection_wrap.dart';
import '../ui/todo_card.dart';
import 'note_detail_page.dart';
import 'todo_edit_sheet.dart';

/// 某个分类下的内容列表。
///
/// 和「最近删除」页一致：笔记一组、待办一组，每组用 ListItem 行 + 分组标题。
/// 顶栏可搜索、可多选批量删除。分类名只用来筛选和做标题。
class CategoryNotesPage extends StatefulWidget {
  const CategoryNotesPage({
    super.key,
    required this.category,
    required this.repository,
  });

  final NoteCategory category;
  final NoteRepository repository;

  @override
  State<CategoryNotesPage> createState() => _CategoryNotesPageState();
}

class _CategoryNotesPageState extends State<CategoryNotesPage> {
  final TodoRepository _todoRepository = PrefsTodoRepository();

  var _loading = true;
  var _searching = false;
  var _query = '';
  List<Note> _notes = const [];
  List<Todo> _todos = const [];

  var _selecting = false;

  /// 多选态用带类型前缀的 id，避免笔记与待办 id 撞车：
  /// `n:` 是笔记，`t:` 是待办。
  final Set<String> _selected = {};

  List<Note> get _visibleNotes {
    final query = _query.trim().toLowerCase();
    return [
      for (final note in _notes)
        if (NoteCategory.of(note.category) == widget.category &&
            (query.isEmpty ||
                note.title.toLowerCase().contains(query) ||
                note.body.toLowerCase().contains(query)))
          note,
    ];
  }

  List<Todo> get _visibleTodos {
    final query = _query.trim().toLowerCase();
    return [
      for (final todo in _todos)
        if (NoteCategory.of(todo.category) == widget.category &&
            (query.isEmpty ||
                todo.text.toLowerCase().contains(query) ||
                todo.detail.toLowerCase().contains(query)))
          todo,
    ];
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    notesRevision.addListener(_onNotesChanged);
    todoRevision.addListener(_onNotesChanged);
  }

  @override
  void dispose() {
    notesRevision.removeListener(_onNotesChanged);
    todoRevision.removeListener(_onNotesChanged);
    super.dispose();
  }

  void _onNotesChanged() {
    if (!mounted) {
      return;
    }
    unawaited(_load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    final notes = await widget.repository.load();
    final todos = await _todoRepository.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _notes = notes;
      _todos = todos;
      _loading = false;
    });
  }

  Future<void> _openNote(Note note) async {
    await pushNestedPage<void>(
      context,
      NoteDetailPage(note: note, repository: widget.repository),
    );
    if (!mounted) {
      return;
    }
    unawaited(_load(silent: true));
  }

  Future<void> _openTodo(Todo todo) async {
    await showNestedSheet<void>(
      context,
      builder: (_) => TodoEditSheet(repository: _todoRepository, todo: todo),
    );
    if (!mounted) {
      return;
    }
    unawaited(_load(silent: true));
  }

  void _toggleTodo(Todo todo) =>
      unawaited(_todoRepository.setDone(todo.id, !todo.done));

  void _setSearching(bool value) {
    if (_searching == value) {
      return;
    }
    setState(() {
      _searching = value;
      if (!value) {
        _query = '';
      }
    });
  }

  void _enterSelection() {
    _setSearching(false);
    setState(() {
      _selecting = true;
      _selected.clear();
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleSelected(String key) {
    setState(() {
      if (!_selected.remove(key)) {
        _selected.add(key);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selected.addAll(_visibleNotes.map((note) => 'n:${note.id}'));
      _selected.addAll(_visibleTodos.map((todo) => 't:${todo.id}'));
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) {
      return;
    }
    final count = _selected.length;
    final ok = await confirmDestructive(
      context,
      title: '删除内容',
      message: '选中的 $count 项将移到「最近删除」，可随时恢复。',
    );
    if (!ok || !mounted) {
      return;
    }
    for (final key in List<String>.of(_selected)) {
      if (key.startsWith('n:')) {
        await widget.repository.delete(key.substring(2));
      } else if (key.startsWith('t:')) {
        await _todoRepository.delete(key.substring(2));
      }
    }
    _exitSelection();
  }

  Future<void> _confirmDeleteNote(Note note) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: Builder(
        builder: (dialogContext) => AlertDialog(
          title: '删除笔记',
          destructive: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
          child: Text('「${note.title}」将移到「最近删除」，可随时恢复。'),
        ),
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.repository.delete(note.id);
    if (mounted) {
      unawaited(_load(silent: true));
    }
  }

  Future<void> _confirmDeleteTodo(Todo todo) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: Builder(
        builder: (dialogContext) => AlertDialog(
          title: '删除待办',
          destructive: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
          child: Text('「${todo.text}」将移到「最近删除」，可随时恢复。'),
        ),
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _todoRepository.delete(todo.id);
    if (mounted) {
      unawaited(_load(silent: true));
    }
  }

  /// 把一条内容移出当前分类（归属改为「无分类」），不删除内容。
  Future<void> _moveOut(Note? note, Todo? todo) async {
    if (note != null) {
      await widget.repository.update(
        note.copyWith(category: NoteCategory.fallbackName),
      );
    } else if (todo != null) {
      await _todoRepository.update(
        todo.copyWith(category: NoteCategory.fallbackName),
      );
    }
    if (mounted) {
      unawaited(_load(silent: true));
    }
  }

  /// 批量移出选中内容；无分类后它们会从本页列表消失。
  Future<void> _moveOutSelected() async {
    if (_selected.isEmpty) {
      return;
    }
    for (final key in List<String>.of(_selected)) {
      if (key.startsWith('n:')) {
        final id = key.substring(2);
        for (final note in _notes) {
          if (note.id == id) {
            await widget.repository.update(
              note.copyWith(category: NoteCategory.fallbackName),
            );
            break;
          }
        }
      } else if (key.startsWith('t:')) {
        final id = key.substring(2);
        for (final todo in _todos) {
          if (todo.id == id) {
            await _todoRepository.update(
              todo.copyWith(category: NoteCategory.fallbackName),
            );
            break;
          }
        }
      }
    }
    _exitSelection();
  }

  /// 分类内容页的笔记卡片：直接用 [NoteCard]，与笔记页长得完全一样。
  Widget _noteRow(Note note) {
    if (_selecting) {
      final key = 'n:${note.id}';
      return SelectionWrap(
        selected: _selected.contains(key),
        onTap: () => _toggleSelected(key),
        child: NoteCard(note: note, onPressed: () {}),
      );
    }
    return ContextMenuRegion(
      menuBuilder: (_) => [
        PopupMenuItem(
          label: '移出分类',
          glyph: Glyphs.close,
          onPressed: () => unawaited(_moveOut(note, null)),
        ),
        PopupMenuItem(
          label: '删除',
          danger: true,
          onPressed: () => unawaited(_confirmDeleteNote(note)),
        ),
      ],
      child: NoteCard(note: note, onPressed: () => unawaited(_openNote(note))),
    );
  }

  /// 分类内容页的待办卡片：直接用 [TodoCard]，与待办页长得完全一样。
  Widget _todoRow(Todo todo) {
    if (_selecting) {
      final key = 't:${todo.id}';
      return SelectionWrap(
        selected: _selected.contains(key),
        onTap: () => _toggleSelected(key),
        child: TodoCard(todo: todo, onToggle: () {}, onPressed: () {}),
      );
    }
    return ContextMenuRegion(
      menuBuilder: (_) => [
        PopupMenuItem(
          label: '移出分类',
          glyph: Glyphs.close,
          onPressed: () => unawaited(_moveOut(null, todo)),
        ),
        PopupMenuItem(
          label: '删除',
          danger: true,
          onPressed: () => unawaited(_confirmDeleteTodo(todo)),
        ),
      ],
      child: TodoCard(
        todo: todo,
        onToggle: () => _toggleTodo(todo),
        onPressed: () => unawaited(_openTodo(todo)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = _visibleNotes;
    final todos = _visibleTodos;
    return PrismScaffold(
      bar: SearchablePageBar(
        title: _selecting ? '选择内容' : widget.category.name,
        showBack: true,
        searching: _searching,
        onSearchingChanged: _setSearching,
        hintText: '搜索${widget.category.name}',
        onChanged: (value) => setState(() => _query = value),
        actions: _selecting
            ? [
                BarIconButton(
                  data: IconButtonData(
                    glyph: Glyphs.close,
                    tooltip: '取消选择',
                    onPressed: _exitSelection,
                  ),
                ),
              ]
            : [
                BarIconButton(
                  data: IconButtonData(
                    glyph: Glyphs.search,
                    tooltip: '搜索',
                    onPressed: () => _setSearching(true),
                  ),
                ),
                BarIconButton(
                  data: IconButtonData(
                    glyph: Glyphs.selectAll,
                    tooltip: '选择',
                    onPressed: _enterSelection,
                  ),
                ),
              ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: BarClearance(
              child: NullStatusSwitcher(
                isLoading: _loading,
                isEmpty: notes.isEmpty && todos.isEmpty,
                isSearching: _query.trim().isNotEmpty,
                nullStatus: NullStatus(
                  label: _query.trim().isNotEmpty ? '没有找到匹配的内容' : '这个分类下还没有内容',
                  description: _query.trim().isNotEmpty
                      ? '换个关键词试试'
                      : '新建笔记或待办时选「${widget.category.name}」，它就会出现在这里',
                  illustration: Illustration.search,
                ),
                child: ListView(
                  padding: context.listInsets.page(
                    top: appBarContentGap,
                    bottom: 32 + context.bottomInset,
                  ),
                  children: [
                    if (notes.isNotEmpty) ...[
                      ListHeader(
                        title: '笔记',
                        atTop: true,
                        padding: groupHeaderPadding(context),
                      ),
                      for (var i = 0; i < notes.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == notes.length - 1 ? 0 : 10,
                          ),
                          child: _noteRow(notes[i]),
                        ),
                    ],
                    if (todos.isNotEmpty) ...[
                      ListHeader(
                        title: '待办',
                        atTop: notes.isEmpty,
                        padding: groupHeaderPadding(context),
                      ),
                      for (var i = 0; i < todos.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == todos.length - 1 ? 0 : 10,
                          ),
                          child: _todoRow(todos[i]),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_selecting)
            SelectionActionBar(
              count: _selected.length,
              onSelectAll: _selectAll,
              onDelete: _deleteSelected,
              onCancel: _exitSelection,
              extraActionLabel: '移出分类',
              onExtraAction: _moveOutSelected,
            ),
        ],
      ),
    );
  }
}
