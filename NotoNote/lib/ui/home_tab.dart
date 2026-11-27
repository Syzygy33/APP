import 'package:flutter/widgets.dart';

/// 底部导航的四个页签。
enum HomeTab { notes, todo, category, favorite }

/// 让页签内的页面能请求切换页签。
///
/// 典型用法：收藏页是空的，空状态里的按钮要跳到笔记页——
/// 那是外壳的状态，页面自己改不了，只能往上请求。
class HomeTabScope extends InheritedWidget {
  const HomeTabScope({super.key, required this.select, required super.child});

  final ValueChanged<HomeTab> select;

  static HomeTabScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeTabScope>();

  /// 外壳每帧都会传新的闭包，但语义没变，不需要通知依赖者重建。
  @override
  bool updateShouldNotify(HomeTabScope oldWidget) => false;
}
