import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// 为整棵控件树提供 `prism_ui` 需要的 `ViewScope`。
///
/// **这个不能省。** `prism_ui` 的 `AppBar`、`ScaffoldBar`、`ListInsets` 全都要读
/// `ViewScope.isMobileOf(context)`，而 `PrismApp` 自己不提供该 scope。
/// 缺了它，`AppBar` 构建时抛空引用，release 构建下整棵子树渲染为空——
/// 表现是顶栏只剩一条底色、标题和按钮全部消失，且不会有任何报错。
///
/// 必须挂在 `Navigator` 之上（用 `PrismApp.builder`），否则 `push` 出来的
/// 子页面拿不到 scope，同样会白掉。
class AppViewScope extends StatelessWidget {
  const AppViewScope({super.key, required this.child});

  final Widget child;

  /// 宽度低于此值按手机布局走。
  ///
  /// `prism_ui` 自身不定义这个断点（它只管"在不在弹层里"），
  /// 由应用决定。平板/折叠屏想走双栏时改这一个数即可。
  static const double mobileBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return ViewScope(
          size: size,
          isMobile: size.width < mobileBreakpoint,
          child: child,
        );
      },
    );
  }
}
