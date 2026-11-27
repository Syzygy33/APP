import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../common/relative_time.dart';
import '../models/category.dart';
import '../models/note.dart';
import 'category_chip.dart';
import 'highlighted_text.dart';
import 'icons/app_glyphs.dart';
import 'pin_badge.dart';

/// 一条笔记的卡片。
///
/// 笔记列表和收藏页共用同一个组件——两处展示逻辑必须一致，
/// 否则改一处漏一处，肉眼很难发现。
///
/// 用 prism_ui 的 `Card`：它自带按压高亮、最小点击区，并把子级包进
/// `SurfaceScope`，卡片里再放卡片会自动升一级表面色。
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onPressed,
    this.query = '',
    this.sortHandle,
  });

  final Note note;

  final VoidCallback onPressed;

  /// 排序模式下左侧的拖动手柄；为 null 时不显示。
  final Widget? sortHandle;

  /// 当前搜索词，用于命中高亮；空串表示未搜索。
  final String query;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final metaStyle = AppTextStyle.caption1
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final excerptStyle = AppTextStyle.subheadline
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    return Card(
      onPressed: onPressed,
      radius: AppCorner.xl,
      padding: const EdgeInsets.all(16),
      // 手柄挂在卡片左缘的垂直中线上：外层 Row 居中，内容整体撑高，
      // 手柄就跟着内容高度居中，卡片变高也不会贴到标题那行。
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ?sortHandle,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (note.pinned) ...[
                      PinBadge(
                        size: 20,
                        child: GlyphIcon(
                          Glyphs.pin,
                          size: 14,
                          fill: 1,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                    ],
                    Expanded(
                      child: HighlightedText(
                        text: note.title,
                        query: query,
                        maxLines: 1,
                        style: AppTextStyle.headline.of(context),
                      ),
                    ),
                    if (note.favorite) ...[
                      const SizedBox(width: 8),
                      GlyphIcon(
                        AppGlyphs.star,
                        size: 14,
                        fill: 1,
                        color: colorScheme.primary,
                      ),
                    ],
                    const SizedBox(width: 10),
                    Text(relativeTime(note.updatedAt), style: metaStyle),
                  ],
                ),
                if (note.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  HighlightedText(
                    text: note.excerpt,
                    query: query,
                    maxLines: 2,
                    style: excerptStyle,
                  ),
                ],
                // 加入了分类就在底部挂一个提示（未分类不显示）
                if (!NoteCategory.isFallback(note.category)) ...[
                  const SizedBox(height: 10),
                  CategoryChip(categoryName: note.category),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
