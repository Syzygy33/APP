import 'package:flutter_test/flutter_test.dart';
import 'package:noto_box/data/database/app_database.dart' show Note;
import 'package:noto_box/data/models/note_display.dart';

/// 卡片标题/预览规则的测试。
///
/// 核心规则：标题没填就借正文第一段，且预览不重复显示那段。
Note makeNote({String title = '', String content = '', int kind = 0}) {
  return Note(
    id: 1,
    title: title,
    content: content,
    pinned: false,
    favorite: false,
    kind: kind,
    done: false,
    isSticky: false,
    deleted: false,
    createdAt: 0,
    updatedAt: 0,
  );
}

void main() {
  group('标题回退', () {
    test('有标题时用标题，不动正文', () {
      final note = makeNote(title: '会议纪要', content: '第一段\n第二段');
      expect(NoteDisplay.titleOf(note, placeholder: '无标题笔记'), '会议纪要');
    });

    test('没标题时借正文第一段', () {
      final note = makeNote(content: '今天要买牛奶\n顺便取快递');
      expect(NoteDisplay.titleOf(note, placeholder: '无标题笔记'), '今天要买牛奶');
    });

    test('正文开头有空行时，取第一个非空行', () {
      final note = makeNote(content: '\n\n  真正的第一段  \n第二段');
      expect(NoteDisplay.titleOf(note, placeholder: '无标题笔记'), '真正的第一段');
    });

    test('标题和正文都没有时，才用占位文字', () {
      final note = makeNote(title: '   ', content: '\n  \n');
      expect(NoteDisplay.titleOf(note, placeholder: '无标题笔记'), '无标题笔记');
    });

    test('只有空格的标题不算标题', () {
      final note = makeNote(title: '   ', content: '正文首段');
      expect(NoteDisplay.titleOf(note, placeholder: '无标题笔记'), '正文首段');
    });
  });

  group('预览去重', () {
    test('标题借用了首段时，预览从第二段开始', () {
      final note = makeNote(content: '第一段标题\n第二段内容');
      expect(NoteDisplay.previewOf(note), '第二段内容');
    });

    test('标题是自己填的时，预览包含全部正文', () {
      final note = makeNote(title: '自填标题', content: '第一段\n第二段');
      expect(NoteDisplay.previewOf(note), '第一段 第二段');
    });

    test('正文只有一段时，预览为空（不重复那句话）', () {
      final note = makeNote(content: '只有一句话');
      expect(NoteDisplay.previewOf(note), '');
    });

    test('多行空白会被压成单个空格', () {
      final note = makeNote(content: '标题行\n\n\n  正文  内容  ');
      expect(NoteDisplay.previewOf(note), '正文 内容');
    });
  });

  group('借用判定', () {
    test('没标题且有正文 → 判定为借用', () {
      expect(NoteDisplay.titleBorrowedFromContent(makeNote(content: '段落')), isTrue);
    });

    test('有标题 → 不借用', () {
      expect(
        NoteDisplay.titleBorrowedFromContent(
          makeNote(title: '标题', content: '段落'),
        ),
        isFalse,
      );
    });

    test('两者都空 → 不借用', () {
      expect(NoteDisplay.titleBorrowedFromContent(makeNote()), isFalse);
    });
  });
}
