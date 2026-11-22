import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';
import '../../data/database/app_database.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/circle_button.dart';
import '../../shared/widgets/common_widgets.dart';
import 'note_actions.dart';
import 'note_card.dart';
import 'swipe_actions.dart';

/// 收藏页 —— 底部导航第三个分支，与笔记/待办共用同一套顶部结构。
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(favoriteNotesProvider);
    final firstImages =
        ref.watch(firstImageMapProvider).value ?? const <int, String>{};
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final folderMap = {for (final f in folders) f.id: f};
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final Color primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部圆形按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDims.s20,
                AppDims.s8,
                AppDims.s20,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleButton(
                    icon: LucideIcons.search,
                    tooltip: '搜索',
                    onTap: () => context.push('/search'),
                  ),
                  const SizedBox(width: AppDims.s12),
                  CircleButton(
                    icon: LucideIcons.moreHorizontal,
                    tooltip: '更多',
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
            ),

            // 标题 + 副标题
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDims.s20,
                AppDims.s20,
                AppDims.s20,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '收藏',
                    style: AppTypography.largeTitle.copyWith(
                      color: primary,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppDims.s6),
                  Text(
                    '值得回看的都收在这里',
                    style: AppTypography.subheadline.copyWith(color: secondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDims.s20),

            // 全部 N
            notesAsync.maybeWhen(
              data: (list) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDims.s20),
                child: Row(
                  children: [
                    Text(
                      '全部',
                      style: AppTypography.headline.copyWith(
                        color: primary,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(width: AppDims.s6),
                    Text(
                      '${list.length}',
                      style: AppTypography.footnote.copyWith(
                        color: secondary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              orElse: () => const SizedBox(height: 24),
            ),

            const SizedBox(height: AppDims.s4),

            Expanded(
              child: notesAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: LucideIcons.star,
                      title: '还没有收藏',
                      subtitle: '长按任意卡片选择「收藏」即可',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 176),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final n = list[i];
                      return NoteCard(
                        note: n,
                        folder: n.folderId != null
                            ? folderMap[n.folderId]
                            : null,
                        imageName: firstImages[n.id],
                        onTap: () => context.push('/note/${n.id}'),
                        onLongPressStart: (details) => showNoteActions(
                          context,
                          ref,
                          n,
                          position: details.globalPosition,
                        ),
                        onSwipeDelete: () => swipeDeleteNote(context, ref, n),
                        // 收藏页右滑 = 取消收藏，并且让卡片滑走
                        onSwipeFavorite: () => swipeToggleFavorite(ref, n),
                        favoriteSwipeRemoves: true,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => EmptyState(
                  icon: LucideIcons.circleAlert,
                  title: '加载失败',
                  subtitle: e.toString(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
