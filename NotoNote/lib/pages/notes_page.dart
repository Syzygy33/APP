import 'dart:async';

import 'package:prism_ui/icons/icons.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import '../ui/bar_clearance.dart';
import '../ui/confirm.dart';
import '../models/note.dart';
import '../services/category_repository.dart';
import '../services/category_revision.dart';
import '../services/note_repository.dart';
import '../services/sort_order_store.dart';
import '../services/notes_revision.dart';
import '../services/todo_repository.dart';
import '../services/prefs_note_repository.dart';
import '../ui/app_page_bar.dart';
import '../ui/icons/app_glyphs.dart';
import '../ui/floating_add_button.dart';
import '../ui/list_filter_header.dart';
import '../ui/nested_sheet.dart';
import '../ui/note_card.dart';
import '../ui/page_back_guard.dart';
import '../ui/searchable_page_bar.dart';
import '../ui/selection_action_bar.dart';
import '../ui/selection_wrap.dart';
import '../ui/sort_handle.dart';
import 'note_edit_page.dart';
import 'note_detail_page.dart';
import 'global_search_page.dart';
import 'settings_demo.dart';
import 'trash_page.dart';

/// 首页：笔记列表。
///
/// 每条笔记是一张独立卡片（卡片之间留间距），不是一张大卡加分割线——
/// 分组列表只用于设置类页面，内容流用卡片。
class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  static const _cardGap = 12.0;

  final NoteRepository _repository = PrefsNoteRepository();
  final CategoryRepository _categoryRepository = PrefsCategoryRepository();

  var _loading = true;
  var _searching = false;
  var _query = '';
  List<Note> _notes = const [];

  /// 排序字段：默认按更新时间，置顶始终在最前。
  var _sort = ListSortField.updated;

  /// 分类过滤，null 表示全部。
  String? _categoryFilter;

  /// 多选模式：进入后卡片点击切换勾选，底部出现批量操作栏。
  var _selecting = false;
  final Set<String> _selected = {};

  /// 排序模式：卡片左侧出现拖动手柄，可上下拖动换位。
  var _sorting = false;

  /// 手动排序名册（id 顺序），只在 [ListSortField.manual] 下生效。
  List<String> _order = const [];
  final _orderStore = const SortOrderStore();

  /// 搜索和筛选都是纯内存处理：数据量小，没必要走仓储。
  /// 等接上数据库、笔记过千时，再改成仓储层的带索引查询。
  List<Note> get _visibleNotes {
    final query = _query.trim().toLowerCase();
    final filtered = [
      for (final note in _notes)
        if ((_categoryFilter == null || note.category == _categoryFilter) &&
            (query.isEmpty ||
                note.title.toLowerCase().contains(query) ||
                note.body.toLowerCase().contains(query)))
          note,
    ];
    // 自定义排序：置顶仍在最前，其余按名册下标；名册里没有的排后面。
    final rank = _sort == ListSortField.manual
        ? SortOrderStore.indexOf(_order)
        : const <String, int>{};
    filtered.sort((a, b) {
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
    });
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadCategories());
    // 收藏/编辑可能在详情页或另一个页签里发生，靠信号同步
    unawaited(_loadOrder());
    notesRevision.addListener(_onNotesChanged);
    // 新建分类后要刷新：筛选菜单和卡片上的分类名都来自 NoteCategory.all
    categoryRevision.addListener(_onCategoriesChanged);
  }

  @override
  void dispose() {
    notesRevision.removeListener(_onNotesChanged);
    categoryRevision.removeListener(_onCategoriesChanged);
    super.dispose();
  }

  void _onNotesChanged() {
    if (!mounted) {
      return;
    }
    _reloadSilently();
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

  /// [silent] 为 true 时不切到加载态，用于关闭子页后的刷新，避免闪白。
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    final notes = await _repository.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  void _reloadSilently() => unawaited(_load(silent: true));

  void _create() => unawaited(_openEditor());

  /// 新建笔记仍走底部编辑弹层。
  Future<void> _openEditor() async {
    await showNestedSheet<Note>(
      context,
      builder: (_) => NoteEditPage(repository: _repository),
    );
    if (!mounted) {
      return;
    }
    _reloadSilently();
  }

  /// 点卡片：从右侧滑入详情。关闭后刷新列表（原地编辑 / 删除都会改数据）。
  Future<void> _openDetail(Note note) async {
    await pushNestedPage<void>(
      context,
      NoteDetailPage(note: note, repository: _repository),
    );
    if (!mounted) {
      return;
    }
    _reloadSilently();
  }

  Future<void> _togglePin(Note note) async {
    await _repository.update(note.copyWith(pinned: !note.pinned));
    if (mounted) {
      _reloadSilently();
    }
  }

  Future<void> _toggleFavorite(Note note) async {
    await _repository.update(note.copyWith(favorite: !note.favorite));
    if (mounted) {
      _reloadSilently();
    }
  }

  Future<void> _confirmDelete(Note note) async {
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
    if (confirmed != true || !mounted) {
      return;
    }
    await _repository.delete(note.id);
    if (mounted) {
      _reloadSilently();
    }
  }

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
          noteRepository: _repository,
          todoRepository: PrefsTodoRepository(),
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

  /// 一张笔记卡片：选择态套选择框，常态套长按菜单；排序模式加拖动手柄。
  Widget _noteTile(Note note, {required bool last, int? dragIndex}) {
    final card = NoteCard(
      note: note,
      query: _query,
      // 排序模式里点击不生效：按住卡片是起拖，松手不该顺手进详情。
      onPressed: _selecting || dragIndex != null
          ? () {}
          : () => unawaited(_openDetail(note)),
      // 排序模式下只是视觉提示，手势挂在外层整张卡上。
      sortHandle: dragIndex == null ? null : const SortGrip(),
    );
    final content = _selecting
        ? SelectionWrap(
            selected: _selected.contains(note.id),
            onTap: () => _toggleSelected(note.id),
            child: card,
          )
        : dragIndex != null
        // 排序模式只做排序：不挂长按菜单，否则长按会先一年抢走手势、
        // 「按住停一下再拖」就起不来了。
        ? card
        : ContextMenuRegion(
            // 长按卡片：置顶 / 收藏 / 删除
            menuBuilder: (_) => [
              PopupMenuItem(
                label: note.pinned ? '取消置顶' : '置顶',
                onPressed: () => _togglePin(note),
              ),
              PopupMenuItem(
                label: note.favorite ? '取消收藏' : '收藏',
                onPressed: () => _toggleFavorite(note),
              ),
              PopupMenuItem(
                label: '删除',
                danger: true,
                onPressed: () => _confirmDelete(note),
              ),
            ],
            child: card,
          );
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : _cardGap),
      // 排序模式：按住卡片任何位置都能拖。
      child: sortableCard(content, dragIndex),
    );
  }

  Future<void> _loadOrder() async {
    final order = await _orderStore.load(SortOrderStore.notesKey);
    final sort = await _orderStore.loadValue(SortOrderStore.notesSortKey);
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
    unawaited(_orderStore.saveValue(SortOrderStore.notesSortKey, value.name));
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
  Future<void> _reorder(int oldIndex, int newIndex) async {
    final visible = _visibleNotes;
    // 注意：回调是 `onReorderItem`，框架已经替我们做过「移除一项后 newIndex 减一」
    // 的换算（见 flutter 的 _handleReorderItem），这里再减一次会让向下拖少挪一格、
    // 而且必须多拖一整张卡才动，手感就是「往下挪不生效」。
    if (newIndex == oldIndex ||
        oldIndex < 0 ||
        oldIndex >= visible.length ||
        newIndex < 0 ||
        newIndex >= visible.length) {
      return;
    }
    final ids = [for (final note in visible) note.id];
    ids.insert(newIndex, ids.removeAt(oldIndex));
    final base = _order.isEmpty ? [for (final note in _notes) note.id] : _order;
    final merged = SortOrderStore.merge(base, ids);
    setState(() {
      _order = merged;
      _sort = ListSortField.manual;
    });
    await _orderStore.save(SortOrderStore.notesKey, merged);
    await _orderStore.saveValue(SortOrderStore.notesSortKey, 'manual');
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
      _selected.addAll(_visibleNotes.map((note) => note.id));
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) {
      return;
    }
    final count = _selected.length;
    final ok = await confirmDestructive(
      context,
      title: '删除笔记',
      message: '选中的 $count 条笔记将移到「最近删除」，可随时恢复。',
    );
    if (!ok || !mounted) {
      return;
    }
    final ids = List<String>.of(_selected);
    for (final id in ids) {
      await _repository.delete(id);
    }
    _exitSelection();
  }

  void _setSearching(bool value) {
    if (_searching == value) {
      return;
    }
    setState(() {
      _searching = value;
      // 搜索框收起时把搜索词清掉，筛选条件保留——
      // 用户是主动选的分类，不该因为收起搜索就丢掉。
      if (!value) {
        _query = '';
      }
    });
  }

  /// 筛选菜单：排序两项 + 分类二级菜单。
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

  @override
  Widget build(BuildContext context) {
    final insets = context.listInsets;
    final visible = _visibleNotes;
    return PageBackGuard(
      // 搜索态 / 多选态下，返回先撤销状态而不是退出页面。
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
          title: _selecting ? '选择笔记' : '笔记',
          searching: _searching,
          onSearchingChanged: _setSearching,
          hintText: '搜索笔记',
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
        // PrismScaffold 的顶栏是浮在 body 之上的（barFloats），
        // body 的 MediaQuery 顶部内边距里已经含了 状态栏 + pageToolbarHeight。
        // 不消费它，列表会钻到标题栏底下。
        body: Stack(
          children: [
            Positioned.fill(
              child: BarClearance(
                child: Column(
                  children: [
                    // 数量 + 筛选固定在顶部，不随列表滚走
                    ListFilterHeader(
                      label: _categoryFilter ?? '全部',
                      count: visible.length,
                      pending: _loading,
                      items: _filterItems,
                    ),
                    Expanded(
                      child: NullStatusSwitcher(
                        isLoading: _loading,
                        isEmpty: visible.isEmpty,
                        isSearching: _query.trim().isNotEmpty,
                        nullStatus: NullStatus(
                          label: _categoryFilter == null
                              ? '还没有笔记'
                              : '这个分类还没有笔记',
                          description: _categoryFilter == null
                              ? '记下第一条，之后可以搜索和置顶'
                              : '换个分类看看，或者直接写一条',
                          illustration: Illustration.search,
                          action: TonalButton(
                            label: '新建笔记',
                            onPressed: _create,
                          ),
                        ),
                        child: _sorting
                            ? PrismReorderableListView(
                                padding: EdgeInsets.fromLTRB(
                                  insets.margin,
                                  0,
                                  insets.margin,
                                  // 悬浮导航 + 新建按钮的高度，否则最后一张卡片会被压住
                                  32 +
                                      context.bottomInset +
                                      FloatingAddButton.reach,
                                ),
                                itemCount: visible.length,
                                onReorderItem: (oldIndex, newIndex) =>
                                    unawaited(_reorder(oldIndex, newIndex)),
                                // 不加默认的抬升阴影，卡片原样跟着手指走。
                                proxyDecorator: (child, index, animation) =>
                                    child,
                                itemBuilder: (context, index) => KeyedSubtree(
                                  key: ValueKey(visible[index].id),
                                  child: _noteTile(
                                    visible[index],
                                    last: index == visible.length - 1,
                                    dragIndex: index,
                                  ),
                                ),
                              )
                            : PrismListView(
                                padding: EdgeInsets.fromLTRB(
                                  insets.margin,
                                  0,
                                  insets.margin,
                                  // 悬浮导航 + 新建按钮的高度，否则最后一张卡片会被压住
                                  32 +
                                      context.bottomInset +
                                      FloatingAddButton.reach,
                                ),
                                // 拖动列表即收起键盘，避免卡片被键盘遮住一半
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: visible.length,
                                itemBuilder: (context, index) => _noteTile(
                                  visible[index],
                                  last: index == visible.length - 1,
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
                glyph: AppGlyphs.pen,
                tooltip: '新建笔记',
                filled: true,
                onPressed: _create,
              ),
          ],
        ),
      ),
    );
  }
}
