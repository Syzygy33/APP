import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Liquid Glass 统一设计令牌。
///
/// 玻璃材质参数、按钮规范、动画规范集中在此管理，各组件不要再各写各的。
/// 深浅色分别给值，不靠简单反色。
class Glass {
  Glass._();

  // ===================== 玻璃材质 =====================

  /// 背景模糊半径（FlClash 风：更糊但更透，让背景颜色透上来）
  static const double blurLight = 10;
  static const double blurMedium = 24;
  static const double blurHeavy = 30;

  /// 玻璃底色不透明度（双层叠加，这里给单层值，越低越通透）
  static const double tintOpacityLight = 0.42;
  static const double tintOpacityDark = 0.32;

  /// 第二层叠加 tint（双层玻璃的「厚度感」来源）
  static const double tintOverlayLight = 0.14;
  static const double tintOverlayDark = 0.10;

  /// 顶部边缘高光不透明度（FlClash 卡片边缘亮白线，很清晰）
  static const double highlightOpacityLight = 1.0;
  static const double highlightOpacityDark = 0.7;

  /// 内部反射渐变不透明度（玻璃内侧柔光，更强）
  static const double reflectionOpacityLight = 0.20;
  static const double reflectionOpacityDark = 0.12;

  /// 边缘描边不透明度（FlClash 卡片边缘清晰亮边）
  static const double borderOpacityLight = 0.75;
  static const double borderOpacityDark = 0.45;

  // ===================== 圆角 =====================
  static const double radiusXS = 8;
  static const double radiusS = 12;
  static const double radiusM = 16;
  static const double radiusL = 22;
  static const double radiusXL = 28;
  static const double radiusPill = 999;

  // ===================== 按钮规范 =====================
  static const double buttonHeight = 48;
  static const double buttonHeightSmall = 36;
  static const double buttonRadius = 14;
  static const double iconButtonSize = 44;
  static const double iconButtonSizeSmall = 36;

  /// 按下收缩比例
  static const double pressedScale = 0.96;
  static const double pressedScaleLarge = 0.92;

  /// 按下变淡到的透明度
  static const double pressedOpacity = 0.85;

  // ===================== 间距 =====================
  static const double gapXS = 4;
  static const double gapS = 8;
  static const double gapM = 12;
  static const double gapL = 16;
  static const double gapXL = 24;

  // ===================== 阴影（随明暗变化） =====================

  /// 玻璃环境阴影：多层立体（FlClash 卡片悬浮感）
  static List<BoxShadow> shadow(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    return [
      // 远层：柔和扩散
      BoxShadow(
        color: isDark ? const Color(0x59000000) : const Color(0x0F000000),
        blurRadius: 28,
        offset: const Offset(0, 10),
      ),
      // 近层：紧贴，定义卡片边缘
      BoxShadow(
        color: isDark ? const Color(0x40000000) : const Color(0x0A000000),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// 浮层（弹窗/菜单）阴影：更重，突出层次
  static List<BoxShadow> shadowOverlay(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark ? const Color(0x8A000000) : const Color(0x22000000),
        blurRadius: 40,
        offset: const Offset(0, 16),
      ),
      BoxShadow(
        color: isDark ? const Color(0x40000000) : const Color(0x0A000000),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }

  // ===================== 玻璃底色（随明暗变化） =====================

  /// 玻璃底色（第一层）
  static Color tint(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    return (isDark ? AppColors.darkSurfaceElevated : Colors.white).withValues(
      alpha: isDark ? tintOpacityDark : tintOpacityLight,
    );
  }

  /// 第二层叠加 tint（双层玻璃厚度）
  static Color tintOverlay(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    return (isDark ? AppColors.darkFill : Colors.white).withValues(
      alpha: isDark ? tintOverlayDark : tintOverlayLight,
    );
  }

  /// 顶部高光色
  static Color highlight(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    return Colors.white.withValues(
      alpha: isDark ? highlightOpacityDark : highlightOpacityLight,
    );
  }

  /// 内部反射色（浅色用白、深色用微白）
  static Color reflection(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    return Colors.white.withValues(
      alpha: isDark ? reflectionOpacityDark : reflectionOpacityLight,
    );
  }

  /// 边缘描边色
  static Color border(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    return Colors.white.withValues(
      alpha: isDark ? borderOpacityDark : borderOpacityLight,
    );
  }

  // ===================== 动画规范 =====================

  /// 按下：快速收缩、无弹跳
  static const Duration pressIn = Duration(milliseconds: 160);
  static const Curve curvePressIn = Curves.easeOutCubic;

  /// 松开：回弹带轻微过冲
  static const Duration pressOut = Duration(milliseconds: 300);
  static const Curve curvePressOut = Curves.easeOutBack;

  /// 淡入淡出
  static const Duration fade = Duration(milliseconds: 130);
  static const Curve curveFade = Curves.easeOut;

  /// 展开/收起
  static const Duration expand = Duration(milliseconds: 240);
  static const Curve curveExpand = Curves.easeOutCubic;

  /// 弹窗出现
  static const Duration dialogIn = Duration(milliseconds: 200);
  static const Curve curveDialogIn = Curves.easeOutBack;
}
