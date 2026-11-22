import 'package:material_ui/material_ui.dart';

/// 统一字体规范 —— 基于 iOS San Francisco 文本样式尺度。
class AppTypography {
  AppTypography._();

  /// iOS 使用 -apple-system (SF Pro)。Android 上用系统 sans 逼近其观感。
  static const String fontFamily = '.SF Pro Display'; // 系统会 fallback 到默认 sans

  static const TextStyle largeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.9,
  );

  static const TextStyle title1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.7,
  );

  static const TextStyle title2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.45,
  );

  static const TextStyle title3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.4,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.2,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: -0.15,
  );

  static const TextStyle callout = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: -0.15,
  );

  static const TextStyle subheadline = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle caption1 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static const TextStyle caption2 = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );
}
