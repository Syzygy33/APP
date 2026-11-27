import 'dart:math';

final _random = Random();

/// 生成一个可靠的唯一 id。
///
/// **不要只用 `DateTime.now().microsecondsSinceEpoch`。**
/// Web 上 `DateTime.now()` 只有毫秒精度，`microsecondsSinceEpoch` 实际是
/// 毫秒值乘 1000。同一毫秒内连续创建（批量导入、演示数据、连点新建）
/// 会生成完全相同的 id，后果是：
/// - `create` 之后 `update`/`delete` 按 id 查找会命中列表里的**第一条**，
///   于是改错对象或删错对象；
/// - 列表里出现"同一份数据被反复覆盖"的假象。
///
/// 所以拼一个随机后缀。它不是 UUID，但对本地单机数据足够。
String newId(String prefix) {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  // 上界取 2^30：Web 上 nextInt 对 2^32 会抛 RangeError
  final noise = _random.nextInt(1 << 30).toRadixString(36);
  return '$prefix-$stamp-$noise';
}
