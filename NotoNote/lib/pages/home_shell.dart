import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import '../ui/home_tab.dart';
import '../ui/icons/app_glyphs.dart';
import 'category_page.dart';
import 'favorites_page.dart';
import 'todos_page.dart';
import 'notes_page.dart';

/// 四个页签的外壳。
///
/// 布局照 FlClash 的做法：
/// - 页面栈用 `IndexedStack` 保住各页状态（切回来还在原滚动位置）
/// - 底部导航是**悬浮**的（`NavigationDock`），不占页面高度，浮在内容之上
/// - 用 `BottomInsetScope` 把导航高度告诉页面，让列表底部留出空间，
///   否则最后一张卡片会被压在导航下面
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  HomeTab _tab = HomeTab.notes;

  static const _tabs = [
    HomeTab.notes,
    HomeTab.todo,
    HomeTab.category,
    HomeTab.favorite,
  ];

  static const _destinations = [
    NavigationDockDestination(glyph: AppGlyphs.compose, label: '笔记'),
    NavigationDockDestination(glyph: AppGlyphs.todo, label: '待办'),
    NavigationDockDestination(glyph: AppGlyphs.category, label: '分类'),
    NavigationDockDestination(glyph: AppGlyphs.star, label: '收藏'),
  ];

  static const _pages = [
    NotesPage(),
    TodosPage(),
    CategoryPage(),
    FavoritesPage(),
  ];

  void _select(HomeTab tab) {
    if (tab == _tab) {
      return;
    }
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexOf(_tab);
    return HomeTabScope(
      select: _select,
      child: Stack(
        children: [
          Positioned.fill(
            child: BottomInsetScope(
              inset: NavigationDock.insetOf(context),
              child: IndexedStack(
                index: index,
                // 每页包一层 PageActivityScope：只有当前页的「返回拦截」生效，
                // 其余页（IndexedStack 里保留着状态）不参与。
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    PageActivityScope(isActive: i == index, child: _pages[i]),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: NavigationDock(
              destinations: _destinations,
              selectedIndex: index,
              onSelected: (i) => _select(_tabs[i]),
            ),
          ),
        ],
      ),
    );
  }
}
