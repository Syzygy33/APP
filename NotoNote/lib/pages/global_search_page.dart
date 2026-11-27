import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import '../common/relative_time.dart';
import '../models/note.dart';
import '../models/todo.dart';
import '../services/note_repository.dart';
import '../services/notes_revision.dart';
import '../services/prefs_note_repository.dart';
import '../services/todo_repository.dart';
import '../services/todo_revision.dart';
import '../ui/app_page_bar.dart';
import '../ui/bar_clearance.dart';
import '../ui/list_item.dart';
import '../ui/list_stats_header.dart';
import '../ui/nested_sheet.dart';
import '../ui/todo_done_mark.dart';
import 'note_detail_page.dart';
import 'todo_edit_sheet.dart';

/// 全局搜索：搜所有笔记与待办，与每个页面自己的局部搜索区分开。
///
/// 从顶栏「⋯ → 全局搜索」进入，一进来就把焦点交给搜索框；
/// 结果按笔记 / 待办分两组，和「最近删除」页一致。
class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final NoteRepository _noteRepository = PrefsNoteRepository();
  final TodoRepository _todoRepository = PrefsTodoRepository();

  final _controller = TextEditingController();
  final _focus = FocusNode();

  var _query = '';
  var _loading = true;
  List<Note> _notes = const [];
  List<Todo> _todos = const [];

  List<Note> get _matchedNotes {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return [
      for (final note in _notes)
        if (note.title.toLowerCase().contains(query) ||
            note.body.toLowerCase().contains(query))
          note,
    ];
  }

  List<Todo> get _matchedTodos {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return [
      for (final todo in _todos)
        if (todo.text.toLowerCase().contains(query) ||
            todo.detail.toLowerCase().contains(query))
          todo,
    ];
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    notesRevision.addListener(_onChanged);
    todoRevision.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    notesRevision.removeListener(_onChanged);
    todoRevision.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) {
      return;
    }
    unawaited(_load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    final notes = await _noteRepository.load();
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

  void _toggleTodo(Todo todo) =>
      unawaited(_todoRepository.setDone(todo.id, !todo.done));

  Future<void> _openNote(Note note) async {
    await pushNestedPage<void>(
      context,
      NoteDetailPage(note: note, repository: _noteRepository),
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

  Widget _noteRow(Note note) {
    return ListItem(
      title: Text(
        note.title.isEmpty ? '无标题' : note.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (note.excerpt.isNotEmpty) note.excerpt,
          relativeTime(note.updatedAt),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => unawaited(_openNote(note)),
    );
  }

  Widget _todoRow(Todo todo) {
    final titleStyle = context.listTitleStyle.copyWith(
      color: todo.done ? context.colorScheme.onSurfaceVariant : null,
      decoration: todo.done ? TextDecoration.lineThrough : null,
    );
    return ListItem(
      leading: TodoDoneMark(
        done: todo.done,
        onTap: () => _toggleTodo(todo),
        size: 22,
      ),
      horizontalTitleGap: 12,
      title: Text(
        todo.text.isEmpty ? '无内容' : todo.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: titleStyle,
      ),
      subtitle: Text(
        [
          if (todo.detail.isNotEmpty) todo.detail,
          relativeTime(todo.updatedAt),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => unawaited(_openTodo(todo)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = _matchedNotes;
    final todos = _matchedTodos;
    final hasQuery = _query.trim().isNotEmpty;
    return PrismScaffold(
      bar: AppPageBar(title: '全局搜索', showBack: true),
      body: BarClearance(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.listInsets.margin,
                vertical: 8,
              ),
              child: SearchField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                hintText: '搜索所有笔记和待办',
                fill: SurfaceLevel.inset.colorOf(context.colorScheme),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: NullStatusSwitcher(
                isLoading: _loading,
                isEmpty: !hasQuery || (notes.isEmpty && todos.isEmpty),
                isSearching: hasQuery,
                nullStatus: NullStatus(
                  label: hasQuery ? '没有找到匹配的内容' : '搜索所有笔记和待办',
                  description: hasQuery ? '换个关键词试试' : '输入关键词，笔记和待办里的内容都会搜到',
                  illustration: Illustration.search,
                ),
                child: ListView(
                  padding: context.listInsets.page(
                    top: 4,
                    bottom: 32 + context.bottomInset,
                  ),
                  children: [
                    if (notes.isNotEmpty)
                      generateSection(
                        headerPadding: groupHeaderPadding(context),
                        title: '笔记',
                        atTop: true,
                        items: [for (final note in notes) _noteRow(note)],
                      ),
                    if (todos.isNotEmpty)
                      generateSection(
                        headerPadding: groupHeaderPadding(context),
                        title: '待办',
                        atTop: notes.isEmpty,
                        last: true,
                        items: [for (final todo in todos) _todoRow(todo)],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
