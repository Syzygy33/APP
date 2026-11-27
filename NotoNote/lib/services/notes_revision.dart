import 'package:flutter/foundation.dart';

/// 笔记数据变更的信号。
///
/// 为什么需要它：`HomeShell` 用 `IndexedStack` 保住各页状态，各页只在自己的
/// `initState` 里加载一次。笔记页写了数据、收藏页并不会因此重新读——
/// 它一直活着，也就不会重跑 `initState`。表现是：在详情页点了收藏，
/// 切到收藏页还是空的。
///
/// 各页各自持有仓储实例、互不引用，所以只能靠一个全局信号把"数据变了"
/// 传出去。任何写操作（新建 / 修改 / 删除）完成后自增一次，页面监听到就重载。
final ValueNotifier<int> notesRevision = ValueNotifier<int>(0);

/// 由仓储的写操作调用，不要从页面里调。
void bumpNotesRevision() => notesRevision.value++;
