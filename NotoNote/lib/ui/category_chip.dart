import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import '../models/category.dart';

/// 卡片底部的分类提示：分类色点 + 名字，浅色胶囊底。
///
/// 笔记/待办只要加入了分类（非「未分类」）就在卡片底部挂一个，
/// 让「这条属于哪」一眼可见。传 [NoteCategory.fallbackName] 时不渲染。
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.categoryName});

  final String categoryName;

  @override
  Widget build(BuildContext context) {
    if (NoteCategory.isFallback(categoryName)) {
      return const SizedBox.shrink();
    }
    final category = NoteCategory.of(categoryName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: ShapeDecoration(
        color: category.color.withValues(alpha: 0.14),
        shape: AppShape.all(AppCorner.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            category.name,
            style: AppTextStyle.caption2
                .of(context)
                .copyWith(color: category.color),
          ),
        ],
      ),
    );
  }
}
