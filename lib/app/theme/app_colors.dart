import 'package:material_ui/material_ui.dart';

/// iOS 26 系统语义色板。
/// 所有颜色均为语义化命名，禁止在业务代码中直接写死 Color 值。
class AppColors {
  AppColors._();

  // ---- 品牌强调色 (iOS systemBlue / 玻璃高光蓝) ----
  static const Color accent = Color(0xFF0A84FF);
  static const Color accentDark = Color(0xFF409CFF);
  static const Color accentPressed = Color(0xFF0062CC);

  // ---- 语义色 (iOS 15 system colors, dark variant) ----
  static const Color green = Color(0xFF30D158);
  static const Color orange = Color(0xFFFF9F0A);
  static const Color red = Color(0xFFFF453A);
  static const Color purple = Color(0xFFBF5AF2);
  static const Color teal = Color(0xFF40C8E0);
  static const Color pink = Color(0xFFFF375F);
  static const Color indigo = Color(0xFF5E5CE6);

  // ---- 浅色模式中性色 ----
  // 背景不用纯白系浅灰，改中性柔灰：与纯白卡片拉开层次，玻璃层才显形
  static const Color lightBackground = Color(0xFFEDECF1);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1C1C1E);
  static const Color lightTextSecondary = Color(0xFF6E6E73);
  static const Color lightTextTertiary = Color(0xFFAEAEB2);
  static const Color lightSeparator = Color(0x3C3C4349);
  static const Color lightFill = Color(0xFFE5E5EA);

  // ---- 深色模式中性色 ----
  // 纯黑太硬、玻璃在纯黑上没有明暗差可成像，改深灰
  static const Color darkBackground = Color(0xFF121214);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkSurfaceElevated = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF98989F);
  static const Color darkTextTertiary = Color(0xFF636366);
  static const Color darkSeparator = Color(0x54584A50);
  static const Color darkFill = Color(0xFF2C2C2E);

  // ---- 玻璃材质 (Liquid Glass) ----
  // 浅色：高透明白 + 极细边框高光；深色：低透明度深灰 + 微弱白边
  static const Color glassLightTint = Color(0xB3FFFFFF);
  static const Color glassDarkTint = Color(0x4D2C2C2E);
  static const Color glassLightBorder = Color(0x59FFFFFF);
  static const Color glassDarkBorder = Color(0x2EFFFFFF);
  static const Color glassLightShadow = Color(0x1A000000);
  static const Color glassDarkShadow = Color(0x66000000);

  // ---- 玻璃导航栏 ----
  static const Color navBarLightTint = Color(0xD9F9F9F9);
  static const Color navBarDarkTint = Color(0xB31C1C1E);
  static const Color navBarLightBorder = Color(0x4DFFFFFF);
  static const Color navBarDarkBorder = Color(0x26FFFFFF);
  static const Color navBarActiveLight = Color(0xFF0A84FF);
  static const Color navBarActiveDark = Color(0xFF409CFF);
  static const Color navBarInactive = Color(0xFF8E8E93);

  /// 分类颜色循环池 —— 新建文件夹时按索引取色。
  static const List<Color> categoryPalette = [
    accent,
    green,
    orange,
    purple,
    teal,
    pink,
    indigo,
    red,
  ];

  static Color categoryColor(int index) =>
      categoryPalette[index % categoryPalette.length];
}
