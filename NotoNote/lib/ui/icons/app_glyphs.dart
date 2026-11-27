import 'package:prism_ui/icons/glyph.dart';

/// 本项目的业务图标。
///
/// `prism_ui` 自带的 `Glyphs` 只有组件内部用到的那批（返回、关闭、搜索、
/// 更多等），业务图标要自己声明。这里沿用它的 DSL，风格与内置图标一致。
///
/// 前四个取自 FlClash 的 `app_glyphs.dart`（同一套设计语言），
/// 用于底部导航的四个页签。
abstract final class AppGlyphs {
  /// 笔记。
  static const compose = Glyph([
    GlyphPolyline([
      GlyphVertex(9.4, 6.2),
      GlyphVertex(4, 6.2, 2.5),
      GlyphVertex(4, 20.2, 2.5),
      GlyphVertex(18, 20.2, 2.5),
      GlyphVertex(18, 14.8),
    ], role: GlyphRole.line),
    GlyphPolyline([
      GlyphVertex(9, 15.2, 1),
      GlyphVertex(13.75, 13.95, 1),
      GlyphVertex(20.75, 6.95, 1.5),
      GlyphVertex(17.25, 3.45, 1.5),
      GlyphVertex(10.25, 10.45, 1),
    ], closed: true),
    GlyphPolyline([
      GlyphVertex(13.75, 6.95),
      GlyphVertex(17.25, 10.45),
    ], role: GlyphRole.detail),
  ]);

  /// 筛选：漏斗。
  ///
  /// 一条闭合折线走完「上口 → 右斜边 → 窄颈 → 底边 → 左斜边」，
  /// 对称、笔画少，22dp 下也不会糊成一个点。
  static const funnel = Glyph([
    GlyphPolyline([
      GlyphVertex(4.6, 5.4, 1.2),
      GlyphVertex(19.4, 5.4, 1.2),
      GlyphVertex(13.7, 12.4, 0.7),
      GlyphVertex(13.7, 18.6, 0.9),
      GlyphVertex(10.3, 18.6, 0.9),
      GlyphVertex(10.3, 12.4, 0.7),
    ], closed: true, role: GlyphRole.line),
  ]);

  /// 待办。
  static const todo = Glyph([
    GlyphCircle(12, 12, 8.8),
    GlyphPolyline([
      GlyphVertex(7.59, 12.3),
      GlyphVertex(10.49, 15.2),
      GlyphVertex(16.41, 8.79),
    ], role: GlyphRole.detail),
  ]);

  /// 分类。
  static const category = Glyph([
    GlyphPolyline([
      GlyphVertex(12, 3, 1.5),
      GlyphVertex(20.8, 7.6, 1.2),
      GlyphVertex(12, 12.2, 1.5),
      GlyphVertex(3.2, 7.6, 1.2),
    ], closed: true),
    GlyphPolyline([
      GlyphVertex(3.2, 12),
      GlyphVertex(12, 16.6, 1.5),
      GlyphVertex(20.8, 12),
    ], role: GlyphRole.line),
    GlyphPolyline([
      GlyphVertex(3.2, 16.4),
      GlyphVertex(12, 21, 1.5),
      GlyphVertex(20.8, 16.4),
    ], role: GlyphRole.line),
  ]);

  /// 收藏。
  static const star = Glyph([
    GlyphPolyline([
      GlyphVertex(12, 3.2, 1.2),
      GlyphVertex(14.41, 9.48, 0.6),
      GlyphVertex(21.13, 9.83, 1.2),
      GlyphVertex(15.9, 14.07, 0.6),
      GlyphVertex(17.64, 20.57, 1.2),
      GlyphVertex(12, 16.9, 0.6),
      GlyphVertex(6.36, 20.57, 1.2),
      GlyphVertex(8.1, 14.07, 0.6),
      GlyphVertex(2.87, 9.83, 1.2),
      GlyphVertex(9.59, 9.48, 0.6),
    ], closed: true),
  ]);

