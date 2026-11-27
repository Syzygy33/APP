import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// 分组标题（笔记 / 待办 / 未完成 / 已完成）统一的内边距。
///
/// 组件库的 `ListHeader` 默认会再缩进 [ListInsets.leading]（16），
/// 但本项目各页的统计头与卡片都从页面 margin 起，两者对不齐。
/// 这里把水平内边距归零、只保留上下间距，分组标题就与「全部 N」左缘一致。
EdgeInsets groupHeaderPadding(BuildContext context) {
  final base = listHeaderPaddingOf(context);
  return EdgeInsets.fromLTRB(0, base.top, 0, base.bottom);
}

/// 列表上方的统计头：「全部 N」+「笔记 x · 待办 y」。
///
/// 回收站、收藏、分类页共用。为了和笔记/待办页的 [ListFilterHeader] 逐像素对齐，
/// 这里必须占同样的高度：那边右边有颗 32dp 的「筛选」胶囊，文字是靠
/// `Row` 垂直居中对齐到这颗胶囊的中线的；统计头没有按钮，如果只按文字高度排，
/// 这一行会比笔记页高 5～6dp，切页签时「全部 N」就会跳一下。
/// 所以固定 `minHeight = TonalButtonSize.compact.button`，让文字落在同一条中线上。
class ListStatsHeader extends StatelessWidget {
  const ListStatsHeader({
    super.key,
    required this.noteCount,
    required this.todoCount,
    this.pending = false,
    this.padding = const EdgeInsets.only(bottom: 8),
  });

  final int noteCount;
  final int todoCount;

  /// 数据还没读出来时不显示 0，避免闪一下（与 `ListFilterHeader` 一致）。
  final bool pending;

  final EdgeInsets padding;

  /// 「筛选」胶囊的高度：`TonalButtonSize.compact.button`。
  /// 枚举字段不是常量表达式，取不到，这里写死同一个数。
  static const _rowHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final total = noteCount + todoCount;
    final style = AppTextStyle.subheadline.of(context);
    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _rowHeight),
        child: Row(
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '全部',
                    style: style.copyWith(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: ' $total',
                    style: style.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              pending
                  ? '笔记 — · 待办 —'
                  : '笔记 $noteCount · 待办 $todoCount',
              style: style.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
