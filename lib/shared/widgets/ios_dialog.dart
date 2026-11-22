import 'dart:ui';

// hide 同名的 GlassContainer，避免与本项目自写的磨砂卡片组件冲突
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    hide GlassContainer;
import 'package:material_ui/material_ui.dart';

import '../../app/theme/glass_design.dart';
import '../glass/liquid_glass_tokens.dart';
import 'glass/glass_container.dart';
import 'pressable.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';

/// iOS 风格居中弹窗（alert）。带背景模糊遮罩，模糊只作用于遮罩一次。
class IOSAlertDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final Widget? content;
  final List<IOSDialogAction> actions;

  const IOSAlertDialog({
    super.key,
    this.title,
    this.message,
    this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
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

    return PopScope<void>(
      canPop: true,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppDims.blurOverlay,
          sigmaY: AppDims.blurOverlay,
        ),
        child: Container(
          color: isDark ? const Color(0x66000000) : const Color(0x33000000),
          alignment: Alignment.center,
          child: Center(
            child: AnimatedScale(
              scale: 1.0,
              duration: AppDims.animNormal,
              curve: Curves.easeOutBack,
              child: SizedBox(
                width: 280,
                child: GlassContainer(
                  radius: AppDims.radiusXL,
                  overlay: true,
                  blur: Glass.blurHeavy,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDims.s20,
                          AppDims.s24,
                          AppDims.s20,
                          AppDims.s16,
                        ),
                        child: Column(
                          children: [
                            if (title != null)
                              Text(
                                title!,
                                textAlign: TextAlign.center,
                                style: AppTypography.headline.copyWith(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (message != null) ...[
                              const SizedBox(height: AppDims.s6),
                              Text(
                                message!,
                                textAlign: TextAlign.center,
                                style: AppTypography.footnote.copyWith(
                                  color: textSecondary,
                                ),
                              ),
                            ],
                            if (content != null) ...[
                              const SizedBox(height: AppDims.s12),
                              content!,
                            ],
                          ],
                        ),
                      ),
                      Divider(height: 0.5, color: separator),
                      Row(
                        children: actions.asMap().entries.map((entry) {
                          final int i = entry.key;
                          final IOSDialogAction a = entry.value;
                          return Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: PressableScale(
                                onTap: () {
                                  Navigator.of(context).pop(a.value);
                                  a.onPressed?.call();
                                },
                                child: Container(
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: i > 0
                                        ? Border(
                                            left: BorderSide(
                                              color: separator,
                                              width: 0.5,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: Text(
                                    a.label,
                                    style: AppTypography.body.copyWith(
                                      color: a.destructive
                                          ? AppColors.red
                                          : (a.preferred
                                                ? accent
                                                : textSecondary),
                                      fontWeight: a.preferred
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class IOSDialogAction<T> {
  final String label;
  final T value;
  final bool preferred;
  final bool destructive;
  final VoidCallback? onPressed;

  const IOSDialogAction({
    required this.label,
    required this.value,
    this.preferred = false,
    this.destructive = false,
    this.onPressed,
  });
}

/// 便捷函数：显示 iOS 风格确认弹窗。返回 true 表示确认。
///
/// 改用 liquid_glass_widgets 的 [GlassDialog]（真机走液态玻璃材质）。
Future<bool?> showIOSConfirm({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool destructive = false,
}) {
  return GlassDialog.show<bool>(
    context: context,
    title: title,
    message: message,
    // 与全 App 卡片统一圆角 28
    shape: const LiquidRoundedSuperellipse(borderRadius: 28),
    // 浮层专用玻璃：官方 overlay 预设（左上单向光源），
    // 边缘只在受光侧亮，不会在深色底上形成一圈白光
    settings: LiquidGlassTokens.glassOverlay,
    actions: [
      GlassDialogAction(
        label: cancelLabel,
        onPressed: () =>
            Navigator.of(context, rootNavigator: true).pop(false),
      ),
      GlassDialogAction(
        label: confirmLabel,
        isPrimary: true,
        isDestructive: destructive,
        onPressed: () =>
            Navigator.of(context, rootNavigator: true).pop(true),
      ),
    ],
  );
}
