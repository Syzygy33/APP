import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:material_ui/material_ui.dart';

/// 全局液态玻璃材质配置：完全使用库官方 iOS 27 预设。
///
/// 库的 ios27Regular 是按 Apple 实拍拟合的折射 / 轮廓 / 高光 / 内阴影，
/// 在**有内容的背景**上会自然透出背景色并呈现清晰边界（见官方参考图）。
/// 不要用 direct 模型 + 实心 tint 去"手动制造质感"——那只会变成一块色块。
class GlassMaterial {
  GlassMaterial._();

  /// Liquid Glass 滑块位置（iOS 设置里 Clear↔Tinted）。官方预设下
  /// 0.5 兼顾通透与雾面，接近参考图的 regular 材质。
  static const double tintAmount = 0.5;

  static LiquidGlassSettings settings(Brightness brightness) =>
      LiquidGlassSettings.ios27Regular(
        brightness: brightness,
        tintAmount: tintAmount,
      );

  /// 单个 glass 的外阴影，强化悬浮与厚度（库 preset 不含外阴影）。
  static const List<BoxShadow> shadows = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 20,
      offset: Offset(0, 7),
    ),
  ];

  /// 弹层阴影：更重，突出层次。
  static const List<BoxShadow> overlayShadows = [
    BoxShadow(
      color: Color(0x2E000000),
      blurRadius: 34,
      offset: Offset(0, 14),
    ),
  ];

  /// 保持库预设的默认外观（tint 透明、iOS 27 colorModel）。
  static LiquidGlassAppearance appearance(
    Brightness brightness, {
    Color? tint,
    double visibility = 1,
  }) =>
      LiquidGlassAppearance.ios27Regular(
        brightness: brightness,
        tint: tint ?? const Color(0x00007AFF),
        visibility: visibility,
      );
}

/// 全局液态玻璃作用域。
///
/// 把整个页面内容作为 backdrop，在其上放一个 [LiquidGlassLayer]，
/// 子树中所有的 `LiquidGlass.auto` 会共享这一次背景采样（性能关键点）。
/// 没有 GPU / Shader 支持时库会自动降级为 FakeGlass，无需手动处理。
class GlassScope extends StatelessWidget {
  final Widget child;

  const GlassScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return LiquidGlassLayer(
      settings: GlassMaterial.settings(brightness),
      defaultAppearance: GlassMaterial.appearance(brightness),
      child: child,
    );
  }
}
