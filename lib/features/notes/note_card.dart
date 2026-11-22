import 'package:intl/intl.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, GlassSurfaceStyle, LiquidRoundedSuperellipse;
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';
import '../../data/database/app_database.dart';
import '../../data/models/note_display.dart';
import '../../data/images/image_store.dart';
import '../../data/models/note_kind.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/swipe_background.dart';

/// 笔记卡片 —— 白底大圆角、左侧缩略块、标题/摘要/更新时间，贴合参考图。
class NoteCard extends StatefulWidget {
  final Note note;
  final Folder? folder;

  /// 首图文件名：有图时缩略块显示图片，替代渐变色块
  final String? imageName;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final void Function(LongPressStartDetails details)? onLongPressStart;

  /// 左滑删除：返回 true 表示允许卡片滑走（数据流会同步移除）
  final Future<bool> Function()? onSwipeDelete;

  /// 右滑收藏 / 取消收藏
  final Future<void> Function()? onSwipeFavorite;

  /// 右滑后是否让卡片滑走（收藏页取消收藏时为 true）
  final bool favoriteSwipeRemoves;

  const NoteCard({
    super.key,
    required this.note,
    this.folder,
    this.imageName,
    required this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onSwipeDelete,
    this.onSwipeFavorite,
    this.favoriteSwipeRemoves = false,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
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
    final Note note = widget.note;
    final Folder? folder = widget.folder;
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

    final NoteKind kind = NoteKind.fromValue(note.kind);
    final Color tint = folder != null
        ? AppColors.categoryColor(folder.colorIndex)
        : switch (kind) {
            NoteKind.todo => AppColors.green,
            NoteKind.note => AppColors.accent,
          };

    // 标题没填就借正文第一段（比显示"无标题笔记"更容易辨认）；
    // 预览会自动跳过被借走的那段，避免同一句出现两遍。
    final String title = NoteDisplay.titleOf(note, placeholder: '无标题笔记');
    final String preview = NoteDisplay.previewOf(note);
    final String time =
        '${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(note.updatedAt))} 更新';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDims.s16,
        vertical: AppDims.s6,
      ),
      child: Dismissible(
        key: ValueKey('note-card-${note.id}'),
        direction: (widget.onSwipeDelete == null && widget.onSwipeFavorite == null)
            ? DismissDirection.none
            : DismissDirection.horizontal,
        // 跟手：把滑动进度喂给背景层（滑多少露多少，松手弹回时同步收回）
        onUpdate: (details) => _swipeProgress.value = details.progress,
        background: ValueListenableBuilder<double>(
          valueListenable: _swipeProgress,
          builder: (_, p, __) => SwipeFavoriteBackground(
            leftSide: true,
            favorited: widget.note.favorite,
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
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onLongPressStart: widget.onLongPressStart,
              // 按下时整块卡片泛灰（标准点击反馈）
              pressedHighlightColor: isDark
                  ? const Color(0x1FFFFFFF)
                  : const Color(0x0F000000),
              child: Padding(
                padding: const EdgeInsets.all(AppDims.s14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Thumb(tint: tint, kind: kind, imageName: widget.imageName),
                    const SizedBox(width: AppDims.s12),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.headline.copyWith(
                                    color: primary,
                                    fontSize: 16.5,
                                  ),
                                ),
                              ),
                              if (note.favorite)
                                Icon(
                                  LucideIcons.star,
                                  size: 14,
                                  color: AppColors.orange,
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            preview.isEmpty ? '暂无内容' : preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.subheadline.copyWith(
                              color: secondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: AppDims.s10),
                          Text(
                            time,
                            style: AppTypography.caption1.copyWith(
                              color: tertiary,
                              fontSize: 12,
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

/// 左侧缩略块：无图片时用分类色渐变 + 类型图标，保持信息可辨识。
class _Thumb extends StatelessWidget {
  final Color tint;
  final NoteKind kind;
  final String? imageName;

  const _Thumb({required this.tint, required this.kind, this.imageName});

  @override
  Widget build(BuildContext context) {
    // 有首图就用图片，视觉上更接近参考图的「照片缩略块」
    if (imageName != null && ImageStore.isReady) {
      final file = ImageStore.fileOf(imageName!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            file,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
          ),
        );
      }
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: 0.95), tint.withValues(alpha: 0.55)],
        ),
      ),
      child: Icon(
        switch (kind) {
          NoteKind.note => LucideIcons.fileText,
          NoteKind.todo => LucideIcons.listChecks,
        },
        size: 24,
        color: Colors.white,
      ),
    );
  }
}
