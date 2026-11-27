import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import 'app_page_bar.dart';

/// 可以在「普通」与「搜索」两种形态之间切换的页面顶栏。
///
/// 交互与时间轴照 FlClash 的 `scaffold_search.dart`：
/// 点右上角放大镜 → 标题和其余按钮在 80ms 内淡出并轻微模糊，
/// 那颗圆形按钮向左生长成一整条搜索胶囊（弹簧 390 / 0.75 / 450ms），
/// 同时玻璃面板有一次「抬起再落下」（0.02–0.12 升，0.16–0.29 落），
/// 右端在 80–200ms 之后才浮出圆形关闭按钮——不是一开始就出现。
///
/// 为什么不用两个 `AppBar` 互相切换：`AppBar` 的 `leading` / `actions` 一变
/// 就是硬跳，没有任何过渡。这里把两种内容叠在同一个 `Stack` 里，
/// 用一条 0→1 的动画按「秒」分段驱动各元素。
class SearchablePageBar extends StatefulWidget implements PreferredSizeWidget {
  const SearchablePageBar({
    super.key,
    required this.title,
    required this.searching,
    required this.onSearchingChanged,
    required this.onChanged,
    this.showBack = false,
    this.actions = const [],
    this.hintText = '搜索',
  });

  final String title;

  /// 推入的页面置 true，根页面保持 false。
  final bool showBack;

  /// 普通态右侧的按钮。搜索按钮自己也算一个，由调用方放进这里。
  final List<Widget> actions;

  /// 是否处于搜索态。状态由页面持有：顶栏只负责把它渲染出来。
  final bool searching;

  final ValueChanged<bool> onSearchingChanged;

  /// 输入变化。关闭搜索时**不会**回调空串，页面应在
  /// [onSearchingChanged] 里清掉自己的查询词。
  final ValueChanged<String> onChanged;

  final String hintText;

  @override
  Size get preferredSize => const Size.fromHeight(pageToolbarHeight);

  @override
  State<SearchablePageBar> createState() => _SearchablePageBarState();
}

