import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/todo.dart';

/// 待办提醒的系统通知。
///
/// 只用 Android + Web 两端：Web 端走 `flutter_local_notifications_web`
/// 的 Notification API，页面开着才会响，主要让预览能走通流程。
///
/// 时间统一按 UTC 排：`TZDateTime.from(time.toUtc(), tz.UTC)` 表示的是同一个
/// 绝对时刻，不依赖设备时区数据库，也就省掉了 `flutter_timezone` 那个额外依赖。
abstract final class ReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void>? _ready;

  /// 初始化 + 要权限。失败不抛：通知不可用不该把页面卡住。
  static Future<void> ensureReady() {
    return _ready ??= _init();
  }

  static Future<void> _init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        // Android 13+ 的通知权限；12+ 的精确闹钟（被拒就退回不精确）。
        await android?.requestNotificationsPermission();
        await android?.requestExactAlarmsPermission();
      }
    } catch (_) {
      // 忽略：没有通知权限时仍然能正常用 App
    }
  }

  /// 通知 id 必须是 32 位 int，而待办 id 是字符串，用哈希映射。
  static int _idFor(String todoId) => todoId.hashCode & 0x7fffffff;

  /// 把一条待办的提醒排上 / 撤掉。完成、删除、清空时间都会撤。
  static Future<void> sync(Todo todo) async {
    await ensureReady();
    final id = _idFor(todo.id);
    final at = todo.remindAt;
    final shouldNotify =
        at != null &&
        !todo.done &&
        !todo.isDeleted &&
        at.isAfter(DateTime.now());
    try {
      if (!shouldNotify) {
        await _plugin.cancel(id: id);
        return;
      }
      await _schedule(
        id: id,
        text: todo.text,
        at: at,
        mode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // 精确闹钟被系统拒绝时退到不精确，晚几分钟也比不响好。
      if (shouldNotify) {
        try {
          await _schedule(
            id: id,
            text: todo.text,
            at: at,
            mode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        } catch (_) {}
      }
    }
  }

  static Future<void> _schedule({
    required int id,
    required String text,
    required DateTime at,
    required AndroidScheduleMode mode,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      title: '待办提醒',
      body: text,
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'todo_reminder',
          '待办提醒',
          channelDescription: '到点提醒你该做这件事',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: mode,
    );
  }

  /// 删掉/完成一条待办时撤销它的通知。
  static Future<void> cancel(String todoId) async {
    await ensureReady();
    try {
      await _plugin.cancel(id: _idFor(todoId));
    } catch (_) {
      // 忽略
    }
  }

  /// 启动或恢复备份后重排：系统里的闹钟在重装后不会自己回来。
  static Future<void> syncAll(Iterable<Todo> todos) async {
    await ensureReady();
    for (final todo in todos) {
      if (todo.remindAt != null || todo.done) {
        await sync(todo);
      }
    }
  }
}
