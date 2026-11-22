import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/glass_ink.dart';
import '../../shared/widgets/app_trash_icon.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../providers/app_providers.dart';
import '../../shared/glass/liquid_glass_tokens.dart';
import '../../shared/widgets/circle_button.dart';
import '../../shared/widgets/pressable.dart';

/// 设置页 —— 主题切换（真实持久化）、统计、入口
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final statsAsync = ref.watch(statsProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final Color primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final Color surface = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final Color accent = isDark ? AppColors.accentDark : AppColors.accent;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDims.s20,
                  AppDims.s16,
                  AppDims.s20,
                  AppDims.s16,
                ),
                child: Row(
                  children: [
                    CircleButton(
                      icon: LucideIcons.arrowLeft,
                      tooltip: '返回',
                      size: 40,
                      iconSize: 18,
                      onTap: () => context.pop(),
                    ),
                    const SizedBox(width: AppDims.s12),
                    Text(
                      '设置',
                      style: AppTypography.title3.copyWith(color: primary),
                    ),
                  ],
                ),
              ),
            ),

            // ---- 外观 ----
            const SliverToBoxAdapter(
              child: Padding(
                // 统一节奏：标题距上方 28（首块为 0）、距下方控件 12
                padding: EdgeInsets.fromLTRB(
                  AppDims.s20,
                  AppDims.s4,
                  AppDims.s20,
                  AppDims.s12,
                ),
                child: Text('外观', style: AppTypography.footnote),
              ),
            ),
            // 不再用液态玻璃分段控件：改为一行入口，点击弹窗选择。
            // 宽度与其他分组卡片一致（_Group 内部统一左右留白 s20）。
            SliverToBoxAdapter(
              child: _Group(
                children: [
                  _ThemeRow(
                    current: themeMode,
                    accent: accent,
                    surface: surface,
                  ),
                ],
              ),
            ),

            // ---- 统计 ----
            const SliverToBoxAdapter(
              child: Padding(
                // 统一节奏：标题距上方 28、距下方卡片 12
                padding: EdgeInsets.fromLTRB(
                  AppDims.s20,
                  AppDims.s28,
                  AppDims.s20,
                  AppDims.s12,
                ),
                child: Text('统计', style: AppTypography.footnote),
              ),
            ),
            SliverToBoxAdapter(
              // 用 valueOrNull 而不是 when(loading: 转圈)：统计是流式实时值，
              // 首帧还没有数据时先按 0 渲染，避免整块卡片闪一下加载圈。
              child: () {
                final Map<String, int>? stats = statsAsync.asData?.value;
                return _Group(
                  children: [
                    _StatRow(
                      icon: Icons.note_outlined,
                      color: AppColors.accent,
                      label: '笔记总数',
                      value: '${stats?['notes'] ?? 0}',
                      surface: surface,
                    ),
                    _StatRow(
                      icon: Icons.check_circle_outline,
                      color: AppColors.green,
                      label: '待办（未完成 / 总数）',
                      value:
                          '${stats?['todoOpen'] ?? 0} / ${stats?['todo'] ?? 0}',
                      surface: surface,
                    ),
                    _StatRow(
                      icon: Icons.star_outline,
                      color: AppColors.orange,
                      label: '收藏内容',
                      value: '${stats?['favorites'] ?? 0}',
                      surface: surface,
                    ),
                  ],
                );
              }(),
            ),

            // ---- 数据 ----
            const SliverToBoxAdapter(
              child: Padding(
                // 统一节奏：标题距上方 28、距下方卡片 12
                padding: EdgeInsets.fromLTRB(
                  AppDims.s20,
                  AppDims.s28,
                  AppDims.s20,
                  AppDims.s12,
                ),
                child: Text('数据', style: AppTypography.footnote),
              ),
            ),
            SliverToBoxAdapter(
              child: _Group(
                children: [
                  _NavRow(
                    icon: const Icon(Icons.cloud_sync_outlined),
                    color: AppColors.accent,
                    label: '同步与备份',
                    surface: surface,
                    onTap: () => context.push('/sync'),
                  ),
                  _NavRow(
                    icon: const AppTrashIcon(color: AppColors.red),
                    color: AppColors.red,
                    label: '回收站',
                    surface: surface,
                    onTap: () => context.push('/trash'),
                  ),
                ],
              ),
            ),

            // ---- 关于 ----
            const SliverToBoxAdapter(
              child: Padding(
                // 统一节奏：标题距上方 28、距下方卡片 12
                padding: EdgeInsets.fromLTRB(
                  AppDims.s20,
                  AppDims.s28,
                  AppDims.s20,
                  AppDims.s12,
                ),
                child: Text('关于', style: AppTypography.footnote),
              ),
            ),
            SliverToBoxAdapter(
              child: _Group(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppDims.s16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppDims.radiusS + 2,
                          ),
                          child: Image.asset(
                            'assets/branding/app_icon_144.png',
                            width: 44,
                            height: 44,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                        const SizedBox(width: AppDims.s12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NotoBox',
                              style: AppTypography.headline.copyWith(
                                color: primary,
                              ),
                            ),
                            Text(
                              '版本 1.0.0 · Liquid Glass',
                              style: AppTypography.caption1.copyWith(
                                color: secondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

/// 分组容器：改用 liquid_glass_widgets 的 [GlassGroupedSection]。
/// 用 `solid` 表面（纯色卡片、零 shader 开销），符合 iOS 规范里
/// 「滚动内容卡片保持不透明、玻璃只用于浮起的导航/控件层」。
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color divider = GlassInk.divider(context);

    // 自己插分隔线，而不是交给 GlassGroupedSection 自动注入：
    // 1) 自动注入的分隔线只有左缩进，右侧直通卡片边缘；
    // 2) 若同时在 children 里再放一条，就会叠成两道（视觉上像三根细线）。
    // 这里统一：每两项之间一根，左右都内缩 16，与 iOS inset grouped 一致。
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDims.s16),
            child: Container(height: 0.5, color: divider),
          ),
        );
      }
    }

    return Padding(
      // 左右留白 20，与「同步与备份」页的卡片**完全一致**：
      // 两边圆角都是 28，只有卡片宽度相同，圆角在视觉上才显得一样大。
      padding: const EdgeInsets.symmetric(horizontal: AppDims.s20),
      child: GlassContainer.card(
        surfaceStyle: GlassSurfaceStyle.solid,
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: const LiquidRoundedSuperellipse(borderRadius: 28),
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: rows,
        ),
      ),
    );
  }
}


