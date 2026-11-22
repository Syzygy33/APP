import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noto_box/shared/glass/liquid_glass_motion.dart';

/// 动效原语的数学性质测试。
///
/// 这些曲线是"物理/数学定义"，不是随便调出来的近似，
/// 所以可以用端点与单调性来断言。
void main() {
  group('SpringCurve 末端补偿', () {
    test('transform(1.0) 精确落在 1.0', () {
      final curve = LiquidGlassMotion.springCurve(
        LiquidGlassMotion.pressSpring,
        seconds: 0.4,
      );
      // 关键：未经补偿的弹簧会停在 0.97 附近，补偿后必须精确为 1
      expect(curve.transform(1.0), closeTo(1.0, 1e-9));
    });

    test('起点为 0', () {
      final curve = LiquidGlassMotion.springCurve(
        LiquidGlassMotion.pressSpring,
        seconds: 0.4,
      );
      expect(curve.transform(0.0), closeTo(0.0, 1e-9));
    });

    test('中途出现过冲（超过 1），说明是弹簧不是缓动', () {
      final curve = LiquidGlassMotion.springCurve(
        LiquidGlassMotion.dropletSpring,
        seconds: 0.5,
      );
      double maxValue = 0;
      for (int i = 0; i <= 100; i++) {
        final v = curve.transform(i / 100);
        if (v > maxValue) maxValue = v;
      }
      expect(maxValue, greaterThan(1.0));
    });

    test('不同阻尼比产生不同过冲幅度', () {
      final soft = LiquidGlassMotion.springCurve(
        LiquidGlassMotion.dropletSpring,
        seconds: 0.5,
      );
      final stiff = LiquidGlassMotion.springCurve(
        LiquidGlassMotion.pressSpring,
        seconds: 0.5,
      );
      double peak(Curve c) {
        double m = 0;
        for (int i = 0; i <= 100; i++) {
          final v = c.transform(i / 100);
          if (v > m) m = v;
        }
        return m;
      }

      // 液滴阻尼比 0.8 > 按压 0.62，但刚度低很多，过冲不应相同
      expect(peak(soft) == peak(stiff), isFalse);
    });
  });

}