  /// 新建：一支斜握的笔。
  ///
  /// 和 [compose]（方框 + 笔，导航页签用）不同，悬浮按钮上只放一支笔，
  /// 按参考图用实心填充——线稿在深色圆底上太细，撑不起主操作的分量。
  static const pen = Glyph([
    GlyphPolyline([
      GlyphVertex(3.6, 20.4, 0.3),
      GlyphVertex(5.2, 16.2, 0.5),
      GlyphVertex(15.9, 5.5, 1.1),
      GlyphVertex(18.5, 8.1, 1.1),
      GlyphVertex(7.8, 18.8, 0.5),
    ], closed: true),
  ]);

  /// 添加一条：加号。描边与 `Glyphs.close` 同一套（`GlyphRole.line`）。
  static const plus = Glyph([
    GlyphPolyline([
      GlyphVertex(12, 4.5),
      GlyphVertex(12, 19.5),
    ], role: GlyphRole.line),
    GlyphPolyline([
      GlyphVertex(4.5, 12),
      GlyphVertex(19.5, 12),
    ], role: GlyphRole.line),
  ]);

  /// 撤销：逆时针弯箭头（向左回转）。
  ///
  /// 主体走「上边向右 → 右侧大圆角 → 下边向左」，圆角半径给到 4.4，
  /// 弯得比较舒展；箭头也跟着放大。
  static const undo = Glyph([
    // 箭头：指向左
    GlyphPolyline([
      GlyphVertex(8.6, 5.4, 1.2),
      GlyphVertex(4.0, 9.9, 1.2),
      GlyphVertex(8.6, 14.4, 1.2),
    ], role: GlyphRole.line),
    // 主体：上边 → 右侧大圆角 → 下边
    GlyphPolyline([
      GlyphVertex(4.0, 9.9, 1.0),
      GlyphVertex(13.6, 9.9, 0.8),
      GlyphVertex(20.2, 9.9, 4.4),
      GlyphVertex(20.2, 19.0, 4.4),
      GlyphVertex(13.4, 19.0, 0.8),
      GlyphVertex(9.2, 19.0, 0.8),
    ], role: GlyphRole.line),
  ]);

  /// 前进：顺时针弯箭头（向右回转），是 [undo] 的镜像。
  static const redo = Glyph([
    GlyphPolyline([
      GlyphVertex(15.4, 5.4, 1.2),
      GlyphVertex(20.0, 9.9, 1.2),
      GlyphVertex(15.4, 14.4, 1.2),
    ], role: GlyphRole.line),
    GlyphPolyline([
      GlyphVertex(20.0, 9.9, 1.0),
      GlyphVertex(10.4, 9.9, 0.8),
      GlyphVertex(3.8, 9.9, 4.4),
      GlyphVertex(3.8, 19.0, 4.4),
      GlyphVertex(10.6, 19.0, 0.8),
      GlyphVertex(14.8, 19.0, 0.8),
    ], role: GlyphRole.line),
  ]);

  /// 垃圾桶：回收站「全部清空」用。
  static const trash = Glyph([
    // 桶盖
    GlyphPolyline([
      GlyphVertex(4.2, 6.6),
      GlyphVertex(19.8, 6.6),
    ], role: GlyphRole.line),
    // 提手
    GlyphPolyline([
      GlyphVertex(9.4, 6.6, 1.4),
      GlyphVertex(9.4, 4.0, 1.4),
      GlyphVertex(14.6, 4.0, 1.4),
      GlyphVertex(14.6, 6.6, 1.4),
    ], role: GlyphRole.line),
    // 桶身
    GlyphPolyline([
      GlyphVertex(6.2, 6.6, 1.2),
      GlyphVertex(7.3, 20.0, 1.6),
      GlyphVertex(16.7, 20.0, 1.6),
      GlyphVertex(17.8, 6.6, 1.2),
    ], role: GlyphRole.line),
    // 桶内两道竖线
    GlyphPolyline([
      GlyphVertex(10.2, 10.2),
      GlyphVertex(10.9, 16.6),
    ], role: GlyphRole.detail),
    GlyphPolyline([
      GlyphVertex(13.8, 10.2),
      GlyphVertex(13.1, 16.6),
    ], role: GlyphRole.detail),
  ]);

