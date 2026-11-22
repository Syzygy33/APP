import 'package:material_ui/material_ui.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassTextField;

import '../../app/theme/glass_ink.dart';

/// 液态玻璃输入框。
///
/// 引擎：`liquid_glass_widgets` 的 `GlassTextField`（shader 玻璃底）。
class LiquidGlassTextField extends StatelessWidget {
  const LiquidGlassTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return GlassTextField(
      controller: controller,
      placeholder: placeholder,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      onSuffixTap: onSuffixTap,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      placeholderStyle: TextStyle(color: GlassInk.placeholder(context)),
    );
  }
}
