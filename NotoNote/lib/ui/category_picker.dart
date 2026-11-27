import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../models/category.dart';

/// 分类选择器：一行胶囊，点开是全部可选分类。
///
/// 做成胶囊而不是下拉框：手机上没有原生下拉，胶囊的点击区域也更好按。
/// 笔记和待办共用——两边都往同一套分类里归类，选项必须一致。
///
/// 开了液态玻璃时胶囊带玻璃质感（与顶栏按钮同一套 `LiquidGlassStyle`），
/// 关掉则退回普通表面色，保证不透明环境下也清晰。
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final NoteCategory value;
  final ValueChanged<NoteCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupAnchor(
        targetBuilder: (open) => _Pill(
          colorScheme: colorScheme,
          onPressed: open,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: value.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(value.name, style: AppTextStyle.subheadline.of(context)),
              const SizedBox(width: 4),
              GlyphIcon(
                Glyphs.chevronDown,
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        popupBuilder: (_) => PopupMenu(
          // 最多显示 3 行，多出的靠滚动；半行露头提示可滚。
          maxVisibleItems: 3,
          items: [
            // 「无分类」排最前，其余分类按网格顺序跟在后面。
            for (final category in NoteCategory.all)
              if (NoteCategory.isFallback(category.name))
                PopupMenuItem(
                  label: category.name,
                  checked: category.name == value.name,
                  onPressed: () => onChanged(category),
                ),
            for (final category in NoteCategory.all)
              if (!NoteCategory.isFallback(category.name))
                PopupMenuItem(
                  label: category.name,
                  checked: category.name == value.name,
                  onPressed: () => onChanged(category),
                ),
          ],
        ),
      ),
    );
  }
}

/// 胶囊外壳：有玻璃走液态玻璃，否则走实心表面。
class _Pill extends StatelessWidget {
  const _Pill({
    required this.colorScheme,
    required this.onPressed,
    required this.child,
  });

  final ColorScheme colorScheme;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: child,
      ),
    );
    if (LiquidGlassScope.of(context)) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: LiquidGlass(
          style: LiquidGlassStyle.regular(colorScheme),
          child: content,
        ),
      );
    }
    return PressSurface(
      fill: context.raisedSurfaceLevel.colorOf(colorScheme),
      shape: AppShape.full,
      onPressed: onPressed,
      minimum: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: child,
    );
  }
}
