import 'package:drift/drift.dart';

/// 文件夹（分类）表
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()(); // 毫秒时间戳
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// 笔记表
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  IntColumn get folderId => integer().nullable().references(Folders, #id)();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();

  /// 内容类型：0 笔记 / 1 便签 / 2 待办（见 [NoteKind]）。
  /// v3 起用本列统一表达类型，取代 v2 的 isSticky 布尔位。
  IntColumn get kind => integer().withDefault(const Constant(0))();

  /// 待办是否已完成（其他类型恒为 false）
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  /// v2 遗留列：仅保留以兼容旧库结构，v3 起不再读写，数据已在迁移时
  /// 搬进 [kind]。新增逻辑一律使用 [kind]，不要再用本列判断类型。
  BoolColumn get isSticky => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

/// 图片附件：只记录文件名与归属，实际文件放在应用私有 `images/` 目录。
/// 不存绝对路径——应用目录在重装/换机后会变，文件名才是稳定标识。
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId => integer().references(Notes, #id)();
  TextColumn get fileName => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
}
