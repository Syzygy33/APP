import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/glass_design.dart';
import 'glass/glass_container.dart';
import '../glass/liquid_glass_tokens.dart';

/// iOS 风格底部面板。带拖拽把手、背景模糊遮罩，从底部滑入。
class IOSBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final double? maxHeightFactor;

  const IOSBottomSheet({
    super.key,
    this.title,
    required this.child,
    this.maxHeightFactor = 0.82,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppDims.blurOverlay,
          sigmaY: AppDims.blurOverlay,
        ),
        child: Container(
          color: isDark ? const Color(0x66000000) : const Color(0x2E000000),
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // 阻止冒泡关闭
            child: FractionallySizedBox(
              widthFactor: 1.0,
              heightFactor: maxHeightFactor,
              // 外层投影：抽屉必须明显浮在内容之上。
              // 双层（近影定轮廓、远影拉开距离），只在向上方向投，
              // 所以 offset 用负值，模拟光从上方来。
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: AppDims.sheetRadius,
                  boxShadow: LiquidGlassTokens.overlayShadows(context),
                ),
                child: GlassContainer(
                  borderRadius: AppDims.sheetRadius,
                  overlay: true,
                  blur: Glass.blurHeavy,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 拖拽把手
                      const SizedBox(height: AppDims.s10),
                      Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary.withValues(
                                  alpha: 0.4,
                                ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      if (title != null) ...[
                        const SizedBox(height: AppDims.s16),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDims.s20,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title!,
                                  style: AppTypography.title3.copyWith(
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                                style: IconButton.styleFrom(
                                  backgroundColor: isDark
                                      ? AppColors.darkFill
                                      : AppColors.lightFill,
                                  foregroundColor: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppDims.s12),
                      Expanded(child: child),
                      SizedBox(
                        height:
                            MediaQuery.of(context).padding.bottom + AppDims.s12,
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

/// 便捷展示函数（带 iOS 滑入动画）
Future<T?> showIOSBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  String? title,
  double? maxHeightFactor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    // 与动作面板一致：挂根导航器，避免被外壳层的悬浮底栏/加号遮挡点击
    useRootNavigator: true,
    builder: (ctx) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 0.0),
      duration: AppDims.animNormal,
      curve: Curves.easeOutCubic,
      builder: (_, offset, child) => Transform.translate(
        offset: Offset(0, MediaQuery.of(ctx).size.height * offset * 0.25),
        child: Opacity(opacity: 1.0 - offset * 1.5, child: child),
      ),
      child: IOSBottomSheet(
        title: title,
        maxHeightFactor: maxHeightFactor,
        child: builder(ctx),
      ),
    ),
  );
}
