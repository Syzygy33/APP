import 'package:flutter/foundation.dart';

/// 待办数据变更的信号。
///
/// 与笔记的 `notesRevision` 同一个思路（见 `notes_revision.dart`）：
/// 页签被 `IndexedStack` 保活，不会因为切页签而重新加载，
/// 所以写操作完成后必须广播一次，页面监听到再重载。
///
/// 单独一个信号而不是复用笔记那个：两张表互不相干，
/// 笔记改动不该触发待办页重建。
final ValueNotifier<int> todoRevision = ValueNotifier<int>(0);

/// 由仓储的写操作调用，不要从页面里调。
void bumpTodoRevision() => todoRevision.value++;