/// 外观：一行入口 + 弹窗选择。
///
/// 之前是一整条液态玻璃分段控件（`GlassSegmentedControl`）。问题在于
/// 它本身就是一块玻璃，浮在纯色背景上只能靠边缘光撑质感，看起来像
/// 一条「贴上去的胶囊」；而且三档并排、每档都带图标和文字，视觉噪音大。
/// 现在收成一行，把选项放进弹窗——既有分组卡片的统一质感，也更省地方。
class _ThemeRow extends ConsumerWidget {
  final int current;
  final Color accent;
  final Color surface;
  const _ThemeRow({
    required this.current,
    required this.accent,
    required this.surface,
  });

  static const List<String> _labels = ['跟随系统', '浅色', '深色'];
  static const List<IconData> _icons = [
    Icons.brightness_auto,
    Icons.light_mode,
    Icons.dark_mode,
  ];

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final int? picked = await GlassDialog.show<int>(
      context: context,
      title: '外观',
      // 与全 App 卡片统一圆角 28
      shape: const LiquidRoundedSuperellipse(borderRadius: 28),
      // 浮层专用玻璃（官方 overlay 预设，左上单向光源）
      settings: LiquidGlassTokens.glassOverlay,
      content: _ThemeOptions(current: current),
      actions: [
        GlassDialogAction(
          label: '取消',
          // 库的回调是无参的，关闭要自己 pop
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
    if (picked != null) {
      ref.read(themeModeProvider.notifier).setMode(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Material(
      color: Colors.transparent,
      child: PressableScale(
        onTap: () => _pick(context, ref),
        child: ListTile(
          leading: Icon(_icons[current], color: accent),
          title: Text(
            '主题',
            style: AppTypography.body.copyWith(color: primary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _labels[current],
                style: AppTypography.body.copyWith(color: secondary),
              ),
              const SizedBox(width: AppDims.s4),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹窗里的三档选项：整行可点，选中项右侧打勾。
class _ThemeOptions extends StatelessWidget {
  final int current;
  const _ThemeOptions({required this.current});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color highlight = isDark
        ? const Color(0x24FFFFFF)
        : const Color(0x14000000);

    return Column(
      mainAxisSize: MainAxisSize.min,
      // 弹窗内的 Column 是居中对齐（loose 约束），这里必须 stretch，
      // 否则整行宽度收缩、里面的 Expanded 拿不到确定宽度。
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < _ThemeRow._labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: PressableScale(
              pressedHighlightColor: highlight,
              pressedHighlightRadius: AppDims.radiusM,
              onTap: () => Navigator.of(
                context,
                rootNavigator: true,
              ).pop(i),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    const SizedBox(width: AppDims.s12),
                    Icon(_ThemeRow._icons[i], size: 20, color: primary),
                    const SizedBox(width: AppDims.s12),
                    Expanded(
                      child: Text(
                        _ThemeRow._labels[i],
                        style: AppTypography.body.copyWith(color: primary),
                      ),
                    ),
                    if (i == current)
                      const Icon(
                        Icons.check,
                        size: 20,
                        color: AppColors.accent,
                      ),
                    const SizedBox(width: AppDims.s12),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Color surface;
  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    // 背景交给 Group 玻璃容器，此处透明
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: AppTypography.body.copyWith(color: primary)),
        trailing: Text(
          value,
          style: AppTypography.title3.copyWith(color: primary),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final Widget icon;
  final Color color;
  final String label;
  final Color surface;
  final VoidCallback onTap;
  const _NavRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.surface,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    // 背景交给 Group 玻璃容器，此处透明
    return Material(
      color: Colors.transparent,
      child: PressableScale(
        onTap: onTap,
        child: ListTile(
          leading: IconTheme(
            data: IconThemeData(color: color, size: 22),
            child: icon,
          ),
          title: Text(
            label,
            style: AppTypography.body.copyWith(color: primary),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
        ),
      ),
    );
  }
}
