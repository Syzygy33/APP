/// 列表里显示"多久以前"，正文里显示具体日期。
///
/// 不引 intl：本项目第一版只有中文，等真要做多语言再换成 `intl` 的
/// `DateFormat`，届时这两个函数是唯一的改动点。
String relativeTime(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(time);
  if (diff.isNegative) {
    return '刚刚';
  }
  if (diff.inMinutes < 1) {
    return '刚刚';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} 分钟前';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} 小时前';
  }
  if (diff.inDays == 1) {
    return '昨天';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays} 天前';
  }
  return fullDate(time);
}

/// 2026年11月23日
String fullDate(DateTime time) => '${time.year}年${time.month}月${time.day}日';

/// 2026年11月23日 12:28
String fullDateTime(DateTime time) {
  final minute = time.minute.toString().padLeft(2, '0');
  return '${fullDate(time)} ${time.hour}:$minute';
}

/// 09:00
String clockTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// 提醒时间的口语化写法：今天 09:00 / 明天 09:00 / 11月28日 09:00。
String reminderLabel(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final day = DateTime(time.year, time.month, time.day);
  final clock = clockTime(time);
  switch (day.difference(today).inDays) {
    case 0:
      return '今天 $clock';
    case 1:
      return '明天 $clock';
    case 2:
      return '后天 $clock';
    case -1:
      return '昨天 $clock';
  }
  if (time.year == reference.year) {
    return '${time.month}月${time.day}日 $clock';
  }
  return '${time.year}年${time.month}月${time.day}日 $clock';
}

/// 周一 … 周日。
String weekdayShort(DateTime time) {
  const names = ['一', '二', '三', '四', '五', '六', '日'];
  return '周${names[time.weekday - 1]}';
}
