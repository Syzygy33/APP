import 'dart:async';

import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/backup_service.dart';
import '../services/webdav_backup.dart';
import '../ui/app_page_bar.dart';
import '../ui/bar_clearance.dart';
import '../ui/icons/app_glyphs.dart';
import '../ui/list_item.dart';
import '../ui/nested_sheet.dart';

/// 备份与恢复。
///
/// 结构照 FlClash 那页来：**远程 / 本地 / 选项** 三段。
/// 远程是 WebDAV（账号 + 连通性小圆点 + 文件 + 备份 / 恢复），
/// 本地是「写到文件 / 从文件读」，两条链路各走各的、互不覆盖；
/// 选项里只有一条「恢复策略」，决定恢复时整体覆盖还是按 id 合并。
class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  static const _backup = BackupService();
  static const _local = LocalBackupFiles();
  static const _webdavStore = WebDavStore();
  static const _strategyKey = 'noto_note.backup.strategy.v1';

  var _config = const WebDavConfig();
  var _strategy = RestoreStrategy.overwrite;

  /// 连通性：null 表示正在测，true / false 是上一次探测结果。
  bool? _connected;

  /// 正在跑的动作名，用来把对应那行显示成「处理中…」并挡住重复点击。
  String? _busy;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final config = await _webdavStore.loadConfig();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _config = config;
      _strategy = RestoreStrategy.parse(prefs.getString(_strategyKey));
    });
    await _checkConnection();
  }

  Future<void> _saveStrategy(RestoreStrategy strategy) async {
    setState(() => _strategy = strategy);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_strategyKey, strategy.name);
  }

  Future<void> _saveConfig(WebDavConfig next) async {
    setState(() => _config = next);
    await _webdavStore.saveConfig(next);
  }

  // -------------------------------------------------------------- 连通性

  /// 测一次 WebDAV：地址没填就不测；结果落到 [_connected] 的小圆点上。
  Future<void> _checkConnection() async {
    if (!_config.isConfigured) {
      if (mounted) {
        setState(() => _connected = null);
      }
      return;
    }
    setState(() => _connected = null);
    var ok = false;
    final client = WebDavClient();
    try {
      await client.ping(_config);
      ok = true;
    } on BackupException {
      ok = false;
    } catch (_) {
      ok = false;
    } finally {
      client.close();
    }
    if (mounted) {
      setState(() => _connected = ok);
    }
  }

  // -------------------------------------------------------------- 远程

  Future<void> _openConfig() async {
    final result = await showNestedSheet<_ConfigResult>(
      context,
      builder: (_) => _WebDavConfigSheet(
        config: _config,
        hasAccount: _config.isConfigured,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    switch (result) {
      case _ConfigSaved(config: final config):
        await _saveConfig(config);
        await _checkConnection();
      case _ConfigDeleted():
        await _webdavStore.clearConfig();
        if (!mounted) {
          return;
        }
        setState(() {
          _config = const WebDavConfig();
          _connected = null;
        });
    }
  }

  Future<void> _backupRemote() async {
    if (!_config.isConfigured) {
      unawaited(_notify('还没绑定 WebDAV', '先点右边「绑定」，填好地址和账号。'));
      return;
    }
    await _run('remote-backup', () async {
      final payload = await _backup.capture();
      final client = WebDavClient();
      try {
        await client.upload(_config, payload);
      } finally {
        client.close();
      }
      final summary = _backup.describe(payload);
      await _notify(
        '备份',
        summary == null
            ? '已写入 ${_config.fileName}'
            : '${summary.contentLabel}\n${summary.sizeLabel}，已写入 ${_config.fileName}',
      );
    });
  }

  Future<void> _restoreRemote() async {
    if (!_config.isConfigured) {
      unawaited(_notify('还没绑定 WebDAV', '先点右边「绑定」，填好地址和账号。'));
      return;
    }
    await _run('remote-restore', () async {
      final client = WebDavClient();
      final String payload;
      try {
        payload = await client.download(_config);
      } finally {
        client.close();
      }
      await _restorePayload(payload, from: '云端');
    });
  }

  // -------------------------------------------------------------- 本地

  Future<void> _backupLocal() async {
    await _run('local-backup', () async {
      final payload = await _backup.capture();
      final record = await _local.export(payload);
      if (record == null) {
        return;
      }
      final summary = _backup.describe(payload);
      await _notify(
        '备份',
        summary == null
            ? '已保存 ${record.name}'
            : '${summary.contentLabel}\n${summary.sizeLabel}，已保存 ${record.name}',
      );
    });
  }

  Future<void> _restoreLocal() async {
    await _run('local-restore', () async {
      final payload = await _local.pickForRestore();
      if (payload == null) {
        return;
      }
      await _restorePayload(payload, from: '文件');
    });
  }

  // -------------------------------------------------------------- 通用

  /// 两条链路恢复前都走这里：先看摘要，再按恢复策略确认一次。
  Future<void> _restorePayload(String payload, {required String from}) async {
    final summary = _backup.describe(payload);
    if (summary == null) {
      throw BackupException('这份$from 备份不是有效的 NotoNote 快照');
    }
    final merging = _strategy == RestoreStrategy.merge;
    final confirmed = await _confirm(
      '用这份备份恢复？',
      '${summary.contentLabel}，${_formatTime(summary.savedAt)}，'
          '${summary.sizeLabel}。\n'
          '恢复策略：${_strategy.label}'
          '${merging ? '（本机多出来的笔记、待办、分类会保留）' : '（本机数据整体被替换）'}。',
    );
    if (!confirmed) {
      return;
    }
    await _backup.restore(payload, strategy: _strategy);
    await _notify('恢复', '${summary.contentLabel} 已写回本机。');
  }

  /// 统一处理「忙碌状态 + 异常提示」。
  Future<void> _run(String key, Future<void> Function() action) async {
    if (_busy != null) {
      return;
    }
    setState(() => _busy = key);
    try {
      await action();
    } on BackupException catch (error) {
      await _notify('没成功', error.message);
    } catch (error) {
      await _notify('没成功', '$error');
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  Future<void> _notify(String title, String message) {
    // 动作已经结束（成功或失败），先把「处理中」撤掉再弹结果。
    if (mounted && _busy != null) {
      setState(() => _busy = null);
    }
    return showFloatingDialog<void>(
      context: context,
      child: Builder(
        builder: (dialogContext) => AlertDialog(
          title: title,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('好'),
            ),
          ],
          child: Text(message),
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showFloatingDialog<bool>(
      context: context,
      child: Builder(
        builder: (dialogContext) => AlertDialog(
          title: title,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('恢复'),
            ),
          ],
          child: Text(message),
        ),
      ),
    );
    return result ?? false;
  }

  String _formatTime(DateTime? time) {
    if (time == null) {
      return '时间未知';
    }
    final local = time.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final hm =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return sameDay ? '今天 $hm' : '${local.month} 月 ${local.day} 日 $hm';
  }

  // -------------------------------------------------------------- UI

  /// 远程那颗账号行显示什么：有账号显示账号，否则退回主机名。
  String get _accountLabel {
    final user = _config.username.trim();
    if (user.isNotEmpty) {
      return user;
    }
    final host = _config.targetUri?.host;
    return host == null || host.isEmpty ? 'WebDAV 已配置' : host;
  }

  List<Widget> _remoteItems() {
    if (!_config.isConfigured) {
      return [
        ListItem(
          leading: const GlyphIcon(AppGlyphs.cloud, size: 22),
          title: const Text('未绑定'),
          subtitle: const Text('添加一个 WebDAV 账号，把备份放到网盘上'),
          trailing: TonalButton(label: '绑定', onPressed: _openConfig),
        ),
      ];
    }
    return [
      ListItem(
        leading: const GlyphIcon(AppGlyphs.cloud, size: 22),
        title: Text(_accountLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Text('连通性：'),
              _ConnectivityDot(connected: _connected),
            ],
          ),
        ),
        trailing: TonalButton(label: '编辑', onPressed: _openConfig),
      ),
      ListItem.input(
        title: const Text('文件'),
        subtitle: Text(_config.fileName),
        dialogTitle: '文件',
        value: _config.fileName,
        resetValue: WebDavConfig.defaultFileName,
        onChanged: (value) {
          final name = (value ?? '').trim();
          unawaited(
            _saveConfig(
              _config.copyWith(
                fileName: name.isEmpty ? WebDavConfig.defaultFileName : name,
              ),
            ),
          );
        },
      ),
      ListItem(
        title: const Text('备份'),
        subtitle: _busy == 'remote-backup' ? const Text('处理中…') : null,
        onTap: _busy == null ? () => unawaited(_backupRemote()) : null,
      ),
      ListItem(
        title: const Text('恢复'),
        subtitle: _busy == 'remote-restore' ? const Text('处理中…') : null,
        onTap: _busy == null ? () => unawaited(_restoreRemote()) : null,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PrismScaffold(
      bar: const AppPageBar(title: '备份与恢复', showBack: true),
      body: BarClearance(
        child: ListView(
          padding: context.listInsets.page(top: appBarContentGap, bottom: 32),
          children: [
            generateSection(title: '远程', atTop: true, items: _remoteItems()),
            generateSection(
              title: '本地',
              items: [
                ListItem(
                  title: const Text('备份'),
                  subtitle: _busy == 'local-backup'
                      ? const Text('处理中…')
                      : null,
                  onTap: _busy == null ? () => unawaited(_backupLocal()) : null,
                ),
                ListItem(
                  title: const Text('恢复'),
                  subtitle: _busy == 'local-restore'
                      ? const Text('处理中…')
                      : null,
                  onTap: _busy == null ? () => unawaited(_restoreLocal()) : null,
                ),
              ],
              footer: '本地备份是一个 .json 文件，存哪儿由你选；和远程那份互不影响。',
            ),
            generateSection(
              title: '选项',
              last: true,
              items: [
                ListItem.options(
                  title: const Text('恢复策略'),
                  options: RestoreStrategy.values,
                  value: _strategy,
                  textBuilder: (strategy) => strategy.label,
                  onChanged: (strategy) => unawaited(_saveStrategy(strategy)),
                ),
              ],
              footer:
                  '覆盖：用备份整体替换本机数据。'
                  '合并：备份优先，本机多出来的笔记、待办、分类保留。',
            ),
          ],
        ),
      ),
    );
  }
}

/// 连通性小圆点：探测中转圈，测完绿 / 红。
class _ConnectivityDot extends StatelessWidget {
  const _ConnectivityDot({required this.connected});

  final bool? connected;

  @override
  Widget build(BuildContext context) {
    if (connected == null) {
      return const Padding(
        padding: EdgeInsetsDirectional.only(start: 2),
        child: ActivityIndicator(size: 12),
      );
    }
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 2),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: connected! ? const Color(0xFF34C759) : context.colorScheme.error,
      ),
    );
  }
}

