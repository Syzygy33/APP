import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import '../theme/app_prefs.dart';
import '../theme/app_theme.dart';
import '../ui/app_page_bar.dart';
import '../ui/bar_clearance.dart';
import '../ui/list_item.dart';
import 'sync_settings_page.dart';

/// 骨架验证页。
///
/// 目的不是做业务，而是一次性验证四件事：
/// 1. 令牌生效（种子色 / 深浅色 / 纯黑）
/// 2. 列表体系（首尾行圆角、分隔线、分组标题与脚注）
/// 3. 六种 `ListItem` 形态都能正常渲染
/// 4. 行展开转场（`ListItem.open`）可用
///
/// 验证通过后，把这一页删掉换成真实业务页。
class SettingsDemoPage extends StatefulWidget {
  const SettingsDemoPage({super.key});

  @override
  State<SettingsDemoPage> createState() => _SettingsDemoPageState();
}

class _SettingsDemoPageState extends State<SettingsDemoPage> {
  bool _notify = true;
  bool _checked = false;
  String _density = '标准';

  @override
  Widget build(BuildContext context) {
    return PrismScaffold(
      bar: const AppPageBar(title: '设置', showBack: true),
      // 顶栏是浮在 body 之上的，body 的 MediaQuery 顶部内边距里已含
      // 状态栏 + pageToolbarHeight；不消费它，第一个分组标题会被顶栏盖住。
      body: BarClearance(
        child: ListView(
          padding: context.listInsets.page(top: appBarContentGap, bottom: 32),
          children: [
            generateSection(
              title: '外观',
              atTop: true,
              items: [
                ListItem<ThemeMode>.options(
                  title: const Text('主题'),
                  options: ThemeMode.values,
                  value: AppTheme.mode.value,
                  textBuilder: _themeModeLabel,
                  onChanged: (mode) {
                    setState(() => AppTheme.mode.value = mode);
                    unawaited(AppPrefs.saveThemeMode(mode));
                  },
                ),
                ListItem.toggle(
                  title: const Text('液态玻璃'),
                  value: AppTheme.liquidGlass.value,
                  onChanged: (value) {
                    setState(() => AppTheme.liquidGlass.value = value);
                    unawaited(AppPrefs.saveLiquidGlass(value));
                  },
                ),
                ListItem(
                  title: const Text('种子色'),
                  trailing: _ColorDot(color: AppTheme.seedColor),
                ),
              ],
            ),
            generateSection(
              title: '控件',
              items: [
                ListItem.toggle(
                  title: const Text('通知'),
                  value: _notify,
                  onChanged: (value) => setState(() => _notify = value),
                ),
                ListItem.checkbox(
                  title: const Text('勾选项'),
                  value: _checked,
                  onChanged: (value) =>
                      setState(() => _checked = value ?? false),
                ),
                ListItem<String>.options(
                  title: const Text('列表密度'),
                  options: const ['紧凑', '标准', '宽松'],
                  value: _density,
                  textBuilder: (value) => value,
                  onChanged: (value) => setState(() => _density = value),
                ),
                ListItem.input(
                  title: const Text('昵称'),
                  dialogTitle: '修改昵称',
                  value: 'Daddy',
                  onChanged: (_) {},
                ),
              ],
            ),
            generateSection(
              title: '数据',
              items: [
                ListItem.open(
                  title: const Text('备份与恢复'),
                  subtitle: const Text('WebDAV 远程备份 / 本地文件备份，各存各的'),
                  widget: const SyncSettingsPage(),
                ),
              ],
            ),
            generateSection(
              title: '关于',
              // 「关于」是中间分组，不能设 atTop——那会让标题顶部间距归零，
              // 紧贴上一组「控件」。只有整页第一组才用 atTop。
              last: true,
              items: [
                ListItem.open(
                  title: const Text('关于 NotoNote'),
                  widget: const _AboutPage(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _themeModeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => '跟随系统',
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
  };
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) {
    return PrismScaffold(
      bar: const AppPageBar(title: '关于', showBack: true),
      body: BarClearance(
        child: ListView(
          padding: context.listInsets.page(top: appBarContentGap, bottom: 32),
          children: [
            generateSection(
              title: 'NotoNote',
              atTop: true,
              last: true,
              items: const [
                ListItem(title: Text('版本'), trailing: Text('0.1.0 (1)')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: ShapeDecoration(color: color, shape: AppShape.circle),
    );
  }
}
