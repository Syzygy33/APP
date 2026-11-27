import 'package:flutter/foundation.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// 界面偏好的本地持久化：主题模式、液态玻璃开关。
///
/// 只有两个值，用 `SharedPreferences` 就够。三条防御：
/// 1. 读失败不影响启动（整段包在 try 里）——为两个偏好把应用卡死不值得。
/// 2. 读到不认识的枚举名就保持默认，不抛异常。
/// 3. 写入失败只打日志：设置在本次会话里依然是生效的。
abstract final class AppPrefs {
  static const _themeModeKey = 'noto_note.theme_mode';
  static const _liquidGlassKey = 'noto_note.liquid_glass';

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeModeKey);
      if (savedMode != null) {
        for (final mode in ThemeMode.values) {
          if (mode.name == savedMode) {
            AppTheme.mode.value = mode;
            break;
          }
        }
      }
      AppTheme.liquidGlass.value =
          prefs.getBool(_liquidGlassKey) ?? AppTheme.liquidGlass.value;
    } catch (error, stack) {
      debugPrint('界面偏好读取失败：$error\n$stack');
    }
  }

  static Future<void> saveThemeMode(ThemeMode mode) =>
      _write((prefs) => prefs.setString(_themeModeKey, mode.name));

  static Future<void> saveLiquidGlass(bool value) =>
      _write((prefs) => prefs.setBool(_liquidGlassKey, value));

  static Future<void> _write(
    Future<bool> Function(SharedPreferences prefs) operation,
  ) async {
    try {
      await operation(await SharedPreferences.getInstance());
    } catch (error) {
      debugPrint('界面偏好写入失败：$error');
    }
  }
}
