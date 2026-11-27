import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Color;

/// 笔记分类。
///
/// 类名不叫 `Category`：`package:flutter/foundation.dart` 里已有一个同名的
/// `Category` 注解，两个一起 import 会直接报 ambiguous_import。
///
/// 第一版是**固定预置**的：分类不落库，只作为 `Note.category` 的字符串存在，
/// 颜色写在代码里。这样笔记里只需要存一个名字，存档不会因为分类改名而失效。
///
/// 之后要做"用户自定义分类"，把 [presets] 换成一个仓储即可，
/// 笔记侧的 `category` 字段不用动。
@immutable
class NoteCategory {
  const NoteCategory({
    required this.name,
    required this.color,
    this.pinned = false,
    this.icon = '',
  });

  final String name;

  /// 分类卡片上色块和图标的颜色。
  final Color color;

  /// 卡片图标的 key，见 `CategoryIcons`。空串表示默认的「方块」图标，
  /// 老存档读出来就是空串，不用迁移。
  final String icon;

  /// 置顶的分类排在网格最前。
  final bool pinned;

  /// 没有指定分类时的归属。必须存在于 [presets] 中。
  static const fallbackName = '无分类';

  /// 旧版本把兜底分类叫「未分类」，存档里可能仍是这个名字。
  /// 读取时统一归一到 [fallbackName]，避免老数据被当成有效分类显示出来。
  static const legacyFallbackName = '未分类';

  static const presets = [
    NoteCategory(name: '设计', color: Color(0xFF0A7CFF)),
    NoteCategory(name: '开发', color: Color(0xFF34C759)),
    NoteCategory(name: '生活', color: Color(0xFFFF9F0A)),
    NoteCategory(name: fallbackName, color: Color(0xFF8E8E93)),
  ];

  /// 可新建分类后，`presets` 不再是全集：这个列表是「预置 + 用户自建」，
  /// 由 `CategoryRepository.load()` 在启动时填充。
  ///
  /// 用可变静态而不是 InheritedWidget：`NoteCategory.of` 在卡片里被频繁调用，
  /// 走一层依赖查找不划算；页面靠 `categoryRevision` 触发重建即可。
  static List<NoteCategory> all = List<NoteCategory>.of(presets);

  /// 重置成预置集合，测试和「数据清空」时用。
  static void resetAll() => all = List<NoteCategory>.of(presets);

  /// 按名字找分类；找不到（已删除或旧存档里的名字）一律归到未分类。
  static NoteCategory of(String? name) {
    // 旧存档里的「未分类」视作兜底，返回现在的「无分类」。
    if (name == legacyFallbackName) {
      return presets.last;
    }
    for (final category in all) {
      if (category.name == name) {
        return category;
      }
    }
    return presets.last;
  }

  /// 一条笔记 / 待办是否属于兜底分类（无分类）。兼容旧存档名字。
  static bool isFallback(String? name) =>
      name == null ||
      name.isEmpty ||
      name == fallbackName ||
      name == legacyFallbackName;

  /// 名字是否已被占用（新建分类时查重，忽略大小写与首尾空格）。
  static bool exists(String name) {
    final target = name.trim();
    return all.any((category) => category.name == target);
  }

  NoteCategory copyWith({
    String? name,
    Color? color,
    bool? pinned,
    String? icon,
  }) => NoteCategory(
    name: name ?? this.name,
    color: color ?? this.color,
    pinned: pinned ?? this.pinned,
    icon: icon ?? this.icon,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'color': color.toARGB32(),
    'pinned': pinned,
    if (icon.isNotEmpty) 'icon': icon,
  };

  /// 解析失败返回 null，让调用方跳过这一条，而不是整份存档作废。
  static NoteCategory? tryParse(Map<String, dynamic> json) {
    final name = json['name'];
    final color = json['color'];
    if (name is! String || name.trim().isEmpty || color is! int) {
      return null;
    }
    return NoteCategory(
      name: name.trim(),
      color: Color(color),
      pinned: json['pinned'] as bool? ?? false,
      // 旧存档没有图标字段，空串即默认图标
      icon: json['icon'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NoteCategory &&
      other.name == name &&
      other.color == color &&
      other.pinned == pinned &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(name, color, pinned, icon);
}
