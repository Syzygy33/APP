import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// 统一的危险操作二次确认框。
///
/// 所有删除类行为都走这里，保证文案风格、按钮顺序（取消在左、确认在右）
/// 和 destructive 配色一致。返回 true 才继续执行。
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '删除',
  String cancelLabel = '取消',
}) async {
  final confirmed = await showFloatingDialog<bool>(
    context: context,
    child: Builder(
      builder: (dialogContext) => AlertDialog(
        title: title,
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
        child: Text(message),
      ),
    ),
  );
  return confirmed == true;
}
