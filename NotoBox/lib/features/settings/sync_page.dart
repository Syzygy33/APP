import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, GlassSurfaceStyle, LiquidRoundedSuperellipse;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../shared/widgets/app_trash_icon.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';
import '../../data/sync/backup_service.dart';
import '../../data/sync/webdav_client.dart';
import '../../providers/sync_providers.dart';
import '../../shared/widgets/circle_button.dart';
import '../../shared/widgets/ios_action_sheet.dart';
import '../../shared/widgets/ios_dialog.dart';
import '../../shared/widgets/pressable.dart';

/// 同步与备份页：WebDAV 配置 / 立即同步 / 自动同步开关 / 本地备份与快照。
class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  late final TextEditingController _urlController;
  late final TextEditingController _userController;
  late final TextEditingController _passController;
  late final TextEditingController _pathController;

  bool _obscure = true;
  bool _busy = false;
  String? _hint;
  bool _hintIsError = false;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(syncConfigProvider);
    _urlController = TextEditingController(text: cfg.baseUrl);
    _userController = TextEditingController(text: cfg.username);
    _passController = TextEditingController();
    _pathController = TextEditingController(text: cfg.remotePath);
    // 已保存过密码时显示占位，避免把真实密码回填进输入框
    ref.read(syncCredentialsProvider).read().then((pwd) {
      if (!mounted || pwd.isEmpty) return;
      _passController.text = pwd;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  WebDavConfig get _currentConfig => WebDavConfig(
    baseUrl: _urlController.text,
    username: _userController.text,
    remotePath: _pathController.text,
  );

  void _setHint(String text, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _hint = text;
      _hintIsError = isError;
    });
  }

  Future<bool> _save({bool quiet = false}) async {
    final cfg = _currentConfig;
    if (cfg.baseUrl.trim().isEmpty || cfg.username.trim().isEmpty) {
      _setHint('请填写服务器地址与账号', isError: true);
      return false;
    }
    await ref
        .read(syncConfigProvider.notifier)
        .save(
          cfg,
          password: _passController.text.isEmpty ? null : _passController.text,
        );
    if (!quiet) _setHint('配置已保存', isError: false);
    return true;
  }

  Future<void> _test() async {
    if (_busy) return;
    final cfg = _currentConfig;
    if (cfg.baseUrl.trim().isEmpty) {
      _setHint('请先填写服务器地址', isError: true);
      return;
    }
    setState(() => _busy = true);
    _setHint('正在连接…', isError: false);
    try {
      final msg = await ref
          .read(syncControllerProvider.notifier)
          .testConnection(config: cfg, password: _passController.text);
      _setHint(msg, isError: false);
    } on WebDavException catch (e) {
      _setHint(e.message, isError: true);
    } on Object catch (e) {
      _setHint('连接失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    if (_busy) return;
    final ok = await _save(quiet: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    _setHint('正在同步…', isError: false);
    await ref.read(syncControllerProvider.notifier).run();
    if (!mounted) return;
    final st = ref.read(syncControllerProvider);
    setState(() => _busy = false);
    if (st.hasError) {
      _setHint(st.error!, isError: true);
    } else {
      _setHint(st.message ?? '同步完成', isError: false);
      ref.invalidate(backupFilesProvider);
    }
  }

  /// 用远端快照覆盖本地（回滚）。与「立即同步」的合并语义分开。
  Future<void> _restoreFromRemote() async {
    if (_busy) return;
    final cfg = _currentConfig;
    if (!cfg.isConfigured) {
      _setHint('请先填写服务器地址与账号', isError: true);
      return;
    }
    setState(() => _busy = true);
    _setHint('正在读取远端备份…', isError: false);
    final String pwd = await ref.read(syncCredentialsProvider).read();
    final client = WebDavClient(config: cfg, password: pwd);
    try {
      final Uint8List? bytes = await client.downloadSnapshot();
      if (bytes == null || bytes.isEmpty) {
        _setHint('远端还没有备份，请先执行一次同步', isError: true);
        return;
      }
      final snap = await ref.read(backupServiceProvider).previewPackage(bytes);
      if (!mounted) return;
      final bool? ok = await showIOSConfirm(
        context: context,
        title: '用远端备份覆盖本地？',
        message:
            '${snap.summary}\n'
            '备份时间：${DateFormat('yyyy/MM/dd HH:mm').format(snap.exportedTime)}',
        confirmLabel: '恢复',
        destructive: true,
      );
      if (ok != true) return;
      final outcome = await ref
          .read(backupServiceProvider)
          .importPackage(bytes, replace: true);
      _setHint('已从远端恢复：${outcome.message}', isError: false);
      ref.invalidate(backupFilesProvider);
    } on WebDavException catch (e) {
      _setHint(e.message, isError: true);
    } on FormatException catch (e) {
      _setHint('远端备份格式不正确：${e.message}', isError: true);
    } on Object catch (e) {
      _setHint('恢复失败：$e', isError: true);
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final Uint8List bytes = await service.buildPackage();
      final name = BackupService.suggestedFileName();

      // 系统「保存到」界面：可选手机存储中任意目录，写入由平台完成
      final Uri? target = await FilePicker.saveFile(
        dialogTitle: '导出备份',
        fileName: name,
        mimeType: 'application/zip',
        bytes: bytes,
      );
      if (target == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      _setHint('已导出：${_readableTarget(target)}', isError: false);
    } on Object catch (e) {
      _setHint('导出失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// content:// 之类的地址对用户没意义，尽量显示可读路径
  String _readableTarget(Uri uri) {
    if (uri.scheme == 'file') return uri.toFilePath();
    return Uri.decodeComponent(
      uri.pathSegments.isEmpty ? uri.toString() : uri.pathSegments.last,
    );
  }

  Future<void> _importBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    Uint8List? bytes;
    try {
      // 系统文件选择器：可从手机存储任意位置挑选备份文件
      final files = await FilePicker.pickFiles(
        dialogTitle: '选择备份文件',
        type: FileType.custom,
        allowedExtensions: const ['zip', 'json'],
      );
      if (files.isEmpty) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      bytes = await files.first.xFile.readAsBytes();
    } on Object catch (e) {
      _setHint('读取文件失败：$e', isError: true);
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _applyImport(bytes);
  }

  /// 导入 / 恢复共用的确认与执行流程
  Future<void> _applyImport(Uint8List bytes) async {
    final preview = await _previewBytes(bytes);
    if (preview == null || !mounted) return;

    final int? mode = await showIOSActionSheet(
      context: context,
      title: '这份备份含：$preview',
      message: '选择导入方式',
      actions: const [
        IOSAction(label: '合并到本地（保留较新）', icon: LucideIcons.combine),
        IOSAction(
          label: '覆盖本地（先自动备份）',
          icon: LucideIcons.refreshCw,
          destructive: true,
        ),
      ],
    );
    if (mode == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final outcome = await ref
          .read(backupServiceProvider)
          .importPackage(bytes, replace: mode == 1);
      _setHint(outcome.message, isError: false);
      ref.invalidate(backupFilesProvider);
    } on FormatException catch (e) {
      _setHint(e.message, isError: true);
    } on Object catch (e) {
      _setHint('导入失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 解析出条目数摘要；格式不合法时提示并返回 null
  Future<String?> _previewBytes(Uint8List bytes) async {
    try {
      final snap = await ref.read(backupServiceProvider).previewPackage(bytes);
      return '${snap.summary}（${DateFormat('yyyy/MM/dd HH:mm').format(snap.exportedTime)}）';
    } on FormatException catch (e) {
      _setHint(e.message, isError: true);
      return null;
    } on Object catch (e) {
      _setHint('无法读取备份：$e', isError: true);
      return null;
    }
  }

  Future<void> _restoreFile(SnapshotFile item) async {
    if (_busy) return;
    Uint8List bytes;
    try {
      bytes = await item.file.readAsBytes();
    } on Object catch (e) {
      _setHint('读取快照失败：$e', isError: true);
      return;
    }
    if (!mounted) return;
    await _applyImport(bytes);
  }

  Future<void> _deleteFile(SnapshotFile item) async {
    final bool? ok = await showIOSConfirm(
      context: context,
      title: '删除这份快照？',
      message: item.name,
      confirmLabel: '删除',
      destructive: true,
    );
    if (ok != true) return;
    await ref.read(backupServiceProvider).deleteSnapshot(item.file);
    ref.invalidate(backupFilesProvider);
  }

  Future<void> _createSnapshot() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ref.read(backupServiceProvider).writeSnapshot();
      _setHint('已生成快照 ${file.name}', isError: false);
      ref.invalidate(backupFilesProvider);
    } on Object catch (e) {
      _setHint('生成快照失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final Color card = isDark ? AppColors.darkSurfaceElevated : Colors.white;
    final Color fill = isDark ? AppColors.darkFill : AppColors.lightFill;
    final Color accent = isDark ? AppColors.accentDark : AppColors.accent;

    final bool autoSync = ref.watch(autoSyncProvider);
    final SyncState syncState = ref.watch(syncControllerProvider);
    final filesAsync = ref.watch(backupFilesProvider);
    final bool running = _busy || syncState.syncing;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDims.s20,
            AppDims.s8,
            AppDims.s20,
            AppDims.s40,
          ),
          children: [
            Row(
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
                  '同步与备份',
                  style: AppTypography.largeTitle.copyWith(
                    color: primary,
                    fontSize: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDims.s20),

            // ---- WebDAV 配置 ----
            _SectionLabel('WebDAV 同步', color: secondary),
            const SizedBox(height: AppDims.s8),
            GlassContainer.card(
              surfaceStyle: GlassSurfaceStyle.solid,
              color: card,
              shape: const LiquidRoundedSuperellipse(
                borderRadius: AppDims.radiusXL,
              ),
              padding: const EdgeInsets.all(AppDims.s16),
              child: Column(
                children: [
                  _Field(
                    label: '服务器地址',
                    hint: 'https://dav.jianguoyun.com/dav/',
                    controller: _urlController,
                    primary: primary,
                    secondary: secondary,
                    keyboardType: TextInputType.url,
                  ),
                  _Field(
                    label: '账号',
                    hint: '登录账号',
                    controller: _userController,
                    primary: primary,
                    secondary: secondary,
                  ),
                  _Field(
                    label: '密码 / 应用密码',
                    hint: '建议使用应用专用密码',
                    controller: _passController,
                    primary: primary,
                    secondary: secondary,
                    obscure: _obscure,
                    trailing: IconButton(
                      icon: Icon(
                        _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 18,
                        color: secondary,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  _Field(
                    label: '远端目录',
                    hint: 'NotoBox',
                    controller: _pathController,
                    primary: primary,
                    secondary: secondary,
                  ),
                  const SizedBox(height: AppDims.s8),
                  Row(
                    children: [
                      Expanded(
                        child: _SecondaryButton(
                          label: '测试连接',
                          color: accent,
                          fill: fill,
                          busy: running,
                          onTap: _test,
                        ),
                      ),
                      const SizedBox(width: AppDims.s10),
                      Expanded(
                        child: _SecondaryButton(
                          label: '保存配置',
                          color: primary,
                          fill: fill,
                          busy: false,
                          onTap: _save,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDims.s16),

            // ---- 同步操作 ----
            GlassContainer.card(
              surfaceStyle: GlassSurfaceStyle.solid,
              color: card,
              shape: const LiquidRoundedSuperellipse(
                borderRadius: AppDims.radiusXL,
              ),
              padding: const EdgeInsets.all(AppDims.s16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '自动同步',
                              style: AppTypography.body.copyWith(
                                color: primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '启动、编辑后与回到前台时自动同步',
                              style: AppTypography.caption1.copyWith(
                                color: secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: autoSync,
                        onChanged: (v) =>
                            ref.read(autoSyncProvider.notifier).setEnabled(v),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDims.s8),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDims.radiusM),
                        ),
                      ),
                      onPressed: running ? null : _syncNow,
                      child: running
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('立即同步'),
                    ),
                  ),
                  const SizedBox(height: AppDims.s10),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                        side: BorderSide(
                          color: AppColors.red.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDims.radiusM),
                        ),
                      ),
                      onPressed: running ? null : _restoreFromRemote,
                      icon: const Icon(LucideIcons.cloudDownload, size: 16),
                      label: const Text('从远端恢复'),
                    ),
                  ),
                  const SizedBox(height: AppDims.s10),
                  Row(
                    children: [
                      Icon(
                        syncState.hasError
                            ? LucideIcons.circleAlert
                            : (running
                                  ? LucideIcons.refreshCw
                                  : LucideIcons.cloud),
                        size: 14,
                        color: syncState.hasError ? AppColors.red : secondary,
                      ),
                      const SizedBox(width: AppDims.s6),
                      Expanded(
                        child: Text(
                          _statusText(syncState, running),
                          style: AppTypography.caption1.copyWith(
                            color: syncState.hasError
                                ? AppColors.red
                                : secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_hint != null) ...[
                    const SizedBox(height: AppDims.s10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _hint!,
                        style: AppTypography.caption1.copyWith(
                          color: _hintIsError ? AppColors.red : AppColors.green,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppDims.s24),

            // ---- 本地备份 ----
            _SectionLabel('本地备份', color: secondary),
            const SizedBox(height: AppDims.s8),
            GlassContainer.card(
              surfaceStyle: GlassSurfaceStyle.solid,
              color: card,
              shape: const LiquidRoundedSuperellipse(
                borderRadius: AppDims.radiusXL,
              ),
              padding: const EdgeInsets.all(AppDims.s16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SecondaryButton(
                          label: '导出备份',
                          color: accent,
                          fill: fill,
                          busy: false,
                          onTap: _exportBackup,
                        ),
                      ),
                      const SizedBox(width: AppDims.s10),
                      Expanded(
                        child: _SecondaryButton(
                          label: '导入备份',
                          color: primary,
                          fill: fill,
                          busy: false,
                          onTap: _importBackup,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDims.s10),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(
                          color: secondary.withValues(alpha: 0.28),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDims.radiusM),
                        ),
                      ),
                      onPressed: running ? null : _createSnapshot,
                      icon: const Icon(LucideIcons.camera, size: 16),
                      label: const Text('立即生成快照'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDims.s16),

            filesAsync.when(
              data: (files) {
                if (files.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDims.s8,
                      vertical: AppDims.s8,
                    ),
                    child: Text(
                      '还没有本地快照。每天首次启动会自动生成一份，最多保留 7 份。',
                      style: AppTypography.caption1.copyWith(color: secondary),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionLabel(
                      '本地快照（最近 ${files.length} 份）',
                      color: secondary,
                    ),
                    const SizedBox(height: AppDims.s8),
                    GlassContainer.card(
                      surfaceStyle: GlassSurfaceStyle.solid,
                      color: card,
                      shape: const LiquidRoundedSuperellipse(
                        borderRadius: AppDims.radiusXL,
                      ),
                      clipBehavior: Clip.antiAlias,
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (int i = 0; i < files.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 0.5,
                                indent: AppDims.s16,
                                color: secondary.withValues(alpha: 0.18),
                              ),
                            _SnapshotRow(
                              item: files[i],
                              primary: primary,
                              secondary: secondary,
                              onRestore: () => _restoreFile(files[i]),
                              onDelete: () => _deleteFile(files[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(AppDims.s16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                '读取快照失败：$e',
                style: AppTypography.caption1.copyWith(color: AppColors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(SyncState state, bool running) {
    if (running) return '同步中…';
    if (state.hasError) {
      final String reason = state.error ?? '未知原因';
      return '上次同步失败：$reason';
    }
    if (state.lastSyncAt == null) return '尚未同步过';
    final t = DateFormat('MM/dd HH:mm').format(state.lastSyncAt!);
    return '上次同步 $t${state.message != null ? ' · ${state.message}' : ''}';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionLabel(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTypography.footnote.copyWith(color: color));
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final Color primary;
  final Color secondary;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.primary,
    required this.secondary,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // 输入框底色：浅色下是极淡的灰，深色下是极淡的白。
    // 之前是「无边框 + 底部一条 Divider」的裸文本行，和整页卡片圆角语言
    // 不一致；现在改成圆角填充块，字段之间靠间距分隔。
    final Color fill = isDark
        ? const Color(0x1FFFFFFF)
        : const Color(0x0F000000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption1.copyWith(color: secondary)),
        const SizedBox(height: AppDims.s6),
        Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppDims.radiusM),
          ),
          padding: const EdgeInsets.only(left: AppDims.s12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  style: AppTypography.body.copyWith(color: primary),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTypography.body.copyWith(
                      color: secondary.withValues(alpha: 0.45),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppDims.s12,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppDims.s4),
                  child: trailing,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDims.s14),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color fill;
  final bool busy;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.label,
    required this.color,
    required this.fill,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDims.radiusM),
          ),
        ),
        onPressed: busy ? null : onTap,
        child: Text(
          label,
          style: AppTypography.subheadline.copyWith(color: color),
        ),
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  final SnapshotFile item;
  final Color primary;
  final Color secondary;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _SnapshotRow({
    required this.item,
    required this.primary,
    required this.secondary,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onRestore,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDims.s16,
          vertical: AppDims.s12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('yyyy/MM/dd HH:mm:ss').format(item.time),
                    style: AppTypography.body.copyWith(
                      color: primary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.sizeLabel,
                    style: AppTypography.caption1.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '恢复这份快照',
              icon: Icon(LucideIcons.history, size: 18, color: primary),
              onPressed: onRestore,
            ),
            IconButton(
              tooltip: '删除',
              icon: const AppTrashIcon(size: 18, color: AppColors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
