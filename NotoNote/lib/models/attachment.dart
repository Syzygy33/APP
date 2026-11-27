import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 附件是照片还是一般文件。
///
/// 只影响展示方式（缩略图 vs 文件行），不影响存储——两者都以 base64 内嵌在
/// 笔记的 JSON 里，这样 WebDAV / 本地备份导出的那份 JSON 自带附件，
/// 不需要额外的文件目录，Web 预览也能直接看到。
enum AttachmentKind { image, file }

/// 一条笔记的附件。
///
/// 图片在挑选时就被压到长边 1600px / 质量 80，手机照片通常落在 200–400 KB，
/// base64 之后约 300–550 KB。整表存在 SharedPreferences 里，所以
/// [maxBytes] 之外的文件会被挡在挑选这一步。
@immutable
class NoteAttachment {
  NoteAttachment({
    required this.id,
    required this.name,
    required this.kind,
    required this.size,
    required this.data,
    this.mime,
  });

  /// 单个附件允许的最大原始字节数（压缩后）。超过就不收。
  ///
  /// 定 2 MB 是因为整表走 base64 存在 SharedPreferences 里，而 Web 预览用的
  /// localStorage 只有约 5 MB 总容量——再大加一张图就会 QuotaExceeded。
  /// 手机照片经 1600px / 质量 80 压完通常 200–500 KB，够用。
  static const maxBytes = 2 * 1024 * 1024;

  final String id;
  final String name;
  final AttachmentKind kind;

  /// 原始（压缩后）字节数，用来在 UI 上显示大小。
  final int size;

  /// 形如 `image/jpeg`。旧存档可能没有。
  final String? mime;

  /// base64 编码的内容。
  final String data;

  bool get isImage => kind == AttachmentKind.image;

  /// 解码结果缓存一次。
  ///
  /// 缩略图列表每帧都会读 `bytes`，不缓存的话每帧都要 base64Decode 一遍，
  /// 而且每次得到的 Uint8List 都是新对象，`Image.memory` 的缓存键跟着变，
  /// 图片会被反复解码。
  late final Uint8List bytes = base64Decode(data);

  /// 人类可读的大小：`820 KB` / `1.4 MB`。
  String get sizeLabel {
    if (size < 1024) {
      return '$size B';
    }
    if (size < 1024 * 1024) {
      return '${(size / 1024).round()} KB';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory NoteAttachment.fromJson(Map<String, dynamic> json) {
    return NoteAttachment(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      kind: json['kind'] == 'image'
          ? AttachmentKind.image
          : AttachmentKind.file,
      size: (json['size'] as num?)?.toInt() ?? 0,
      mime: json['mime'] as String?,
      data: json['data'] as String? ?? '',
    );
  }

  /// 空内容的附件没有意义，也存不进 JSON——读的时候直接丢掉。
  static List<NoteAttachment> listFromJson(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final out = <NoteAttachment>[];
    for (final item in raw) {
      if (item is Map) {
        final parsed = NoteAttachment.fromJson(
          item.map((key, value) => MapEntry('$key', value)),
        );
        if (parsed.data.isNotEmpty) {
          out.add(parsed);
        }
      }
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'size': size,
    if (mime != null) 'mime': mime,
    'data': data,
  };

  NoteAttachment copyWith({String? name}) => NoteAttachment(
    id: id,
    name: name ?? this.name,
    kind: kind,
    size: size,
    mime: mime,
    data: data,
  );

  @override
  bool operator ==(Object other) =>
      other is NoteAttachment &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.size == size &&
      other.mime == mime &&
      other.data == data;

  @override
  int get hashCode => Object.hash(id, name, kind, size, mime, data);

  @override
  String toString() => 'NoteAttachment($name, $sizeLabel)';
}
