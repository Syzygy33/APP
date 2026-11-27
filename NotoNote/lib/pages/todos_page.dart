import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../ui/bar_clearance.dart';
import '../ui/confirm.dart';
import '../models/todo.dart';
import '../services/category_repository.dart';
import '../services/category_revision.dart';
import '../services/sort_order_store.dart';
import '../services/todo_repository.dart';
import '../services/todo_revision.dart';
import '../services/prefs_note_repository.dart';
import '../ui/app_page_bar.dart';
import 'global_search_page.dart';
import 'settings_demo.dart';
import 'todo_edit_sheet.dart';
import 'todo_detail_page.dart';
import '../ui/floating_add_button.dart';
import '../ui/icons/app_glyphs.dart';
import '../ui/list_filter_header.dart';
import '../ui/list_stats_header.dart';
import '../ui/nested_sheet.dart';
import '../ui/page_back_guard.dart';
import '../ui/searchable_page_bar.dart';
import '../ui/selection_action_bar.dart';
import '../ui/selection_wrap.dart';
import '../ui/sort_handle.dart';
import '../ui/todo_card.dart';
import 'trash_page.dart';

/// 待办页。
///
/// 列表按「未完成在前、完成在后」排，组内先看置顶、再按筛选的排序字段。
/// 点圆点切完成态，点卡片进编辑，长按出菜单——与笔记页的操作习惯保持一致。
class TodosPage extends StatefulWidget {
  const TodosPage({super.key});

  @override
  State<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends State<TodosPage> {
  static const _cardGap = 10.0;

  final TodoRepository _repository = PrefsTodoRepository();
  final CategoryRepository _categoryRepository = PrefsCategoryRepository();

  var _loading = true;
  var _searching = false;
  var _query = '';
  List<Todo> _todos = const [];

  var _sort = ListSortField.updated;
  String? _categoryFilter;

  /// 多选模式状态。
  var _selecting = false;
  final Set<String> _selected = {};

  /// 排序模式：卡片左侧出现拖动手柄，可上下拖动换位。
  var _sorting = false;

  /// 手动排序名册（id 顺序），只在 [ListSortField.manual] 下生效。
  List<String> _order = const [];
  final _orderStore = const SortOrderStore();

  /// 搜索与筛选都是纯内存处理，与笔记页同一套做法。
  List<Todo> get _ordered {
    final query = _query.trim().toLowerCase();
    final matched = [
      for (final todo in _todos)
        if ((_categoryFilter == null || todo.category == _categoryFilter) &&
            (query.isEmpty ||
                todo.text.toLowerCase().contains(query) ||
                todo.detail.toLowerCase().contains(query)))
          todo,
    ];
    // 自定义排序：置顶仍在最前，其余按名册下标；名册里没有的排后面。
    final rank = _sort == ListSortField.manual
        ? SortOrderStore.indexOf(_order)
        : const <String, int>{};
    int compare(Todo a, Todo b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      if (rank.isNotEmpty) {
        final ai = rank[a.id];
        final bi = rank[b.id];
        if (ai != null || bi != null) {
          if (ai == null) {
            return 1;
          }
          if (bi == null) {
            return -1;
          }
          if (ai != bi) {
            return ai.compareTo(bi);
          }
        }
      }
      return switch (_sort) {
        ListSortField.updated ||
        ListSortField.manual => b.updatedAt.compareTo(a.updatedAt),
        ListSortField.created => b.createdAt.compareTo(a.createdAt),
      };
    }

    return [
      ...(matched.where((todo) => !todo.done).toList()..sort(compare)),
      ...(matched.where((todo) => todo.done).toList()..sort(compare)),
    ];
  }

  /// 未完成的一批（分「未完成」组）。
  List<Todo> get _pendingTodos => [
    for (final todo in _ordered)
      if (!todo.done) todo,
  ];

  /// 已完成的一批（分「已完成」组）。
  List<Todo> get _doneTodos => [
    for (final todo in _ordered)
      if (todo.done) todo,
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadOrder());
    unawaited(_loadCategories());
    todoRevision.addListener(_onChanged);
    categoryRevision.addListener(_onCategoriesChanged);
  }

