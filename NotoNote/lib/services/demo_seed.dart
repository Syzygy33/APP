import 'package:flutter/foundation.dart';

import 'prefs_note_repository.dart';
import 'todo_repository.dart';

/// 演示数据：只在**编译时**加了 `--dart-define=SEED_DEMO=true` 才生效，
/// 且只在仓储为空时写入。正式构建不带这个开关，永远是一张白纸。
///
/// 存在的理由：预览环境（浏览器面板）每次都是新的存储，不种数据就只能看到
/// 空状态，无法判断列表、分类计数、完成态这些是否正常。
const bool _seedEnabled = bool.fromEnvironment('SEED_DEMO');

Future<void> seedDemoIfEmpty() async {
  if (!_seedEnabled) {
    return;
  }
  // 种数据是可选的：任何异常都不能挡住 runApp，否则就是一片白屏
  try {
    await _seedNotes();
  } catch (error, stack) {
    debugPrint('演示笔记写入失败：$error\n$stack');
  }
  try {
    await _seedTodos();
  } catch (error, stack) {
    debugPrint('演示待办写入失败：$error\n$stack');
  }
}

Future<void> _seedNotes() async {
  final repository = PrefsNoteRepository();
  final existing = await repository.load();
  if (existing.isNotEmpty) {
    return;
  }

  final now = DateTime.now();
  final seeds =
      <
        ({
          String title,
          String body,
          String category,
          bool pinned,
          bool favorite,
          Duration age,
        })
      >[
        (
          title: 'prism_ui 的四级表面',
          body:
              'page → card → block → inset。卡片里再放卡片要升一级表面色，而不是加阴影。'
              '这是这套设计扁平但有层次的关键。',
          category: '设计',
          pinned: true,
          favorite: true,
          age: const Duration(minutes: 12),
        ),
        (
          title: '顶栏为什么必须浮动',
          body:
              'PrismScaffold 把「状态栏 + 72」塞进 body 的 MediaQuery 顶部内边距，'
              '页面不消费它，第一个控件就会被标题栏盖住。弹层里来源还不一样，要用 BarClearance。',
          category: '开发',
          pinned: false,
          favorite: false,
          age: const Duration(hours: 3),
        ),
        (
          title: '超椭圆与普通圆角的差别',
          body:
              '圆角用 RoundedSuperellipseBorder，曲率连续，边缘更「鼓」。'
              '小圆角看不太出来，但光标尺量能看出差别。',
          category: '设计',
          pinned: false,
          favorite: true,
          age: const Duration(hours: 26),
        ),
        (
          title: '今天的采购清单',
          body: '牛奶、鸡蛋、面包、咖啡豆。顺路去取快递。',
          category: '生活',
          pinned: false,
          favorite: false,
          age: const Duration(days: 2),
        ),
      ];

  for (final seed in seeds) {
    final created = await repository.create(
      title: seed.title,
      body: seed.body,
      category: seed.category,
    );
    // create 不接置顶/收藏（新建笔记本来就不该带这些），种数据时补一次
    await repository.update(
      created.copyWith(
        pinned: seed.pinned,
        favorite: seed.favorite,
        updatedAt: now.subtract(seed.age),
      ),
    );
  }
}

Future<void> _seedTodos() async {
  final repository = PrefsTodoRepository();
  final existing = await repository.load();
  if (existing.isNotEmpty) {
    return;
  }

  const seeds = [
    (
      text: '补完 Android SDK 安装',
      detail: 'platform-tools + build-tools + API 36',
      done: false,
    ),
    (text: '真机跑一次冒烟测试', detail: '重点看变高列表的滚动', done: false),
    (text: '确定品牌种子色', detail: '当前沿用 #007AFF', done: true),
  ];

  for (final seed in seeds) {
    final created = await repository.create(
      text: seed.text,
      detail: seed.detail,
    );
    if (seed.done) {
      await repository.setDone(created.id, true);
    }
  }
}
