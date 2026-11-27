import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'category_revision.dart';
import 'notes_revision.dart';
import 'todo_revision.dart';

/// 恢复时怎么处理本机已有的数据。
enum RestoreStrategy {
  /// 用备份整体替换。
  overwrite('覆盖'),

  /// 备份优先，但本机多出来的笔记 / 待办 / 分类保留（按 id / 分类名比对）。
  merge('合并');

  const RestoreStrategy(this.label);

  final String label;

  static RestoreStrategy parse(String? raw) => values.firstWhere(
    (value) => value.name == raw,
    orElse: () => RestoreStrategy.overwrite,
  );
}

/// 备份失败时抛这个，`message` 直接拿去显示给用户。
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 恢复 / 备份结果的摘要，用来拼提示文案。
class BackupSummary {
  const BackupSummary({
    required this.savedAt,
    required this.notes,
    required this.todos,
    required this.categories,
    required this.bytes,
  });

  final DateTime? savedAt;
  final int notes;
  final int todos;
  final int categories;
  final int bytes;

  String get sizeLabel {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String get contentLabel => '$notes 条笔记 · $todos 条待办 · $categories 个分类';
}

/// 备份快照：把 `noto_note.` 前缀下的全部键打包成一份 JSON。
///
/// 不逐个列键，是因为以后加新数据（排序名册、分类隐藏名单…）不用回来改这里；
/// 反过来，也**不备份**备份自己的状态：
/// - `noto_note.backup.*`：本地备份的内容与时间戳
/// - `noto_note.webdav.*`：WebDAV 的地址与账号
/// 否则「从备份恢复」会把上次备份时间一起回滚，甚至把备份套娃写进自己。
class BackupService {
  const BackupService();

  static const snapshotVersion = 1;
  static const appTag = 'notonote';

  static const _prefix = 'noto_note.';
  static const _excludedPrefixes = ['noto_note.backup.', 'noto_note.webdav.'];

  /// 打包当前全部数据。返回的是可以直接写进文件的 JSON 字符串。
  Future<String> capture() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) {
        continue;
      }
      if (_excludedPrefixes.any(key.startsWith)) {
        continue;
      }
      final value = prefs.get(key);
      // 只搬 JSON 表达得出的类型；SharedPreferences 也就这几种。
      if (value is String) {
        data[key] = {'s': value};
      } else if (value is List<String>) {
        data[key] = {'l': value};
      } else if (value is int) {
        data[key] = {'i': value};
      } else if (value is bool) {
        data[key] = {'b': value};
      } else if (value is double) {
        data[key] = {'d': value};
      }
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': appTag,
      'version': snapshotVersion,
      'savedAt': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  /// 解析快照里的统计信息，用于在界面上显示「上次备份了什么」。
  /// 快照损坏时返回 null，而不是抛异常——UI 只需要展示。
  BackupSummary? describe(String raw) {
    final decoded = _decode(raw);
    if (decoded == null) {
      return null;
    }
    final data = decoded['data'] as Map<String, dynamic>;
    return BackupSummary(
      savedAt: DateTime.tryParse(decoded['savedAt'] as String? ?? ''),
      notes: _countOf(data['noto_note.notes.v1']),
      todos: _countOf(data['noto_note.todos.v1']),
      categories: _countOf(data['noto_note.categories.v1']),
      bytes: utf8.encode(raw).length,
    );
  }

