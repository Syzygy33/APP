import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    hide GlassContainer;
import 'package:material_ui/material_ui.dart';

/// 单个动作项
class IOSAction {
  final String label;
  final IconData? icon;
  final bool destructive;

  const IOSAction({required this.label, this.icon, this.destructive = false});
}

/// iOS 风格动作面板：内容高度自适应，底部独立「取消」按钮。
/// 返回被点击动作的下标，取消返回 null。
Future<int?> showIOSActionSheet({
  required BuildContext context,
  String? title,
  String? message,
  required List<IOSAction> actions,
  String cancelLabel = '取消',
}) {
  // 改用 liquid_glass_widgets 的 showGlassActionSheet（真机走液态玻璃材质）。
  // 对外仍返回被点击动作的下标，取消返回 null。
  return showGlassActionSheet<int>(
    context: context,
    title: title,
    message: message,
    cancelLabel: cancelLabel,
    actions: [
      for (int i = 0; i < actions.length; i++)
        GlassActionSheetAction(
          label: actions[i].label,
          icon: actions[i].icon == null ? null : Icon(actions[i].icon, size: 20),
          style: actions[i].destructive
              ? GlassActionSheetStyle.destructive
              : GlassActionSheetStyle.defaultStyle,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(i),
        ),
    ],
  );
}