  /// 远程（WebDAV / 云端）。朵云的轮廓：底部一条平边，上面两个鼓包。
  ///
  /// 用 cubic 画而不是 SVG 的圆弧命令——本项目 GlyphPath 只实现了
  /// move/line/cubic/close，遇到 `A` 会直接抛错。
  static const cloud = Glyph([
    GlyphPath(
      'M5.2 17.6 L18.6 17.6 '
      'C20.45 17.6 21.9 16.15 21.9 14.3 '
      'C21.9 12.45 20.45 11 18.6 11 '
      'C18.3 11 18 11.04 17.7 11.1 '
      'C17 8.4 14.6 6.4 11.8 6.4 '
      'C8.5 6.4 5.8 9 5.7 12.25 '
      'C4.2 12.55 3.1 13.85 3.1 15.3 '
      'C3.1 16.6 4 17.6 5.2 17.6 Z',
      role: GlyphRole.line,
    ),
  ]);

  /// 附件：回形针。
  ///
  /// 一条向内的螺旋——外层从右侧下来绕过底部，内层再折回顶部收口，
  /// 顶点给 2–3 的圆角，22dp 下也认得出是回形针而不是一团线。
  static const paperclip = Glyph([
    GlyphPolyline([
      GlyphVertex(15.6, 8.4, 2.2),
      GlyphVertex(15.6, 15.8, 2.2),
      GlyphVertex(12.2, 19.2, 2.2),
      GlyphVertex(8.8, 15.8, 2.2),
      GlyphVertex(8.8, 7.0, 3.0),
      GlyphVertex(12.0, 3.8, 3.0),
      GlyphVertex(18.6, 7.0, 3.0),
      GlyphVertex(18.6, 13.4, 3.0),
    ], role: GlyphRole.line),
  ]);

  /// 照片：相框 + 山 + 太阳。
  static const photo = Glyph([
    GlyphPolyline([
      GlyphVertex(3.6, 5.6, 2.6),
      GlyphVertex(20.4, 5.6, 2.6),
      GlyphVertex(20.4, 18.4, 2.6),
      GlyphVertex(3.6, 18.4, 2.6),
    ], closed: true, role: GlyphRole.line),
    // 山：从左下爬到峰顶再落回右下
    GlyphPolyline([
      GlyphVertex(4.8, 17.2, 0.6),
      GlyphVertex(9.4, 11.6, 0.8),
      GlyphVertex(12.6, 15.0, 0.8),
      GlyphVertex(15.2, 12.2, 0.8),
      GlyphVertex(19.2, 17.2, 0.6),
    ], role: GlyphRole.line),
    GlyphCircle(7.6, 9.4, 1.4),
  ]);

  /// 拍照：相机机身 + 顶部取景凸起 + 镜头。
  static const camera = Glyph([
    GlyphPolyline([
      GlyphVertex(3.2, 9.0, 2.4),
      GlyphVertex(8.2, 9.0, 1.2),
      GlyphVertex(9.6, 6.4, 1.0),
      GlyphVertex(14.4, 6.4, 1.0),
      GlyphVertex(15.8, 9.0, 1.2),
      GlyphVertex(20.8, 9.0, 2.4),
      GlyphVertex(20.8, 19.0, 2.4),
      GlyphVertex(3.2, 19.0, 2.4),
    ], closed: true, role: GlyphRole.line),
    GlyphCircle(12, 14.0, 3.4),
  ]);

  /// 提醒：铃铛。
  ///
  /// 钟身用 cubic 画（上收口 + 顶部圆顶），底边一道横线当铃口，
  /// 下面一小段是铃舌。
  static const bell = Glyph([
    GlyphPath(
      'M6.6 16.8 L6.6 10.6 '
      'C6.6 7.5 9.0 5.2 12 5.2 '
      'C15.0 5.2 17.4 7.5 17.4 10.6 '
      'L17.4 16.8',
      role: GlyphRole.line,
    ),
    GlyphPolyline([
      GlyphVertex(4.8, 16.8, 0.8),
      GlyphVertex(19.2, 16.8, 0.8),
    ], role: GlyphRole.line),
    GlyphPolyline([
      GlyphVertex(10.1, 19.6, 1.4),
      GlyphVertex(13.9, 19.6, 1.4),
    ], role: GlyphRole.line),
  ]);
}
