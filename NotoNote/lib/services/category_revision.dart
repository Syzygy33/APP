import 'package:flutter/foundation.dart';

/// 分类集合变动信号。
///
/// 分类会同时影响分类页的网格、笔记/待办卡片上的标签颜色，以及编辑页的选择器。
/// 新建分类后发一次信号，所有正在展示的页面各自重载即可，不需要页面之间互相持有引用。
final categoryRevision = ValueNotifier<int>(0);

void bumpCategoryRevision() => categoryRevision.value++;
