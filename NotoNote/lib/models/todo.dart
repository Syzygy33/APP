import 'package:flutter/foundation.dart';

import 'category.dart';

/// 一条待办。
///
/// 和 `Note` 是两套数据：待办有完成状态、通常没有长正文。
/// 置顶/收藏/分类与笔记同义，列表、筛选的行为也和笔记对齐。
@immutable
class Todo {
  const Todo({
    required this.id,
    required this.text,
    this.detail = '',
    this.done = false,
    required this.createdAt,
    DateTime? updatedAt,
    this.pinned = false,
    this.favorite = false,
    this.category = NoteCategory.fallbackName,
    DateTime? remindAt,
    DateTime? deletedAt,
  })  : _updatedAt = updatedAt,
        _remindAt = remindAt,
        _deletedAt = deletedAt;

  final String id;

  /// 要做什么。列表里加粗显示。
  final String text;

  /// 备注，可空。列表里是第二行的浅色小字。
  final String detail;

  final bool done;

  final DateTime createdAt;

  /// 旧存档没有更新时间，回退到创建时间。
  final DateTime? _updatedAt;

  DateTime get updatedAt => _updatedAt ?? createdAt;

  /// 置顶的待办排在未完成组的最前面。
  final bool pinned;

  /// 收藏。与置顶是两件事：置顶影响排序，收藏只是标记。
  final bool favorite;

  /// 分类名，与笔记共用同一套分类。
  final String category;

  /// 提醒时间。非空表示到点要弹一条系统通知；完成或删除待办时取消。
  final DateTime? _remindAt;

  DateTime? get remindAt => _remindAt;

  /// 提醒是否已过期（超过一分钟后仍没过问）。
  bool get isReminderDue {
    final at = _remindAt;
    return at != null && at.isBefore(DateTime.now());
  }

  /// 软删除时间，语义与 [Note.deletedAt] 一致。
  final DateTime? _deletedAt;

  DateTime? get deletedAt => _deletedAt;

  bool get isDeleted => _deletedAt != null;

  factory Todo.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return Todo(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      pinned: json['pinned'] as bool? ?? false,
      favorite: json['favorite'] as bool? ?? false,
      category: json['category'] as String? ?? NoteCategory.fallbackName,
      remindAt: DateTime.tryParse(json['remindAt'] as String? ?? ''),
      deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'detail': detail,
    'done': done,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'pinned': pinned,
    'favorite': favorite,
    'category': category,
    if (_remindAt != null) 'remindAt': _remindAt.toIso8601String(),
    if (_deletedAt != null) 'deletedAt': _deletedAt.toIso8601String(),
  };

  static const _copyUnset = Object();

  Todo copyWith({
    String? text,
    String? detail,
    bool? done,
    DateTime? updatedAt,
    bool? pinned,
    bool? favorite,
    String? category,
    Object? remindAt = _copyUnset,
    Object? deletedAt = _copyUnset,
  }) {
    return Todo(
      id: id,
      text: text ?? this.text,
      detail: detail ?? this.detail,
      done: done ?? this.done,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
      favorite: favorite ?? this.favorite,
      category: category ?? this.category,
      // 传 null 表示「取消提醒」，不传表示保持原状。
      remindAt: identical(remindAt, _copyUnset)
          ? _remindAt
          : remindAt as DateTime?,
      deletedAt: identical(deletedAt, _copyUnset)
          ? _deletedAt
          : deletedAt as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Todo &&
      other.id == id &&
      other.text == text &&
      other.detail == detail &&
      other.done == done &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.pinned == pinned &&
      other.favorite == favorite &&
      other.category == category &&
      other.remindAt == remindAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
    id,
    text,
    detail,
    done,
    createdAt,
    updatedAt,
    pinned,
    favorite,
    category,
    remindAt,
    deletedAt,
  );
}
