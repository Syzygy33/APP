import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../models/todo.dart';
import 'id.dart';
import 'reminder_service.dart';
import 'todo_revision.dart';

/// 待办读写接口。
///
/// 和笔记分开：两张表、两个仓储、两个变更信号。
/// 合在一起会让"笔记变了要重载待办"这种无意义的重建发生。
abstract interface class TodoRepository {
  Future<List<Todo>> load();

  Future<Todo> create({
    required String text,
    String detail = '',
    String category = NoteCategory.fallbackName,
    DateTime? remindAt,
  });

  Future<void> setDone(String id, bool done);

  /// 覆盖保存一条待办（编辑文字/备注用）。
  Future<Todo?> update(Todo todo);

  /// 软删除：进入「最近删除」。
  Future<void> delete(String id);

  Future<List<Todo>> loadTrash();

  Future<void> restore(String id);

  Future<void> purge(String id);

  Future<void> purgeAll();

  /// 把 [from] 分类下的待办改到 [to] 分类。
  Future<void> reassignCategory(String from, String to);

  /// 软删除 [category] 分类下的所有待办。
  Future<void> deleteByCategory(String category);
}

/// 本地实现：整表 JSON 存进 SharedPreferences。
///
/// 存法与笔记一致（带版本号、损坏不崩、整体重写），
/// 理由见 `docs/integration-spec.md` 的「存储」一节。
class PrefsTodoRepository implements TodoRepository {
  static const _key = 'noto_note.todos.v1';
  static const _version = 1;

  SharedPreferences? _store;

  Future<SharedPreferences> _prefs() async {
    final existing = _store;
    if (existing != null) {
      return existing;
    }
    final created = await SharedPreferences.getInstance();
    _store = created;
    return created;
  }

  @override
  Future<List<Todo>> load() async {
    final todos = await _read();
    todos.removeWhere((todo) => todo.isDeleted);
    return List<Todo>.unmodifiable(todos);
  }

  @override
  Future<Todo> create({
    required String text,
    String detail = '',
    String category = NoteCategory.fallbackName,
    DateTime? remindAt,
  }) async {
    final now = DateTime.now();
    final todos = await _read();
    final todo = Todo(
      id: newId('todo'),
      text: text.trim(),
      detail: detail.trim(),
      createdAt: now,
      updatedAt: now,
      category: category,
      remindAt: remindAt,
    );
    todos.add(todo);
    await _write(todos);
    bumpTodoRevision();
    if (remindAt != null) {
      unawaited(ReminderService.sync(todo));
    }
    return todo;
  }

  @override
  Future<void> setDone(String id, bool done) async {
    final todos = await _read();
    final index = todos.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    todos[index] = todos[index].copyWith(
      done: done,
      updatedAt: DateTime.now(),
    );
    await _write(todos);
    bumpTodoRevision();
    // 完成就不再提醒，改回未完成时把闹钟补上。
    unawaited(ReminderService.sync(todos[index]));
  }

  @override
  Future<Todo?> update(Todo todo) async {
    final todos = await _read();
    final index = todos.indexWhere((item) => item.id == todo.id);
    if (index == -1) {
      return null;
    }
    todos[index] = todo;
    await _write(todos);
    bumpTodoRevision();
    // 提醒时间是待办字段的一部分，任何一次写入都要重排通知。
    unawaited(ReminderService.sync(todo));
    return todo;
  }

  @override
  Future<void> delete(String id) async {
    final todos = await _read();
    final index = todos.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    todos[index] = todos[index].copyWith(deletedAt: DateTime.now());
    await _write(todos);
    bumpTodoRevision();
    unawaited(ReminderService.cancel(id));
  }

  @override
  Future<List<Todo>> loadTrash() async {
    final todos = await _read();
    final trashed = [
      for (final todo in todos)
        if (todo.isDeleted) todo,
    ]..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return List<Todo>.unmodifiable(trashed);
  }

  @override
  Future<void> restore(String id) async {
    final todos = await _read();
    final index = todos.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    todos[index] = todos[index].copyWith(deletedAt: null);
    await _write(todos);
    bumpTodoRevision();
    // 恢复时如果提醒时间还在未来，把闹钟重新排上。
    unawaited(ReminderService.sync(todos[index]));
  }

  @override
  Future<void> purge(String id) async {
    final todos = await _read();
    todos.removeWhere((item) => item.id == id);
    await _write(todos);
    bumpTodoRevision();
    unawaited(ReminderService.cancel(id));
  }

  @override
  Future<void> purgeAll() async {
    final todos = await _read();
    final removed = [
      for (final todo in todos)
        if (todo.isDeleted) todo.id,
    ];
    todos.removeWhere((item) => item.isDeleted);
    await _write(todos);
    bumpTodoRevision();
    for (final id in removed) {
      unawaited(ReminderService.cancel(id));
    }
  }

  @override
  Future<void> reassignCategory(String from, String to) async {
    final todos = await _read();
    for (var i = 0; i < todos.length; i++) {
      if (todos[i].category == from) {
        todos[i] = todos[i].copyWith(category: to);
      }
    }
    await _write(todos);
    bumpTodoRevision();
  }

  @override
  Future<void> deleteByCategory(String category) async {
    final todos = await _read();
    final now = DateTime.now();
    for (var i = 0; i < todos.length; i++) {
      if (todos[i].category == category) {
        todos[i] = todos[i].copyWith(deletedAt: now);
        unawaited(ReminderService.cancel(todos[i].id));
      }
    }
    await _write(todos);
    bumpTodoRevision();
  }

  Future<List<Todo>> _read() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return <Todo>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <Todo>[];
      }
      // 版本比我们高说明是新版写的，按空处理，别用旧结构去猜
      final version = decoded['version'] as int? ?? _version;
      if (version > _version) {
        return <Todo>[];
      }
      final list = decoded['todos'];
      if (list is! List) {
        return <Todo>[];
      }
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) Todo.fromJson(item),
      ];
    } on FormatException {
      // 存档损坏：当成空的，下次写入自动覆盖
      return <Todo>[];
    }
  }

  Future<void> _write(List<Todo> todos) async {
    final prefs = await _prefs();
    await prefs.setString(
      _key,
      jsonEncode({
        'version': _version,
        'todos': [for (final todo in todos) todo.toJson()],
      }),
    );
  }
}
