import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import 'icons/app_glyphs.dart';

/// 页面顶栏。
///
/// 必须走 `prism_ui` 的 `ScaffoldBar`：它把内容包成 `PreferredSizeWidget`
/// （`AppBar` 自身没实现该接口），并负责页面模式下的浮动、渐变遮罩、
/// 加载线和窗口控件避让。
///
/// 两个容易漏的点：
/// 1. `actions` 必须经 `genActions(..., edge: ...)` 生成。它会在末尾补一个
///    `ActionEdgeGap`，也就是顶栏末端的内缩；直接传裸列表会让按钮贴到屏幕边缘。
/// 2. 必须在 `PrismApp.builder` 里提供 `AppViewScope`，否则 `AppBar` 读
///    `ViewScope.isMobileOf` 时取不到值，整条顶栏渲染为空且不报错。
class AppPageBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPageBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions = const [],
  });

  final String title;

  /// 推入的页面置 true，根页面保持 false。
  final bool showBack;

  final List<Widget> actions;

  /// 无状态变化，也不需要顶栏加载线。用静态实例避免每帧重建。
  static final _noChange = Listenable.merge(const []);
  static final _notLoading = ValueNotifier<bool>(false);

  /// 紧凑模式下 `SheetToolBar` 不读这个值，只有页面模式会用到，
  /// 因此固定为 `pageToolbarHeight`，与 `ScaffoldBar` 的页面值一致。
  @override
  Size get preferredSize => const Size.fromHeight(pageToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isCompact = ScaffoldSurface.of(context).isCompact;
    return ScaffoldBar(
      isCompact: isCompact,
      listenable: _noChange,
      loading: _notLoading,
      // 顶栏按钮的玻璃由 `TonalButtonTheme` 给：不在 group 里的按钮走
      // `paned` 分支，每颗自己有一层玻璃面板，边缘是柔和反光（FlClash 同款）。
      builder: (context) => TonalButtonTheme(
        glass: LiquidGlassScope.of(context),
        child: AppBar(
          leading: showBack ? const Center(child: BarBackButton()) : null,
          title: Text(title),
          actions: genActions(actions, edge: AppBarActionEdge.container),
        ),
      ),
    );
  }
}

/// 顶栏的图标按钮。
///
/// 不用 `TonalButtonGroup`：group 会把整行按钮包进一层
/// `LiquidGlassStyle.regular`，那套样式 `rim: 0.28`，圆边会出现一圈硬白线。
///
/// FlClash 的顶栏按钮是 `ElasticPress(child: AppBarActionButton(...))`——
/// 不在 group 里，于是走 `TonalButtonTheme` 的 `paned` 分支：每颗按钮
/// 自己有一层玻璃面板（边缘是柔和的反光，不是硬白线），底色也是玻璃的。
class BarIconButton extends StatelessWidget {
  const BarIconButton({super.key, required this.data, this.icon});

  final IconButtonData data;

  /// 顶替 [data] 里的图标。需要实心图标时用它——
  /// `AppBarActionButton` 用的是默认描边版 `GlyphIcon(data.glyph)`。
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return ElasticPress(
      enabled: !data.isLoading && data.onPressed != null,
      child: AppBarActionButton(data: data, icon: icon),
    );
  }
}

/// 顶栏里「共用一颗圆角胶囊」的一组图标按钮：搜索 + 排序。
///
/// 走 prism_ui 的 `TonalButtonGroup`：它们共用一层面板（开着液态玻璃时是
/// 同一块玻璃），指针移过时那颗按钮上浮出一颗 4pt 内缩的胶囊高亮，
/// 是 iOS 27 的分组按钮观感。
///
/// 注意子按钮必须用 `AppBarActionButton`——`BarIconButton` 自带
/// `ElasticPress`，会和 group 外层那层重复。
///
/// 不要在 group 外面再套一层 `TonalButtonTheme`：它内部的 `_GlassButtons`
/// 会把顶栏那层 `TonalButtonTheme(glass: true)` 挡掉，`TonalButtonGroup`
/// 读到的 `glassOf` 变成 false，整颗胶囊就退化成实心填充（再也看不到玻璃）。
/// 尺寸由 `TonalButtonGroup` 自己给子按钮，包一层是多余的。
class BarButtonGroup extends StatelessWidget {
  const BarButtonGroup({super.key, required this.items});

