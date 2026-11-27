import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// 把 [text] 里命中 [query] 的片段染色加粗。
///
/// 纯 Flutter 实现，不依赖 prism_ui 的任何组件；颜色取 `colorScheme.primary`，
/// 所以换种子色时高亮自动跟着变。
///
/// 注意：匹配用的是小写归一后的字符串。`toLowerCase` 对个别语言（如土耳其语 İ）
/// 会改变字符数，导致下标错位。中文和英文不受影响，真要支持那些语言得换成
/// 逐字符比较。
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final String query;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final spans = _buildSpans(context);
    if (spans == null) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    return Text.rich(
      TextSpan(children: spans),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  List<InlineSpan>? _buildSpans(BuildContext context) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return null;
    }
    final haystack = text.toLowerCase();
    final spans = <InlineSpan>[];
    var cursor = 0;
    while (true) {
      final index = haystack.indexOf(needle, cursor);
      if (index < 0) {
        break;
      }
      if (index > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + needle.length),
          style: TextStyle(
            color: context.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      cursor = index + needle.length;
    }
    if (spans.isEmpty) {
      return null;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }
}
