import 'dart:math' as math;

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show LiquidGlassSettings;
import 'package:material_ui/material_ui.dart';

import 'liquid_glass_motion.dart';

/// Liquid Glass 设计令牌（Design Tokens）。
///
/// 全 App 的玻璃外观只从这里取值，不在各页面散写数字，
/// 目的是根治「这个卡片 28、那个菜单 20」这类不一致。
///
/// 视觉引擎统一为 `liquid_glass_widgets`（自定义 fragment shader 折射），
/// 不再混用 BackdropFilter 方案。
class LiquidGlassTokens {
  LiquidGlassTokens._();

  // ---- 圆角 ----
  /// 页面卡片、菜单容器、弹窗、抽屉：统一母数
  static const double radiusCard = 28;

  /// 内层元素（菜单项高亮、输入框、按钮）
  /// 嵌套圆角法则：内层 = 外层 − 内边距，视觉上弧线才平行
  static const double radiusInner = 20;
  static const double radiusControl = 14;

  /// 胶囊 / 底栏
  static const double radiusCapsule = 999;

  // ---- 玻璃 ----
  /// 标准模糊强度（有 shader 时的雾化参考值）
  static const double blurSigma = 22;

  /// 低端机降级后的模糊强度
  static const double blurSigmaReduced = 10;

  /// 内容卡片不做玻璃（保持纯色，保证文字对比度）
  static const double cardOpacity = 1.0;

  // ---- 玻璃材质预设 ----
  //
  // 数值来自 liquid_glass_widgets 官方 example 的 RecommendedGlassSettings
  // （MIT）。关键点：
  //
  // **`lightAngle: 0.75π`（左上 135°）** —— 这是全 App 唯一光源方向，
  // 所有表面必须一致，否则视觉会"散架"。之前手写参数漏了这个，
  // 光变成整圈均匀，在深色底上就成了"一圈白光"。
  //
  // **`refractiveIndex`** 控制边缘厚度：0.7 = iOS 26 的细边审美；
  // 大面积浮层反而要更小（sheet 用 0.15），否则大面上会出现一道硬线。

  /// 按钮 / 可交互元素：边缘细、按下时才有辉光
  static const LiquidGlassSettings glassInteractive = LiquidGlassSettings(
    blur: 10,
    thickness: 10,
    glassColor: Color.fromRGBO(255, 255, 255, 0.2),
    lightAngle: 0.75 * math.pi,
    lightIntensity: 0.7,
    ambientStrength: 0.3,
    saturation: 0.0,
    refractiveIndex: 0.7,
    chromaticAberration: 0.0,
  );

  /// 浮层（弹窗、气泡菜单）：比按钮略实，边缘仍细
  static const LiquidGlassSettings glassOverlay = LiquidGlassSettings(
    blur: 10,
    thickness: 10,
    glassColor: Color.fromRGBO(255, 255, 255, 0.12),
    lightAngle: 0.75 * math.pi,
    lightIntensity: 0.7,
    ambientStrength: 0.4,
    saturation: 1.2,
    refractiveIndex: 0.7,
    chromaticAberration: 0.0,
  );

  /// 大抽屉：`refractiveIndex` 必须压到 0.15，
  /// 否则大面积上那道边缘高光会变成一条生硬的线
  static const LiquidGlassSettings glassSheet = LiquidGlassSettings(
    blur: 10,
    thickness: 10,
    glassColor: Color.fromRGBO(255, 255, 255, 0.12),
    lightAngle: 0.75 * math.pi,
    lightIntensity: 0.7,
    ambientStrength: 0.4,
    saturation: 1.2,
    refractiveIndex: 0.15,
    chromaticAberration: 0.0,
  );

