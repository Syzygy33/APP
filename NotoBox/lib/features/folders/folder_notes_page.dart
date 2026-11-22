import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../notes/note_card.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../notes/swipe_actions.dart';

/// 某分类下的笔记列表
class FolderNotesPage extends ConsumerWidget {
  final int folderId;
  const FolderNotesPage({super.key, required this.folderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(folderNotesProvider(folderId));
    final folders = ref.watch(foldersProvider).value ?? [];
    final folder = folders.where((f) => f.id == folderId).firstOrNull;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color accent = isDark ? AppColors.accentDark : AppColors.accent;
    final Color color = folder != null
        ? AppColors.categoryColor(folder.colorIndex)
        : accent;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDims.s20,
                  AppDims.s16,
                  AppDims.s20,
                  AppDims.s12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: AppDims.s4),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppDims.s12),
                    Expanded(
                      child: Text(
                        folder?.name ?? '分类',
                        style: AppTypography.title1.copyWith(color: primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            notesAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.note_add_outlined,
                      title: '这个分类还没有笔记',
                      subtitle: '新建笔记时选择该分类即可',
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final n = list[i];
                    return NoteCard(
                      note: n,
                      folder: folder,
                      onTap: () => context.push('/note/${n.id}'),
                      onSwipeDelete: () => swipeDeleteNote(context, ref, n),
                      onSwipeFavorite: () => swipeToggleFavorite(ref, n),
                    );
                  },
                );
              },
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(icon: Icons.error_outline, title: '加载失败'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/note/new'),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
