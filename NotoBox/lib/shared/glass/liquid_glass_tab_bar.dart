import 'package:material_ui/material_ui.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassSegment, GlassSegmentedControl;

import '../../app/theme/glass_ink.dart';

/// 胶囊式液态玻璃标签栏。
///
/// 引擎：`liquid_glass_widgets` 的 `GlassSegmentedControl`
/// （玻璃透镜指示器，会随选中项滑动）。
///
/// 颜色显式指定：库默认色在深色模式下会出现「黑底黑字」，
/// 所以选中项固定在白色胶囊上用黑色，未选中按明暗取半透明主色。
class LiquidGlassTabBar<T> extends StatelessWidget {
  const LiquidGlassTabBar({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height = 44,
    this.labelStyle,
  });

  /// 值 → 显示内容（通常是文字，也可以是图标+文字）
  final Map<T, Widget> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final List<T> keys = segments.keys.toList();
    final int index = keys.indexOf(selected);

    return GlassSegmentedControl(
      segments: [
        for (final T k in keys)
          GlassSegment(
            label: _labelOf(segments[k]!),
            icon: _iconOf(segments[k]!),
          ),
      ],
      selectedIndex: index < 0 ? 0 : index,
      onSegmentSelected: (i) => onChanged(keys[i]),
      height: height,
      selectedIconColor: const Color(0xFF000000),
      unselectedIconColor: GlassInk.secondary(context),
      selectedTextStyle: (labelStyle ?? const TextStyle(fontSize: 13))
          .copyWith(
            color: const Color(0xFF000000),
            fontWeight: FontWeight.w600,
          ),
      unselectedTextStyle: (labelStyle ?? const TextStyle(fontSize: 13))
          .copyWith(
            color: GlassInk.secondary(context),
            fontWeight: FontWeight.w500,
          ),
    );
  }

  /// 从传入的 Widget 里提取文字（Text 或含 Text 的组合）
  String? _labelOf(Widget w) => w is Text ? (w.data ?? '') : null;

  Widget? _iconOf(Widget w) => w is Icon ? w : null;
}
