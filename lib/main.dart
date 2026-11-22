import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart'
    show LiquidGlass;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/router.dart';
import 'app/theme/app_theme.dart';
import 'data/images/image_store.dart';
import 'providers/app_providers.dart';
import 'shared/widgets/glass/glass_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 预加载两套玻璃 shader，避免首帧先渲染 fallback 造成闪烁。
  // 都吞掉错误：没有 GPU / shader 不可用时自动退化，不阻塞启动。
  await LiquidGlass.precache();
  try {
    await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  } on Object {
    // shader 不可用时库会退化渲染，启动不受影响
  }
  final prefs = await SharedPreferences.getInstance();
  // 图片目录初始化失败不应阻塞启动（无存储权限等极端情况）
  try {
    await ImageStore.init();
  } on Object {
    // 忽略：没有图片时不会用到该目录
  }

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const NotoBoxApp(),
    ),
  );
}

class NotoBoxApp extends ConsumerWidget {
  const NotoBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeModeValue = ref.watch(themeModeProvider);

    // themeMode: 0=系统 1=浅色 2=深色
    final ThemeMode themeMode = switch (themeModeValue) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    // liquid_glass_widgets 是 Material-free 的，必须整体包一层 wrap，
    // 并把 ThemeMode 的明暗通过 brightnessResolver 传进玻璃的明暗级联。
    //
    // 背景是纯色（没有壁纸可折射），所以用 GlassThemeData 做部分覆盖，
    // 把「看得见」的几项堆出来：底色更实、雾化更明显、加阴影让玻璃浮起来。
    return LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      theme: const GlassThemeData(
        light: GlassThemeVariant(
          settings: GlassThemeSettings(
            glassColor: Color(0xA6F8F8F8),
            frost: 18,
            frostOpacity: 0.82,
            shadowElevation: 1.2,
          ),
        ),
        dark: GlassThemeVariant(
          settings: GlassThemeSettings(
            glassColor: Color(0x402C2C2E),
            frost: 18,
            frostOpacity: 0.9,
            bodyShade: 0.34,
            shadowElevation: 1.2,
          ),
        ),
      ),
      child: MaterialApp.router(
        title: 'NotoBox',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
        builder: (context, child) {
          final brightness = Theme.of(context).brightness;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            SystemChrome.setSystemUIOverlayStyle(
              AppTheme.overlayStyle(brightness),
            );
          });
          // 平板/折叠屏限宽，保持手机观感。
          // GlassScope 为全局液态玻璃层：所有 LiquidGlass.auto 复用这一次
          // 背景采样，避免每个玻璃元素各建 layer 造成多次全屏读回。
          return GlassScope(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                // 库不带 Material 祖先，补一层透明 Material 供其子组件使用
                child: Material(
                  type: MaterialType.transparency,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
