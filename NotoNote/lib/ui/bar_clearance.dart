import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// 为**浮动顶栏**留出空间。
///
/// 为什么不能直接用 `SafeArea`：内边距的来源在两种布局下不一样。
///
/// | 布局 | 顶栏内边距从哪来 | `MediaQuery.padding.top` | `context.appBarInset` |
/// |---|---|---|---|
/// | 页面（`_ScaffoldFrame`） | 注入到 MediaQuery | 状态栏 + 72 | 只有状态栏（Web 为 0） |
/// | 紧凑弹层（`SheetToolBar`） | 通过 `FloatingBarScope` | 0 | `sheetAppBarHeight`（68） |
///
/// 所以取两者较大值：页面模式得到 72+，弹层模式得到 68。
/// 只用 `SafeArea` 的话，弹层里的第一个控件会被顶栏压住——
/// 这是加待办弹层时实际踩到的。
class BarClearance extends StatelessWidget {
  const BarClearance({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = math.max(
      context.appBarInset,
      MediaQuery.paddingOf(context).top,
    );
    return Padding(
      padding: EdgeInsets.only(top: inset),
      child: child,
    );
  }
}
