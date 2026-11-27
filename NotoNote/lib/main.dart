import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import 'l10n/ui_localizations.dart';
import 'pages/home_shell.dart';
import 'services/demo_seed.dart';
import 'services/reminder_service.dart';
import 'services/todo_repository.dart';
import 'theme/app_prefs.dart';
import 'theme/app_theme.dart';
import 'ui/app_view_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 主题模式与液态玻璃开关：读不到就用默认值，不会挡住启动
  await AppPrefs.load();
  // 只有 --dart-define=SEED_DEMO=true 的构建才会种数据，正式包不受影响
  await seedDemoIfEmpty();
  runApp(const NotoNoteApp());
  // 启动后把已有的提醒重排一遍：重装或从备份恢复后，系统里的闹钟不会自己回来。
  // Web 上通知只在页面开着时有效，没必要去要权限。
  if (!kIsWeb) {
    unawaited(_restoreReminders());
  }
}

Future<void> _restoreReminders() async {
  final todos = await PrefsTodoRepository().load();
  await ReminderService.syncAll(todos);
}

class NotoNoteApp extends StatelessWidget {
  const NotoNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 两个外观偏好都要能实时切换：主题改变 ThemeData，玻璃改变 LiquidGlassScope，
    // 后者由 PrismApp 在顶层注入，所以必须重建整个 App 而不是只重建某个子树。
    return ListenableBuilder(
      listenable: Listenable.merge([AppTheme.mode, AppTheme.liquidGlass]),
      builder: (context, _) {
        return PrismApp(
          debugShowCheckedModeBanner: false,
          title: 'NotoNote',
          theme: AppTheme.of(Brightness.light),
          darkTheme: AppTheme.of(Brightness.dark),
          themeMode: AppTheme.mode.value,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppUiLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          // 液态玻璃：导航栏、顶栏按钮、弹层的玻璃质感，出自 iOS 27。
          // 用 standard 不用 ultra：ultra 多了模糊+色散两层，中低端机会掉帧。
          // 传 null 即全程平面，设置页的开关控制这里。
          liquidGlass: AppTheme.liquidGlass.value
              ? LiquidGlassQuality.standard
              : null,
          // builder 在 Navigator 之上，保证 push 出来的子页也能拿到 ViewScope。
          builder: (context, child) =>
              AppViewScope(child: child ?? const SizedBox.shrink()),
          home: const HomeShell(),
        );
      },
    );
  }
}