  /// 输入框：稍重的雾化，不抢内容
  static const LiquidGlassSettings glassInput = LiquidGlassSettings(
    blur: 20,
    thickness: 10,
    glassColor: Color.fromRGBO(255, 255, 255, 0.12),
    lightAngle: 0.75 * math.pi,
    lightIntensity: 0.7,
    ambientStrength: 0.4,
    saturation: 1.2,
    refractiveIndex: 0.7,
    chromaticAberration: 0.0,
  );

  /// 底部导航栏：对齐 Apple 的 nav chrome（约 20pt 重雾化）
  static const LiquidGlassSettings glassBottomBar = LiquidGlassSettings(
    blur: 20,
    thickness: 20,
    glassColor: Color.fromRGBO(255, 255, 255, 0.15),
    lightAngle: 0.75 * math.pi,
    lightIntensity: 0.7,
    ambientStrength: 0.5,
    saturation: 1.2,
    refractiveIndex: 1.2,
    chromaticAberration: 0.0,
  );

  // ---- 投影：纯色背景下唯一能造出"悬浮"的手段 ----
  //
  // 双层：近影贴地（硬、小）、远影托起（柔、大）。
  // 只有一层柔影会"糊"，只有一层硬影会"脏"。

  /// 按钮投影（小而紧）
  static List<BoxShadow> buttonShadows(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.10),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.13),
        blurRadius: isDark ? 20 : 16,
        offset: const Offset(0, 6),
      ),
    ];
  }

  /// 浮层投影（大而柔，明显高于内容）
  static List<BoxShadow> overlayShadows(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.12),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.18),
        blurRadius: isDark ? 40 : 32,
        offset: const Offset(0, 14),
      ),
    ];
  }

  // ---- 动效 ----
  /// 按下反馈
  static const Duration pressDuration = Duration(milliseconds: 160);
  static const Curve pressCurve = Curves.easeOutCubic;

  /// 按下回弹用的弹簧曲线（物理模型 + 末端补偿）
  ///
  /// 注意 `seconds` 必须等于 [pressDuration] 的秒数：
  /// [SpringCurve] 把 t∈[0,1] 映射到 [0, seconds] 的物理时间，
  /// 两者不一致会压缩/拉伸动画（曾因 550ms 配 160ms 导致"瞬间到位"）。
  static final Curve pressSpringCurve = LiquidGlassMotion.springCurve(
    LiquidGlassMotion.pressSpring,
    seconds: pressDuration.inMilliseconds / 1000,
  );

  /// 选中态过渡（导航栏指示器滑动）
  static const Duration selectionDuration = Duration(milliseconds: 400);

  /// 选中态弹簧曲线（比 easeOut 更有"落定"分量感）
  static final Curve selectionSpringCurve = LiquidGlassMotion.springCurve(
    LiquidGlassMotion.selectionSpring,
    seconds: selectionDuration.inMilliseconds / 1000,
  );

  /// 弹层进出
  static const Duration overlayDuration = Duration(milliseconds: 260);

  /// 按下缩放比例
  static const double pressedScale = 0.96;

  // ---- 质量降级 ----

  /// 系统是否要求减少动效（无障碍 / 省电）
  static bool reduceMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// 是否走「简化玻璃」：低端机或系统要求减少透明
  ///
  /// 判定依据只有一条可靠的：系统无障碍设置。
  /// 不做机型硬编码——设备型号不可枚举，且容易误伤。
  static bool simplifiedGlass(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    // 系统开启「减弱动态效果」时，同时降低模糊与大范围动画
    return mq.disableAnimations;
  }

  /// 按质量档位返回模糊强度
  static double blurFor(BuildContext context) =>
      simplifiedGlass(context) ? blurSigmaReduced : blurSigma;

  /// 按质量档位返回动效时长（减弱动效时趋近于 0）
  static Duration durationFor(BuildContext context, Duration base) =>
      reduceMotion(context) ? Duration.zero : base;

  /// 按质量档位返回曲线（减弱动效时退化为线性，避免过冲）
  static Curve curveFor(BuildContext context, Curve base) =>
      reduceMotion(context) ? Curves.linear : base;
}
