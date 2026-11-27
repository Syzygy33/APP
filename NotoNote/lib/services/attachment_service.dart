import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../models/attachment.dart';
import 'id.dart';

/// 一次挑选的结果：收下的附件，以及因为太大被跳过的数量。
class AttachmentPickResult {
  const AttachmentPickResult({this.attachments = const [], this.skipped = 0});

  final List<NoteAttachment> attachments;

  /// 超过 [NoteAttachment.maxBytes] 而被挡掉的文件数，页面据此给一句提示。
  final int skipped;

  bool get isEmpty => attachments.isEmpty && skipped == 0;
}

/// 附件挑选：相册、拍照、任意文件。
///
/// 图片在挑的时候就压到长边 1600px / 质量 80（Android 由 image_picker 的
/// 原生实现完成；Web 端插件不支持压缩，只能靠 [NoteAttachment.maxBytes]
/// 兜底），结果一律转 base64 内嵌进笔记，跟着备份一起走。
abstract final class AttachmentService {
  static final _picker = ImagePicker();

  /// 从相册选，支持多选。
  static Future<AttachmentPickResult> pickPhotos() async {
    final files = await _picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
      requestFullMetadata: false,
    );
    if (files.isEmpty) {
      return const AttachmentPickResult();
    }
    return _consume(files, preferredMime: 'image/jpeg');
  }

  /// 直接拍照，一次一张。
  static Future<AttachmentPickResult> takePhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
      requestFullMetadata: false,
    );
    if (file == null) {
      return const AttachmentPickResult();
    }
    return _consume([file], preferredMime: 'image/jpeg');
  }

  /// 任意文件：PDF、文档、压缩包等。以文件行展示，不显示缩略图。
  static Future<AttachmentPickResult> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return const AttachmentPickResult();
    }
    final picked = <NoteAttachment>[];
    var skipped = 0;
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        skipped += 1;
        continue;
      }
      if (bytes.length > NoteAttachment.maxBytes) {
        skipped += 1;
        continue;
      }
      picked.add(
        NoteAttachment(
          id: newId('att'),
          name: file.name,
          kind: _isImageName(file.name)
              ? AttachmentKind.image
              : AttachmentKind.file,
          size: bytes.length,
          mime: _mimeFor(file.name),
          data: base64Encode(bytes),
        ),
      );
    }
    return AttachmentPickResult(attachments: picked, skipped: skipped);
  }

  static Future<AttachmentPickResult> _consume(
    List<XFile> files, {
    required String preferredMime,
  }) async {
    final picked = <NoteAttachment>[];
    var skipped = 0;
    for (final file in files) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > NoteAttachment.maxBytes) {
        skipped += 1;
        continue;
      }
      picked.add(
        NoteAttachment(
          id: newId('att'),
          name: _readableName(file.name),
          kind: AttachmentKind.image,
          size: bytes.length,
          mime: _mimeFor(file.name) ?? preferredMime,
          data: base64Encode(bytes),
        ),
      );
    }
    return AttachmentPickResult(attachments: picked, skipped: skipped);
  }

  /// 挑完相册拿到的名字常常是 `image_picker_ab12cd.jpg`（移动端）或
  /// `scaled_xxx.jpg`（Web 端），对用户没有意义，换成「照片 11-25 20-31」。
  static String _readableName(String raw) {
    final temporary = raw.isEmpty ||
        raw.startsWith('image_picker_') ||
        raw.startsWith('scaled_');
    if (!temporary) {
      return raw;
    }
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '照片 ${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}-${two(now.minute)}';
  }

  static bool _isImageName(String name) {
    final lower = name.toLowerCase();
    return const [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.heic',
      '.bmp',
    ].any(lower.endsWith);
  }

  static String? _mimeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.heic')) {
      return 'image/heic';
    }
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.txt') || lower.endsWith('.md')) {
      return 'text/plain';
    }
    return null;
  }
}
