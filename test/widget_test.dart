import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:noto_box/app/theme/app_theme.dart';

/// 设计系统层测试：验证主题构建。
void main() {
  test('深色与浅色主题均可构建且配色不同', () {
    final light = AppTheme.light;
    final dark = AppTheme.dark;
    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(light.scaffoldBackgroundColor, isNot(dark.scaffoldBackgroundColor));
  });
}
