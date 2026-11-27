import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../ui/bar_clearance.dart';
import '../models/category.dart';
import '../models/note.dart';
import '../models/todo.dart';
import '../services/category_repository.dart';
import '../services/category_revision.dart';
import '../services/note_repository.dart';
import '../services/notes_revision.dart';
import '../services/prefs_note_repository.dart';
import '../services/todo_repository.dart';
import '../services/todo_revision.dart';
import '../ui/app_page_bar.dart';
import 'settings_demo.dart';
import '../ui/floating_add_button.dart';
import '../ui/icons/app_glyphs.dart';
import '../ui/icons/category_icons.dart';
import '../ui/list_stats_header.dart';
import '../ui/nested_sheet.dart';
import '../ui/page_back_guard.dart';
import '../ui/pin_badge.dart';
import '../ui/searchable_page_bar.dart';
import '../ui/selection_action_bar.dart';
import '../ui/selection_wrap.dart';
import '../ui/sort_handle.dart';
import 'category_notes_page.dart';
import 'global_search_page.dart';
import 'trash_page.dart';

/// 删除分类的两种方式：只删分类（内容转未分类）/ 连内容一起删。
enum _DeleteMode { categoryOnly, withContent }

/// 分类页：两列卡片，每张一个分类，显示颜色、名字和内容数量。
///
/// 点进去是该分类下的笔记列表。分类 = 预置四个 + 用户自建（存在本地），
/// 底部居中按钮用来新建分类。
class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final NoteRepository _repository = PrefsNoteRepository();
  final TodoRepository _todoRepository = PrefsTodoRepository();
  final CategoryRepository _categoryRepository = PrefsCategoryRepository();

  var _loading = true;
  var _searching = false;
  var _query = '';
  List<Note> _notes = const [];
  List<Todo> _todos = const [];

  var _selecting = false;

  /// 排序模式：按住卡片任意位置拖动换位（置顶组不能越界）。
  var _sorting = false;

  /// 拖动中的临时顺序（分类名）。换位在指针压到别的卡片上时**立刻**生效，
  /// 靠每张卡的 `AnimatedPositioned` 把位移补成动画；松手才写回仓库。
  List<String>? _dragOrder;

  /// 正在拖的分类名；null 表示没在拖。
  String? _draggingName;

  static const _gridGap = 12.0;
  static const _gridAspect = 1.5;

  /// 卡片里内容本身的高度（图标 + 名字 + 计数 + 上下内边距 + 一点呼吸）。
  ///
  /// 之前高度只按 1.5 的比例算，窄屏（360dp）上只有 ~105dp，减掉上下各 16 的
  /// 内边距只剩 73dp，而这块内容要 88dp —— 装不下就溢出，视觉上整块被顶到
  /// 卡片下缘，看着像没居中。所以高度取「比例高度」和「内容高度」里较大的那个。
  static double _contentHeightOf(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    // 图标块 34 + 图标与名字 12 + 名字与计数 2 + 卡片上下内边距 32 + 呼吸 12
    const chrome = 34 + 12 + 2 + 32 + 12;
    return chrome +
        (AppTextStyle.headline.leading + AppTextStyle.footnote.leading) *
            textScale;
  }

  /// 一张分类卡片的高度：宽屏按 1.5 的比例，窄屏至少放得下内容。
  static double cardHeightOf(BuildContext context, double cardWidth) =>
      math.max(cardWidth / _gridAspect, _contentHeightOf(context));
  final Set<String> _selectedCategories = {};

  /// 分类页的搜索只匹配**分类名**，不搜笔记内容。
  /// 「未分类」不是用户建的分组，不参与搜索。
  /// 查询为空时返回全部分类。
  List<NoteCategory> get _matchedCategories {
    final query = _query.trim().toLowerCase();
    return [
      for (final category in NoteCategory.all)
        if (category.name != NoteCategory.fallbackName &&
            (query.isEmpty || category.name.toLowerCase().contains(query)))
          category,
    ];
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    notesRevision.addListener(_onNotesChanged);
    todoRevision.addListener(_onNotesChanged);
    categoryRevision.addListener(_onCategoriesChanged);
  }

  @override
  void dispose() {
    notesRevision.removeListener(_onNotesChanged);
    todoRevision.removeListener(_onNotesChanged);
    categoryRevision.removeListener(_onCategoriesChanged);
    super.dispose();
  }

  void _onNotesChanged() {
    if (!mounted) {
      return;
    }
    unawaited(_load(silent: true));
  }

  void _onCategoriesChanged() {
    if (!mounted) {
      return;
    }
    unawaited(_load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    // 分类要先读：NoteCategory.all 决定卡片上显示的名字与颜色
    await _categoryRepository.load();
    final notes = await _repository.load();
    final todos = await _todoRepository.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _notes = notes;
      _todos = todos;
      _loading = false;
      // 松手后的乐观顺序，等仓库把新顺序读回来就交给 NoteCategory.all。
      if (_draggingName == null) {
        _dragOrder = null;
      }
    });
  }

  int _noteCountOf(NoteCategory category) =>
      _notes.where((note) => NoteCategory.of(note.category) == category).length;

  int _todoCountOf(NoteCategory category) =>
      _todos.where((todo) => NoteCategory.of(todo.category) == category).length;

  Future<void> _open(NoteCategory category) async {
    await pushNestedPage<void>(
      context,
      CategoryNotesPage(category: category, repository: _repository),
    );
    if (!mounted) {
      return;
    }
    unawaited(_load(silent: true));
  }

  Future<void> _addCategory() async {
    await showNestedSheet<void>(
      context,
      builder: (_) => _AddCategorySheet(repository: _categoryRepository),
    );
    if (!mounted) {
      return;
    }
    unawaited(_load(silent: true));
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
        TrashPage(noteRepository: _repository, todoRepository: _todoRepository),
      ),
    );
  }

  void _enterSelection() {
    _setSearching(false);
    setState(() {
      _selecting = true;
      _selectedCategories.clear();
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selectedCategories.clear();
    });
  }

  void _toggleSelected(String name) {
    // 未分类是内容转归的落点，不参与删除
    if (name == NoteCategory.fallbackName) {
      return;
    }
    setState(() {
      if (!_selectedCategories.remove(name)) {
        _selectedCategories.add(name);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedCategories.addAll(
        NoteCategory.all
            .map((category) => category.name)
            .where((name) => name != NoteCategory.fallbackName),
      );
    });
  }

  /// 弹出「删除分类 / 删除全部」二选一，返回用户选择；取消返回 null。
  Future<_DeleteMode?> _askDeleteMode(List<String> names) {
    final label = names.length == 1
        ? '「${names.first}」'
        : '这 ${names.length} 个分类';
    return showFloatingDialog<_DeleteMode>(
      context: context,
      child: Builder(
        builder: (dialogContext) => AlertDialog(
          title: '删除分类',
          child: Text('$label 要怎么删除？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_DeleteMode.categoryOnly),
              child: const Text('删除分类'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_DeleteMode.withContent),
              child: const Text('删除全部'),
            ),
          ],
        ),
      ),
    );
  }

  /// 「删除全部」的二次确认：明确告知会连分类里的内容一起删掉。
  Future<bool> _confirmDeleteAll(List<String> names) async {
    final label = names.length == 1
        ? '「${names.first}」'
        : '这 ${names.length} 个分类';
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: Builder(
        builder: (dialogContext) => AlertDialog(
          title: '确认删除全部',
          child: Text('将删除 $label 及分类下的所有内容，这些内容会进入「最近删除」，可随时恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除全部'),
            ),
          ],
        ),
      ),
    );
    return confirmed ?? false;
  }

  /// 只删分类：内容不删除，只是失去归属变成「无分类」。
  Future<bool> _confirmDeleteCategory(List<String> names) async {
    final label = names.length == 1
        ? '「${names.first}」'
        : '这 ${names.length} 个分类';
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: Builder(
        builder: (dialogContext) => AlertDialog(
          title: '删除分类',
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
          child: Text('将删除 $label，分类下的内容不会删除，会变成「无分类」。'),
        ),
      ),
    );
    return confirmed ?? false;
  }

  /// 执行删除：[mode] 决定只删分类（内容转未分类）还是连内容一起软删除。
  Future<void> _performDelete(List<String> names, _DeleteMode mode) async {
    if (names.isEmpty) {
      return;
    }
    // 两种删除都先二次确认；「删除分类」内容只是转无分类，文案要说明白。
    final confirmed = mode == _DeleteMode.withContent
        ? await _confirmDeleteAll(names)
        : await _confirmDeleteCategory(names);
    if (!confirmed) {
      return;
    }
    for (final name in names) {
      if (mode == _DeleteMode.withContent) {
        await _repository.deleteByCategory(name);
        await _todoRepository.deleteByCategory(name);
      } else {
        await _repository.reassignCategory(name, NoteCategory.fallbackName);
        await _todoRepository.reassignCategory(name, NoteCategory.fallbackName);
      }
      await _categoryRepository.delete(name);
    }
    if (mounted) {
      _exitSelection();
      unawaited(_load(silent: true));
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedCategories.isEmpty) {
      return;
    }
    final names = List<String>.of(_selectedCategories);
    final mode = await _askDeleteMode(names);
    if (mode != null) {
      await _performDelete(names, mode);
    }
  }

  /// 长按菜单里的「删除」：先弹二选一，再执行。
  Future<void> _deleteOne(NoteCategory category) async {
    final mode = await _askDeleteMode([category.name]);
    if (mode != null) {
      await _performDelete([category.name], mode);
    }
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

  @override
  Widget build(BuildContext context) {
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
          title: _selecting ? '选择分类' : '分类',
          searching: _searching,
          onSearchingChanged: _setSearching,
          hintText: '搜索分类',
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
                // 搜索态同样展示分类卡片（按名字筛选），选择模式作用于卡片本身
                child: _buildCategories(context, insets),
              ),
            ),
            if (_selecting)
              SelectionActionBar(
                count: _selectedCategories.length,
                onSelectAll: _selectAll,
                onDelete: _deleteSelected,
                onCancel: _exitSelection,
              )
            else if (!_searching)
              FloatingAddButton(
                glyph: AppGlyphs.plus,
                tooltip: '新建分类',
                onPressed: () => unawaited(_addCategory()),
              ),
          ],
        ),
      ),
    );
  }

  /// 分类卡片网格（搜索态按名字筛选，普通态全部）。
  ///
  /// 骨架与笔记/待办/收藏完全一致：统计头固定在顶部，`NullStatusSwitcher`
  /// 只占下面那块。之前 switcher 把整个 Column 包住，空态/无结果时
  /// 统计头会跟着消失，切换页签时插画的位置就会比别的页偏上跳一下。
  Widget _buildCategories(BuildContext context, ListInsets insets) {
    // 搜索态只按分类名筛选；普通态显示全部（都不含「未分类」）
    final categories = _matchedCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 与笔记/待办/收藏/回收站一致的统计头。
        ListStatsHeader(
          noteCount: _notes.length,
          todoCount: _todos.length,
          pending: _loading,
          padding: EdgeInsets.fromLTRB(insets.margin, 2, insets.margin, 8),
        ),
        Expanded(
          child: NullStatusSwitcher(
            isLoading: _loading,
            isEmpty: categories.isEmpty,
            isSearching: _query.trim().isNotEmpty,
            nullStatus: NullStatus(
              label: _query.trim().isNotEmpty ? '没有找到这个分类' : '还没有分类',
              description: _query.trim().isNotEmpty
                  ? '换个关键词试试'
                  : '先建一个分类，再把笔记和待办放进去',
              illustration: Illustration.search,
              // 四个页签的空状态保持同一副骨架（插画 + 标题 + 说明 + 按钮），
              // 少一颗按钮整块就矮 60dp，切页签时插画会跟着上下跳。
              action: TonalButton(
                label: '新建分类',
                onPressed: () => unawaited(_addCategory()),
              ),
            ),
            child: _sorting
                // 排序模式：位置自己算，换位才有「补位」动画。
                ? _buildSortableGrid(context, insets, categories)
                : GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                      insets.margin,
                      0,
                      insets.margin,
                      32 + context.bottomInset + FloatingAddButton.reach,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: _gridGap,
                      crossAxisSpacing: _gridGap,
                      mainAxisExtent: cardHeightOf(
                        context,
                        (MediaQuery.sizeOf(context).width -
                                insets.margin * 2 -
                                _gridGap) /
                            2,
                      ),
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) =>
                        _buildCard(categories[index]),
                  ),
          ),
        ),
      ],
    );
  }

  /// 一张分类卡片：选择态用勾选框包裹，常态挂长按菜单；排序模式带手柄。
  Widget _buildCard(NoteCategory category, {int? dragIndex}) {
    if (_selecting) {
      return SelectionWrap(
        selected: _selectedCategories.contains(category.name),
        onTap: () => _toggleSelected(category.name),
        boxPosition: SelectionBoxPosition.topEnd,
        fillChild: true,
        child: _CategoryCard(
          category: category,
          noteCount: _noteCountOf(category),
          todoCount: _todoCountOf(category),
          pending: _loading,
          onPressed: () => _toggleSelected(category.name),
        ),
      );
    }
    final card = _CategoryCard(
      category: category,
      noteCount: _noteCountOf(category),
      todoCount: _todoCountOf(category),
      // 计数未加载完时不显示 0，避免闪一下
      pending: _loading,
      // 排序模式里点卡片不进详情：按住是起拖。
      onPressed: dragIndex != null
          ? () {}
          : () => unawaited(_open(category)),
      // 排序模式下只是视觉提示，手势挂在外层整张卡上。
      sortHandle: dragIndex == null ? null : const SortGrip(),
    );
    // 排序模式只做排序：不挂长按菜单，「按住停一下再拖」才起得来；
    // 拖动本身由外层 `_sortableCard` 包（要配合补位动画）。
    if (dragIndex != null) {
      return card;
    }
    return ContextMenuRegion(
      menuBuilder: (_) => [
        PopupMenuItem(
          label: category.pinned ? '取消置顶' : '置顶',
          glyph: Glyphs.pin,
          onPressed: () => unawaited(
            _categoryRepository.setPinned(
              category.name,
              pinned: !category.pinned,
            ),
          ),
        ),
        if (category.name != NoteCategory.fallbackName)
          PopupMenuItem(
            label: '删除',
            danger: true,
            onPressed: () => unawaited(_deleteOne(category)),
          ),
      ],
      child: card,
    );
  }

  /// 拖动时跟着手指走的那张卡（尺寸按网格单元算）。
  Widget _dragFeedback(NoteCategory category, double width) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: width,
        height: cardHeightOf(context, width),
        child: Opacity(
          opacity: 0.92,
          child: _CategoryCard(
            category: category,
            noteCount: _noteCountOf(category),
            todoCount: _todoCountOf(category),
            pending: _loading,
            onPressed: () {},
          ),
        ),
      ),
    );
  }

  /// 排序模式的网格。
  ///
  /// 两列位置自己算（跟 GridView 的 12 间距、1.5 比例一致），每张卡放在
  /// `AnimatedPositioned` 里：拖动中一旦换位，卡片、包括那张半透明的占位卡
  /// 都会平滑滑到新格子，而不是「啪」地跳过去。
  Widget _buildSortableGrid(
    BuildContext context,
    ListInsets insets,
    List<NoteCategory> categories,
  ) {
    final display = _displayOrder(categories);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        insets.margin,
        0,
        insets.margin,
        32 + context.bottomInset + FloatingAddButton.reach,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - _gridGap) / 2;
          final cardHeight = cardHeightOf(context, cardWidth);
          final rows = (display.length + 1) ~/ 2;
          return SizedBox(
            height: rows * cardHeight + (rows - 1) * _gridGap,
            child: Stack(
              children: [
                for (var i = 0; i < display.length; i++)
                  AnimatedPositioned(
                    key: ValueKey('category-${display[i].name}'),
                    duration: context.motionDuration(midDuration),
                    curve: Curves.easeOutCubic,
                    left: (i % 2) * (cardWidth + _gridGap),
                    top: (i ~/ 2) * (cardHeight + _gridGap),
                    width: cardWidth,
                    height: cardHeight,
                    child: _sortableCard(display[i], i, cardWidth),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 展示顺序：拖动中用临时顺序，其余时候用仓库顺序。
  ///
  /// 临时顺序里没有的分类（拖动途中新建）补到末尾，避免凭空消失。
  List<NoteCategory> _displayOrder(List<NoteCategory> base) {
    final order = _dragOrder;
    if (order == null) {
      return base;
    }
    final remaining = {for (final category in base) category.name: category};
    final result = <NoteCategory>[];
    for (final name in order) {
      final category = remaining.remove(name);
      if (category != null) {
        result.add(category);
      }
    }
    result.addAll(remaining.values);
    return result;
  }

  /// 一张可拖的卡片：整卡都能按，指针压到别人身上就立刻换位。
  Widget _sortableCard(NoteCategory category, int index, double cardWidth) {
    final card = _buildCard(category, dragIndex: index);
    return DragTarget<NoteCategory>(
      // 不等松手：指针一进入这张卡就换位，才能看到补位动画。
      onWillAcceptWithDetails: (details) {
        if (details.data.name != category.name) {
          _hoverCategory(category, index);
        }
        return true;
      },
      builder: (context, candidate, rejected) => Draggable<NoteCategory>(
        data: category,
        feedback: _dragFeedback(category, cardWidth),
        // 被拖走的那格留一张淡卡，它会跟着换位动画滑到新位置。
        childWhenDragging: Opacity(opacity: 0.28, child: card),
        onDragStarted: () => _startDrag(category),
        onDragEnd: (_) => unawaited(_endDrag()),
        child: card,
      ),
    );
  }

  void _startDrag(NoteCategory category) {
    setState(() {
      _draggingName = category.name;
      _dragOrder = [for (final c in _matchedCategories) c.name];
    });
  }

  /// 指针压到第 [index] 张上：把正在拖的分类挪过去（置顶组不能越界）。
  void _hoverCategory(NoteCategory hovered, int index) {
    final order = _dragOrder;
    final name = _draggingName;
    if (order == null || name == null) {
      return;
    }
    final from = order.indexOf(name);
    if (from < 0 || from == index) {
      return;
    }
    final moved = NoteCategory.of(name);
    final pinnedCount = order
        .where((category) => NoteCategory.of(category).pinned)
        .length;
    final min = moved.pinned ? 0 : pinnedCount;
    final max = moved.pinned ? pinnedCount - 1 : order.length - 1;
    final target = index.clamp(min, max);
    if (target == from) {
      return;
    }
    setState(() {
      order.removeAt(from);
      order.insert(target, name);
    });
  }

  /// 松手：顺序已经在 [_dragOrder] 里了，写回仓库即可。
  Future<void> _endDrag() async {
    final order = _dragOrder;
    setState(() => _draggingName = null);
    if (order == null) {
      return;
    }
    final current = [for (final c in _matchedCategories) c.name];
    if (order.length == current.length) {
      var same = true;
      for (var i = 0; i < order.length; i++) {
        if (order[i] != current[i]) {
          same = false;
          break;
        }
      }
      if (same) {
        return;
      }
    }
    await _categoryRepository.reorder(List<String>.of(order));
  }

  void _toggleSorting() {
    _setSearching(false);
    setState(() {
      _sorting = !_sorting;
      if (_sorting) {
        _selecting = false;
        _selectedCategories.clear();
      }
    });
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.noteCount,
    required this.todoCount,
    required this.pending,
    required this.onPressed,
    this.sortHandle,
  });

  /// 排序模式下左缘垂直居中的拖动手柄；为 null 时不显示。
  final Widget? sortHandle;

  final NoteCategory category;
  final int noteCount;
  final int todoCount;
  final bool pending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Card(
      onPressed: onPressed,
      radius: AppCorner.xl,
      padding: const EdgeInsets.all(16),
      // 置顶符号浮在左上角，不占 Column 的一行——否则会把下面的图标
      // 整体往下挤。Stack 铺满卡片，图钉用 PositionedDirectional 定位。
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            // 卡片里只有图标、名字、计数三行，居中对齐比左对齐更均衡
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 色块底 + 同色图标：颜色本身是分类的主要识别标志
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  // 浅色底用 12% 透明度，深色下也一样能看清
                  color: category.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: GlyphIcon(
                    // 新建时挑的图标；老分类用默认方块。
                    CategoryIcons.resolve(category.icon),
                    size: 18,
                    color: category.color,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                category.name,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.headline.of(context),
              ),
              const SizedBox(height: 2),
              Text(
                pending ? '—' : _countLabel(),
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          // 排序手柄贴在左缘的垂直中线上，与列表卡片同一个位置；
          // 铺满高度再居中，卡片高度变了也不用改数字。
          if (sortHandle case final handle?)
            PositionedDirectional(
              top: 0,
              bottom: 0,
              start: 2,
              child: Center(child: handle),
            ),
          // 置顶符号：浮在左上角，不参与 Column 布局，图标不会下移。
          // 用正方形居中框 + 相等的 top/start，保证到左缘、上缘严格等距。
          if (category.pinned)
            PositionedDirectional(
              top: 10,
              start: 10,
              child: PinBadge(
                size: 16,
                color: category.color,
                child: GlyphIcon(
                  Glyphs.pin,
                  size: 12,
                  fill: 1,
                  color: category.color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 只有一类有内容时不写另一类的 0，省得卡片上挂一串零。
  String _countLabel() {
    if (todoCount == 0) {
      return '$noteCount 条笔记';
    }
    if (noteCount == 0) {
      return '$todoCount 条待办';
    }
    return '$noteCount 条笔记 · $todoCount 条待办';
  }
}

/// 新建分类的弹层：名字 + 颜色。
///
/// 颜色给一排固定选项而不是取色器：手机上调色盘不好按，
/// 而且分类色只需要「彼此好区分」。
class _AddCategorySheet extends StatefulWidget {
  const _AddCategorySheet({required this.repository});

  final CategoryRepository repository;

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  /// 7 个颜色，正好和 7 个图标同一栅格；灰色留给「无分类」，不在这里选。
  static const _palette = [
    Color(0xFF0A7CFF),
    Color(0xFF34C759),
    Color(0xFFFF9F0A),
    Color(0xFFFF453A),
    Color(0xFFAF52DE),
    Color(0xFF5AC8FA),
    // 原来是玫红 #FF2D55，和正红只差 14° 色相，换成咖啡棕拉开
    Color(0xFFA2845E),
  ];

  final _name = TextEditingController();
  final _undo = UndoHistoryController();
  var _color = _palette.first;
  var _icon = CategoryIcons.defaultKey;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _undo.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final created = await widget.repository.add(
      name: name,
      color: _color,
      icon: _icon,
    );
    if (!mounted) {
      return;
    }
    if (created == null) {
      // 重名：留在弹层里提示，别把用户刚打的字清掉
      setState(() {
        _saving = false;
        _error = '已经有同名分类了';
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return PrismScaffold(
      bar: AppPageBar(
        // 顶栏不显示标题文字。
        title: '',
        showBack: true,
        actions: [
          BarUndoRedo(controller: _undo),
          const SizedBox(width: 4),
          BarSaveButton(onPressed: _saving ? null : () => unawaited(_save())),
        ],
      ),
      body: BarClearance(
        child: ListView(
          padding: context.listInsets.page(top: appBarContentGap, bottom: 32),
          children: [
            TextField(
              controller: _name,
              undoController: _undo,
              autofocus: true,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              style: AppTextStyle.title3.of(context),
              decoration: const InputDecoration(
                hintText: '分类名称',
                border: NoInputBorder(),
              ),
            ),
            const SizedBox(height: 26),
            // 图标与颜色两行都横向铺满（首尾贴住内容区左右缘），
            // 这样两行看起来是同一条栅格，不会一行缩在左边、一行拉满。
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final key in CategoryIcons.keys)
                  GestureDetector(
                    onTap: () => setState(() => _icon = key),
                    child: AnimatedContainer(
                      duration: context.motionDuration(midDuration),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        // 图标不跟颜色走：选中只靠加深底色 + 描边表示，
                        // 颜色交给下面那排色点。
                        color: colorScheme.onSurface.withValues(
                          alpha: _icon == key ? 0.14 : 0.06,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: _icon == key
                              ? colorScheme.onSurface
                              : const Color(0x00000000),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: GlyphIcon(
                          CategoryIcons.resolve(key),
                          size: 19,
                          color: _icon == key
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            // 一行 7 个，和上面 7 个图标用同一条栅格：每格 40 宽、整行铺满，
            // 圆点在格里居中，所以两行的列中心严格对齐。
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final color in _palette)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => setState(() => _color = color),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == _color
                                  ? colorScheme.onSurface
                                  : const Color(0x00000000),
                              width: 2,
                            ),
                          ),
                          child: color == _color
                              ? const Center(
                                  child: GlyphIcon(
                                    Glyphs.check,
                                    size: 16,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
