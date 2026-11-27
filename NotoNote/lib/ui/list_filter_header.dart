import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import '../models/category.dart';
import 'icons/app_glyphs.dart';

/// 列表顶部的「数量 + 筛选」一行。
///
/// 笔记和待办共用：两页的筛选语义完全一致（按时间排序、按分类过滤），
/// 各自只提供自己的菜单项，样式和位置保持相同。
class ListFilterHeader extends StatelessWidget {
  const ListFilterHeader({
    super.key,
    required this.label,
    required this.count,
    required this.items,
    this.pending = false,
    this.subVisibleItems = 4,
  });

  /// 当前过滤范围的名字，`全部` 或某个分类名。
  final String label;

  final int count;

  /// 数据还没读出来时不显示 0，避免闪一下。
  final bool pending;

  final List<PopupMenuItem> Function() items;

  /// 二级菜单一屏显示几行，超出的滚动。
  ///
  /// 传 4 而不是 3：`PopupMenu` 用「文字行高 + 内边距」估算行高，比实际行矮
  /// 约 4dp，所以 4 档才是肉眼上的三行加半行截断。
  final int subVisibleItems;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final insets = context.listInsets;
    final labelStyle = AppTextStyle.subheadline.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(insets.margin, 2, insets.margin, 8),
      child: Row(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: labelStyle.copyWith(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: pending ? ' —' : ' $count',
                  style: labelStyle.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          PopupAnchor(
            targetBuilder: (open) => TonalButton(
              size: TonalButtonSize.compact,
              glyph: AppGlyphs.funnel,
              label: '筛选',
              // 和顶栏那颗胶囊同一块玻璃，别在列表里露出一颗实心白块。
              glass: true,
              onPressed: open,
            ),
            popupBuilder: (_) =>
                PopupMenu(items: items(), subMaxVisibleItems: subVisibleItems),
          ),
        ],
      ),
    );
  }
}

/// 把一组分类转换成二级菜单项：顶部「全部」，其后是各分类。
///
/// `selected` 为 null 表示不按分类过滤。二级菜单只显示三行，超出可滑动。
List<PopupMenuItem> categoryFilterItems({
  required String? selected,
  required ValueChanged<String?> onSelected,
}) {
  return [
    PopupMenuItem(
      label: '全部',
      checked: selected == null,
      onPressed: () => onSelected(null),
    ),
    // 「无分类」紧跟「全部」，其余分类按网格顺序排在后面。
    for (final category in NoteCategory.all)
      if (NoteCategory.isFallback(category.name))
        PopupMenuItem(
          label: category.name,
          checked: selected == category.name,
          onPressed: () => onSelected(category.name),
        ),
    for (final category in NoteCategory.all)
      if (!NoteCategory.isFallback(category.name))
        PopupMenuItem(
          label: category.name,
          checked: selected == category.name,
          onPressed: () => onSelected(category.name),
        ),
  ];
}

/// 排序字段。前两种都是「最新在前」，所以只有一个方向；
/// [manual] 是用户拖动排出来的自定义顺序（没见过拖动的退回更新时间）。
enum ListSortField { updated, created, manual }

List<PopupMenuItem> sortFilterItems({
  required ListSortField current,
  required ValueChanged<ListSortField> onSelected,
}) {
  return [
    PopupMenuItem(
      label: '更新时间',
      checked: current == ListSortField.updated,
      onPressed: () => onSelected(ListSortField.updated),
    ),
    PopupMenuItem(
      label: '创建时间',
      checked: current == ListSortField.created,
      onPressed: () => onSelected(ListSortField.created),
    ),
    PopupMenuItem(
      label: '自定义',
      checked: current == ListSortField.manual,
      onPressed: () => onSelected(ListSortField.manual),
    ),
  ];
}
