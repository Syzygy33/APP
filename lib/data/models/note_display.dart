import '../database/app_database.dart' show Note;

/// 笔记卡片的标题与预览如何呈现。
///
/// 规则：**标题没填就借正文第一段**，而不是显示"无标题笔记"。
/// 这样新建后只写正文也能一眼认出是哪一条。
///
/// 配套细节：标题借走了第一段，预览就必须跳过它，
/// 否则同一句话会在卡片上出现两遍。
class NoteDisplay {
  NoteDisplay._();

  /// 正文第一段：第一个非空行（用户很少在手机上手打空行分隔）。
  static String firstParagraph(String content) {
    for (final String line in content.split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  /// 卡片标题。
  ///
  /// [placeholder] 是最后的兜底（笔记「无标题笔记」、待办「未命名待办」），
  /// 只在标题和正文都不存在时才出现。
  static String titleOf(Note note, {required String placeholder}) {
    final String typed = note.title.trim();
    if (typed.isNotEmpty) return typed;

    final String first = firstParagraph(note.content);
    return first.isNotEmpty ? first : placeholder;
  }

  /// 标题是否借用了正文第一段。
  static bool titleBorrowedFromContent(Note note) =>
      note.title.trim().isEmpty && firstParagraph(note.content).isNotEmpty;

  /// 卡片预览（标题下方那行小字）。
  ///
  /// 若标题借用了第一段，这里从第二段开始，避免重复。
  static String previewOf(Note note) {
    final List<String> lines = note.content.split('\n');
    final bool borrows = titleBorrowedFromContent(note);

    final List<String> kept = <String>[];
    bool skippedFirst = !borrows;

    for (final String line in lines) {
      if (!skippedFirst && line.trim().isNotEmpty) {
        skippedFirst = true;
        continue;
      }
      kept.add(line);
    }

    return kept.join(' ').trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
