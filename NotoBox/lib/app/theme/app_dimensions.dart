import 'package:material_ui/material_ui.dart';

/// 统一间距、圆角、模糊半径、动画时长。
class AppDims {
  AppDims._();

  // ---- 间距 (4pt 栅格) ----
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  // ---- 圆角 ----
  static const double radiusXS = 6;
  static const double radiusS = 10;
  static const double radiusM = 14;
  static const double radiusL = 20;
  static const double radiusXL = 28;
  static const double radiusPill = 999;

  /// iOS 连续圆角——卡片用较大圆角。
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(radiusL),
  );
  static const BorderRadius sheetRadius = BorderRadius.only(
    topLeft: Radius.circular(radiusXL),
    topRight: Radius.circular(radiusXL),
  );

  // ---- 模糊 (性能可控：仅局部使用，sigma 适中) ----
  static const double blurGlass = 18; // 卡片/导航栏
  static const double blurOverlay = 24; // 弹窗遮罩，单次短时
  static const double blurLight = 8; // 轻玻璃

  // ---- 动画时长 ----
  static const Duration animFast = Duration(milliseconds: 160);
  static const Duration animNormal = Duration(milliseconds: 280);
  static const Duration animSlow = Duration(milliseconds: 420);

  // ---- 尺寸 ----
  static const double navBarHeight = 64;
  static const double navBarBottomInset = 14;
  static const double touchTarget = 44;
  static const double maxContentWidth = 720; // 平板/折叠屏内容限宽
}
