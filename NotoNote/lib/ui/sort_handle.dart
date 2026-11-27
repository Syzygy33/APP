import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

/// 排序模式里卡片左侧的拖动手柄（三条横线）。
///
/// 只负责长相：排序模式下按住卡片**任何位置**都能拖（见 [sortableCard]），
/// 手柄只是一个「这里可以拖」的视觉提示。
class SortGrip extends StatelessWidget {
  const SortGrip({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GlyphIcon(
        Glyphs.dragHandle,
        size: size,
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 排序模式下把整张卡片变成拖动把手。
///
/// 手势由 [_ImmediateDrag] 接管：指针一移动越过 slop 就开始拖，
/// **不用先长按**（prism_ui 自带那版对触摸用的是 DelayedMultiDrag，
/// 也就是「按住等一下才能拖」，桌面鼠标却很顺——手机上就是这个差别）。
///
/// [dragIndex] 为 null（不在排序模式）时原样返回，调用方可以直接套用。
Widget sortableCard(Widget card, int? dragIndex) {
  if (dragIndex == null) {
    return card;
  }
  return _ImmediateDrag(index: dragIndex, child: card);
}

/// 和 prism_ui 的 `ReorderDragStartListener` 同一条路子（都调
/// `SliverReorderableList.startItemDragReorder`），只是换成
/// [ImmediateMultiDragGestureRecognizer]：触摸也立刻起拖。
class _ImmediateDrag extends StatelessWidget {
  const _ImmediateDrag({required this.index, required this.child});

  final int index;
  final Widget child;

  void _handlePointerDown(BuildContext context, PointerDownEvent event) {
    final recognizer = ImmediateMultiDragGestureRecognizer(debugOwner: this)
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    SliverReorderableList.maybeOf(
      context,
    )?.startItemDragReorder(index: index, event: event, recognizer: recognizer);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(onPointerDown: (event) => _handlePointerDown(context, event), child: child);
  }
}
