import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// 品牌令牌。
///
/// 换肤只改这个文件：种子色、风格、纯黑开关三项，其余（圆角、字号、
/// 动效、表面层级）由 prism_ui 决定，不要在这里重写。
abstract final class AppTheme {
  /// 起始种子色：FlClash 默认主色（iOS system blue）。
  /// 换成品牌色后，整套配色（含深浅色、语义色容器）会自动重算。
  static const seedColor = Color(0xFF007AFF);

  /// 配色风格：
  /// - `soft`         柔和，FlClash 的默认观感
  /// - `vivid`        强调色更饱和鲜明
  /// - `tinted`       强调色鲜明，中性面也带色相
  /// - `monochrome`   全灰阶，只靠明度区分
  static const style = ColorStyle.soft;

  /// 深色模式压制到纯黑。OLED 省电，观感更"黑"。
  static const pureBlack = true;

  /// 自动跟随系统中文/日文字形，避免英文界面下中文渲染成日文字形。
  static const useSystemFontFallback = true;

  /// 当前主题模式。
  ///
  /// 骨架期先用全局 `ValueNotifier`，正式项目接入自己的状态管理后替换掉它，
  /// 只保留 [of] / [schemeOf] 两个入口即可。
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);

  /// 液态玻璃开关。
  ///
  /// 打开后导航栏、顶栏圆形按钮、弹层变成 iOS 27 的玻璃质感；关掉回到平面。
  /// 每帧要跑一次着色器，中低端机可以关掉换帧率，所以做成设置项而不是常量。
  static final liquidGlass = ValueNotifier<bool>(true);

  static final _schemes = <Brightness, ColorScheme>{};
  static final _themes = <Brightness, ThemeData>{};

  static ColorScheme schemeOf(Brightness brightness) =>
      _schemes[brightness] ??= seededColorScheme(
        seedColor: seedColor,
        brightness: brightness,
        style: style,
      ).toPureBlack(pureBlack);

  static ThemeData of(Brightness brightness) =>
      _themes[brightness] ??= _build(brightness);

  static ThemeData _build(Brightness brightness) {
    final scheme = schemeOf(brightness);
    return ThemeData(
      colorScheme: scheme,
      fontFamilyFallback: useSystemFontFallback
          ? appFontFamilyFallback(
              platform: defaultTargetPlatform,
              locales: WidgetsBinding.instance.platformDispatcher.locales,
            )
          : null,
      // 深色下弹层/表单需要比页面再亮一级，这是 prism_ui 的表面体系约定
      elevatedColorScheme: brightness == Brightness.dark
          ? scheme.elevated
          : null,
    );
  }
}