class _SearchablePageBarState extends State<SearchablePageBar>
    with SingleTickerProviderStateMixin {
  /// FlClash 的 `_searchSettleDuration`。
  static const _duration = Duration(milliseconds: 450);

  /// 关闭不是把展开倒放：FlClash 的 group 返回要跑到 0.55s。
  static const _closeDuration = Duration(milliseconds: 550);

  /// 同 FlClash `_searchCurve`：弹簧 stiffness 390 / ratio 0.75。
  static final _spring = SpringCurve(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 390, ratio: 0.75),
    seconds: _duration.inMicroseconds / Duration.microsecondsPerSecond,
  );

  /// FlClash 的 `_searchCloseSpring`：关得更硬（600），收得干脆。
  static final _closeSpring = SpringCurve(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 600, ratio: 0.75),
    seconds: _closeDuration.inMicroseconds / Duration.microsecondsPerSecond,
  );

  /// 顶栏按钮直径，也是搜索胶囊收起后的宽度。
  static const _barButton = 44.0;

  /// 胶囊与关闭按钮之间的间距。
  static const _gap = 8.0;

  /// 两个动作按钮之间的间距，与 `genActions` 的 `barButtonGap` 一致。
  static const _actionGap = 8.0;

  static final _noChange = Listenable.merge(const []);
  static final _notLoading = ValueNotifier<bool>(false);

  late final _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.searching) {
      _controller.value = 1;
      _focusAfterFrame();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 系统开了「减弱动态效果」时这里会变成 zero，动画直接跳到末态
    _controller
      ..duration = context.motionDuration(_duration)
      ..reverseDuration = context.motionDuration(_closeDuration);
  }

  @override
  void didUpdateWidget(SearchablePageBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searching == oldWidget.searching) {
      return;
    }
    if (widget.searching) {
      _controller.forward();
      _focusAfterFrame();
    } else {
      _focus.unfocus();
      _controller.reverse();
      // 收起时把输入框也清空，下次展开是干净的。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _text.text.isNotEmpty) {
          _text.clear();
        }
      });
    }
  }

  void _focusAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = ScaffoldSurface.of(context).isCompact;
    return ScaffoldBar(
      isCompact: isCompact,
      listenable: _noChange,
      loading: _notLoading,
      builder: (context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _buildBar(
          context,
          _controller.value,
          isCompact ? sheetToolbarHeight : pageToolbarHeight,
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context, double t, double height) {
    final closing = _controller.status == AnimationStatus.reverse;
    // 两套时间轴，各自从 0 秒走到自己的总时长。
    final time = closing
        ? (1 - t) * _closeDuration.inMilliseconds / 1000
        : t * _duration.inMilliseconds / 1000;

    final double titleOpacity;
    final double actionsOpacity;
    final double flankOpacity;
    final double contentOpacity;
    final double growth;
    final double lift;

    if (closing) {
      // FlClash `_SearchMove(opens: false, returns: group)`：
      // 内容立刻消失 → 关闭按钮 0.11–0.2 退场 → 标题 0.08–0.19 回来 →
      // 动作按钮 0.18–0.26 回来 → 胶囊 0.33 收完。
      titleOpacity = _between(time, 0, 1, 0.08, 0.19);
      actionsOpacity = _between(time, 0, 1, 0.18, 0.26);
      flankOpacity = _between(time, 1, 0, 0.11, 0.2);
      contentOpacity = _between(time, 1, 0, 0, 0.04);
      growth =
          1 -
          _closeSpring.transform(
            (math.max(0.0, time - 0.04) / 0.55).clamp(0.0, 1.0),
          );
      // 玻璃抬一次再落回去：0.06–0.16 升，0.21–0.32 落。
      lift = time < 0.21
          ? _between(time, 0, 1, 0.06, 0.16, Curves.easeOut)
          : _between(time, 1, 0, 0.21, 0.32, Curves.easeInOut);
    } else {
      // 展开：标题 0–0.08s 淡出，动作按钮 0.02–0.08s，
      // 关闭按钮 0.08–0.2s，搜索框内容 0.07–0.22s 才淡入。
      titleOpacity = _between(time, 1, 0, 0, 0.08);
      actionsOpacity = _between(time, 1, 0, 0.02, 0.08);
      flankOpacity = _between(time, 0, 1, 0.08, 0.2);
      // FlClash 的 fieldOpacity 是 0–0.05s，几乎立刻可见；
      // 实录视频里 1.26s 那帧搜索框内容已经清晰，所以不能拖到 0.22s。
      contentOpacity = _between(time, 0, 1, 0, 0.05);
      // FlClash 的 `delay: 0.05`：先让标题淡出，胶囊晚 50ms 才开始长。
      growth = _spring.transform(
        ((time - 0.05) / (_duration.inMilliseconds / 1000)).clamp(0.0, 1.0),
      );
      // 玻璃抬一次再落下 1：0.02–0.12 升，0.16–0.29 落。
      lift = time < 0.16
          ? _between(time, 0, 1, 0.02, 0.12, Curves.easeOut)
          : _between(time, 1, 0, 0.16, 0.29, Curves.easeInOut);
    }

    return TonalButtonTheme(
      glass: LiquidGlassScope.of(context),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: widget.searching,
                  child: _regularContent(
                    context,
                    height,
                    titleOpacity,
                    actionsOpacity,
                  ),
                ),
              ),
              if (t > 0)
                Positioned.fill(
                  child: _searchContent(
                    context,
                    height,
                    flankOpacity,
                    contentOpacity,
                    growth,
                    lift,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 普通态：返回按钮 + 标题 + 若干动作按钮。
  ///
  /// 标题和右侧按钮各自淡出——FlClash 里标题先走（0–0.08s），
  /// 动作按钮稍后（0.02–0.08s），这样胶囊长出来时不会压着一缕残字。
  Widget _regularContent(
    BuildContext context,
    double height,
    double titleOpacity,
    double actionsOpacity,
  ) {
    final margin = context.listInsets.margin;
    return Row(
      // 标题与右侧 44px 圆按钮按圆心对齐，避免大字重下视觉上偏下。
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.showBack)
          Padding(
            padding: EdgeInsetsDirectional.only(start: margin - 8),
            child: _blurredIn(
              actionsOpacity,
              const BarBackButton(),
            ),
          ),
        Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: widget.showBack ? 4 : margin,
              end: 8,
            ),
            child: _blurredIn(
              titleOpacity,
              Transform.scale(
                alignment: AlignmentDirectional.centerStart,
                scale: 1 - 0.04 * (1 - titleOpacity),
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // 页面名用 pageTitle（24）比 title3 大一级，配 w800 更醒目；
                  // height: 1 收掉行高留白，让文字重心与右侧按钮圆心齐平。
                  style: AppTextStyle.pageTitle.of(context).copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        for (var i = 0; i < widget.actions.length; i++) ...[
          if (i > 0) const SizedBox(width: _actionGap),
          _blurredIn(actionsOpacity, widget.actions[i]),
        ],
        SizedBox(width: margin),
      ],
    );
  }

  /// 搜索态：胶囊从右侧按钮位置向左生长，关闭按钮后浮出。
  Widget _searchContent(
    BuildContext context,
    double height,
    double flankOpacity,
    double contentOpacity,
    double growth,
    double lift,
  ) {
    final colorScheme = context.colorScheme;
    final margin = context.listInsets.margin;
    final endSlot = _barButton + _gap;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = math.max(
          _barButton,
          constraints.maxWidth - margin * 2 - endSlot,
        );
        final width = _barButton + (fullWidth - _barButton) * growth;
        // 胶囊本身的按压缩放：与 FlClash `_lifted` 同一算式。
        final scale = 1 + lift * ElasticPress.growthOf(width);

        return Stack(
          children: [
            Positioned(
              left: margin,
              right: margin + endSlot,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width: width,
                    height: _barButton,
                    // 输入框始终按满宽布局，只裁掉左边：生长过程中文字
                    // 不逐帧重排，看起来才是真的在被「拉长」。
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: AlignmentDirectional.centerEnd,
                        minWidth: fullWidth,
                        maxWidth: fullWidth,
                        child: SizedBox(
                          width: fullWidth,
                          height: _barButton,
                          // 输入框本身不做模糊：FlClash 的 `_BarSearch` 只把
                          // field 按宽度裁切露出，blur 只给按钮内容用。
                          // 早先给整块加 blurredIn，生长初期会糊成一团黑。
                          child: Opacity(
                            opacity: contentOpacity,
                            child: SearchField(
                              controller: _text,
                              focusNode: _focus,
                              hintText: widget.hintText,
                              fill: SurfaceLevel.inset.colorOf(colorScheme),
                              onChanged: widget.onChanged,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: margin,
              top: (height - _barButton) / 2,
              child: Opacity(
                opacity: flankOpacity,
                child: IgnorePointer(
                  ignoring: flankOpacity < 0.5,
                  child: Transform.scale(
                    scale: 0.7 + 0.3 * flankOpacity,
                    child: BarIconButton(
                      data: IconButtonData(
                        glyph: Glyphs.close,
                        tooltip: '取消搜索',
                        onPressed: () => widget.onSearchingChanged(false),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// FlClash 的 `to()`：把 `[start, end]` 秒映射到 `[from, target]`。
double _between(
  double time,
  double from,
  double target,
  double start,
  double end, [
  Curve curve = Curves.linear,
]) {
  final t = ((time - start) / (end - start)).clamp(0.0, 1.0);
  return ui.lerpDouble(from, target, curve.transform(t))!;
}

/// FlClash 的 `_blurredIn`：透明度的同时叠一层模糊，
/// 元素是「化开」的，而不是单纯变淡。
Widget _blurredIn(double opacity, Widget child) {
  final sigma = 6.0 * (1 - opacity);
  return Opacity(
    opacity: opacity,
    child: ImageFiltered(
      enabled: sigma > 0.01,
      imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    ),
  );
}
