import 'package:prism_ui/icons/glyph.dart';

import 'app_glyphs.dart';

/// 分类可选图标。
///
/// 分类里只存一个短 key（`NoteCategory.icon`），渲染时在这里查表——
/// 存 key 而不是存图形，以后换图标集不会让旧存档失效。
///
/// 第一个是空 key：表示用默认的「方块」图标，旧分类读出来就是它。
abstract final class CategoryIcons {
  /// 没选图标时用的 key（空串）。
  static const defaultKey = '';

  /// 供新建分类时挑选的图标，顺序即界面顺序。
  static const keys = [
    defaultKey,
    'folder',
    'tag',
    'heart',
    'bolt',
    'book',
    'star',
  ];

  /// key → 图标；不认识的 key（未来版本 / 手改存档）统一退默认图标。
  static Glyph resolve(String key) => switch (key) {
    'folder' => _folder,
    'tag' => _tag,
    'heart' => _heart,
    'bolt' => _bolt,
    'book' => _book,
    'star' => AppGlyphs.star,
    _ => AppGlyphs.category,
  };

  /// 文件夹：上沿带一个折角标签。
  static const _folder = Glyph([
    GlyphPolyline([
      GlyphVertex(3.6, 7.0, 1.4),
      GlyphVertex(9.2, 7.0, 1.2),
      GlyphVertex(10.9, 9.0, 1.0),
      GlyphVertex(20.4, 9.0, 1.4),
      GlyphVertex(20.4, 18.2, 1.8),
      GlyphVertex(3.6, 18.2, 1.8),
    ], closed: true, role: GlyphRole.line),
  ]);

  /// 标签：右边一个尖角，左边一个圆孔。
  static const _tag = Glyph([
    GlyphPolyline([
      GlyphVertex(3.8, 7.6, 1.4),
      GlyphVertex(12.6, 7.6, 1.2),
      GlyphVertex(20.2, 12.0, 1.4),
      GlyphVertex(12.6, 16.4, 1.2),
      GlyphVertex(3.8, 16.4, 1.4),
    ], closed: true, role: GlyphRole.line),
    GlyphCircle(7.0, 12.0, 1.15, role: GlyphRole.line),
  ]);

  /// 心形：三段贝塞尔，左右对称。
  static const _heart = Glyph([
    GlyphPath(
      'M12 20.2'
      'C 6.4 16.4, 3.0 12.9, 3.0 9.6'
      'C 3.0 6.9, 5.0 5.0, 7.5 5.0'
      'C 9.5 5.0, 11.1 6.2, 12 7.9'
      'C 12.9 6.2, 14.5 5.0, 16.5 5.0'
      'C 19.0 5.0, 21.0 6.9, 21.0 9.6'
      'C 21.0 12.9, 17.6 16.4, 12 20.2 Z',
      role: GlyphRole.line,
    ),
  ]);

  /// 闪电。
  static const _bolt = Glyph([
    GlyphPolyline([
      GlyphVertex(13.6, 3.0, 0.8),
      GlyphVertex(6.4, 13.4, 0.6),
      GlyphVertex(11.4, 13.4, 0.6),
      GlyphVertex(10.6, 21.0, 0.8),
      GlyphVertex(17.8, 10.6, 0.6),
      GlyphVertex(12.8, 10.6, 0.6),
    ], closed: true, role: GlyphRole.line),
  ]);

  /// 摊开的书：中间是书脊，上下各一个 V。
  static const _book = Glyph([
    GlyphPolyline([
      GlyphVertex(12, 6.6, 0.6),
      GlyphVertex(19.6, 4.8, 1.2),
      GlyphVertex(19.6, 18.6, 1.2),
      GlyphVertex(12, 20.4, 0.6),
      GlyphVertex(4.4, 18.6, 1.2),
      GlyphVertex(4.4, 4.8, 1.2),
    ], closed: true, role: GlyphRole.line),
  ]);
}
