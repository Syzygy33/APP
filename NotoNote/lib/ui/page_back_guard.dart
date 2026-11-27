import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// 页面级返回拦截：有临时状态（搜索 / 多选 / 原地编辑）时，
/// 系统返回手势先撤销状态，而不是直接把页面（甚至 App）退掉。
///
/// [blocking] 由调用方判断：注意首页四个页签共用一个路由，
/// 必须再与 [PageActivityScope.isActiveOf] 相与——否则未显示的页签
/// 也会注册拦截，把返回吞掉。
class PageBackGuard extends StatelessWidget {
  const PageBackGuard({
    super.key,
    required this.child,
    required this.blocking,
    this.onBack,
  });

  final Widget child;

  /// true 时拦截返回，改为调用 [onBack]。
  final bool blocking;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !blocking,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        // 只有当前显示的页面才处理，避免隐藏页签也响应。
        if (PageActivityScope.isActiveOf(context)) {
          onBack?.call();
        }
      },
      child: child,
    );
  }
}
