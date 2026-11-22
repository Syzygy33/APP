import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/glass_design.dart';
import '../pressable.dart';
import 'glass_container.dart';

/// 按钮视觉变体
enum GlassButtonVariant {
  /// 主操作：强调色玻璃
  primary,

  /// 次操作：中性玻璃
  secondary,

  /// 文字按钮：无玻璃底
  text,

  /// 圆形图标按钮
  icon,

  /// 危险操作：红字
  destructive,

  /// 悬浮新增按钮（加号）
  fab,
}

/// 全局统一按钮。覆盖圆形图标 / 文字 / 主操作 / 次操作 / 悬浮新增 / 更多 / 菜单选项等。
///
/// 5 态：默认、按下（缩小+回弹）、选中、禁用、加载。
/// 点击反馈柔和，配轻触觉，禁止夸张弹跳。
class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final GlassButtonVariant variant;

  /// 选中态（toggle 类按钮，如分段选择）
  final bool selected;

  /// 禁用态：降低不透明度、不响应点击
  final bool disabled;

  /// 加载态：显示进度圈、不响应点击
  final bool loading;

  final double? width;
  final double height;
  final EdgeInsetsGeometry? padding;
  final bool haptics;

  const GlassButton({
    super.key,
    required this.child,
    required this.onTap,
    this.variant = GlassButtonVariant.secondary,
    this.selected = false,
    this.disabled = false,
    this.loading = false,
    this.width,
    this.height = Glass.buttonHeight,
    this.padding,
    this.haptics = true,
  });

  /// 圆形图标按钮便捷构造
  const GlassButton.icon({
    super.key,
    required this.child,
    required this.onTap,
    this.selected = false,
    this.disabled = false,
    this.loading = false,
    this.width = Glass.iconButtonSize,
    this.height = Glass.iconButtonSize,
    this.haptics = true,
  }) : variant = GlassButtonVariant.icon,
       padding = null;

  /// 悬浮新增按钮便捷构造
  const GlassButton.fab({
    super.key,
    required this.child,
    required this.onTap,
    this.disabled = false,
    this.loading = false,
    this.width = 52,
    this.height = 52,
    this.haptics = true,
  }) : variant = GlassButtonVariant.fab,
       selected = false,
       padding = null;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;
    final bool blocked = disabled || loading;
    final VoidCallback? effectiveTap = blocked ? null : onTap;

    final Color accent = isDark ? AppColors.accentDark : AppColors.accent;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    // 文字色
    final Color fg = switch (variant) {
      GlassButtonVariant.primary => Colors.white,
      GlassButtonVariant.destructive => AppColors.red,
      GlassButtonVariant.text => accent,
      GlassButtonVariant.fab => isDark ? const Color(0xFF1C1C1E) : Colors.white,
      _ => textPrimary,
    };

    final Widget inner = loading
        ? Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: variant == GlassButtonVariant.fab
                    ? (isDark ? const Color(0xFF1C1C1E) : Colors.white)
                    : accent,
              ),
            ),
          )
        : DefaultTextStyle(
            style: TextStyle(color: fg),
            child: IconTheme(
              data: IconThemeData(color: fg, size: 20),
              child: child,
            ),
          );

    final double radius = switch (variant) {
      GlassButtonVariant.icon => Glass.radiusPill,
      GlassButtonVariant.fab => Glass.radiusPill,
      GlassButtonVariant.text => Glass.radiusS,
      _ => Glass.buttonRadius,
    };

    // 玻璃底：text 无底，primary 用强调色实心，其余用玻璃
    final Widget surface;
    if (variant == GlassButtonVariant.text) {
      surface = Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: width,
          height: height,
          child: Center(child: inner),
        ),
      );
    } else if (variant == GlassButtonVariant.primary) {
      surface = Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: Glass.shadow(brightness),
        ),
        child: Center(child: inner),
      );
    } else if (variant == GlassButtonVariant.fab) {
      surface = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? Colors.white : const Color(0xFF1C1C1E),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x4D000000) : const Color(0x2E000000),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(child: inner),
      );
    } else {
      surface = GlassContainer(
        radius: radius,
        blur: Glass.blurMedium,
        padding: padding,
        child: SizedBox(
          width: width,
          height: height,
          child: Center(child: inner),
        ),
      );
    }

    return Opacity(
      opacity: blocked ? 0.5 : 1.0,
      child: PressableScale(
        onTap: effectiveTap,
        haptics: haptics && !blocked,
        pressedScale: variant == GlassButtonVariant.fab
            ? Glass.pressedScaleLarge
            : Glass.pressedScale,
        child: selected
            ? DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: accent, width: 1.5),
                ),
                child: surface,
              )
            : surface,
      ),
    );
  }
}
