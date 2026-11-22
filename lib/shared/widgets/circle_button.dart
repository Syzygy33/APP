import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    hide GlassContainer;
import 'package:material_ui/material_ui.dart';

import '../../app/theme/glass_ink.dart';
import '../glass/liquid_glass_tokens.dart';

/// 顶部圆形图标按钮：库的 [GlassIconButton] + 全 App 统一的玻璃参数与投影。
///
/// 质感的两个来源（纯色背景下缺一不可）：
/// - 玻璃用官方 `interactive` 预设：左上单向光源，边缘只在受光侧发亮
/// - 外层双层投影：近影贴地、远影托起，把它从背景上"抬"起来
class CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final double iconSize;

  const CircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 44,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    // 图标色按明暗反转：亮色黑、暗色白
    final Color fg = GlassInk.primary(context);

    final Widget button = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: LiquidGlassTokens.buttonShadows(context),
      ),
      child: GlassIconButton(
        icon: Icon(icon),
        onPressed: onTap,
        size: size,
        iconSize: iconSize,
        iconColor: fg,
        shape: GlassIconButtonShape.circle,
        settings: LiquidGlassTokens.glassInteractive,
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
