import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

/// 液态玻璃的动效原语。
///
/// 动画由物理模型生成，而不是对 easeOut 的手工模仿：
/// 弹簧带真实阻尼振动，且末端精确收在 1.0。
///
/// 与 [LiquidGlassTokens] 的分工：token 放数值，这里放"怎么动"。
class LiquidGlassMotion {
  LiquidGlassMotion._();

  /// 按压回弹：略硬、回弹明显（适合按钮/卡片）
  static final SpringDescription pressSpring =
      SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 520,
    ratio: 0.62,
  );

  /// 导航/选中态：偏软、回弹克制（适合指示器滑动）
  ///
  /// 刚度不能太高：stiffness 越大，位移越早完成，
  /// 视觉上会变成"跳过去"而不是"滑过去"。
  static final SpringDescription selectionSpring =
      SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 190,
    ratio: 0.86,
  );

  /// 液滴：更大过冲，用于强调性的弹入
  static final SpringDescription dropletSpring =
      SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 165,
    ratio: 0.8,
  );

  /// 把弹簧包装成 [Curve]
  ///
  /// 注意：`SpringSimulation` 在 `seconds` 时刻通常还没稳定到 1.0
  /// （会有 0.97 之类的残差），直接用会导致动画"差一点"。
  /// 这里用末端线性补偿，保证 `transform(1.0) == 1.0`。
  static Curve springCurve(
    SpringDescription spring, {
    double seconds = 0.55,
  }) =>
      SpringCurve(spring, seconds: seconds);

}

/// 带末端补偿的弹簧曲线。
///
/// 关键点：`_residual` 是弹簧在 `seconds` 时刻距 1.0 的差额，
/// 用 `_residual * t` 在整段上线性补足，末端精确收在 1.0。
class SpringCurve extends Curve {
  SpringCurve(this.spring, {this.seconds = 0.55})
      : assert(seconds > 0),
        _simulation = SpringSimulation(spring, 0, 1, 0);

  final SpringDescription spring;
  final double seconds;
  final SpringSimulation _simulation;

  late final double _residual = 1.0 - _simulation.x(seconds);

  @override
  double transformInternal(double t) {
    // t 可能超出 [0,1]（部分场景会传入带动量的值），这里不做 clamp，
    // 让弹簧自然的过冲得以保留。
    return _simulation.x(t * seconds) + _residual * t;
  }
}

/// 让弹簧在目标值处收住，而不是无限过冲。
///
/// 判断方式：起始值不为终点，且当前值与终点的相对位置发生了翻转，
/// 说明已经越过目标——此时视为结束。
class ArrivingSimulation extends Simulation {
  ArrivingSimulation(this.simulation, {required this.end})
      : _start = simulation.x(0),
        super(tolerance: simulation.tolerance);

  final Simulation simulation;
  final double end;
  final double _start;

  @override
  double x(double time) => simulation.x(time);

  @override
  double dx(double time) => simulation.dx(time);

  @override
  bool isDone(double time) {
    if (simulation.isDone(time)) return true;
    if (_start == end) return false;
    // 越过终点即认为到达
    return (x(time) - end) * (_start - end) <= 0;
  }
}
