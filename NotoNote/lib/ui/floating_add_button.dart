import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import 'app_page_bar.dart';

/// 页面底部居中的主操作按钮。
///
/// 复用的就是顶栏那颗 `BarIconButton`（44 圆底、`raisedSurfaceLevel` 填充、
/// 弹性按压），因此和「放大镜」「更多」看起来完全一样——这是刻意的：
/// 同一个应用里同一类按钮不该有两种尺寸。
///
/// 高度靠 [BottomInsetScope] 算：底部导航是悬浮的，不占布局高度，
/// 只知道 `bottomInset` 才能正好停在导航上沿留一点空隙。
class FloatingAddButton extends StatelessWidget {
  const FloatingAddButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final Glyph glyph;
  final String tooltip;
  final VoidCallback onPressed;

  /// 是否实心填充。笔是实心的（参考图如此），加号要保持描边。
  final bool filled;

  /// 与导航栏的间距。
  static const gap = 20.0;

  /// 列表底部要留出的高度：按钮 44 + 间距，否则最后一条会被压住。
  static const reach = 44.0 + gap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: context.bottomInset + gap),
        // 与顶栏按钮一致走实心底色，不套玻璃（避免圆边出现白光）。
        child: TonalButtonTheme(
          glass: LiquidGlassScope.of(context),
          child: BarIconButton(
            data: IconButtonData(
              glyph: glyph,
              tooltip: tooltip,
              onPressed: onPressed,
            ),
            // 笔是实心的：44 的圆底上描边太细，按参考图用填充
            icon: filled ? GlyphIcon(glyph, fill: 1) : null,
          ),
        ),
      ),
    );
  }
}
