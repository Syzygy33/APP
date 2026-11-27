import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// 给置顶图钉套一层悬停高亮：鼠标移上去时淡入一个圆形底色。
///
/// 纯装饰组件，不拦截点击（笔记/待办行本身的 onTap 照常生效）。
/// 外框用正方形 + 居中 child，保证到左缘、上缘等距。
class PinBadge extends StatefulWidget {
  const PinBadge({
    super.key,
    required this.child,
    this.color,
    this.size = 20,
  });

  final Widget child;

  /// 悬停底色，默认取主题主色。
  final Color? color;

  /// 外框边长（正方形）。
  final double size;

  @override
  State<PinBadge> createState() => _PinBadgeState();
}

class _PinBadgeState extends State<PinBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.colorScheme.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: context.motionDuration(const Duration(milliseconds: 150)),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _hovered
              ? color.withValues(alpha: 0.14)
              : const Color(0x00000000),
          shape: BoxShape.circle,
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}
