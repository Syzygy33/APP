import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import 'app_page_bar.dart';

/// 多选模式下浮在底部导航上方的批量操作栏。
///
/// 与 [FloatingAddButton] 同一套定位（BottomInsetScope），互相替换出现，
/// 不会出现两个按钮叠在一起。
class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({
    super.key,
    required this.count,
    required this.onSelectAll,
    required this.onDelete,
    required this.onCancel,
    this.canSelectAll = true,
    this.extraActionLabel,
    this.onExtraAction,
  });

  /// 已选数量，0 时删除不可点。
  final int count;

  final VoidCallback onSelectAll;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  /// 收藏页/分类页可能没有「全选」语义，置 false 隐藏。
  final bool canSelectAll;

  /// 可选的第二操作（如分类详情页的「移出分类」）。仅在有选择时显示。
  final String? extraActionLabel;
  final VoidCallback? onExtraAction;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: context.bottomInset + 16),
        child: TonalButtonTheme(
          glass: LiquidGlassScope.of(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: ShapeDecoration(
              color: SurfaceLevel.block.colorOf(context.colorScheme),
              shape: AppShape.xl,
              shadows: [
                BoxShadow(
                  color: context.colorScheme.shadow.withValues(alpha: 0.16),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BarIconButton(
                  data: IconButtonData(
                    glyph: Glyphs.close,
                    tooltip: '取消选择',
                    onPressed: onCancel,
                  ),
                ),
                const SizedBox(width: 4),
                if (canSelectAll)
                  BarIconButton(
                    data: IconButtonData(
                      glyph: Glyphs.selectAll,
                      tooltip: '全选',
                      onPressed: onSelectAll,
                    ),
                  ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    count == 0 ? '未选择' : '已选 $count 项',
                    style: AppTextStyle.subheadline.of(context),
                  ),
                ),
                if (extraActionLabel != null) ...[
                  TonalButton(
                    label: extraActionLabel!,
                    onPressed: count == 0 ? null : onExtraAction,
                  ),
                  const SizedBox(width: 8),
                ],
                TonalButton(
                  label: '删除',
                  onPressed: count == 0 ? null : onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
