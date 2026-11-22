import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database/app_database.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/glass_design.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/glass/glass_container.dart';

/// 左滑删除：软删除进回收站，并给一条「撤销」提示。
/// 返回 true 让卡片滑走（数据流随后移除该项）。
Future<bool> swipeDeleteNote(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final repo = ref.read(repositoryProvider);
  await repo.softDelete(note.id);
  if (!context.mounted) return true;

  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      // 让开悬浮底栏与加号
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 150),
      duration: const Duration(seconds: 3),
      content: GlassContainer(
        radius: Glass.radiusXL,
        overlay: true,
        blur: Glass.blurMedium,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Expanded(child: Text('已移入回收站')),
            GestureDetector(
              onTap: () {
                repo.restore(note.id);
                messenger.hideCurrentSnackBar();
              },
              child: Text(
                '撤销',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // 兜底：不依赖 duration，3 秒后强制隐藏，避免提示条一直挂着不消失
  Future<void>.delayed(const Duration(seconds: 3), () {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  });
  return true;
}

/// 右滑收藏 / 取消收藏
Future<void> swipeToggleFavorite(WidgetRef ref, Note note) {
  return ref.read(repositoryProvider).toggleFavorite(note.id);
}
