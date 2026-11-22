import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// 应用主题：启用 Material 3 作为组件底座，但覆盖为 iOS 视觉语言。
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color background = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final Color surface = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final Color separator = isDark
        ? AppColors.darkSeparator
        : AppColors.lightSeparator;
    final Color accent = isDark ? AppColors.accentDark : AppColors.accent;

    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
      primary: accent,
      surface: surface,
      onSurface: textPrimary,
      error: AppColors.red,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      fontFamily: AppTypography.fontFamily,

      // 导航栏透明——交由自绘玻璃导航栏接管
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: accent, size: 22),
        titleTextStyle: AppTypography.headline.copyWith(color: textPrimary),
      ),

      // 分割线
      dividerTheme: DividerThemeData(
        color: separator,
        thickness: 0.5,
        space: 1,
      ),

      // 列表 tile —— iOS inset grouped 观感
      listTileTheme: ListTileThemeData(
        iconColor: accent,
        textColor: textPrimary,
        subtitleTextStyle: AppTypography.footnote.copyWith(
          color: textSecondary,
        ),
        titleTextStyle: AppTypography.body.copyWith(color: textPrimary),
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // 输入
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkFill : AppColors.lightFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: AppTypography.body.copyWith(color: textSecondary),
      ),

      // 底部面板/弹窗
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTypography.title2.copyWith(color: textPrimary),
        contentTextStyle: AppTypography.body.copyWith(color: textSecondary),
      ),

      // 开关/滑块走 iOS 风 accent
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? AppColors.darkTextTertiary : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return isDark ? AppColors.darkFill : AppColors.lightFill;
        }),
      ),

      // 文本选择
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.25),
        selectionHandleColor: accent,
      ),

      // 分页/进度
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),

      // 页面切换：iOS 风格——禁用 splash/高亮
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
    );
  }

  /// SystemUI 覆盖层样式（状态栏图标颜色随主题）
  static SystemUiOverlayStyle overlayStyle(Brightness brightness) =>
      brightness == Brightness.dark
      ? SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        )
      : SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        );
}
