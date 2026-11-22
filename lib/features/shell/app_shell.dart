import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/glass_ink.dart';
import '../../shared/glass/liquid_glass_tokens.dart';
import '../../app/theme/app_dimensions.dart';
import '../../data/models/note_kind.dart';
import '../../features/folders/folders_page.dart';
import '../../providers/app_providers.dart';
import '../../providers/sync_providers.dart';

/// 底栏一个标签的配置（图标 + 选中图标 + 文字）
class BottomTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const BottomTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// 应用外壳 —— 页面容器 + 悬浮底部栏（笔记 / 待办 / 收藏）
/// 以及浮在底栏上方居中的新增按钮。
///
/// 同时承担自动同步的调度：启动、数据变更后与回到前台时触发。
class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  static const List<BottomTab> tabs = [
    BottomTab(
      icon: LucideIcons.notebook,
      activeIcon: LucideIcons.notebookPen,
      label: '笔记',
    ),
    BottomTab(
      icon: LucideIcons.listTodo,
      activeIcon: LucideIcons.listChecks,
      label: '待办',
    ),
    BottomTab(
      icon: LucideIcons.folderClosed,
      activeIcon: LucideIcons.folderOpen,
      label: '分类',
    ),
    BottomTab(
      icon: LucideIcons.star,
      activeIcon: LucideIcons.star,
      label: '收藏',
    ),
  ];

  /// 分类页与收藏页都没有「新建内容」语义，加号在这两个页面收起
  static const int foldersIndex = 2;
  static const int favoritesIndex = 3;

  /// 与底栏保持一致的高度与底部留白，用于把加号精确放在胶囊正上方
  static const double barHeight = 64;
  static const double createSize = 52;
  static const double createGap = 12;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  static const String _prefDailyBackup = 'backup_last_day';

  Timer? _debounce;
  StreamSubscription<Object?>? _dbSub;
  DateTime? _lastAutoSync;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _dbSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回到前台补一次同步（后台被系统限制时的补偿）
    if (state == AppLifecycleState.resumed) {
      _autoSync();
    }
  }

  Future<void> _bootstrap() async {
    if (_started || !mounted) return;
    _started = true;
    await _maybeDailySnapshot();
    await _autoSync();
    _listenDatabase();
  }

  /// 每天首次启动自动生成一份本地快照
  Future<void> _maybeDailySnapshot() async {
    try {
      final prefs = ref.read(sharedPrefsProvider);
      final String today = DateFormat('yyyyMMdd').format(DateTime.now());
      if (prefs.getString(_prefDailyBackup) == today) return;

      final service = ref.read(backupServiceProvider);
      final snapshot = await service.capture();
      // 空库不占用快照名额
      if (snapshot.notes.isEmpty && snapshot.folders.isEmpty) {
        await prefs.setString(_prefDailyBackup, today);
        return;
      }
      await service.writeSnapshot();
      await prefs.setString(_prefDailyBackup, today);
    } on Object {
      // 快照失败不影响正常使用
    }
  }

  /// 监听数据变更：静默 20 秒后推送一次，连续编辑只同步一次
  void _listenDatabase() {
    final db = ref.read(databaseProvider);
    _dbSub = db
        .tableUpdates(TableUpdateQuery.onAllTables([db.notes, db.folders]))
        .listen((_) => _scheduleSync());
  }

  void _scheduleSync() {
    if (!ref.read(autoSyncProvider)) return;
    if (!ref.read(syncConfigProvider).isConfigured) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 20), _autoSync);
  }

  Future<void> _autoSync() async {
    if (!mounted) return;
    if (!ref.read(autoSyncProvider)) return;
    if (!ref.read(syncConfigProvider).isConfigured) return;

    // 30 秒内的重复触发合并掉，避免启动与回前台连触两次
    final DateTime now = DateTime.now();
    final DateTime? last = _lastAutoSync;
    if (last != null && now.difference(last).inSeconds < 30) return;
    _lastAutoSync = now;

    await ref.read(syncControllerProvider.notifier).run(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final StatefulNavigationShell navigationShell = widget.navigationShell;
    final int index = navigationShell.currentIndex;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // 收藏页没有「新建」语义，加号收起；分类页用加号新建分类。
    final bool showCreate = index != AppShell.favoritesIndex;
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double barBottom = bottomInset > 0 ? bottomInset + 8 : AppDims.s16;
    final NoteKind createKind = switch (index) {
      1 => NoteKind.todo,
      _ => NoteKind.note,
    };

    void handleCreate() {
      if (index == AppShell.foldersIndex) {
        showCreateFolderSheet(context, ref);
      } else {
        context.push('/note/new?kind=${createKind.value}');
      }
    }

    return Scaffold(
      // 内容延伸到底栏之下，让胶囊浮在内容上方，玻璃才有内容可折射
      extendBody: true,
      body: Stack(
        children: [
          navigationShell,
          // 底部导航：改用 liquid_glass_widgets 的 GlassTabBar，
          // 自带液态玻璃指示器与水滴融合；外层只管安全区留白。
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset > 0 ? bottomInset + 6 : AppDims.s12,
            child: GlassTabBar.bottom(
              selectedIndex: index,
              onTabSelected: (i) => navigationShell.goBranch(
                i,
                initialLocation: i == navigationShell.currentIndex,
              ),
              horizontalPadding: AppDims.s16,
              verticalPadding: 0,
              barHeight: AppShell.barHeight,
              // ---- 玻璃：官方 bottomBar 预设 ----
              // 之前手写过 frost/rimLight（rimLight 1.25），因为没设 lightAngle，
              // 光在整圈均匀发亮，深色底上就是"一圈白光"。改用库作者调校过的
              // 参数（左上 135° 单向光源 + 20pt 重雾化）后边缘只在受光侧亮。
              settings: LiquidGlassTokens.glassBottomBar,
              // ---- 选中胶囊：色块而非白色高亮 ----
              showIndicator: true,
              indicatorColor: isDark
                  ? const Color(0xFF2B3350) // 深蓝灰
                  : AppColors.accent.withValues(alpha: 0.16), // 淡蓝
              // ---- 前景色：选中走蓝色系，未选中半透明 ----
              selectedIconColor: isDark ? AppColors.accentDark : AppColors.accent,
              selectedLabelColor: isDark ? AppColors.accentDark : AppColors.accent,
              unselectedIconColor: GlassInk.secondary(context),
              unselectedLabelColor: GlassInk.secondary(context),
              tabs: [
                for (final t in AppShell.tabs)
                  GlassTab(
                    icon: Icon(t.icon, size: 22),
                    activeIcon: Icon(t.activeIcon, size: 22),
                    label: t.label,
                  ),
              ],
            ),
          ),
          // 悬浮新增按钮：底栏上方居中。切到收藏时原地缩小淡出收起。
          Positioned(
            left: 0,
            right: 0,
            bottom: barBottom + AppShell.barHeight + AppShell.createGap,
            child: IgnorePointer(
              ignoring: !showCreate,
              child: Center(
                child: AnimatedScale(
                  scale: showCreate ? 1 : 0,
                  duration: Duration(milliseconds: showCreate ? 260 : 200),
                  curve: showCreate ? Curves.easeOutBack : Curves.easeInCubic,
                  child: AnimatedOpacity(
                    key: const ValueKey('create-fab'),
                    opacity: showCreate ? 1 : 0,
                    duration: Duration(milliseconds: showCreate ? 200 : 180),
                    child: _CreateButton(
                      onTap: handleCreate,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 浮在底栏上方的小号圆形新增按钮：蓝色磨砂玻璃质感。
class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 液态玻璃按钮：官方 interactive 预设（左上单向光源）+ 双层投影。
    // 纯色背景没有内容可折射，悬浮感只能靠投影撑起来。
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: LiquidGlassTokens.buttonShadows(context),
      ),
      child: GlassIconButton(
        icon: const Icon(LucideIcons.plus),
        onPressed: onTap,
        size: AppShell.createSize,
        iconSize: 24,
        shape: GlassIconButtonShape.circle,
        iconColor: GlassInk.primary(context),
        settings: LiquidGlassTokens.glassInteractive,
        interactionScale: 0.92,
      ),
    );
  }
}
