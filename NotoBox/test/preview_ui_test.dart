import 'dart:io';

import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:noto_box/data/database/app_database.dart';
import 'package:noto_box/main.dart';
import 'package:noto_box/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 离屏渲染预览：把真实界面画成 PNG，便于肉眼核对视觉还原度。
/// 运行：flutter test test/preview_ui_test.dart
void main() {
  const fontCandidates = [
    r'C:\Windows\Fonts\Deng.ttf',
    r'C:\Windows\Fonts\msyh.ttc',
    r'C:\Windows\Fonts\simhei.ttf',
  ];

  Future<void> loadSystemFont() async {
    for (final path in fontCandidates) {
      final f = File(path);
      if (!f.existsSync()) continue;
      final bytes = f.readAsBytesSync();
      // 用 Roboto 这个名字注册，测试环境默认字体族即 Roboto，文本才不会画成方块
      // 主题里 fontFamily 固定为 '.SF Pro Display'，预览时按同名注册真实字体，
      // 否则测试环境会退化成方块字形（FlutterTest 占位字体）。
      for (final family in ['.SF Pro Display', 'FlutterTest']) {
        final loader = FontLoader(family)
          ..addFont(Future.value(ByteData.view(bytes.buffer)));
        await loader.load();
      }
      return;
    }
  }

  /// 加载 lucide 图标字体，否则预览里的图标会画成方块
  Future<void> loadIconFont() async {
    final f = File(
      r'C://Users//Syzygy//AppData//Local//Pub//Cache//hosted//pub.flutter-io.cn'
      r'\lucide_icons_flutter-4.0.3\assets\lucide.ttf',
    );
    if (!f.existsSync()) return;
    final bytes = f.readAsBytesSync();
    // 带 package 的字体在运行时以 packages/<pkg>/<family> 注册
    for (final family in ['Lucide', 'packages/lucide_icons_flutter/Lucide']) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    // 图片编码是真实异步，必须放在 runAsync 中，否则会被测试假时钟挂住
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('preview');
      if (!dir.existsSync()) dir.createSync();
      File('preview/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  late AppDatabase db;

  tearDown(() async {
    await db.close();
  });

  testWidgets('生成界面预览图', (tester) async {
    await loadSystemFont();
    await loadIconFont();
    await tester.binding.setSurfaceSize(const Size(390, 844));

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.test(NativeDatabase.memory());

    await tester.runAsync(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final folderId = await db.folderDao.insertFolder(
        FoldersCompanion.insert(name: '工程', createdAt: now),
      );
      await db.noteDao.insertNote(
        NotesCompanion.insert(
          title: const Value('鄂尔多斯场平'),
          content: const Value('燃气管线长度 300，置换 截断盲板盲死'),
          folderId: Value(folderId),
          createdAt: now,
          updatedAt: now - 3600 * 1000,
        ),
      );
      await db.noteDao.insertNote(
        NotesCompanion.insert(
          title: const Value('周会要点'),
          content: const Value('EPC 结算口径确认，检测费归属待定'),
          createdAt: now - 86400000,
          updatedAt: now - 86400000,
        ),
      );
      await db.noteDao.insertNote(
        NotesCompanion.insert(
          title: const Value('买牛奶'),
          content: const Value('顺手买鸡蛋'),
          kind: const Value(1),
          createdAt: now,
          updatedAt: now,
        ),
      );
      // 待办：一条已完成、两条未完成，用于核对勾选态与沉底排序
      await db.noteDao.insertNote(
        NotesCompanion.insert(
          title: const Value('确认 EPC 结算口径'),
          content: const Value('检测费归属先跟造价确认'),
          kind: const Value(2),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.noteDao.insertNote(
        NotesCompanion.insert(
          title: const Value('补齐燃气管线资料'),
          content: const Value(''),
          kind: const Value(2),
          createdAt: now - 7200000,
          updatedAt: now - 7200000,
        ),
      );
      await db.noteDao.insertNote(
        NotesCompanion.insert(
          title: const Value('发出周会纪要'),
          content: const Value('昨天下班前已发'),
          kind: const Value(2),
          done: const Value(true),
          createdAt: now - 86400000,
          updatedAt: now - 86400000,
        ),
      );
      // 收藏页需要至少一条收藏
      await db.noteDao.insertNote(
        NotesCompanion.insert(
          title: const Value('最高投标限价要点'),
          content: const Value('暂估价与暂列金额的界面划分'),
          favorite: const Value(true),
          createdAt: now - 172800000,
          updatedAt: now - 172800000,
        ),
      );
    });

    await tester.pumpWidget(
      RepaintBoundary(
        child: ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
          ],
          child: const NotoBoxApp(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await shoot(tester, '01_home');

    // 切到待办
    await tester.tap(find.bySemanticsLabel('待办'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await shoot(tester, '02_todo');

    // 切到收藏：加号应已向下滑出收起
    await tester.tap(find.bySemanticsLabel('收藏'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await shoot(tester, '03_favorites');

    // 三点直接进入设置（放大转场）。
    // 这里只做断言不截图：设置页由 root navigator 的 overlay 承载，
    // 离屏光栅化时字体族会回退成占位字体，产出的图会全是方块，容易误判。
    await tester.tap(find.byIcon(LucideIcons.moreHorizontal).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('外观'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // 冲刷关闭查询流/弹层动画残留的零延迟定时器
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
  });
}
