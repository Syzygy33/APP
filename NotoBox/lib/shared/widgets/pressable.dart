import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// 苹果 Liquid Glass 的交互触感：按下瞬间收缩 + 变淡，松开回弹并轻微过冲，
/// 配一次轻触感。用于替换所有可点元素上的 Material 水波纹（Android ripple），
/// 让反馈方式更贴近玻璃被按压的物理感。
///
/// 参数对应苹果的手感规范：
/// - 按下：scale 0.96、opacity 0.85，约 160ms，无弹跳
/// - 松开：回 1.0，约 300ms，带轻微过冲（easeOutBack）
class PressableScale extends StatefulWidget {
  final Widget child;

  /// 点按回调；[haptics] 为 true 时在按下瞬间给一次轻触感
  final VoidCallback? onTap;

  /// 带点击位置的点按（用于就近弹出菜单）；提供后优先于 [onTap]
  final void Function(Offset position)? onTapWithPosition;
  final VoidCallback? onLongPress;

  /// 带位置的长按（用于就近弹出菜单）；提供后优先于 [onLongPress]
  final void Function(LongPressStartDetails details)? onLongPressStart;

  final bool haptics;

  /// 按下时缩放到的比例，默认 0.96
  final double pressedScale;

  /// 按下时在内容背后叠一层浅灰圆角高亮（整块卡片变灰）。
  /// 为 null 时不画高亮（保持原有「变淡 + 缩放」反馈）。
  final Color? pressedHighlightColor;

  /// 高亮层的圆角，默认 28（与页面卡片一致）
  final double pressedHighlightRadius;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onTapWithPosition,
    this.onLongPress,
    this.onLongPressStart,
    this.haptics = true,
    this.pressedScale = 0.96,
    this.pressedHighlightColor,
    this.pressedHighlightRadius = 28,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;
  Offset? _lastTapPosition;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        _lastTapPosition = details.globalPosition;
        _setPressed(true);
      },
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () {
        if (widget.haptics) {
          HapticFeedback.lightImpact();
        }
        final Offset? position = _lastTapPosition;
        if (widget.onTapWithPosition != null && position != null) {
          widget.onTapWithPosition!(position);
        } else {
          widget.onTap?.call();
        }
      },
      onLongPress: widget.onLongPressStart == null ? widget.onLongPress : null,
      onLongPressStart: widget.onLongPressStart,
      child: AnimatedScale(
        // 按下压到 0.96 无弹跳；松开带回弹过冲。
        // 时长比早期略放宽，节奏从容一些，避免"傻快"的生硬感。
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: Duration(milliseconds: _pressed ? 210 : 400),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Stack(
          children: [
            if (widget.pressedHighlightColor != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _pressed ? 1 : 0,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.pressedHighlightColor,
                        borderRadius: BorderRadius.circular(
                          widget.pressedHighlightRadius,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            AnimatedOpacity(
              opacity: _pressed ? 0.85 : 1.0,
              duration: const Duration(milliseconds: 210),
              curve: Curves.easeOut,
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
