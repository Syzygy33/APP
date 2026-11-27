import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

/// 多选态下选择框出现的位置。
enum SelectionBoxPosition {
  /// 右侧垂直居中：笔记、收藏卡片用。
  centerEnd,

  /// 右上角：分类卡片用（那里平时是置顶符号的位置，已被移到左上）。
  topEnd,

  /// 不画框：卡片本体自己把某个控件（如待办右侧圆点）换成选择框。
  none,
}

/// 多选模式下包住卡片的壳：点整张卡片切换勾选，选择框常驻显示。
///
/// 不改卡片本体，复用同一个 [NoteCard]/待办行/分类卡片，保证多选态与
/// 普通态一致。选择框用 `IgnorePointer` 包住——点击交给下面铺满的
/// 手势层，否则点框本身会被它吃掉而不切换。
class SelectionWrap extends StatelessWidget {
  const SelectionWrap({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.boxPosition = SelectionBoxPosition.centerEnd,

    /// 分类卡片是固定尺寸的网格项，放进 Stack 后会因松约束而缩成一团，
    /// 必须给紧约束（Positioned.fill）才能保持原尺寸。
    this.fillChild = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final SelectionBoxPosition boxPosition;
  final bool fillChild;

  @override
  Widget build(BuildContext context) {
    // 右侧选择框要占独立一列，不能压住卡片末尾的时间文字。
    // 分类页走 topEnd + fillChild，不进来，所以卡片保持原尺寸。
    Widget content = child;
    if (boxPosition == SelectionBoxPosition.centerEnd) {
      content = Padding(
        padding: const EdgeInsetsDirectional.only(end: 44),
        child: content,
      );
    }    Widget card = IgnorePointer(child: content);
    if (fillChild) {
      card = Positioned.fill(child: card);
    }
    return Stack(
      children: [
        card,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: selected
                    ? context.colorScheme.primary.withValues(alpha: 0.10)
                    : const Color(0x00000000),
                shape: AppShape.xl,
              ),
            ),
          ),
        ),
        if (boxPosition == SelectionBoxPosition.centerEnd)
          PositionedDirectional(
            top: 0,
            bottom: 0,
            end: 14,
            child: IgnorePointer(
              child: Center(child: SelectionBox(selected: selected)),
            ),
          )
        else if (boxPosition == SelectionBoxPosition.topEnd)
          PositionedDirectional(
            top: 10,
            end: 10,
            child: IgnorePointer(
              child: SelectionBox(selected: selected, size: 22),
            ),
          ),
      ],
    );
  }
}

/// 常驻的圆角方形选择框：未选中时空心描边，选中时主色填充 + 白色勾。
class SelectionBox extends StatelessWidget {
  const SelectionBox({super.key, required this.selected, this.size = 24});

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return AnimatedContainer(
      duration: context.motionDuration(const Duration(milliseconds: 150)),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? colorScheme.primary : const Color(0x00000000),
        borderRadius: AppRadius.all(7),
        border: selected
            ? null
            : Border.all(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                width: 2,
              ),
      ),
      child: selected
          ? Center(
              child: GlyphIcon(
                Glyphs.check,
                size: size - 8,
                fill: 1,
                color: colorScheme.onPrimary,
              ),
            )
          : null,
    );
  }
}