  @override
  void dispose() {
    todoRevision.removeListener(_onChanged);
    categoryRevision.removeListener(_onCategoriesChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) {
      return;
    }
    unawaited(_load(silent: true));
  }

  void _onCategoriesChanged() {
    if (!mounted) {
      return;
    }
    unawaited(_loadCategories());
  }

  Future<void> _loadCategories() async {
    await _categoryRepository.load();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    final todos = await _repository.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _todos = todos;
      _loading = false;
    });
  }

  void _toggle(Todo todo) =>
      unawaited(_repository.setDone(todo.id, !todo.done));

  void _add() => unawaited(_openAddSheet());

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
        TrashPage(
          noteRepository: PrefsNoteRepository(),
          todoRepository: _repository,
        ),
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

  void _toggleSelected(String id) {
    setState(() {
      if (!_selected.remove(id)) {
        _selected.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selected.addAll(_ordered.map((todo) => todo.id));
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) {
      return;
    }
    final count = _selected.length;
    final ok = await confirmDestructive(
      context,
      title: '删除待办',
      message: '选中的 $count 条待办将移到「最近删除」，可随时恢复。',
    );
    if (!ok || !mounted) {
      return;
    }
    for (final id in List<String>.of(_selected)) {
      await _repository.delete(id);
    }
    _exitSelection();
  }

  Future<void> _loadOrder() async {
    final order = await _orderStore.load(SortOrderStore.todosKey);
    final sort = await _orderStore.loadValue(SortOrderStore.todosSortKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _order = order;
      _sort = ListSortField.values.firstWhere(
        (value) => value.name == sort,
        orElse: () => ListSortField.updated,
      );
    });
  }

  void _setSort(ListSortField value) {
    setState(() => _sort = value);
    unawaited(_orderStore.saveValue(SortOrderStore.todosSortKey, value.name));
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

  /// 拖动结束后把新顺序写进名册，并切到「自定义」排序。
  ///
  /// 组标题不是拖动目标：落在标题上、或跨「未完成 / 已完成」都直接放弃。
  Future<void> _reorder(int oldIndex, int newIndex) async {
    final items = _listItems();
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
    final moved = items[oldIndex].todo;
    if (moved == null) {
      return;
    }
    // 组标题也占一个 item，它本身不是拖动目标：落到标题上时朝拖回来的
    // 方向找最近的卡片——向上拖到标题上＝插到该组第一张之前，
    // 向下拖到别组标题上＝落在本组最后一张之后（跨组仍然不允许）。
    var target = items[newIndex].todo;
    if (target == null) {
      final step = newIndex > oldIndex ? -1 : 1;
      for (var k = newIndex + step; k != oldIndex; k += step) {
        if (items[k].todo case final card?) {
          target = card;
          break;
        }
      }
    }
    if (target == null || moved.done != target.done) {
      return;
    }
    // 原顺序（去掉组标题），把被拖的项挪到目标位置的前/后。
    final ids = [
      for (final item in items)
        if (item.todo case final todo?) todo.id,
    ];
    ids.remove(moved.id);
    final at = ids.indexOf(target.id);
    if (at < 0) {
      return;
    }
    ids.insert(newIndex > oldIndex ? at + 1 : at, moved.id);
    final base = _order.isEmpty ? [for (final todo in _todos) todo.id] : _order;
    final merged = SortOrderStore.merge(base, ids);
    setState(() {
      _order = merged;
      _sort = ListSortField.manual;
    });
    await _orderStore.save(SortOrderStore.todosKey, merged);
    await _orderStore.saveValue(SortOrderStore.todosSortKey, 'manual');
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

  Future<void> _togglePin(Todo todo) async {
    await _repository.update(todo.copyWith(pinned: !todo.pinned));
    if (mounted) {
      unawaited(_load(silent: true));
    }
  }

  Future<void> _toggleFavorite(Todo todo) async {
    await _repository.update(todo.copyWith(favorite: !todo.favorite));
    if (mounted) {
      unawaited(_load(silent: true));
    }
  }

  Future<void> _confirmDelete(Todo todo) async {
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
    if (confirmed != true || !mounted) {
      return;
    }
    await _repository.delete(todo.id);
    if (mounted) {
      unawaited(_load(silent: true));
    }
  }

  Future<void> _openAddSheet() => _showSheet(null);

  Future<void> _showSheet(Todo? todo) async {
    await showNestedSheet<void>(
      context,
      builder: (_) => TodoEditSheet(repository: _repository, todo: todo),
    );
    if (!mounted) {
      return;
    }
    unawaited(_load(silent: true));
  }

  List<PopupMenuItem> _filterItems() {
    return [
      ...sortFilterItems(current: _sort, onSelected: _setSort),
      PopupMenuItem(
        label: '分类',
        subtitle: _categoryFilter ?? '全部',
        subItems: categoryFilterItems(
          selected: _categoryFilter,
          onSelected: (value) => setState(() => _categoryFilter = value),
        ),
      ),
    ];
  }

  /// 列表项：组标题（带数量）或一张卡片。
  ///
  /// 只有「已完成」有标题：未完成就是列表本身，顶上是「全部 N / 筛选」那一行，
  /// 再顶一行「未完成」纯属重复。两张卡片之间只靠 `_cardGap` 分开。
  List<_TodoListItem> _listItems() {
    final pending = _pendingTodos;
    final done = _doneTodos;
    return [
      if (pending.isNotEmpty) ...[
        const _TodoListItem.spacer(),
        for (final todo in pending) _TodoListItem.card(todo),
      ],
      if (done.isNotEmpty) ...[
        _TodoListItem.header('已完成', done.length),
        for (final todo in done) _TodoListItem.card(todo),
      ],
    ];
  }

  /// 一行：组标题或卡片。排序模式下卡片左侧带拖动手柄。
  Widget _listTile(_TodoListItem item, {required bool last, int? dragIndex}) {
    if (item.header != null) {
      // 与收藏/回收站同一套分组标题（组件库 ListHeader）。
      return ListHeader(
        title: item.header!,
        atTop: false,
        padding: groupHeaderPadding(context),
        trailing: Text(
          '${item.count}',
          style: AppTextStyle.subheadline
              .of(context)
              .copyWith(color: context.colorScheme.onSurfaceVariant),
        ),
      );
    }
    if (item.todo == null) {
      // 未完成那一组没有标题，只用这一行留一点顶部间距。
      return const SizedBox(height: 2);
    }
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : _cardGap),
      child: _buildCard(item.todo!, dragIndex: dragIndex),
    );
  }

  /// 一张待办卡片（选择态 / 常态两种包法）。
  Widget _buildCard(Todo todo, {int? dragIndex}) {
    if (_selecting) {
      return SelectionWrap(
        selected: _selected.contains(todo.id),
        onTap: () => _toggleSelected(todo.id),
        // 与笔记页一致：卡片内容往左缩，选择框浮在右侧留白里。
        // 待办原来的圆点不跟着缩进卡片，由这个选择框取代。
        child: TodoCard(
          todo: todo,
          query: _query,
          onToggle: () {},
          onPressed: () {},
        ),
      );
    }
    final card = TodoCard(
      todo: todo,
      query: _query,
      // 点圆点才切完成；点卡片进详情。排序模式里两者都不生效：
      // 按住是起拖，松手不该顺手切状态或进详情。
      onToggle: dragIndex != null ? () {} : () => _toggle(todo),
      onPressed: dragIndex != null
          ? () {}
          : () => unawaited(_openDetail(todo)),
      // 排序模式下只是视觉提示，手势挂在外层整张卡上。
      sortHandle: dragIndex == null ? null : const SortGrip(),
    );
    return sortableCard(
      // 排序模式只做排序：不挂长按菜单，「按住停一下再拖」才起得来。
      dragIndex != null
          ? card
          : ContextMenuRegion(
              // 长按卡片：置顶 / 收藏 / 删除，与笔记完全一致
              menuBuilder: (_) => [
                PopupMenuItem(
                  label: todo.pinned ? '取消置顶' : '置顶',
                  onPressed: () => _togglePin(todo),
                ),
                PopupMenuItem(
                  label: todo.favorite ? '取消收藏' : '收藏',
                  onPressed: () => _toggleFavorite(todo),
                ),
                PopupMenuItem(
                  label: '删除',
                  danger: true,
                  onPressed: () => _confirmDelete(todo),
                ),
              ],
              // 点卡片从右侧滑入详情。
              child: card,
            ),
      dragIndex,
    );
  }

  /// 点卡片：从右侧滑入详情，关闭后刷新。
  Future<void> _openDetail(Todo todo) async {
    await pushNestedPage<void>(
      context,
      TodoDetailPage(todo: todo, repository: _repository),
    );
    if (!mounted) {
      return;
    }
    unawaited(_load(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    final insets = context.listInsets;
    final todos = _ordered;
    // 列表项：组标题（带数量）或一张卡片。
    // 只有两组都有内容时才插组标题，避免单组时多一行空标题。
    final items = _listItems();
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
          title: _selecting ? '选择待办' : '待办',
          searching: _searching,
          onSearchingChanged: _setSearching,
          hintText: '搜索待办',
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
                child: Column(
                  children: [
                    ListFilterHeader(
                      label: _categoryFilter ?? '全部',
                      count: todos.length,
                      pending: _loading,
                      items: _filterItems,
                    ),
                    Expanded(
                      child: NullStatusSwitcher(
                        isLoading: _loading,
                        isEmpty: todos.isEmpty,
                        isSearching: _query.trim().isNotEmpty,
                        nullStatus: NullStatus(
                          label: _categoryFilter == null
                              ? '还没有待办'
                              : '这个分类还没有待办',
                          description: _categoryFilter == null
                              ? '把要做的事记下来，做完打个勾'
                              : '换个分类看看，或者直接加一条',
                          illustration: Illustration.search,
                          action: TonalButton(label: '添加一条', onPressed: _add),
                        ),
                        child: _sorting
                            ? PrismReorderableListView(
                                padding: EdgeInsets.fromLTRB(
                                  insets.margin,
                                  0,
                                  insets.margin,
                                  32 +
                                      context.bottomInset +
                                      FloatingAddButton.reach,
                                ),
                                itemCount: items.length,
                                onReorderItem: (oldIndex, newIndex) =>
                                    unawaited(_reorder(oldIndex, newIndex)),
                                proxyDecorator: (child, index, animation) =>
                                    child,
                                itemBuilder: (context, index) => KeyedSubtree(
                                  key: ValueKey('todo-${index}'),
                                  child: _listTile(
                                    items[index],
                                    last: index == items.length - 1,
                                    dragIndex: index,
                                  ),
                                ),
                              )
                            : PrismListView(
                                padding: EdgeInsets.fromLTRB(
                                  insets.margin,
                                  0,
                                  insets.margin,
                                  // 给居中的添加按钮留出位置
                                  32 +
                                      context.bottomInset +
                                      FloatingAddButton.reach,
                                ),
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: items.length,
                                itemBuilder: (context, index) => _listTile(
                                  items[index],
                                  last: index == items.length - 1,
                                ),
                              ),
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
              )
            else if (!_searching)
              FloatingAddButton(
                glyph: AppGlyphs.plus,
                tooltip: '添加待办',
                onPressed: _add,
              ),
          ],
        ),
      ),
    );
  }
}

// 待办编辑弹层已提取到 todo_edit_sheet.dart（TodoEditSheet），
// 供待办 / 收藏 / 分类内容页共用。

/// 待办列表里的一项：要么是分组标题，要么是一张卡片。
class _TodoListItem {
  const _TodoListItem.header(this.header, this.count) : todo = null;

  const _TodoListItem.card(this.todo) : header = null, count = 0;

  const _TodoListItem.spacer() : header = null, count = 0, todo = null;

  final String? header;
  final int count;
  final Todo? todo;
}
