import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../common/relative_time.dart';
import 'app_page_bar.dart';
import 'bar_clearance.dart';
import 'icons/app_glyphs.dart';
import 'nested_sheet.dart';

/// 选择器的结果：设一个时间，或清掉已有提醒。
@immutable
class ReminderResult {
  const ReminderResult.at(DateTime this.time);

  const ReminderResult.cleared() : time = null;

  final DateTime? time;

  bool get cleared => time == null;
}

/// 打开「提醒时间」选择器。取消返回 null。
Future<ReminderResult?> showReminderPicker(
  BuildContext context, {
  DateTime? initial,
  String? subject,
}) {
  return showNestedSheet<ReminderResult>(
    context,
    builder: (_) => ReminderPickerSheet(initial: initial, subject: subject),
  );
}

/// 日期横条 + 时/分两个滚轮。
///
/// 刻意不用系统的 DatePicker：Material 那套和 prism_ui 的圆角/字体完全不搭，
/// 而且项目本身没有引入 Material 主题。这里只用 widgets 层就能做出来。
class ReminderPickerSheet extends StatefulWidget {
  const ReminderPickerSheet({super.key, this.initial, this.subject});

  /// 已有提醒时传进来，选择器会停在那个时间上，并多一颗「清除」。
  final DateTime? initial;

  /// 弹层里显示的对象（待办文本），让用户确认在给谁设提醒。
  final String? subject;

  @override
  State<ReminderPickerSheet> createState() => _ReminderPickerSheetState();
}

class _ReminderPickerSheetState extends State<ReminderPickerSheet> {
  static const _minuteStep = 5;
  static const _maxDays = 60;

  late DateTime _today;
  late DateTime _day;
  late int _hour;
  late int _minute;

  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    final start = widget.initial ?? _suggested(now);
    _day = DateTime(start.year, start.month, start.day);
    _hour = start.hour;
    _minute = (start.minute ~/ _minuteStep) * _minuteStep;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(
      initialItem: _minute ~/ _minuteStep,
    );
  }

  /// 没设过提醒时默认给「下一个整点后一小时」，落在用户大概还醒着的时间。
  static DateTime _suggested(DateTime now) {
    final next = now.add(const Duration(hours: 1));
    return DateTime(next.year, next.month, next.day, next.hour);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  DateTime get _selected =>
      DateTime(_day.year, _day.month, _day.day, _hour, _minute);

  bool get _valid => _selected.isAfter(DateTime.now());

  void _confirm() {
    if (!_valid) {
      return;
    }
    Navigator.of(context).pop(ReminderResult.at(_selected));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final subject = widget.subject?.trim() ?? '';
    return PrismScaffold(
      bar: AppPageBar(
        title: '提醒时间',
        showBack: true,
        actions: [
          BarSaveButton(
            onPressed: _valid ? _confirm : null,
          ),
        ],
      ),
      body: BarClearance(
        child: ListView(
          padding: context.listInsets.page(
            top: appBarContentGap,
            bottom: 32,
          ),
          children: [
            if (subject.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.subheadline
                      .of(context)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            _SectionLabel(text: '哪一天'),
            const SizedBox(height: 8),
            SizedBox(height: 66, child: _buildDayStrip(context)),
            const SizedBox(height: 20),
            _SectionLabel(text: '几点'),
            const SizedBox(height: 4),
            SizedBox(height: 168, child: _buildWheels(context)),
            if (!_valid)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    GlyphIcon(
                      AppGlyphs.bell,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '这个时间已经过了，往后选一点',
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            if (widget.initial != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: TonalButton(
                  size: TonalButtonSize.section,
                  glyph: AppGlyphs.bell,
                  label: '清除提醒',
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(const ReminderResult.cleared()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayStrip(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _maxDays,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final day = _today.add(Duration(days: index));
        final selected = day == _day;
        return GestureDetector(
          onTap: () => setState(() => _day = day),
          child: Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: AppRadius.md,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  switch (index) {
                    0 => '今天',
                    1 => '明天',
                    2 => '后天',
                    _ => weekdayShort(day),
                  },
                  style: AppTextStyle.caption1.of(context).copyWith(
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.month}/${day.day}',
                  style: AppTextStyle.subheadline.of(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWheels(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Row(
      children: [
        Expanded(
          child: _Wheel(
            controller: _hourController,
            count: 24,
            selected: _hour,
            label: (value) => value.toString().padLeft(2, '0'),
            suffix: '时',
            onChanged: (value) => setState(() => _hour = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            ':',
            style: AppTextStyle.title2
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: _Wheel(
            controller: _minuteController,
            count: 60 ~/ _minuteStep,
            selected: _minute ~/ _minuteStep,
            label: (value) => (value * _minuteStep).toString().padLeft(2, '0'),
            suffix: '分',
            onChanged: (value) => setState(() => _minute = value * _minuteStep),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyle.footnote.of(context).copyWith(
        color: context.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// 一列滚轮：中间放大、上下淡出，选中项高亮。
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.count,
    required this.selected,
    required this.label,
    required this.suffix,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int count;
  final int selected;
  final String Function(int value) label;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        stops: [0, 0.22, 0.78, 1],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 44,
        perspective: 0.004,
        diameterRatio: 1.5,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, index) {
            final active = index == selected;
            return Center(
              child: Text(
                '${label(index)} $suffix',
                style: AppTextStyle.title3.of(context).copyWith(
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 「提醒时间」一行：没设时显示「未设置」，点一下打开选择器。
///
/// 待办详情与新建待办共用，保证两处的样子和点击范围一致。
class ReminderRow extends StatelessWidget {
  const ReminderRow({super.key, required this.remindAt, required this.onTap});

  final DateTime? remindAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final at = remindAt;
    final overdue = at != null && at.isBefore(DateTime.now());
    final tint = at == null || overdue
        ? colorScheme.onSurfaceVariant
        : colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            GlyphIcon(AppGlyphs.bell, size: 16, color: tint),
            const SizedBox(width: 8),
            Text('提醒时间', style: AppTextStyle.subheadline.of(context)),
            const Spacer(),
            Text(
              at == null ? '未设置' : reminderLabel(at),
              style: AppTextStyle.subheadline.of(context).copyWith(
                color: at == null ? colorScheme.onSurfaceVariant : tint,
              ),
            ),
            const SizedBox(width: 4),
            GlyphIcon(
              Glyphs.chevronForward,
              size: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
