import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:noto_box/data/database/app_database.dart';
import 'package:noto_box/main.dart';
import 'package:noto_box/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 整机冒烟测试：真实装配 Riverpod + GoRouter + 内存数据库，
/// 验证应用可启动、四标签导航可切换、悬浮加号的显示规则、
/// 三点菜单可进入设置、数据能真实落库并渲染。
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: const NotoBoxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// 卸载组件树并冲刷 drift 关闭查询流时产生的零延迟定时器。
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 底部标签点击：底栏用 LoupeTabBar 的语义按钮，稳定命中且无 hitTest 警告
  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('启动后渲染首页，底栏四个标签齐全', (tester) async {
    await pumpApp(tester);

    expect(find.text('日行一记，灵感有光'), findsOneWidget);
    expect(find.text('笔记'), findsWidgets);
    expect(find.text('待办'), findsWidgets);
    expect(find.text('分类'), findsWidgets);
    expect(find.text('收藏'), findsWidgets);
    expect(find.text('筛选'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('切到待办页显示待办标题与副标题', (tester) async {
    await pumpApp(tester);
    await tapTab(tester, '待办');

    expect(find.text('列出要紧事，逐件清空'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('加号在笔记/待办/分类出现，切到收藏时收起', (tester) async {
    await pumpApp(tester);

    double fabOpacity() => tester
        .widget<AnimatedOpacity>(find.byKey(const ValueKey('create-fab')))
        .opacity;

    expect(fabOpacity(), 1);

    await tapTab(tester, '待办');
    expect(fabOpacity(), 1);

    // 分类页：加号用于新建分类，保持显示
    await tapTab(tester, '分类');
    expect(fabOpacity(), 1);
    expect(find.byIcon(Icons.create_new_folder_outlined), findsNothing);

    // 收藏页没有「新建」语义，加号收起
    await tapTab(tester, '收藏');
    expect(fabOpacity(), 0);
    expect(find.text('值得回看的都收在这里'), findsOneWidget);

    // 回到笔记页重新出现
    await tapTab(tester, '笔记');
    expect(fabOpacity(), 1);

    await disposeApp(tester);
  });

  testWidgets('分类页点加号弹出新建分类弹窗', (tester) async {
    await pumpApp(tester);
    await tapTab(tester, '分类');

    await tester.tap(find.byKey(const ValueKey('create-fab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('新建分类'), findsOneWidget);
    expect(find.text('分类名称'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('点加号按当前标签创建对应类型的内容', (tester) async {
    await pumpApp(tester);

    // 笔记页：加号进入笔记编辑器
    await tester.tap(find.byKey(const ValueKey('create-fab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('开始记录你的想法…'), findsOneWidget);

    // 返回列表（编辑器用的是自定义返回按钮，非系统 BackButton）
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // 待办页：加号进入待办编辑器
    await tapTab(tester, '待办');
    await tester.tap(find.byKey(const ValueKey('create-fab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('要做什么？'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('右上角三点直接进入设置页', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(LucideIcons.moreHorizontal).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 不再弹菜单，直接是设置页
    expect(find.text('外观'), findsOneWidget);
    // 分类管理已移到底栏，设置页数据分组只剩同步与备份、回收站
    expect(find.text('同步与备份'), findsOneWidget);
    expect(find.text('回收站'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('打开已有内容但不修改，不会刷新更新时间', (tester) async {
    final int oldTime = DateTime.now().millisecondsSinceEpoch - 100000;
    await tester.runAsync(() async {
      await db.noteDao.insertNote(
        NotesCompanion.insert(
          title: const Value('时间戳测试'),
          content: const Value('原样内容'),
          createdAt: oldTime,
          updatedAt: oldTime,
        ),
      );
    });

    await pumpApp(tester);
    await tester.tap(find.text('时间戳测试').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // 不输入任何内容，直接返回
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final note = await tester.runAsync(
      () async => (await db.noteDao.selectAllActive().get()).first,
    );
    expect(note!.updatedAt, oldTime, reason: '仅仅打开不应改写更新时间');

    await disposeApp(tester);
  });

  testWidgets('数据库中已有笔记会在首页渲染', (tester) async {
    // 数据库操作走真实 IO，需在 runAsync 中执行，避免被测试的假时钟挂起
    await tester.runAsync(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.noteDao.insertNote(
        NotesCompanion.insert(
          title: const Value('端到端验证笔记'),
          content: const Value('这条内容来自内存数据库'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.noteDao.insertNote(
        NotesCompanion.insert(
          title: const Value('端到端验证待办'),
          content: const Value('待办内容'),
          kind: const Value(2),
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    await pumpApp(tester);
    await tester.pump(const Duration(milliseconds: 600));

    // 待办不该出现在笔记页
    expect(find.text('端到端验证笔记'), findsWidgets);
    expect(find.text('端到端验证待办'), findsNothing);

    await tapTab(tester, '待办');
    expect(find.text('端到端验证待办'), findsWidgets);

    await disposeApp(tester);
  });
}
