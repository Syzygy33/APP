import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart' show HapticFeedback;

import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';

/// 浮层菜单的一行
class ContextMenuItem {
  final String label;

  /// 图标。与 [iconWidget] 二选一；传了 [iconWidget] 时优先用它。
  final IconData? icon;

  /// 自定义图标（用于实心垃圾桶这类没有等价字体图标的情况）
  final Widget? iconWidget;

  /// 破坏性操作（红字）
  final bool destructive;

  /// 选中态（右侧打勾），用于排序项
  final bool selected;

  /// 该项之前加分隔线（用于把「分类」和「排序」隔开）
  final bool dividerBefore;

  const ContextMenuItem({
    required this.label,
    this.icon,
    this.iconWidget,
    this.destructive = false,
    this.selected = false,
    this.dividerBefore = false,
  });
}

/// 从指定全局坐标就近弹出的浮层菜单（不占全宽）。
/// 返回选中项的索引，点空白/取消返回 null。
Future<int?> showContextMenu(
  BuildContext context, {
  required Offset position,
  required List<ContextMenuItem> items,
  double width = 240,
}) {
  final Size size = MediaQuery.of(context).size;
  const double itemHeight = 48;
  final double menuHeight = items.length * itemHeight + 8;

  // 垂直：优先向下弹，空间不够则向上
  double top = position.dy + 8;
  if (top + menuHeight > size.height - 16) {
    top = position.dy - menuHeight - 8;
    if (top < 16) top = 16;
  }

  // 水平：以触发点为中心，clamp 到屏幕内
  double left = position.dx - width / 2;
  if (left < 16) left = 16;
  if (left + width > size.width - 16) left = size.width - 16 - width;

  // 缩放原点指向触发点：菜单从「筛选 / 长按点」长出来，而不是从中心弹出。
  // 归一到 Alignment 的 -1..1（中心 0，左上角 -1，右下角 +1）。
  final double anchorX = ((position.dx - left) / width * 2 - 1).clamp(-1.0, 1.0);
  final double anchorY =
      ((position.dy - top) / menuHeight * 2 - 1).clamp(-1.0, 1.0);
  final Alignment menuAnchor = Alignment(anchorX, anchorY);

  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: const Color(0x26000000),
    pageBuilder: (ctx, _, _) {
      return _ContextMenuLayer(
        top: top,
        left: left,
        width: width,
        items: items,
        onSelected: (index) => Navigator.of(ctx).pop(index),
      );
    },
    // iOS 上下文菜单：从触发点缩放展开 + 淡入，带轻微弹性回弹，
    // 约 0.3 秒稳定——从容不"傻快"。
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween(begin: 0.72, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        ),
        alignment: menuAnchor,
        child: child,
      ),
    ),
    transitionDuration: const Duration(milliseconds: 300),
  );
}

class _ContextMenuLayer extends StatelessWidget {
  final double top;
  final double left;
  final double width;
  final List<ContextMenuItem> items;
  final ValueChanged<int> onSelected;

  const _ContextMenuLayer({
    required this.top,
    required this.left,
    required this.width,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color separator = isDark
        ? AppColors.darkSeparator
        : AppColors.lightSeparator;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          // 与底部悬浮导航栏同款磨砂玻璃：手写 BackdropFilter + 半透明底，
          // 不依赖 LiquidGlassLayer（弹层在 root overlay，跨层会渲染不出玻璃）。
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDims.radiusXL),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xC21C1C1E)
                      : const Color(0xC2FFFFFF),
                  borderRadius: BorderRadius.circular(AppDims.radiusXL),
                  border: Border.all(
                    color: isDark
                        ? const Color(0x33FFFFFF)
                        : const Color(0x338E8E93),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      if (i > 0 || items[i].dividerBefore)
                        Padding(
                          // 分割线比高亮块再内缩一点（16 对 8）：
                          // 高亮块比线更宽，压下去时像整行被「抬起来」，
                          // 而不是一条与线上下齐平的死板色条。
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDims.s16,
                          ),
                          child: Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: separator,
                          ),
                        ),
                      _MenuItem(item: items[i], onTap: () => onSelected(i)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatefulWidget {
  final ContextMenuItem item;
  final VoidCallback onTap;

  const _MenuItem({required this.item, required this.onTap});

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  /// 手指正按着
  bool _pressed = false;

  /// 已点中，高亮要一直留到菜单缩回去（从哪来回哪去）
  bool _committed = false;

  bool get _highlighted => _pressed || _committed;

  void _handleTap() {
    if (_committed) return;
    // 与全 App 的按压反馈一致：松手给一次轻触感
    HapticFeedback.lightImpact();
    // 松手后不立刻关：先让整行灰底亮着，稍停再关闭菜单，
    // 让菜单有时间缩回触发点，而不是一松手就瞬间消失。
    setState(() => _committed = true);
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (mounted) widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    // 高亮块：按下**立刻**出现（不等松手），上下各留 4px 内缩，
    // 与分割线之间留出空隙——参考 iOS 上下文菜单的样子，
    // 色块是「浮在行上的圆角胶囊」，不是贴着分割线的满格色条。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _handleTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDims.s8,
          vertical: AppDims.s4,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _highlighted
                ? (isDark
                    ? const Color(0x24FFFFFF)
                    : const Color(0x18000000))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDims.radiusM),
          ),
          child: SizedBox(
            // 40 + 上下各 4 内缩 = 48，与 showContextMenu 里
            // 计算菜单高度用的 itemHeight 保持一致。
            height: 40,
            child: Row(
              children: [
                const SizedBox(width: AppDims.s10),
                widget.item.iconWidget ??
                    Icon(
                  widget.item.icon!,
                  size: 18,
                  color: widget.item.destructive ? AppColors.red : primary,
                ),
                const SizedBox(width: AppDims.s10),
                Expanded(
                  child: Text(
                    widget.item.label,
                    style: AppTypography.body.copyWith(
                      color: widget.item.destructive ? AppColors.red : primary,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (widget.item.selected)
                  const Padding(
                    padding: EdgeInsets.only(right: AppDims.s10),
                    child: Icon(Icons.check, size: 18, color: AppColors.accent),
                  )
                else
                  const SizedBox(width: AppDims.s10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
