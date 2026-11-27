import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import 'category_revision.dart';

/// 分类读写接口。
///
/// 只持久化**用户自建**的分类；预置那几个写在代码里，不进存档。
/// 这样以后调整预置分类的名字/颜色，不会被旧存档覆盖。
///
/// 删除与置顶是「覆盖」语义，记录在独立的键里：预置分类也能被删/置顶，
/// 但代码里的 `presets` 常量不改，随时能恢复默认。
abstract interface class CategoryRepository {
  /// 读出全部分类（预置 + 自建，已应用删除/置顶，并排好序），同步到 [NoteCategory.all]。
  Future<List<NoteCategory>> load();

  /// 新建一个分类。重名时返回 null，由调用方提示。
  /// [icon] 是 `CategoryIcons` 里的 key，空串表示默认图标。
  Future<NoteCategory?> add({
    required String name,
    required Color color,
    String icon = '',
  });

  /// 删除分类（预置也可删：记入隐藏名单）。未分类不可删——它是内容转归的落点。
  Future<void> delete(String name);

  /// 置顶/取消置顶。
  Future<void> setPinned(String name, {required bool pinned});

  /// 保存自定义顺序（只影响同组内的排列）。置顶组始终排在非置顶组之前。
  Future<void> reorder(List<String> orderedNames);
}

/// 本地实现：一份 JSON 存进 SharedPreferences。
class PrefsCategoryRepository implements CategoryRepository {
  PrefsCategoryRepository();

  static const _storageKey = 'noto_note.categories.v1';
  static const _schemaVersion = 1;

  /// 被隐藏的预置分类名（预置写在代码里，只能靠名单屏蔽）。
  static const _deletedKey = 'noto_note.categories.deleted.v1';

  /// 置顶的分类名（预置与自建共用一份）。
  static const _pinnedKey = 'noto_note.categories.pinned.v1';

  /// 用户拖拽后的自定义顺序（全部分类名，置顶组在前）。
  /// 没有这个键时按「预置 + 自建」的默认顺序。
  static const _orderKey = 'noto_note.categories.order.v1';

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
  Future<List<NoteCategory>> load() async {
    final customs = await _read();
    final deleted = await _readNames(_deletedKey);
    final pinned = await _readNames(_pinnedKey);
    final order = await _readOrder();

    // 删掉预置分类后又建了同名分类时，`customs` 里那份带用户选的颜色/图标，
    // 合并时优先用它，否则预置项会把图标悄悄吃掉。
    final customByName = {for (final category in customs) category.name: category};
    final merged = <NoteCategory>[
      for (final category in NoteCategory.presets)
        if (!deleted.contains(category.name))
          (customByName[category.name] ?? category).copyWith(
            name: category.name,
            pinned: pinned.contains(category.name),
          ),
    ];
    for (final category in customs) {
      if (deleted.contains(category.name) ||
          merged.any((item) => item.name == category.name)) {
        continue;
      }
      merged.add(category.copyWith(pinned: pinned.contains(category.name)));
    }

    // 组内按用户拖拽的顺序排：名单里有的按名单序号，没出现的按原顺序垫后。
    int rankOf(NoteCategory item) {
      final index = order.indexOf(item.name);
      return index < 0 ? order.length + merged.indexOf(item) : index;
    }

    // 置顶在前，组内用自定义顺序。
    final pinnedList = merged.where((item) => item.pinned).toList()
      ..sort((a, b) => rankOf(a).compareTo(rankOf(b)));
    final normalList = merged.where((item) => !item.pinned).toList()
      ..sort((a, b) => rankOf(a).compareTo(rankOf(b)));

    final sorted = <NoteCategory>[...pinnedList, ...normalList];
    NoteCategory.all = sorted;
    return List<NoteCategory>.unmodifiable(sorted);
  }

  @override
  Future<void> reorder(List<String> orderedNames) async {
    final prefs = await _prefs;
    await prefs.setStringList(_orderKey, orderedNames);
    bumpCategoryRevision();
  }

  /// 顺序名单必须保序，单独用 List 读（`_readNames` 会转成 Set 丢顺序）。
  Future<List<String>> _readOrder() async {
    final prefs = await _prefs;
    return prefs.getStringList(_orderKey) ?? const [];
  }

  @override
  Future<NoteCategory?> add({
    required String name,
    required Color color,
    String icon = '',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || NoteCategory.exists(trimmed)) {
      return null;
    }
    if ((await _readNames(_deletedKey)).contains(trimmed)) {
      // 曾删掉同名预置分类：这里把它恢复出来，而不是新建一个冲突项
      final deleted = await _readNames(_deletedKey);
      deleted.remove(trimmed);
      await _writeNames(_deletedKey, deleted);
      final category = NoteCategory(name: trimmed, color: color, icon: icon);
      await _apply();
      bumpCategoryRevision();
      return category;
    }
    final category = NoteCategory(name: trimmed, color: color, icon: icon);
    final customs = (await _read())..add(category);
    await _write(customs);
    await _apply();
    bumpCategoryRevision();
    return category;
  }

  @override
  Future<void> delete(String name) async {
    // 未分类是内容转归的落点，不能删
    if (name == NoteCategory.fallbackName) {
      return;
    }
    final customs = await _read();
    final wasCustom = customs.any((item) => item.name == name);
    if (wasCustom) {
      customs.removeWhere((item) => item.name == name);
      await _write(customs);
    } else {
      final deleted = await _readNames(_deletedKey);
      deleted.add(name);
      await _writeNames(_deletedKey, deleted);
    }
    final pinned = await _readNames(_pinnedKey);
    pinned.remove(name);
    await _writeNames(_pinnedKey, pinned);
    await _apply();
    bumpCategoryRevision();
  }

  @override
  Future<void> setPinned(String name, {required bool pinned}) async {
    final names = await _readNames(_pinnedKey);
    if (pinned) {
      if (!names.contains(name)) {
        names.add(name);
      }
    } else {
      names.remove(name);
    }
    await _writeNames(_pinnedKey, names);
    await _apply();
    bumpCategoryRevision();
  }

  /// 把最新的 `NoteCategory.all` 刷出来，让页面下一帧就能读到。
  Future<void> _apply() => load();

  Future<Set<String>> _readNames(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getStringList(key);
    if (raw == null) {
      return <String>{};
    }
    return raw.toSet();
  }

  Future<void> _writeNames(String key, Set<String> names) async {
    final prefs = await _prefs;
    await prefs.setStringList(key, names.toList());
  }

  Future<List<NoteCategory>> _read() async {
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
        debugPrint('[CategoryRepository] 忽略更高版本的数据: $version');
        return [];
      }
      final items = decoded['categories'];
      if (items is! List) {
        return [];
      }
      final parsed = <NoteCategory>[];
      for (final item in items) {
        if (item is! Map) {
          continue;
        }
        final category = NoteCategory.tryParse(Map<String, dynamic>.from(item));
        if (category != null) {
          parsed.add(category);
        }
      }
      return parsed;
    } on FormatException catch (error) {
      // 存档损坏不应让 App 起不来：丢弃并继续，下次写入即覆盖
      debugPrint('[CategoryRepository] 数据解析失败，已重置: $error');
      return [];
    }
  }

  Future<void> _write(List<NoteCategory> categories) async {
    final prefs = await _prefs;
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'version': _schemaVersion,
        'categories': [for (final category in categories) category.toJson()],
      }),
    );
  }
}
