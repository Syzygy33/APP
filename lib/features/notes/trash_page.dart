import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, GlassSurfaceStyle, LiquidRoundedSuperellipse;
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../shared/widgets/app_trash_icon.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';
import '../../data/database/app_database.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/ios_dialog.dart';

/// 回收站 —— 恢复 / 彻底删除
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(trashNotesProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '回收站',
          style: AppTypography.title3.copyWith(color: primary),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: notesAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                iconWidget: AppTrashIcon(size: 40, color: AppColors.red),
                title: '回收站是空的',
                subtitle: '删除的笔记会在这里保留',
              );
            }
            return Stack(
              children: [
                ListView.separated(
                  // 底部让出清空按钮的空间
                  padding: const EdgeInsets.fromLTRB(
                    AppDims.s16,
                    AppDims.s16,
                    AppDims.s16,
                    104,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppDims.s8),
                  itemBuilder: (context, i) => _TrashTile(note: list[i]),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppDims.s16),
                      child: Center(
                        child: _ClearTrashButton(
                          onPressed: () async {
                            final confirmed = await showIOSConfirm(
                              context: context,
                              title: '清空回收站？',
                              message: '所有内容将被永久删除，无法恢复。',
                              confirmLabel: '清空',
                              destructive: true,
                            );
                            if (confirmed == true) {
                              await ref.read(repositoryProvider).emptyTrash();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(icon: Icons.error_outline, title: '加载失败'),
        ),
      ),
    );
  }
}

class _TrashTile extends ConsumerWidget {
  final Note note;
  const _TrashTile({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final Color primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final title = note.title.trim().isEmpty ? '无标题笔记' : note.title.trim();

    // 库的实色卡片（solid 表面），与其他页面卡片一致
    return GlassContainer.card(
      surfaceStyle: GlassSurfaceStyle.solid,
      color: surface,
      shape: const LiquidRoundedSuperellipse(
        borderRadius: AppDims.radiusXL,
      ),
      padding: EdgeInsets.zero,
      child: ListTile(
        title: Text(
          title,
          style: AppTypography.headline.copyWith(color: primary),
        ),
        subtitle: Text(
          note.content.trim().replaceAll(RegExp(r'\s+'), ' '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.footnote.copyWith(color: secondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: '恢复',
              color: isDark ? AppColors.accentDark : AppColors.accent,
              onPressed: () => ref.read(repositoryProvider).restore(note.id),
            ),
            IconButton(
              icon: const AppTrashIcon(color: AppColors.red),
              tooltip: '彻底删除',
              color: AppColors.red,
              onPressed: () async {
                final confirmed = await showIOSConfirm(
                  context: context,
                  title: '彻底删除？',
                  message: '此操作无法撤销。',
                  confirmLabel: '删除',
                  destructive: true,
                );
                if (confirmed == true) {
                  await ref.read(repositoryProvider).permanentlyDelete(note.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部居中的「清空」按钮：垃圾桶图标 + 文字，破坏性语义用红色
class _ClearTrashButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ClearTrashButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color tint = isDark ? AppColors.darkSurfaceElevated : Colors.white;

    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(AppDims.radiusPill),
      elevation: 0,
      child: PressableScale(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDims.s24,
            vertical: AppDims.s12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDims.radiusPill),
            border: Border.all(
              color: AppColors.red.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppTrashIcon(size: 18, color: AppColors.red),
              const SizedBox(width: AppDims.s8),
              Text(
                '清空',
                style: AppTypography.body.copyWith(
                  color: AppColors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
