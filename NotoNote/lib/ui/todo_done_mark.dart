import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

/// 待办完成圆点：未完成是空心圈，完成是绿色填充 + 白勾。
///
/// 待办页卡片、收藏页与分类内容页的待办行共用同一个视觉，
/// 保证「待办状态」在三处看起来完全一样。点圆点只切完成状态，
/// 靠 [HitTestBehavior.opaque] 吞掉点击，不冒泡到整行的 onTap。
class TodoDoneMark extends StatelessWidget {
  const TodoDoneMark({
    super.key,
    required this.done,
    required this.onTap,
    this.size = 24,
  });

  final bool done;
  final VoidCallback onTap;

  /// 圆点直径，列表行里可以比卡片略小。
  final double size;

  @override
  Widget build(BuildContext context) {
    // 完成态用系统绿；prism_ui 的 ColorScheme 没有语义色，直接取色值
    const doneColor = Color(0xFF34C759);
    final colorScheme = context.colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // 圆点本身较小，撑到 44 的可点区域（列表行里不占那么多视觉空间）
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: AnimatedContainer(
            duration: context.motionDuration(midDuration),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: done ? doneColor : const Color(0x00000000),
              shape: BoxShape.circle,
              border: Border.all(
                color: done ? doneColor : colorScheme.onSurfaceVariant,
                width: 2,
              ),
            ),
            child: done
                ? Center(
                    child: GlyphIcon(
                      Glyphs.check,
                      size: 13,
                      color: const Color(0xFFFFFFFF),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
