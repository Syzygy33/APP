import 'package:material_ui/material_ui.dart';

/// 库组件的显式前景色 / 分隔线色。
///
/// 为什么需要：`liquid_glass_widgets` 的默认颜色是库自己按明暗推导的，
/// 和我们这套「深灰胶囊 + 纯色卡片」的配色不匹配——暗色模式下会出现
/// 黑底黑字（底栏选中项、外观分段控件都踩过）。
///
/// 所有库组件一律从这里取色，不再依赖库的自动推导。
class GlassInk {
  GlassInk._();

  static bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// 主文字 / 图标：亮色黑、暗色白
  static Color primary(BuildContext context) =>
      _dark(context) ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  /// 次文字 / 未选中图标：半透明主色
  static Color secondary(BuildContext context) =>
      _dark(context) ? const Color(0x8AFFFFFF) : const Color(0x8A000000);

  /// 更弱的提示色（占位符、禁用态）
  static Color placeholder(BuildContext context) =>
      _dark(context) ? const Color(0x4DFFFFFF) : const Color(0x4D000000);

  /// 分隔线
  static Color divider(BuildContext context) =>
      _dark(context) ? const Color(0x33FFFFFF) : const Color(0x1A000000);

  /// 卡片 / 容器底色：亮色纯白、暗色深灰
  static Color surface(BuildContext context) =>
      _dark(context) ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
}