// ------------------------------------------------------------------ 配置弹层

sealed class _ConfigResult {
  const _ConfigResult();
}

class _ConfigSaved extends _ConfigResult {
  const _ConfigSaved(this.config);

  final WebDavConfig config;
}

class _ConfigDeleted extends _ConfigResult {
  const _ConfigDeleted();
}

class _WebDavConfigSheet extends StatefulWidget {
  const _WebDavConfigSheet({required this.config, required this.hasAccount});

  final WebDavConfig config;

  /// 已经有账号时，弹层底部多一条「删除」。
  final bool hasAccount;

  @override
  State<_WebDavConfigSheet> createState() => _WebDavConfigSheetState();
}

class _WebDavConfigSheetState extends State<_WebDavConfigSheet> {
  late final _uri = TextEditingController(text: widget.config.baseUrl);
  late final _user = TextEditingController(text: widget.config.username);
  late final _password = TextEditingController(text: widget.config.password);
  var _revealed = false;
  String? _error;

  @override
  void dispose() {
    _uri.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _uri.text.trim();
    final uri = Uri.tryParse(raw);
    if (raw.isEmpty || uri == null || !uri.hasScheme) {
      setState(() => _error = '地址要以 http:// 或 https:// 开头');
      return;
    }
    Navigator.of(context).pop(
      _ConfigSaved(
        widget.config.copyWith(
          baseUrl: raw,
          username: _user.text.trim(),
          password: _password.text,
        ),
      ),
    );
  }