  final List<IconButtonData> items;

  @override
  Widget build(BuildContext context) {
    return TonalButtonGroup(
      size: TonalButtonSize.bar,
      children: [for (final data in items) AppBarActionButton(data: data)],
    );
  }
}

/// 顶栏的「更多」菜单按钮。
///
/// 与设置页那行「主题」逐字一致：`PopupAnchor` + `PopupMenu`，
/// 不给菜单加任何参数，也不动按钮。
class BarMenuButton extends StatelessWidget {
  const BarMenuButton({
    super.key,
    this.glyph = Glyphs.more,
    this.tooltip = '更多',
    required this.items,
  });

  final Glyph glyph;
  final String tooltip;
  final List<PopupMenuItem> Function() items;

  @override
  Widget build(BuildContext context) {
    return PopupAnchor(
      targetBuilder: (open) => BarIconButton(
        data: IconButtonData(glyph: glyph, tooltip: tooltip, onPressed: open),
      ),
      popupBuilder: (_) => PopupMenu(items: items()),
    );
  }
}

/// 顶栏返回按钮。
///
/// 尺寸由 `TonalButtonGroup` 的 `bar` 规格决定（44），不自己写死；
/// 放进 `AppBar` 的 leading 槽位（84×72）时要套一层 `Center`，
/// 否则会被撑满格子，按下时整块着色看起来像一大团阴影。
class BarBackButton extends StatelessWidget {
  const BarBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    // 弹层（compact 容器）里是「关闭」，用 ✕；普通页面仍是箭头。
    // FlClash 的表单弹层也是这个规矩。
    final isSheet = ScaffoldSurface.of(context).isCompact;
    return BarIconButton(
      data: IconButtonData(
        glyph: isSheet ? Glyphs.close : Glyphs.arrowBack,
        tooltip: isSheet ? '关闭' : '返回',
        // 不能用 maybePop()：编辑页是 sheet 里的第一页，Navigator.canPop()
        // 为 false 会把它吞掉，点了没反应。pop() 才能触发 PagedSheetRoute
        // 的 didPop → onPopFirst 关掉整张 sheet；普通 push 页同样正常返回。
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// 顶栏的「保存」对勾按钮。
///
/// 编辑类页面统一用对勾代替文字「保存」，风格与搜索/更多一致。
/// `onPressed` 传 null 即进入保存中禁用态。
class BarSaveButton extends StatelessWidget {
  const BarSaveButton({
    super.key,
    required this.onPressed,
    this.tooltip = '保存',
  });

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return BarIconButton(
      data: IconButtonData(
        glyph: Glyphs.check,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// 顶栏的撤销 / 前进一对按钮。
///
/// 直接吃 [UndoHistoryController]：不可撤销/前进时按钮自动禁用（灰掉），
/// 与返回、对勾同一行同一高度。
class BarUndoRedo extends StatelessWidget {
  const BarUndoRedo({super.key, required this.controller});

  final UndoHistoryController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UndoHistoryValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BarIconButton(
              data: IconButtonData(
                glyph: AppGlyphs.undo,
                tooltip: '撤销',
                onPressed: value.canUndo ? controller.undo : null,
              ),
            ),
            const SizedBox(width: _undoGap),
            BarIconButton(
              data: IconButtonData(
                glyph: AppGlyphs.redo,
                tooltip: '前进',
                onPressed: value.canRedo ? controller.redo : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 撤销与前进之间的间距，与顶栏按钮间距一致。
const double _undoGap = 8;
