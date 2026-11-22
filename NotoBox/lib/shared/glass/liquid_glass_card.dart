import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, GlassSurfaceStyle, LiquidRoundedSuperellipse;
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/glass_ink.dart';
import 'liquid_glass_tokens.dart';

/// 液态玻璃卡片。
///
/// 默认**不透明**：内容卡片若做成玻璃，文字会与背后内容互相干扰，
/// 可读性反而下降——这也符合 Apple「不要玻璃叠玻璃」的原则。
/// 需要强调的浮层才传 [glass] = true。
class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.glass = false,
    this.radius = LiquidGlassTokens.radiusCard,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// true = 玻璃表面（浮层用）；false = 不透明内容卡片
  final bool glass;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget body = GlassContainer.card(
      // solid 分支是纯色 + 零 shader，符合「内容卡片保持不透明」的规范
      surfaceStyle:
          glass ? GlassSurfaceStyle.glass : GlassSurfaceStyle.solid,
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      padding: padding,
      child: child,
    );

    if (onTap == null) return body;

    return _TapScale(
      onTap: onTap!,
      radius: radius,
      highlight: GlassInk.divider(context),
      child: body,
    );
  }
}

/// 按下轻微缩放 + 高亮（弹性反馈）
class _TapScale extends StatefulWidget {
  const _TapScale({
    required this.child,
    required this.onTap,
    required this.radius,
    required this.highlight,
  });

  final Widget child;
  final VoidCallback onTap;
  final double radius;
  final Color highlight;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool noMotion = LiquidGlassTokens.reduceMotion(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? LiquidGlassTokens.pressedScale : 1.0,
        duration: noMotion ? Duration.zero : LiquidGlassTokens.pressDuration,
        // 物理弹簧：按下有轻微回弹，比 easeOut 更有"按到实体"的手感
        curve: noMotion
            ? Curves.linear
            : LiquidGlassTokens.pressSpringCurve,
        child: Stack(
          children: [
            if (_pressed)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.highlight,
                      borderRadius: BorderRadius.circular(widget.radius),
                    ),
                  ),
                ),
              ),
            widget.child,
          ],
        ),
      ),
    );
  }
}
