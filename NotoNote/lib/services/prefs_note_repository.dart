import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attachment.dart';
import '../models/category.dart';
import '../models/note.dart';
import 'id.dart';
import 'notes_revision.dart';
import 'note_repository.dart';

/// 本地持久化实现：整个笔记列表序列化成一段 JSON 存进 SharedPreferences。
///
/// 适用规模：几十到几百条笔记。正文总量到 1MB 量级时该换成 sqflite，
/// 换的时候只改这一个文件——`NoteRepository` 接口不用动，页面层零改动。
///
/// 写入策略：每次变更整体重写。数据量小，这是最简单也最不容易出错的方案；
/// 换来的是不需要处理增量更新的部分失败。
class PrefsNoteRepository implements NoteRepository {
  PrefsNoteRepository();

  /// 带版本号，将来迁移格式时能识别旧数据。
  static const _storageKey = 'noto_note.notes.v1';
  static const _schemaVersion = 1;

  SharedPreferences? _store;

  Future<SharedPreferences> get _prefs async {
    final cached = _store;
    if (cached != null) {
      return cached;
    }
    final store = await SharedPreferences.getInstance();
    _store = store;
    return store;
  }

  @override
  Future<List<Note>> load() async {
    final notes = await _read();
    notes.removeWhere((note) => note.isDeleted);
    _sort(notes);
    return List<Note>.unmodifiable(notes);
  }

  @override
  Future<Note> create({
    required String title,
    required String body,
    String category = NoteCategory.fallbackName,
    List<NoteAttachment> attachments = const [],
  }) async {
    final now = DateTime.now();
    final notes = await _read();
    final note = Note(
      id: newId('note'),
      title: normalizeTitle(title),
      body: body,
      category: category,
      attachments: attachments,
      updatedAt: now,
      createdAt: now,
    );
    notes.add(note);
    await _write(notes);
    bumpNotesRevision();
    return note;
  }

  @override
  Future<Note?> update(Note note) async {
    final notes = await _read();
    final index = notes.indexWhere((item) => item.id == note.id);
    if (index == -1) {
      return null;
    }
    notes[index] = note;
    await _write(notes);
    bumpNotesRevision();
    return note;
  }

  @override
  Future<void> delete(String id) async {
    final notes = await _read();
    final index = notes.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    notes[index] = notes[index].copyWith(deletedAt: DateTime.now());
    await _write(notes);
    bumpNotesRevision();
  }

  @override
  Future<List<Note>> loadTrash() async {
    final notes = await _read();
    final trashed = [
      for (final note in notes)
        if (note.isDeleted) note,
    ]..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return List<Note>.unmodifiable(trashed);
  }

  @override
  Future<void> restore(String id) async {
    final notes = await _read();
    final index = notes.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    notes[index] = notes[index].copyWith(deletedAt: null);
    await _write(notes);
    bumpNotesRevision();
  }

  @override
  Future<void> purge(String id) async {
    final notes = await _read();
    notes.removeWhere((item) => item.id == id);
    await _write(notes);
    bumpNotesRevision();
  }

  @override
  Future<void> purgeAll() async {
    final notes = await _read();
    notes.removeWhere((item) => item.isDeleted);
    await _write(notes);
    bumpNotesRevision();
  }

  @override
  Future<void> reassignCategory(String from, String to) async {
    final notes = await _read();
    for (var i = 0; i < notes.length; i++) {
      if (notes[i].category == from) {
        notes[i] = notes[i].copyWith(category: to);
      }
    }
    await _write(notes);
    bumpNotesRevision();
  }

  @override
  Future<void> deleteByCategory(String category) async {
    final notes = await _read();
    final now = DateTime.now();
    for (var i = 0; i < notes.length; i++) {
      if (notes[i].category == category) {
        notes[i] = notes[i].copyWith(deletedAt: now);
      }
    }
    await _write(notes);
    bumpNotesRevision();
  }

  Future<List<Note>> _read() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return [];
      }
      // 数据来自未来版本时宁可当空，也不要用旧结构去猜
      final version = decoded['version'];
      if (version is int && version > _schemaVersion) {
        debugPrint('[NoteRepository] 忽略更高版本的数据: $version');
        return [];
      }
      final items = decoded['notes'];
      if (items is! List) {
        return [];
      }
      return [
        for (final item in items)
          if (item is Map) Note.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on FormatException catch (error) {
      // 存档损坏不应让 App 起不来：丢弃并继续，下次写入即覆盖
      debugPrint('[NoteRepository] 数据解析失败，已重置: $error');
      return [];
    }
  }

  Future<void> _write(List<Note> notes) async {
    final prefs = await _prefs;
    final payload = jsonEncode({
      'version': _schemaVersion,
      'notes': [for (final note in notes) note.toJson()],
    });
    await prefs.setString(_storageKey, payload);
  }

  static void _sort(List<Note> notes) {
    notes.sort((a, b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }
}
