import 'dart:ui';

import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/glass_design.dart';
import 'glass_scope.dart';

/// 统一的液态玻璃容器。
///
/// - 重模式（默认）：走 [LiquidGlass] 渲染器（iOS 27 拟合的折射 / 轮廓 /
///   高光 / 内阴影），冻结了过去手写双层 tint + 描边带来的浅色黑边与生硬感。
///   支持 GPU 时出完整折射，否则库自动降级为 FakeGlass。
/// - 轻模式（[light]）：实色底 + 极细亮边，用于内容卡片，保证文字可读。
/// - 非对称圆角（[borderRadius]）：库只支持单一圆角值，这种情况保留手写实现。
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double radius;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  /// 模糊半径（库模式下由 settings.frost 接管，此值仅手写模式生效）
  final double blur;

  /// 阴影层级：overlay 用于弹层
  final bool overlay;

  /// 自定义圆角（覆盖 [radius]）；非对称时回退手写渲染
  final BorderRadius? borderRadius;

  /// 轻模式：实色底 + 边缘反光，不模糊背景，适合内容卡片
  final bool light;

  /// 轻模式下的实色底色（卡片用）；不传则用玻璃底色
  final Color? solidColor;

  /// 是否画 0.6px 边缘细线。分组卡片设为 false 可得到无描边的纯色卡片。
  final bool showBorder;

  /// 覆盖默认玻璃参数（如浮层用官方 `sheet` 预设），
  /// 传 null 时沿用 [GlassMaterial] 的默认调校。
  final LiquidGlassSettings? settings;

  const GlassContainer({
    super.key,
    required this.child,
    this.radius = Glass.radiusM,
    this.padding,
    this.blur = Glass.blurMedium,
    this.overlay = false,
    this.borderRadius,
    this.light = false,
    this.solidColor,
    this.showBorder = true,
    this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    // 重模式 + 对称圆角：交给液态玻璃渲染器
    if (!light && borderRadius == null) {
      final Widget content = padding == null
          ? child
          : Padding(padding: padding!, child: child);
      return LiquidGlass.auto(
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        settings: settings ?? GlassMaterial.settings(brightness),
        appearance: GlassMaterial.appearance(brightness),
        shadows: overlay ? GlassMaterial.overlayShadows : GlassMaterial.shadows,
        child: content,
      );
    }

    return _buildFallback(context, brightness);
  }

  /// 手写兜底：轻模式卡片 / 非对称圆角面板。
  ///
  /// 边缘只保留 1px 极细亮线，不再叠深色描边，避免浅色模式出现黑边。
  Widget _buildFallback(BuildContext context, Brightness brightness) {
    final BorderRadius rounded = borderRadius ?? BorderRadius.circular(radius);
    final Color surface =
        solidColor ?? (light ? Glass.tint(brightness) : Glass.tint(brightness));

    // 边框改成**方向渐变**而不是均匀描边：
    // 均匀描边在深色底上会让整圈一起发白，看着像发光；真正的材质
    // 是左上受光最亮、右下转暗——这也是 iPadOS / iOS 的通用约定。
    final List<Color> rimColors = brightness == Brightness.dark
        ? const [
            Color(0x8CFFFFFF), // 左上：明显亮边
            Color(0x1FFFFFFF), // 中段：过渡
            Color(0x59000000), // 右下：压暗
          ]
        : const [
            Color(0xE6FFFFFF),
            Color(0x59FFFFFF),
            Color(0x0F000000),
          ];

    final Widget surfaceWidget = Container(
      padding: showBorder ? const EdgeInsets.all(0.7) : EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: rounded,
        gradient: showBorder
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: rimColors,
                stops: const [0.0, 0.42, 1.0],
              )
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(color: surface, borderRadius: rounded),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );

    if (light) return surfaceWidget;

    return Container(
      decoration: BoxDecoration(
        borderRadius: rounded,
        boxShadow: overlay
            ? Glass.shadowOverlay(brightness)
            : Glass.shadow(brightness),
      ),
      child: ClipRRect(
        borderRadius: rounded,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: surfaceWidget,
        ),
      ),
    );
  }
}
