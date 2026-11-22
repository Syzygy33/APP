import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, GlassSurfaceStyle, LiquidRoundedSuperellipse;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../shared/widgets/app_trash_icon.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';
import '../../data/database/app_database.dart';

import '../../providers/app_providers.dart';
import '../../shared/widgets/circle_button.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/context_menu.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/ios_dialog.dart';

/// 文件夹（分类）管理页
class FoldersPage extends ConsumerWidget {
  const FoldersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider);
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
        // 与笔记 / 待办 / 收藏页一致：头部固定在滚动区外，只有列表滚动。
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部圆形按钮行
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
                    '分类',
                    style: AppTypography.largeTitle.copyWith(
                      color: primary,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppDims.s6),
                  Text(
                    '把笔记装进不同的抽屉',
                    style: AppTypography.subheadline.copyWith(color: secondary),
                  ),
                ],
              ),
            ),

            Expanded(
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDims.s20),
                  ),
                  foldersAsync.when(
              data: (folders) {
                if (folders.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.folder_off_outlined,
                      title: '还没有分类',
                      subtitle: '点按底部 + 号创建分类，给笔记归类',
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: folders.length,
                  itemBuilder: (context, i) {
                    final f = folders[i];
                    final color = AppColors.categoryColor(f.colorIndex);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDims.s16,
                        vertical: AppDims.s4,
                      ),
                      // 库的实色卡片（solid 表面），全 App 页面卡片统一圆角 28
                      child: GlassContainer.card(
                        surfaceStyle: GlassSurfaceStyle.solid,
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        shape: const LiquidRoundedSuperellipse(
                          borderRadius: AppDims.radiusXL,
                        ),
                        padding: EdgeInsets.zero,
                        child: PressableScale(
                          onTap: () => context.push('/folder/${f.id}'),
                          // 按下整块泛灰 + 缩放回弹，与笔记/待办卡片一致
                          pressedHighlightColor: isDark
                              ? const Color(0x1FFFFFFF)
                              : const Color(0x0F000000),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(
                                  AppDims.radiusS,
                                ),
                              ),
                              child: Icon(Icons.folder, color: color, size: 22),
                            ),
                            title: Text(f.name, style: AppTypography.headline),
                            subtitle: FutureBuilder<int>(
                              future: ref
                                  .read(repositoryProvider)
                                  .countNotesInFolder(f.id),
                              builder: (context, snap) {
                                return Text(
                                  '${snap.data ?? 0} 条笔记',
                                  style: AppTypography.footnote.copyWith(
                                    color: secondary,
                                  ),
                                );
                              },
                            ),
                            trailing: PressableScale(
                              onTapWithPosition: (pos) =>
                                  _showItemMenu(context, ref, f, pos),
                              child: Icon(Icons.more_horiz, color: secondary),
                            ),
                          ),
                        ),
                      ),
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
                  // 与笔记/收藏页一致：底部让出底栏与悬浮加号的空间
                  const SliverToBoxAdapter(child: SizedBox(height: 176)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showItemMenu(
    BuildContext context,
    WidgetRef ref,
    Folder f,
    Offset position,
  ) async {
    final int? index = await showContextMenu(
      context,
      position: position,
      items: const [
        ContextMenuItem(label: '重命名', icon: Icons.edit_outlined),
        ContextMenuItem(
          label: '删除',
          iconWidget: AppTrashIcon(size: 20, color: AppColors.red),
          destructive: true,
        ),
      ],
    );
    if (index == null || !context.mounted) return;
    if (index == 0) {
      _showRenameDialog(context, ref, f);
    } else {
      _confirmDelete(context, ref, f);
    }
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, Folder folder) {
    final controller = TextEditingController(text: folder.name);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurfaceElevated
            : AppColors.lightSurface,
        title: const Text('重命名分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '分类名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              ref.read(repositoryProvider).renameFolder(folder.id, name);
              Navigator.of(ctx).pop(true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) async {
    final confirmed = await showIOSConfirm(
      context: context,
      title: '删除分类「${folder.name}」？',
      message: '该分类下的笔记不会被删除，会移为「无分类」。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (confirmed == true) {
      await ref.read(repositoryProvider).deleteFolder(folder.id);
    }
  }
}

/// 新建分类弹窗（带文本输入）。
///
/// 由外壳底部悬浮的加号触发（分类页不再有右上角按钮），故提取为顶层函数。
void showCreateFolderSheet(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();
  int selectedColor = 0;
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurfaceElevated
            : AppColors.lightSurface,
        title: const Text('新建分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: '分类名称'),
              maxLength: 40,
            ),
            const SizedBox(height: AppDims.s16),
            Wrap(
              spacing: AppDims.s12,
              children: List.generate(AppColors.categoryPalette.length, (i) {
                return PressableScale(
                  onTap: () => setLocal(() => selectedColor = i),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.categoryColor(i),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedColor == i
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: selectedColor == i
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          )
                        : null,
                  ),
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              ref.read(repositoryProvider).createFolder(name, selectedColor);
              Navigator.of(ctx).pop(true);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    ),
  );
}