  void _delete() {
    Navigator.of(context).pop(const _ConfigDeleted());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return PrismScaffold(
      bar: AppPageBar(
        title: 'WebDAV 配置',
        showBack: true,
        actions: [BarSaveButton(onPressed: _submit)],
      ),
      body: BarClearance(
        child: ListView(
          padding: context.listInsets.page(top: appBarContentGap, bottom: 32),
          children: [
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  error,
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: colorScheme.error),
                ),
              ),
            Card(
              padding: EdgeInsets.zero,
              radius: AppCorner.xl,
              child: Column(
                children: [
                  _FieldRow(
                    label: '地址',
                    controller: _uri,
                    hint: 'https://dav.example.com/dav/',
                    keyboardType: TextInputType.url,
                    onChanged: () {
                      if (_error != null) {
                        setState(() => _error = null);
                      }
                    },
                  ),
                  const _RowDivider(),
                  _FieldRow(label: '账号', controller: _user, hint: '选填'),
                  const _RowDivider(),
                  _FieldRow(
                    label: '密码',
                    controller: _password,
                    hint: '选填',
                    obscure: !_revealed,
                    trailing: IconButton(
                      onPressed: () => setState(() => _revealed = !_revealed),
                      icon: GlyphIcon(
                        _revealed ? Glyphs.eyeOff : Glyphs.eye,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.hasAccount)
              generateSection(
                items: [
                  ListItem(
                    title: Text(
                      '删除',
                      style: TextStyle(color: colorScheme.error),
                    ),
                    onTap: _delete,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 配置弹层里的一行：左边标题，右边贴着右缘输入。
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.trailing,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(label, style: AppTextStyle.body.of(context)),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              textAlign: TextAlign.end,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              style: AppTextStyle.body.of(context),
              onChanged: (_) => onChanged?.call(),
              decoration: InputDecoration(
                hintText: hint,
                border: const NoInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (trailing case final trailing?) ...[
            const SizedBox(width: 4),
            trailing,
          ],
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16),
      child: const Divider(height: 1, thickness: 0.5),
    );
  }
}
