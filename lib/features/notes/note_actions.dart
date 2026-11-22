import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database/app_database.dart';
import '../../data/models/note_kind.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/context_menu.dart';

/// 长按条目弹出的操作菜单。笔记 / 待办共用同一套入口，
/// 在长按位置就近弹出（不占全宽），按条目自身类型决定可用项。
Future<void> showNoteActions(
  BuildContext context,
  WidgetRef ref,
  Note note, {
  required Offset position,
}) async {
  final repo = ref.read(repositoryProvider);
  final NoteKind kind = NoteKind.fromValue(note.kind);
  final List<ContextMenuItem> items = [];
  final List<Future<void> Function()> handlers = [];

  items.add(
    ContextMenuItem(label: note.pinned ? '取消置顶' : '置顶', icon: LucideIcons.pin),
  );
  handlers.add(() => repo.togglePin(note.id));

  if (kind.isTodo) {
    items.add(
      ContextMenuItem(
        label: note.done ? '标记为未完成' : '标记为完成',
        icon: note.done ? LucideIcons.circle : LucideIcons.circleCheck,
      ),
    );
    handlers.add(() => repo.setDone(note.id, !note.done));
  }

  for (final target in NoteKind.values) {
    if (target == kind) continue;
    items.add(
      ContextMenuItem(
        label: '转为${target.label}',
        icon: switch (target) {
          NoteKind.note => LucideIcons.fileText,
          NoteKind.todo => LucideIcons.listChecks,
        },
      ),
    );
    handlers.add(() => repo.setKind(note.id, target));
  }

  final int? index = await showContextMenu(
    context,
    position: position,
    items: items,
  );
  if (index == null || !context.mounted) return;
  await handlers[index]();
}
