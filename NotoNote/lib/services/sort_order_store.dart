import 'package:shared_preferences/shared_preferences.dart';

/// 手动排序的名册：按展示顺序存一条 id 列表。
///
/// 每个页面（或分组）各存一份，页面进入「自定义排序」时据此排列；
/// 名册里没有的 id（新建内容）排在末尾，仍按更新时间兜底。
class SortOrderStore {
  const SortOrderStore();

  /// 名册键：一个页面 / 分组一个。
  static const notesKey = 'noto_note.order.notes.v1';
  static const todosKey = 'noto_note.order.todos.v1';
  static const favoriteNotesKey = 'noto_note.order.favorite_notes.v1';
  static const favoriteTodosKey = 'noto_note.order.favorite_todos.v1';

  /// 各页当前选的排序字段（`updated` / `created` / `manual`）。
  static const notesSortKey = 'noto_note.sort.notes.v1';
  static const todosSortKey = 'noto_note.sort.todos.v1';

  Future<List<String>> load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? const [];
  }

  Future<void> save(String key, List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, ids);
  }

  /// 读一个单值设置（例如本页当前选的排序字段）。
  Future<String?> loadValue(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> saveValue(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// 把 [visible] 的新顺序合并回全局名册 [existing]。
  ///
  /// 只调整可见项的相对位置：筛选/搜索时拖动，其他项留在原位不动。
  /// 名册里还没有的 id 按 [visible] 的顺序补到末尾。
  static List<String> merge(List<String> existing, List<String> visible) {
    final inVisible = visible.toSet();
    final rest = [
      for (final id in existing)
        if (!inVisible.contains(id)) id,
    ];
    final merged = <String>[];
    var vi = 0;
    var ri = 0;
    for (final id in existing) {
      if (inVisible.contains(id)) {
        if (vi < visible.length) {
          merged.add(visible[vi++]);
        }
      } else if (ri < rest.length) {
        merged.add(rest[ri++]);
      }
    }
    while (vi < visible.length) {
      merged.add(visible[vi++]);
    }
    // 去重，保序。
    final seen = <String>{};
    return [
      for (final id in merged)
        if (seen.add(id)) id,
    ];
  }

  /// id → 名册里的下标；不在名册里的返回 null。
  static Map<String, int> indexOf(List<String> order) {
    return {for (var i = 0; i < order.length; i++) order[i]: i};
  }
}
