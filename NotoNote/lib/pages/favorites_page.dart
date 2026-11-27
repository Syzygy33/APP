import 'dart:async';

import 'package:prism_ui/icons/icons.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import '../ui/bar_clearance.dart';
import '../models/note.dart';
import '../models/todo.dart';
import '../services/note_repository.dart';
import '../services/sort_order_store.dart';
import '../services/notes_revision.dart';
import '../services/prefs_note_repository.dart';
import '../services/todo_repository.dart';
import '../services/todo_revision.dart';
import '../ui/app_page_bar.dart';
import '../ui/confirm.dart';
import '../ui/list_stats_header.dart';
import '../ui/note_card.dart';
import 'global_search_page.dart';
import 'settings_demo.dart';
import '../ui/home_tab.dart';
import '../ui/nested_sheet.dart';
import '../ui/page_back_guard.dart';
import '../ui/searchable_page_bar.dart';
import '../ui/selection_action_bar.dart';
import '../ui/selection_wrap.dart';
import '../ui/sort_handle.dart';
import '../ui/todo_card.dart';
import 'note_detail_page.dart';
import 'todo_detail_page.dart';
import 'trash_page.dart';

/// 收藏页：笔记与待办的收藏项各成一组，与「最近删除」页一致。
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final NoteRepository _repository = PrefsNoteRepository();
  final TodoRepository _todoRepository = PrefsTodoRepository();

  var _loading = true;
  var _searching = false;
  var _query = '';
  List<Note> _notes = const [];
  List<Todo> _todos = const [];

  var _selecting = false;

  /// 选择态用带类型前缀的 id，避免笔记与待办 id 撞车。
  /// `n:` 前缀是笔记，`t:` 前缀是待办。
  final Set<String> _selected = {};

  /// 排序模式：卡片左侧出现拖动手柄，可上下拖动换位。
  var _sorting = false;

  /// 手动排序名册：笔记与待办各一份（两组各自排序）。
  List<String> _orderNotes = const [];
  List<String> _orderTodos = const [];
  final _orderStore = const SortOrderStore();

  List<Note> get _favoriteNotes {
    final query = _query.trim().toLowerCase();
    final list = [
      for (final note in _notes)
        if (note.favorite &&
            (query.isEmpty ||
                note.title.toLowerCase().contains(query) ||
                note.body.toLowerCase().contains(query)))
          note,
    ];
    final rank = SortOrderStore.indexOf(_orderNotes);
    list.sort((a, b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      final ai = rank[a.id];
      final bi = rank[b.id];
      if (ai == null || bi == null) {
        return ai == null && bi == null
            ? b.updatedAt.compareTo(a.updatedAt)
            : (ai == null ? 1 : -1);
      }
      return ai != bi ? ai.compareTo(bi) : b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  List<Todo> get _favoriteTodos {
    final query = _query.trim().toLowerCase();
    final list = [
      for (final todo in _todos)
        if (todo.favorite &&
            (query.isEmpty ||
                todo.text.toLowerCase().contains(query) ||
                todo.detail.toLowerCase().contains(query)))
          todo,
    ];
    final rank = SortOrderStore.indexOf(_orderTodos);
    list.sort((a, b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      final ai = rank[a.id];
      final bi = rank[b.id];
      if (ai == null || bi == null) {
        return ai == null && bi == null
            ? b.updatedAt.compareTo(a.updatedAt)
            : (ai == null ? 1 : -1);
      }
      return ai != bi ? ai.compareTo(bi) : b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadOrder());
    // 收藏可能在别处（详情页）被改掉，靠信号重载；IndexedStack 下本页不会重建
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

  /// [silent] 为 true 时不切加载态，用于关闭子页后的刷新，避免闪白。
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    final notes = await _repository.load();
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

  /// 详情页关闭后重载：里面可能取消了收藏 / 改了分类，否则列表不更新。
  void _reloadSilently() {
    if (mounted) {
      unawaited(_load(silent: true));
    }
  }

  void _toggleTodo(Todo todo) =>
      unawaited(_todoRepository.setDone(todo.id, !todo.done));

  void _goToNotes() => HomeTabScope.maybeOf(context)?.select(HomeTab.notes);

  void _openSettings() {
    unawaited(pushNestedPage<void>(context, const SettingsDemoPage()));
  }

  void _openGlobalSearch() {
    unawaited(pushNestedPage<void>(context, const GlobalSearchPage()));
  }

  void _openTrash() {
    unawaited(
      pushNestedPage<void>(
        context,
        TrashPage(noteRepository: _repository, todoRepository: _todoRepository),
      ),
    );
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
      _selected.addAll(_favoriteNotes.map((note) => 'n:${note.id}'));
      _selected.addAll(_favoriteTodos.map((todo) => 't:${todo.id}'));
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) {
      return;
    }
    final count = _selected.length;
    final ok = await confirmDestructive(
      context,
      title: '删除收藏内容',
      message: '选中的 $count 项将移到「最近删除」，可随时恢复。',
    );
    if (!ok || !mounted) {
      return;
    }
    for (final key in List<String>.of(_selected)) {
      if (key.startsWith('n:')) {
        await _repository.delete(key.substring(2));
      } else if (key.startsWith('t:')) {
        await _todoRepository.delete(key.substring(2));
      }
    }
    _exitSelection();
  }

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

  List<PopupMenuItem> _noteMenu(Note note) => [
    PopupMenuItem(
      label: note.pinned ? '取消置顶' : '置顶',
      onPressed: () => unawaited(
        _repository.update(
          note.copyWith(pinned: !note.pinned, updatedAt: DateTime.now()),
        ),
      ),
    ),
    PopupMenuItem(
      label: '取消收藏',
      onPressed: () => unawaited(
        _repository.update(
          note.copyWith(favorite: false, updatedAt: DateTime.now()),
        ),
      ),
    ),
    PopupMenuItem(
      label: '删除',
      danger: true,
      onPressed: () => unawaited(_confirmDeleteNote(note)),
    ),
  ];

  /// 菜单里的删除也要二次确认。
  Future<void> _confirmDeleteNote(Note note) async {
    final ok = await confirmDestructive(
      context,
      title: '删除笔记',
      message: '「${note.title}」将移到「最近删除」，可随时恢复。',
    );
    if (!ok || !mounted) {
      return;
    }
    await _repository.delete(note.id);
    _reloadSilently();
  }

  Future<void> _confirmDeleteTodo(Todo todo) async {
    final ok = await confirmDestructive(
      context,
      title: '删除待办',
      message: '「${todo.text}」将移到「最近删除」，可随时恢复。',
    );
    if (!ok || !mounted) {
      return;
    }
    await _todoRepository.delete(todo.id);
    _reloadSilently();
  }

  List<PopupMenuItem> _todoMenu(Todo todo) => [
    PopupMenuItem(
      label: todo.pinned ? '取消置顶' : '置顶',
      onPressed: () => unawaited(
        _todoRepository.update(todo.copyWith(pinned: !todo.pinned)),
      ),
    ),
    PopupMenuItem(
      label: '取消收藏',
      onPressed: () =>
          unawaited(_todoRepository.update(todo.copyWith(favorite: false))),
    ),
    PopupMenuItem(
      label: '删除',
      danger: true,
      onPressed: () => unawaited(_confirmDeleteTodo(todo)),
    ),
  ];

  /// 收藏页的笔记卡片：直接用 [NoteCard]，与笔记页长得完全一样。
  Widget _noteRow(Note note, {int? dragIndex}) {
    if (_selecting) {
      final key = 'n:${note.id}';
      return SelectionWrap(
        selected: _selected.contains(key),
        onTap: () => _toggleSelected(key),
        child: NoteCard(note: note, onPressed: () {}),
      );
    }
    final card = NoteCard(
      note: note,
      onPressed: dragIndex != null ? () {} : () => unawaited(_openNote(note)),
      // 排序模式下只是视觉提示，手势挂在外层整张卡上。
      sortHandle: dragIndex == null ? null : const SortGrip(),
    );
    return sortableCard(
      // 排序模式只做排序：不挂长按菜单，「按住停一下再拖」才起得来。
      dragIndex != null
          ? card
          : ContextMenuRegion(
              // 长按：置顶 / 取消收藏 / 删除（与笔记页一致，不再用行尾三点）
              menuBuilder: (_) => _noteMenu(note),
              child: card,
            ),
      dragIndex,
    );
  }

  /// 收藏页的待办卡片：直接用 [TodoCard]，与待办页长得完全一样。
  Widget _todoRow(Todo todo, {int? dragIndex}) {
    if (_selecting) {
      final key = 't:${todo.id}';
      return SelectionWrap(
        selected: _selected.contains(key),
        onTap: () => _toggleSelected(key),
        child: TodoCard(todo: todo, onToggle: () {}, onPressed: () {}),
      );
    }
    final card = TodoCard(
      todo: todo,
      onToggle: dragIndex != null ? () {} : () => _toggleTodo(todo),
      onPressed: dragIndex != null
          ? () {}
          : () => unawaited(_openTodo(note: todo)),
      // 排序模式下只是视觉提示，手势挂在外层整张卡上。
      sortHandle: dragIndex == null ? null : const SortGrip(),
    );
    return sortableCard(
      // 排序模式只做排序：不挂长按菜单，「按住停一下再拖」才起得来。
      dragIndex != null
          ? card
          : ContextMenuRegion(
              // 长按：置顶 / 取消收藏 / 删除（与待办页一致，不再用行尾三点）
              menuBuilder: (_) => _todoMenu(todo),
              child: card,
            ),
      dragIndex,
    );
  }

  /// 列表：常态用普通 ListView，排序模式换成可拖动版（组标题仍不可拖）。
  ///
  /// 统计头已经移到列表外（见 `build` 的 Column），这里的 padding top 必须是 0，
  /// 否则第一张卡片和「全部 N」之间会多出一段只有这一页才有的空隙。
  Widget _buildFavoriteList(
    BuildContext context,
    List<Note> notes,
    List<Todo> todos,
  ) {
    final items = _favItems(notes, todos);
    final padding = context.listInsets.page(
      top: 0,
      bottom: 32 + context.bottomInset,
    );
    if (_sorting) {
      return PrismReorderableListView(
        padding: padding,
        itemCount: items.length,
        onReorderItem: (oldIndex, newIndex) =>
            unawaited(_reorder(oldIndex, newIndex)),
        proxyDecorator: (child, index, animation) => child,
        itemBuilder: (context, index) => KeyedSubtree(
          key: ValueKey('favorite-$index'),
          child: _favTile(
            items[index],
            last: index == items.length - 1,
            atTop: index == 0,
            dragIndex: index,
          ),
        ),
      );
    }
    return ListView(
      padding: padding,
      children: [
        for (var i = 0; i < items.length; i++)
          _favTile(items[i], last: i == items.length - 1, atTop: i == 0),
      ],
    );
  }

  /// 列表项：组标题（笔记 / 待办）或一张卡片。
  List<_FavItem> _favItems(List<Note> notes, List<Todo> todos) {
    return [
      if (notes.isNotEmpty) _FavItem.header('笔记'),
      for (final note in notes) _FavItem.note(note),
      if (todos.isNotEmpty) _FavItem.header('待办'),
      for (final todo in todos) _FavItem.todo(todo),
    ];
  }

  Widget _favTile(
    _FavItem item, {
    required bool last,
    required bool atTop,
    int? dragIndex,
  }) {
    if (item.header case final header?) {
      return ListHeader(
        title: header,
        atTop: atTop,
        padding: groupHeaderPadding(context),
      );
    }
    if (item.note case final note?) {
      return Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 10),
        child: _noteRow(note, dragIndex: dragIndex),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: _todoRow(item.todo!, dragIndex: dragIndex),
    );
  }

  Future<void> _loadOrder() async {
    final notes = await _orderStore.load(SortOrderStore.favoriteNotesKey);
    final todos = await _orderStore.load(SortOrderStore.favoriteTodosKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _orderNotes = notes;
      _orderTodos = todos;
    });
  }

  void _toggleSorting() {
    _setSearching(false);
    setState(() {
      _sorting = !_sorting;
      if (_sorting) {
        _selecting = false;
        _selected.clear();
      }
    });
  }

  /// 拖动换位：只在同一组内生效（笔记组 / 待办组各自排序）。
  Future<void> _reorder(int oldIndex, int newIndex) async {
    final notes = _favoriteNotes;
    final todos = _favoriteTodos;
    final items = _favItems(notes, todos);
    // 注意：回调是 `onReorderItem`，框架已经替我们做过「移除一项后 newIndex 减一」
    // 的换算（见 flutter 的 _handleReorderItem），这里再减一次会让向下拖少挪一格、
    // 而且必须多拖一整张卡才动，手感就是「往下挪不生效」。
    if (oldIndex < 0 ||
        oldIndex >= items.length ||
        newIndex < 0 ||
        newIndex >= items.length ||
        newIndex == oldIndex) {
      return;
    }
    final moved = items[oldIndex];
    if (moved.note == null && moved.todo == null) {
      return;
    }
    // 组标题也占一个 item，它本身不是拖动目标：落到标题上时朝拖回来的
    // 方向找最近的卡片——向上拖到标题上＝插到该组第一张之前，
    // 向下拖到别组标题上＝落在本组最后一张之后（跨组仍然不允许）。
    var target = items[newIndex];
    if (target.note == null && target.todo == null) {
      final step = newIndex > oldIndex ? -1 : 1;
      for (var k = newIndex + step; k != oldIndex; k += step) {
        if (items[k].note != null || items[k].todo != null) {
          target = items[k];
          break;
        }
      }
      if (target.note == null && target.todo == null) {
        return;
      }
    }
    if (moved.note != null && target.note != null) {
      final ids = [for (final note in notes) note.id];
      final order = _moved(
        ids,
        moved.note!.id,
        target.note!.id,
        oldIndex,
        newIndex,
      );
      final base = _orderNotes.isEmpty
          ? [for (final note in _notes) note.id]
          : _orderNotes;
      final merged = SortOrderStore.merge(base, order);
      setState(() => _orderNotes = merged);
      await _orderStore.save(SortOrderStore.favoriteNotesKey, merged);
    } else if (moved.todo != null && target.todo != null) {
      final ids = [for (final todo in todos) todo.id];
      final order = _moved(
        ids,
        moved.todo!.id,
        target.todo!.id,
        oldIndex,
        newIndex,
      );
      final base = _orderTodos.isEmpty
          ? [for (final todo in _todos) todo.id]
          : _orderTodos;
      final merged = SortOrderStore.merge(base, order);
      setState(() => _orderTodos = merged);
      await _orderStore.save(SortOrderStore.favoriteTodosKey, merged);
    }
  }

  /// 把 [id] 挪到 [targetId] 前（向上拖）或后（向下拖）。
  List<String> _moved(
    List<String> ids,
    String id,
    String targetId,
    int oldIndex,
    int newIndex,
  ) {
    final result = List<String>.of(ids)..remove(id);
    final at = result.indexOf(targetId);
    if (at < 0) {
      return ids;
    }
    result.insert(newIndex > oldIndex ? at + 1 : at, id);
    return result;
  }

  Future<void> _openNote(Note note) async {
    await pushNestedPage<void>(
      context,
      NoteDetailPage(note: note, repository: _repository),
    );
    if (mounted) {
      _reloadSilently();
    }
  }

  Future<void> _openTodo({required Todo note}) async {
    await pushNestedPage<void>(
      context,
      TodoDetailPage(todo: note, repository: _todoRepository),
    );
    if (mounted) {
      _reloadSilently();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = _favoriteNotes;
    final todos = _favoriteTodos;
    final hasContent = notes.isNotEmpty || todos.isNotEmpty;
    final insets = context.listInsets;
    return PageBackGuard(
      blocking:
          PageActivityScope.isActiveOf(context) &&
          (_searching || _selecting || _sorting),
      onBack: () {
        if (_sorting) {
          _toggleSorting();
        } else if (_selecting) {
          _exitSelection();
        } else {
          _setSearching(false);
        }
      },
      child: PrismScaffold(
        bar: SearchablePageBar(
          title: _selecting ? '选择收藏' : '收藏',
          searching: _searching,
          onSearchingChanged: _setSearching,
          hintText: '搜索收藏',
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
                  // 搜索与排序共用一颗圆角胶囊。
                  BarButtonGroup(
                    items: [
                      if (!_sorting)
                        IconButtonData(
                          glyph: Glyphs.search,
                          tooltip: '搜索',
                          onPressed: () => _setSearching(true),
                        ),
                      IconButtonData(
                        glyph: _sorting ? Glyphs.check : Glyphs.sort,
                        tooltip: _sorting ? '完成排序' : '排序',
                        onPressed: _toggleSorting,
                      ),
                    ],
                  ),
                  BarMenuButton(
                    items: () => [
                      PopupMenuItem(label: '选择', onPressed: _enterSelection),
                      PopupMenuItem(label: '设置', onPressed: _openSettings),
                      PopupMenuItem(
                        label: '全局搜索',
                        onPressed: _openGlobalSearch,
                      ),
                      PopupMenuItem(label: '最近删除', onPressed: _openTrash),
                    ],
                  ),
                ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: BarClearance(
                // 统计头固定在顶部，与笔记/待办/分类页同一个位置：
                // 之前它挂在 ListView 里（还带 appBarContentGap），
                // 切页签时「全部 N」会比别的页低一截、还会跟着列表滚走。
                child: Column(
                  children: [
                    ListStatsHeader(
                      noteCount: notes.length,
                      todoCount: todos.length,
                      pending: _loading,
                      padding: EdgeInsets.fromLTRB(
                        insets.margin,
                        2,
                        insets.margin,
                        8,
                      ),
                    ),
                    Expanded(
                      child: NullStatusSwitcher(
                        isLoading: _loading,
                        isEmpty: !hasContent,
                        isSearching: _query.trim().isNotEmpty,
                        nullStatus: NullStatus(
                          label: '还没有收藏',
                          // 控制在一行：四页空状态的说明必须同样高，
                          // 多折一行的插画会比别的页高 6dp，切页签像在跳。
                          description: '在笔记或待办里点收藏，会集中到这里',
                          illustration: Illustration.search,
                          action: TonalButton(
                            label: '去笔记看看',
                            onPressed: _goToNotes,
                          ),
                        ),
                        child: _buildFavoriteList(context, notes, todos),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_selecting)
              SelectionActionBar(
                count: _selected.length,
                onSelectAll: _selectAll,
                onDelete: _deleteSelected,
                onCancel: _exitSelection,
              ),
          ],
        ),
      ),
    );
  }
}

/// 收藏页列表里的一项：组标题、笔记或待办。
class _FavItem {
  const _FavItem.header(this.header) : note = null, todo = null;
  const _FavItem.note(Note this.note) : header = null, todo = null;
  const _FavItem.todo(Todo this.todo) : header = null, note = null;

  final String? header;
  final Note? note;
  final Todo? todo;
}
