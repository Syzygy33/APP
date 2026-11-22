import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';

/// 空状态占位（无笔记/无结果）
class EmptyState extends StatelessWidget {
  /// 图标。与 [iconWidget] 二选一；传了 [iconWidget] 时优先用它。
  final IconData? icon;

  /// 自定义图标 Widget
  final Widget? iconWidget;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    this.icon,
    this.iconWidget,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDims.s40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkFill : AppColors.lightFill)
                    .withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: iconWidget ??
                  Icon(
                    icon,
                    size: 34,
                    color: secondary.withValues(alpha: 0.8),
                  ),
            ),
            const SizedBox(height: AppDims.s20),
            Text(
              title,
              style: AppTypography.title3,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppDims.s8),
              Text(
                subtitle!,
                style: AppTypography.subheadline.copyWith(color: secondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppDims.s24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// iOS 风格胶囊按钮
class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool filled;
  final Color? color;

  const PillButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.filled = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color base =
        color ?? (isDark ? AppColors.accentDark : AppColors.accent);
    return SizedBox(
      height: AppDims.touchTarget,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: filled ? base : base.withValues(alpha: 0.14),
          foregroundColor: filled ? Colors.white : base,
          padding: const EdgeInsets.symmetric(horizontal: AppDims.s24),
          shape: const StadiumBorder(),
          textStyle: AppTypography.callout,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon!, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// 区块标题（分组列表 header）
class SectionHeader extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionHeader({super.key, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDims.s20,
        AppDims.s20,
        AppDims.s16,
        AppDims.s8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text.toUpperCase(),
            style: AppTypography.caption1.copyWith(
              color: secondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
