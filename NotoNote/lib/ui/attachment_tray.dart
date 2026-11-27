import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../models/attachment.dart';
import 'icons/app_glyphs.dart';

/// 笔记详情底部常驻的附件工具条。
///
/// 放在 body 的 `Column` 最后一行：Scaffold 在键盘弹出时会把 body 压短，
/// 于是它天然「跟着键盘抬起」，不需要自己监听 `viewInsets` 去挪位置。
class AttachmentTray extends StatelessWidget {
  const AttachmentTray({
    super.key,
    required this.onAttachFile,
    required this.onPickPhotos,
    required this.onTakePhoto,
    this.enabled = true,
  });

  /// 选任意文件（PDF、文档等）。
  final VoidCallback onAttachFile;

  /// 从相册选照片，支持多选。
  final VoidCallback onPickPhotos;

  /// 直接调相机拍一张。
  final VoidCallback onTakePhoto;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    // 键盘顶上来时系统安全区已经被它占了，不要再垫一次。
    // 用 View 上的原始 insets：PrismScaffold 会把 body 的 MediaQuery 里
    // viewInsets.bottom 清零（它自己已经让出键盘高度了）。
    final keyboard = View.of(context).viewInsets.bottom;
    final safeBottom = keyboard > 0
        ? 0.0
        : MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SurfaceLevel.page.colorOf(colorScheme),
        border: Border(
          top: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        // 底部留出比顶部更多的呼吸空间：真机上还有 home indicator 的安全区，
        // 两者相加后按钮不会贴着屏幕下沿。
        padding: EdgeInsets.fromLTRB(16, 12, 16, 18 + safeBottom),
        child: Row(
          children: [
            Expanded(
              child: _TrayButton(
                glyph: AppGlyphs.paperclip,
                label: '附件',
                onPressed: enabled ? onAttachFile : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TrayButton(
                glyph: AppGlyphs.photo,
                label: '照片',
                onPressed: enabled ? onPickPhotos : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TrayButton(
                glyph: AppGlyphs.camera,
                label: '拍照',
                onPressed: enabled ? onTakePhoto : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrayButton extends StatelessWidget {
  const _TrayButton({
    required this.glyph,
    required this.label,
    required this.onPressed,
  });

  final Glyph glyph;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TonalButton(
      size: TonalButtonSize.section,
      glyph: glyph,
      label: label,
      onPressed: onPressed,
    );
  }
}

/// 正文下方的附件区：照片排成缩略图，其它文件是一行。
class AttachmentSection extends StatelessWidget {
  const AttachmentSection({
    super.key,
    required this.attachments,
    required this.onRemove,
    required this.onPreview,
  });

  final List<NoteAttachment> attachments;
  final ValueChanged<NoteAttachment> onRemove;
  final ValueChanged<NoteAttachment> onPreview;

  @override
  Widget build(BuildContext context) {
    final images = [
      for (final attachment in attachments)
        if (attachment.isImage) attachment,
    ];
    final files = [
      for (final attachment in attachments)
        if (!attachment.isImage) attachment,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final image in images)
                _Thumb(
                  key: ValueKey(image.id),
                  attachment: image,
                  onTap: () => onPreview(image),
                  onRemove: () => onRemove(image),
                ),
            ],
          ),
        if (files.isNotEmpty) ...[
          if (images.isNotEmpty) const SizedBox(height: 10),
          for (final file in files)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FileRow(
                key: ValueKey(file.id),
                attachment: file,
                onRemove: () => onRemove(file),
              ),
            ),
        ],
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    super.key,
    required this.attachment,
    required this.onTap,
    required this.onRemove,
  });

  final NoteAttachment attachment;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              child: ClipRSuperellipse(
                borderRadius: AppRadius.md,
                child: Image.memory(
                  attachment.bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) =>
                      const _BrokenThumb(),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0x8A000000),
                  shape: BoxShape.circle,
                ),
                child: const GlyphIcon(
                  Glyphs.close,
                  size: 10,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrokenThumb extends StatelessWidget {
  const _BrokenThumb();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.md,
      ),
      child: Center(
        child: GlyphIcon(
          AppGlyphs.photo,
          size: 20,
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    super.key,
    required this.attachment,
    required this.onRemove,
  });

  final NoteAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.md,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.sm,
              ),
              child: Center(
                child: GlyphIcon(
                  AppGlyphs.paperclip,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.subheadline.of(context),
                  ),
                  Text(
                    attachment.sizeLabel,
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: GlyphIcon(
                  Glyphs.close,
                  size: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 点缩略图看大图：浮层里按比例铺满，点一下关掉。
Future<void> showAttachmentPreview(
  BuildContext context,
  NoteAttachment attachment,
) {
  return showFloatingDialog<void>(
    context: context,
    child: Builder(
      builder: (dialogContext) {
        // 尺寸要在弹层自己的 context 里取：外层的 MediaQuery 是页面的，
        // 在 Web 预览里可能比 iframe 大得多，图片会顶到屏幕边缘。
        final size = MediaQuery.sizeOf(dialogContext);
        return GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: math.min(size.width - 40, 560),
                  maxHeight: size.height * 0.66,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(
                    attachment.bytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// 底栏上方的一句临时提示（例如挑中的文件太大被跳过）。
///
/// 详情页与新建页共用，所以放在这里而不是各自页面里。
class AttachmentNoticeBar extends StatelessWidget {
  const AttachmentNoticeBar({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        style: AppTextStyle.footnote
            .of(context)
            .copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
