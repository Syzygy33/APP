import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import 'glass/glass_container.dart';
import 'app_trash_icon.dart';

/// 卡片滑动时的底层提示：左滑露出删除、右滑露出收藏。
///
/// 圆角与外边距与卡片保持一致，滑动时看起来是「同一张卡片下面的一层」。
///
/// **跟手驱动**（不是循环动画）：外部把 `Dismissible.onUpdate` 的
/// `progress`（0→1）喂给 [progress]，这里按进度实时算出
/// 图标的缩放、透明度与滑入位移——滑多少露多少，松手回弹时同步收回。
class SwipeActionBackground extends StatelessWidget {
  final bool leftSide;
  final Color color;
  final Widget icon;
  final String label;

  /// 滑动进度 0→1（0 = 未滑动，1 = 达到滑走阈值）
  final double progress;

  const SwipeActionBackground({
    super.key,
    required this.leftSide,
    required this.color,
    required this.icon,
    required this.label,
    this.progress = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // 进度曲线：前 60% 快速到位，后段轻微过冲一点，手感更「弹」
    final double t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final double scale = 0.55 + 0.45 * t;
    final double opacity = Curves.easeOut.transform(
      (progress * 1.6).clamp(0.0, 1.0),
    );
    // 图标从边缘向内滑入一小段，做出「被拉出来」的感觉
    final double slide = (1 - t) * 24;

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leftSide) ...[
          IconTheme(
            data: const IconThemeData(color: Colors.white, size: 22),
            child: icon,
          ),
          const SizedBox(width: AppDims.s8),
          Text(label, style: _labelStyle),
        ] else ...[
          Text(label, style: _labelStyle),
          const SizedBox(width: AppDims.s8),
          IconTheme(
            data: const IconThemeData(color: Colors.white, size: 22),
            child: icon,
          ),
        ],
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 磨砂玻璃层
          const GlassContainer(
            overlay: true,
            radius: 28,
            child: SizedBox.expand(),
          ),
          // 强调色染色层：随进度加深，滑出越多颜色越实
          ColoredBox(
            color: color.withValues(alpha: 0.28 + 0.34 * t),
          ),
          // 跟手内容层
          Align(
            alignment:
                leftSide ? Alignment.centerLeft : Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDims.s24),
              child: Opacity(
                key: const ValueKey('swipe-action-content'),
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(leftSide ? -slide : slide, 0),
                  child: Transform.scale(
                    key: const ValueKey('swipe-action-scale'),
                    scale: scale,
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _labelStyle => const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );
}

/// 删除侧统一使用红色 + 垃圾桶
class SwipeDeleteBackground extends StatelessWidget {
  final bool leftSide;
  final double progress;

  const SwipeDeleteBackground({
    super.key,
    required this.leftSide,
    this.progress = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SwipeActionBackground(
      leftSide: leftSide,
      color: AppColors.red.withValues(alpha: 0.92),
      icon: const AppTrashIcon(size: 22, color: Colors.white),
      label: '删除',
      progress: progress,
    );
  }
}

/// 收藏侧统一使用橙色 + 星标
class SwipeFavoriteBackground extends StatelessWidget {
  final bool leftSide;
  final bool favorited;
  final double progress;

  const SwipeFavoriteBackground({
    super.key,
    required this.leftSide,
    this.favorited = false,
    this.progress = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SwipeActionBackground(
      leftSide: leftSide,
      color: AppColors.orange.withValues(alpha: 0.92),
      icon: const Icon(LucideIcons.star, color: Colors.white, size: 22),
      label: favorited ? '取消收藏' : '收藏',
      progress: progress,
    );
  }
}