  /// 用快照写回本机，并通知各页重载。返回写回的键数量。
  ///
  /// [strategy] 为 [RestoreStrategy.merge] 时，三张表按 id / 分类名合并
  /// （备份优先，本机多出来的保留），排序名册取并集；其余键仍然照备份写。
  Future<int> restore(
    String raw, {
    RestoreStrategy strategy = RestoreStrategy.overwrite,
  }) async {
    final decoded = _decode(raw);
    if (decoded == null) {
      throw const BackupException('备份内容不是有效的 NotoNote 快照');
    }
    final version = decoded['version'];
    if (version is int && version > snapshotVersion) {
      throw const BackupException('备份来自更新的版本，当前版本读不了');
    }
    final data = decoded['data'];
    if (data is! Map) {
      throw const BackupException('备份内容缺少数据段');
    }
    final prefs = await SharedPreferences.getInstance();
    var written = 0;
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! Map) {
        continue;
      }
      final incoming = Map<String, dynamic>.from(value);
      final payload = strategy == RestoreStrategy.merge
          ? _mergeWithLocal(prefs, key, incoming)
          : incoming;
      final ok = await _writeValue(prefs, key, payload);
      if (ok) {
        written++;
      }
    }
    // 各页靠 revision 重载，恢复完必须广播一次。
    bumpNotesRevision();
    bumpTodoRevision();
    bumpCategoryRevision();
    return written;
  }

  /// 三张「表」的键 → 里面的列表名。
  static const _tables = {
    'noto_note.notes.v1': 'notes',
    'noto_note.todos.v1': 'todos',
    'noto_note.categories.v1': 'categories',
  };

  /// 分类按名字当主键，笔记和待办按 id。
  static const _idFields = {'notes': 'id', 'todos': 'id', 'categories': 'name'};

  /// 把备份里的一条和本机现有的合起来。任何一步认不出来就退回备份原值。
  Map<String, dynamic> _mergeWithLocal(
    SharedPreferences prefs,
    String key,
    Map<String, dynamic> incoming,
  ) {
    final local = prefs.get(key);
    final incomingText = incoming['s'];
    if (local is! String || incomingText is! String) {
      // 备份里这一项不是字符串（理论上不会发生），或者本机本来没有这项。
      return incoming;
    }
    final table = _tables[key];
    if (table != null) {
      final merged = _mergeTable(local, incomingText, table);
      return merged == null ? incoming : {'s': merged};
    }
    if (key.startsWith('noto_note.order.')) {
      final merged = _mergeOrder(local, incomingText);
      return merged == null ? incoming : {'s': merged};
    }
    return incoming;
  }

  /// 表合并：备份里的条目在前且优先，本机独有的接在后面。
  String? _mergeTable(String localJson, String incomingJson, String table) {
    final localList = _listOf(localJson, table);
    final incomingList = _listOf(incomingJson, table);
    if (localList == null || incomingList == null) {
      return null;
    }
    final idField = _idFields[table]!;
    final seen = <String>{};
    final result = <dynamic>[];
    for (final item in incomingList) {
      final id = _idOf(item, idField);
      if (id != null) {
        seen.add(id);
      }
      result.add(item);
    }
    for (final item in localList) {
      final id = _idOf(item, idField);
      if (id == null || seen.add(id)) {
        result.add(item);
      }
    }
    final version = _mapOf(incomingJson)?['version'] ?? snapshotVersion;
    return jsonEncode({'version': version, table: result});
  }

  /// 排序名册合并：备份顺序在前，本机多出来的接在后面。
  String? _mergeOrder(String localJson, String incomingJson) {
    final local = _stringList(localJson);
    final incoming = _stringList(incomingJson);
    if (local == null || incoming == null) {
      return null;
    }
    final seen = {...incoming};
    return jsonEncode([...incoming, ...local.where(seen.add)]);
  }

  static List<dynamic>? _listOf(String json, String table) {
    final list = _mapOf(json)?[table];
    return list is List ? list : null;
  }

  static Map<String, dynamic>? _mapOf(String json) {
    try {
      final decoded = jsonDecode(json);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  static List<String>? _stringList(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) {
        return null;
      }
      return [for (final item in decoded) '$item'];
    } on FormatException {
      return null;
    }
  }

  static String? _idOf(Object? item, String field) {
    if (item is! Map) {
      return null;
    }
    final id = item[field];
    return id is String && id.isNotEmpty ? id : null;
  }

  Future<bool> _writeValue(
    SharedPreferences prefs,
    String key,
    Map<String, dynamic> value,
  ) async {
    if (value['s'] case final String text) {
      return prefs.setString(key, text);
    }
    if (value['l'] case final List<dynamic> list) {
      return prefs.setStringList(key, [for (final item in list) '$item']);
    }
    if (value['i'] case final int number) {
      return prefs.setInt(key, number);
    }
    if (value['b'] case final bool flag) {
      return prefs.setBool(key, flag);
    }
    if (value['d'] case final num number) {
      return prefs.setDouble(key, number.toDouble());
    }
    return false;
  }

  Map<String, dynamic>? _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);
      if (map['app'] != appTag || map['data'] is! Map) {
        return null;
      }
      return map;
    } on FormatException {
      return null;
    }
  }

  /// 数一数快照里某张表有几条（`{"version":1,"notes":[...]}` 这种结构）。
  static int _countOf(Object? entry) {
    if (entry is! Map) {
      return 0;
    }
    final raw = entry['s'];
    if (raw is! String) {
      return 0;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return 0;
      }
      for (final key in ['notes', 'todos', 'categories']) {
        final list = decoded[key];
        if (list is List) {
          return list.length;
        }
      }
    } on FormatException {
      return 0;
    }
    return 0;
  }
}

