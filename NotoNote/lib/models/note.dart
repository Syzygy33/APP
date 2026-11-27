import 'package:flutter/foundation.dart';

import 'attachment.dart';
import 'category.dart';

/// 一条笔记。
///
/// 刻意做成不可变值对象：页面之间只传值，不传可变引用，
/// 避免详情页改动影响列表页持有的那份数据。
@immutable
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
    this.pinned = false,
    this.favorite = false,
    this.category = NoteCategory.fallbackName,
    this.attachments = const [],
    DateTime? createdAt,
    DateTime? deletedAt,
  })  : _createdAt = createdAt,
        _deletedAt = deletedAt;

  final String id;
  final String title;
  final String body;
  final DateTime updatedAt;

  /// 附件（照片与文件）。内容以 base64 内嵌，跟着笔记一起备份。
  final List<NoteAttachment> attachments;

  /// 旧存档里没有创建时间，存成可空再回退到 [updatedAt]——
  /// 这样不需要写迁移，老笔记按更新时间排序也不会乱。
  final DateTime? _createdAt;

  DateTime get createdAt => _createdAt ?? updatedAt;

  /// 置顶的笔记排在列表最前。
  final bool pinned;

  /// 收藏。与置顶是两件事：置顶影响笔记列表的排序，收藏决定是否出现在收藏页。
  final bool favorite;

  /// 分类名。存字符串而不是外键：预置分类写在代码里，改名不会让旧笔记失联。
  final String category;

  /// 软删除时间。非空表示在「最近删除」里；列表默认不显示这些笔记。
  /// 私有字段 + getter，方便 copyWith 区分「不改」和「清空（恢复）」。
  final DateTime? _deletedAt;

  DateTime? get deletedAt => _deletedAt;

  /// 是否已进入回收站。
  bool get isDeleted => _deletedAt != null;

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      pinned: json['pinned'] as bool? ?? false,
      // 旧存档没有这个字段，缺省 false——读老数据不会报错，也不需要迁移
      favorite: json['favorite'] as bool? ?? false,
      category: json['category'] as String? ?? NoteCategory.fallbackName,
      attachments: NoteAttachment.listFromJson(json['attachments']),
      deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'updatedAt': updatedAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'pinned': pinned,
    'favorite': favorite,
    'category': category,
    if (attachments.isNotEmpty)
      'attachments': [for (final attachment in attachments) attachment.toJson()],
    if (_deletedAt != null) 'deletedAt': _deletedAt.toIso8601String(),
  };

  Note copyWith({
    String? title,
    String? body,
    DateTime? updatedAt,
    DateTime? createdAt,
    bool? pinned,
    bool? favorite,
    String? category,
    List<NoteAttachment>? attachments,
    Object? deletedAt = _copyUnset,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      pinned: pinned ?? this.pinned,
      favorite: favorite ?? this.favorite,
      category: category ?? this.category,
      attachments: attachments ?? this.attachments,
      // 传 null 表示「恢复到正常列表」，不传表示保持原状。
      deletedAt: identical(deletedAt, _copyUnset)
          ? _deletedAt
          : deletedAt as DateTime?,
    );
  }

  static const _copyUnset = Object();

  /// 列表副标题用的摘要：正文压成一行，去掉换行。
  String get excerpt => body.replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.updatedAt == updatedAt &&
      other.createdAt == createdAt &&
      other.pinned == pinned &&
      other.favorite == favorite &&
      other.category == category &&
      listEquals(other.attachments, attachments) &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    body,
    updatedAt,
    createdAt,
    pinned,
    favorite,
    category,
    Object.hashAll(attachments),
    deletedAt,
  );

  @override
  String toString() => 'Note($id, $title)';
}
