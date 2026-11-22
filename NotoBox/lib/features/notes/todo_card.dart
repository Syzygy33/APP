import 'package:intl/intl.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, GlassSurfaceStyle, LiquidRoundedSuperellipse;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';
import '../../data/database/app_database.dart';
import '../../data/models/note_display.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/swipe_background.dart';

/// 待办卡片 —— 左侧可勾选圆圈，完成项整体弱化。
class TodoCard extends StatefulWidget {
  final Note note;
  final Folder? folder;

  /// 首图文件名，仅用于提示「这条待办带图」
  final String? imageName;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final void Function(LongPressStartDetails details)? onLongPressStart;

  /// 左滑删除：返回 true 表示允许卡片滑走
  final Future<bool> Function()? onSwipeDelete;

  /// 右滑收藏 / 取消收藏
  final Future<void> Function()? onSwipeFavorite;

  /// 右滑后是否让卡片滑走（收藏页取消收藏时为 true）
  final bool favoriteSwipeRemoves;

  const TodoCard({
    super.key,
    required this.note,
    this.folder,
    this.imageName,
    required this.onToggle,
    required this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onSwipeDelete,
    this.onSwipeFavorite,
    this.favoriteSwipeRemoves = false,
  });

  @override
  State<TodoCard> createState() => _TodoCardState();
}

class _TodoCardState extends State<TodoCard> {
  /// 滑动进度：只驱动背景层，不重建整卡
  final ValueNotifier<double> _swipeProgress = ValueNotifier<double>(0);

  Future<bool> _handleSwipe(DismissDirection direction) async {
    if (direction == DismissDirection.startToEnd) {
      await widget.onSwipeFavorite?.call();
      return widget.favoriteSwipeRemoves;
    }
    if (direction == DismissDirection.endToStart) {
      final handler = widget.onSwipeDelete;
      if (handler == null) return false;
      return handler();
    }
    return false;
  }

  @override
  void dispose() {
    _swipeProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // StatefulWidget 里访问原 StatelessWidget 的字段，统一走 widget.
    final Note note = widget.note;
    final Folder? folder = widget.folder;
    final String? imageName = widget.imageName;
    final VoidCallback onToggle = widget.onToggle;
    final VoidCallback onTap = widget.onTap;
    final VoidCallback? onLongPress = widget.onLongPress;
    final void Function(LongPressStartDetails details)? onLongPressStart =
        widget.onLongPressStart;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color card = isDark ? AppColors.darkSurfaceElevated : Colors.white;
    final Color primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final Color tertiary = isDark
        ? AppColors.darkTextTertiary
        : AppColors.lightTextTertiary;
    final Color accent = isDark ? AppColors.accentDark : AppColors.accent;

    final bool done = note.done;
    final Color titleColor = done ? tertiary : primary;
    // 与笔记卡片一致：标题没填就借正文第一段
    final String title = NoteDisplay.titleOf(note, placeholder: '未命名待办');
    // 与笔记卡片一致：标题借走了第一段，预览就从第二段开始
    final String preview = NoteDisplay.previewOf(note);
    final String time =
        '${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(note.updatedAt))} 更新';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDims.s16,
        vertical: AppDims.s6,
      ),
      child: Dismissible(
        key: ValueKey('todo-card-${note.id}'),
        direction: (widget.onSwipeDelete == null && widget.onSwipeFavorite == null)
            ? DismissDirection.none
            : DismissDirection.horizontal,
        // 跟手：把滑动进度喂给背景层
        onUpdate: (details) => _swipeProgress.value = details.progress,
        background: ValueListenableBuilder<double>(
          valueListenable: _swipeProgress,
          builder: (_, p, __) => SwipeFavoriteBackground(
            leftSide: true,
            favorited: note.favorite,
            progress: p,
          ),
        ),
        secondaryBackground: ValueListenableBuilder<double>(
          valueListenable: _swipeProgress,
          builder: (_, p, __) => SwipeDeleteBackground(
            leftSide: false,
            progress: p,
          ),
        ),
        confirmDismiss: _handleSwipe,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0x33000000)
                    : const Color(0x0A000000),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // 库的实色卡片（solid 表面，零 shader 开销）
          child: GlassContainer.card(
            surfaceStyle: GlassSurfaceStyle.solid,
            color: card,
            shape: const LiquidRoundedSuperellipse(borderRadius: 28),
            padding: EdgeInsets.zero,
            child: PressableScale(
              onTap: onTap,
              onLongPress: onLongPress,
              onLongPressStart: onLongPressStart,
              // 按下时整块卡片泛灰（标准点击反馈）
              pressedHighlightColor: isDark
                  ? const Color(0x1FFFFFFF)
                  : const Color(0x0F000000),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDims.s10,
                  AppDims.s14,
                  AppDims.s14,
                  AppDims.s14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 勾选区：单独响应点击，避免误触进编辑页。
                    // 用 PressableScale 与卡片/按钮统一手感：
                    // 按下缩小到 0.88 + 变淡 + 轻触感，松开带轻微过冲回弹。
                    PressableScale(
                      onTap: onToggle,
                      pressedScale: 0.88,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: AnimatedContainer(
                          duration: AppDims.animFast,
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done ? accent : Colors.transparent,
                            border: Border.all(
                              color: done
                                  ? accent
                                  : (folder != null
                                        ? AppColors.categoryColor(
                                            folder.colorIndex,
                                          )
                                        : tertiary),
                              width: 1.6,
                            ),
                          ),
                          child: AnimatedOpacity(
                            duration: AppDims.animFast,
                            opacity: done ? 1 : 0,
                            child: Icon(
                              LucideIcons.check,
                              size: 16,
                              color: isDark
                                  ? const Color(0xFF1C1C1E)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDims.s10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (note.pinned)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                    LucideIcons.pin,
                                    size: 13,
                                    color: tertiary,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.headline.copyWith(
                                    color: titleColor,
                                    fontSize: 16.5,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: tertiary,
                                  ),
                                ),
                              ),
                              if (imageName != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Icon(
                                    LucideIcons.image,
                                    size: 14,
                                    color: tertiary,
                                  ),
                                ),
                              if (note.favorite)
                                const Icon(
                                  LucideIcons.star,
                                  size: 14,
                                  color: AppColors.orange,
                                ),
                            ],
                          ),
                          if (preview.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.subheadline.copyWith(
                                color: done ? tertiary : secondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppDims.s8),
                          Text(
                            done ? '已完成' : time,
                            style: AppTypography.caption1.copyWith(
                              color: done ? accent : tertiary,
                              fontSize: 12,
                              fontWeight: done
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
