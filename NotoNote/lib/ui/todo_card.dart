import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../models/category.dart';
import '../models/todo.dart';
import 'category_chip.dart';
import 'highlighted_text.dart';
import 'icons/app_glyphs.dart';
import 'pin_badge.dart';

/// 一条待办的卡片。
///
/// 待办列表、收藏页、分类内容页共用同一个组件——三处展示必须一致，
/// 否则改一处漏一处，肉眼很难发现。
class TodoCard extends StatelessWidget {
  const TodoCard({
    super.key,
    required this.todo,
    required this.onPressed,
    required this.onToggle,
    this.query = '',
    this.sortHandle,
  });

  /// 排序模式下左侧的拖动手柄；为 null 时不显示。
  final Widget? sortHandle;

  final Todo todo;

  /// 点卡片其余部分：进入详情。
  final VoidCallback onPressed;

  /// 点左侧圆点：只切换完成状态。
  final VoidCallback onToggle;

  /// 当前搜索词，用于命中高亮；空串表示未搜索。
  final String query;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    // 完成态用系统绿；prism_ui 的 ColorScheme 没有语义色，直接取色值
    const doneColor = Color(0xFF34C759);
    // 已完成用删除线（不再整卡变灰）。
    final textColor = todo.done
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurface;
    return Card(
      onPressed: onPressed,
      radius: AppCorner.lg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      // 圆点与手柄都落在卡片左缘的垂直中线上；排序模式下圆点让位给手柄，
      // 左侧只剩一个「能拖」的目标，不会把点完成误当成起拖。
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ?sortHandle,
          if (sortHandle == null) ...[
            // 左侧完成圆点：只有它切完成，不冒泡到卡片的 onPressed。
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              // 24 的圆点太小，撑到 44 的可点区域
              child: SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: AnimatedContainer(
                    duration: context.motionDuration(midDuration),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: todo.done ? doneColor : const Color(0x00000000),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: todo.done
                            ? doneColor
                            : colorScheme.onSurfaceVariant,
                        width: 2,
                      ),
                    ),
                    child: todo.done
                        ? const Center(
                            child: GlyphIcon(
                              Glyphs.check,
                              size: 13,
                              color: Color(0xFFFFFFFF),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (todo.pinned) ...[
                      PinBadge(
                        size: 20,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: GlyphIcon(
                            Glyphs.pin,
                            size: 13,
                            fill: 1,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 1),
                    ],
                    Expanded(
                      child: HighlightedText(
                        text: todo.text,
                        query: query,
                        maxLines: 2,
                        style: AppTextStyle.body
                            .of(context)
                            .copyWith(
                              color: textColor,
                              fontWeight: todo.done
                                  ? FontWeight.w400
                                  : FontWeight.w500,
                              // 完成态用删除线。
                              decoration: todo.done
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    if (todo.favorite) ...[
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: GlyphIcon(
                          AppGlyphs.star,
                          size: 13,
                          fill: 1,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (todo.detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  HighlightedText(
                    text: todo.detail,
                    query: query,
                    maxLines: 2,
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
                // 加入了分类就在底部挂一个提示（无分类不显示）
                if (!NoteCategory.isFallback(todo.category)) ...[
                  const SizedBox(height: 8),
                  CategoryChip(categoryName: todo.category),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
