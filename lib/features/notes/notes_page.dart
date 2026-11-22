import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';
import '../../data/database/app_database.dart';
import '../../data/models/note_kind.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/circle_button.dart';
import '../../shared/widgets/common_widgets.dart';
import 'note_actions.dart';
import 'swipe_actions.dart';
import '../../shared/widgets/context_menu.dart';
import '../../shared/widgets/pressable.dart';
import 'note_card.dart';
import 'todo_card.dart';

/// 排序方式
enum _SortMode { updated, created, title }

/// 内容列表页，笔记 / 待办共用同一套顶部结构、筛选与空状态。
/// [kind] 决定数据源与卡片形态（待办使用可勾选的卡片）。
class NotesPage extends ConsumerStatefulWidget {
  final NoteKind kind;

  const NotesPage({super.key, this.kind = NoteKind.note});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  int? _folderFilter;
  _SortMode _sort = _SortMode.updated;

  bool get _isTodo => widget.kind.isTodo;

  List<Note> _apply(List<Note> source) {
    var list = source;
    if (_folderFilter != null) {
      list = list.where((n) => n.folderId == _folderFilter).toList();
    }
    final sorted = [...list];
    sorted.sort((a, b) {
      // 待办：未完成始终在前，完成项沉底
      if (_isTodo && a.done != b.done) return a.done ? 1 : -1;
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      switch (_sort) {
        case _SortMode.updated:
          return b.updatedAt.compareTo(a.updatedAt);
        case _SortMode.created:
          return b.createdAt.compareTo(a.createdAt);
        case _SortMode.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });
    return sorted;
  }

  Future<void> _openFilter(Offset position) async {
    final folders = ref.read(foldersProvider).value ?? const <Folder>[];
    final List<ContextMenuItem> items = [];
    final List<VoidCallback> handlers = [];

    // 分类筛选（保留）
    items.add(
      ContextMenuItem(
        label: '全部分类',
        icon: LucideIcons.folderClosed,
        selected: _folderFilter == null,
      ),
    );
    handlers.add(() {
      _folderFilter = null;
      setState(() {});
    });

    for (final f in folders) {
      items.add(
        ContextMenuItem(
          label: f.name,
          icon: LucideIcons.folderClosed,
          selected: _folderFilter == f.id,
        ),
      );
      handlers.add(() {
        _folderFilter = f.id;
        setState(() {});
      });
    }

    // 排序：只保留最近更新 / 创建时间
    items.add(
      ContextMenuItem(
        label: '最近更新',
        icon: LucideIcons.clock,
        selected: _sort == _SortMode.updated,
        dividerBefore: true,
      ),
    );
    handlers.add(() {
      _sort = _SortMode.updated;
      setState(() {});
    });

    items.add(
      ContextMenuItem(
        label: '创建时间',
        icon: LucideIcons.calendar,
        selected: _sort == _SortMode.created,
      ),
    );
    handlers.add(() {
      _sort = _SortMode.created;
      setState(() {});
    });

    final int? index = await showContextMenu(
      context,
      position: position,
      items: items,
    );
    if (index == null || !mounted) return;
    handlers[index]();
  }

  @override
  Widget build(BuildContext context) {
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

    final notesAsync = ref.watch(notesByKindProvider(widget.kind));
    final firstImages =
        ref.watch(firstImageMapProvider).value ?? const <int, String>{};
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final folderMap = {for (final f in folders) f.id: f};

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          // 关键：让子项撑满宽度，否则标题等会被居中压窄
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
                    widget.kind.label,
                    style: AppTypography.largeTitle.copyWith(
                      color: primary,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppDims.s6),
                  Text(
                    widget.kind.subtitle,
                    style: AppTypography.subheadline.copyWith(color: secondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDims.s20),

            // 全部 N + 待办进度 + 筛选
            notesAsync.maybeWhen(
              data: (all) {
                final list = _apply(all);
                final int doneCount = all.where((n) => n.done).length;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDims.s20,
                    0,
                    AppDims.s12,
                    0,
                  ),
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
                      if (_isTodo && all.isNotEmpty) ...[
                        const SizedBox(width: AppDims.s8),
                        Text(
                          '已完成 $doneCount',
                          style: AppTypography.footnote.copyWith(
                            color: secondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const Spacer(),
                      PressableScale(
                        onTapWithPosition: _openFilter,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDims.s8,
                            vertical: AppDims.s6,
                          ),
                          child: Row(
                            children: [
                              Text(
                                '筛选',
                                style: AppTypography.subheadline.copyWith(
                                  color: secondary,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: AppDims.s4),
                              Icon(
                                LucideIcons.listFilter,
                                size: 18,
                                color: secondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              orElse: () => const SizedBox(height: 24),
            ),

            const SizedBox(height: AppDims.s4),

            // 列表
            Expanded(
              child: notesAsync.when(
                data: (all) {
                  final list = _apply(all);
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: switch (widget.kind) {
                        NoteKind.note => LucideIcons.notebook,
                        NoteKind.todo => LucideIcons.listTodo,
                      },
                      title: _folderFilter != null
                          ? '该分类下暂无内容'
                          : '还没有${widget.kind.label}',
                      subtitle: _folderFilter != null
                          ? '试试切换筛选条件'
                          : '点按下方的 + 立即创建',
                    );
                  }
                  return ListView.builder(
                    // 底部让出底栏与悬浮加号的空间
                    padding: const EdgeInsets.only(bottom: 176),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final n = list[i];
                      final Folder? folder = n.folderId != null
                          ? folderMap[n.folderId]
                          : null;
                      if (_isTodo) {
                        return TodoCard(
                          note: n,
                          folder: folder,
                          imageName: firstImages[n.id],
                          onToggle: () =>
                              ref.read(repositoryProvider).toggleDone(n.id),
                          onTap: () => context.push('/note/${n.id}'),
                          onLongPressStart: (details) => showNoteActions(
                            context,
                            ref,
                            n,
                            position: details.globalPosition,
                          ),
                          onSwipeDelete: () => swipeDeleteNote(context, ref, n),
                          onSwipeFavorite: () => swipeToggleFavorite(ref, n),
                        );
                      }
                      return NoteCard(
                        note: n,
                        folder: folder,
                        imageName: firstImages[n.id],
                        onTap: () => context.push('/note/${n.id}'),
                        onLongPressStart: (details) => showNoteActions(
                          context,
                          ref,
                          n,
                          position: details.globalPosition,
                        ),
                        onSwipeDelete: () => swipeDeleteNote(context, ref, n),
                        onSwipeFavorite: () => swipeToggleFavorite(ref, n),
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