/// 本地备份：把快照写成**用户自己选位置**的 `.json` 文件。
///
/// 和 WebDAV 完全独立——不互相同步、不互相覆盖，各自记自己的时间戳。
/// 快照本身不放在 App 内部：位置由用户在系统保存框里决定
/// （Android 走 SAF，不需要存储权限；Web 上就是浏览器下载）。
class LocalBackupFiles {
  const LocalBackupFiles();

  /// 只存「上次导出了什么」，不存内容——内容在用户选的文件夹里。
  static const _recordKey = 'noto_note.backup.local.v1';
  static const fileExtension = 'json';

  /// 默认文件名：`notonote-20261125-1620.json`。
  static String suggestedFileName([DateTime? now]) {
    final time = (now ?? DateTime.now()).toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'notonote-${time.year}${two(time.month)}${two(time.day)}'
        '-${two(time.hour)}${two(time.minute)}.$fileExtension';
  }

  /// 上一次导出：文件名 + 时间；没导出过返回 null。
  Future<({String name, DateTime savedAt})?> lastRecord() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordKey);
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return (
        name: decoded['name'] as String? ?? '',
        savedAt: DateTime.tryParse(decoded['savedAt'] as String? ?? '') ??
            DateTime.now(),
      );
    } on FormatException {
      return null;
    }
  }

  /// 弹系统保存框让用户选位置并写入。
  ///
  /// 用户取消返回 null。Web 上没有「选位置」这一步（浏览器直接下载），
  /// `saveFile` 也会返回 null，所以 Web 端一律当成功。
  Future<({String name, DateTime savedAt})?> export(String payload) async {
    final now = DateTime.now();
    final fallback = suggestedFileName(now);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '选择备份保存位置',
      fileName: fallback,
      type: FileType.custom,
      allowedExtensions: [fileExtension],
      bytes: Uint8List.fromList(utf8.encode(payload)),
    );
    if (path == null && !kIsWeb) {
      return null;
    }
    final record = (name: _nameFrom(path, fallback), savedAt: now);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recordKey,
      jsonEncode({'name': record.name, 'savedAt': now.toIso8601String()}),
    );
    return record;
  }

  /// 弹文件选择器读一份备份；用户取消返回 null。
  Future<String?> pickForRestore() async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择备份文件',
        type: FileType.custom,
        allowedExtensions: [fileExtension],
        withData: true,
      );
    } on PlatformException catch (error) {
      throw BackupException('打不开文件选择器：${error.message ?? error.code}');
    }
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.first;
    // Web 上 withData 直接给字节；手机上偶尔只有路径，用 xFile 兜一下。
    final bytes = file.bytes ?? await file.xFile.readAsBytes();
    if (bytes.isEmpty) {
      throw const BackupException('这个文件是空的');
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// 保存框返回的路径不一定带文件名（Android 可能是 content URI），
  /// 取不到就退回我们自己提议的名字。
  String _nameFrom(String? path, String fallback) {
    if (path == null || path.isEmpty) {
      return fallback;
    }
    final segments = (Uri.tryParse(path)?.path ?? path)
        .split('/')
        .where((segment) => segment.isNotEmpty);
    if (segments.isEmpty) {
      return fallback;
    }
    final last = segments.last;
    return last.toLowerCase().endsWith('.$fileExtension') ? last : fallback;
  }
}

/// 便于日志里看清是哪条链路出的错。
@visibleForTesting
String describeError(Object error) =>
    error is BackupException ? error.message : '$error';
