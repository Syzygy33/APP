import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/sync/backup_service.dart';
import '../data/sync/sync_service.dart';
import '../data/sync/webdav_client.dart';
import 'app_providers.dart';

const String _kBaseUrl = 'sync_base_url';
const String _kUsername = 'sync_username';
const String _kRemotePath = 'sync_remote_path';
const String _kAutoSync = 'sync_auto_enabled';
const String _kLastSyncAt = 'sync_last_at';
const String _kSecurePassword = 'webdav_password';

/// 本地备份服务
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});

/// 本地快照列表（读取目录，需要时 invalidate 刷新）
final backupFilesProvider = FutureProvider<List<SnapshotFile>>((ref) {
  return ref.watch(backupServiceProvider).listSnapshots();
});

/// WebDAV 密码存储（Android Keystore 加密；测试环境无平台通道时降级为空）
final syncCredentialsProvider = Provider<SyncCredentials>((ref) {
  return SyncCredentials();
});

class SyncCredentials {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String> read() async {
    try {
      return await _storage.read(key: _kSecurePassword) ?? '';
    } on Object {
      return '';
    }
  }

  Future<void> write(String password) async {
    try {
      await _storage.write(key: _kSecurePassword, value: password);
    } on Object {
      // 没有 Keystore 时静默失败，同步会以 401 提示用户
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _kSecurePassword);
    } on Object {
      // 忽略
    }
  }
}

/// 同步配置（地址 / 账号 / 远端目录）；密码单独走安全存储
final syncConfigProvider = NotifierProvider<SyncConfigNotifier, WebDavConfig>(
  SyncConfigNotifier.new,
);

class SyncConfigNotifier extends Notifier<WebDavConfig> {
  @override
  WebDavConfig build() {
    final prefs = ref.watch(sharedPrefsProvider);
    return WebDavConfig(
      baseUrl: prefs.getString(_kBaseUrl) ?? '',
      username: prefs.getString(_kUsername) ?? '',
      remotePath: prefs.getString(_kRemotePath) ?? 'NotoBox',
    );
  }

  Future<void> save(WebDavConfig config, {String? password}) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString(_kBaseUrl, config.baseUrl.trim());
    await prefs.setString(_kUsername, config.username.trim());
    await prefs.setString(_kRemotePath, config.remotePath.trim());
    if (password != null) {
      await ref.read(syncCredentialsProvider).write(password);
    }
    state = WebDavConfig(
      baseUrl: config.baseUrl.trim(),
      username: config.username.trim(),
      remotePath: config.remotePath.trim(),
    );
  }

  Future<void> clear() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.remove(_kBaseUrl);
    await prefs.remove(_kUsername);
    await prefs.remove(_kRemotePath);
    await ref.read(syncCredentialsProvider).clear();
    state = const WebDavConfig();
  }
}

/// 自动同步开关（默认开启）
final autoSyncProvider = NotifierProvider<AutoSyncNotifier, bool>(
  AutoSyncNotifier.new,
);

class AutoSyncNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedPrefsProvider).getBool(_kAutoSync) ?? true;

  Future<void> setEnabled(bool enabled) async {
    await ref.read(sharedPrefsProvider).setBool(_kAutoSync, enabled);
    state = enabled;
  }
}

/// 同步运行状态
class SyncState {
  final bool syncing;
  final DateTime? lastSyncAt;
  final String? error;
  final String? message;

  const SyncState({
    this.syncing = false,
    this.lastSyncAt,
    this.error,
    this.message,
  });

  bool get hasError => error != null;
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final int? ms = prefs.getInt(_kLastSyncAt);
    return SyncState(
      lastSyncAt: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  /// 执行一次同步。[silent] 为自动触发，未配置时直接跳过不打扰用户。
  Future<void> run({bool silent = false}) async {
    if (state.syncing) return;
    final config = ref.read(syncConfigProvider);
    if (!config.isConfigured) {
      if (!silent) {
        state = SyncState(lastSyncAt: state.lastSyncAt, error: '请先填写服务器地址与账号');
      }
      return;
    }

    state = SyncState(syncing: true, lastSyncAt: state.lastSyncAt);
    final String password = await ref.read(syncCredentialsProvider).read();
    final client = WebDavClient(config: config, password: password);
    final service = SyncService(
      backup: ref.read(backupServiceProvider),
      client: client,
    );

    try {
      final SyncOutcome outcome = await service.sync();
      final DateTime now = DateTime.now();
      await ref
          .read(sharedPrefsProvider)
          .setInt(_kLastSyncAt, now.millisecondsSinceEpoch);
      state = SyncState(lastSyncAt: now, message: outcome.message);
      // 远端可能拉入了新条目，刷新列表
      ref.invalidate(backupFilesProvider);
    } on WebDavException catch (e) {
      state = SyncState(lastSyncAt: state.lastSyncAt, error: e.message);
    } on Object catch (e) {
      final text = e.toString();
      state = SyncState(
        lastSyncAt: state.lastSyncAt,
        error: text.length > 120 ? '${text.substring(0, 120)}…' : text,
      );
    } finally {
      service.dispose();
    }
  }

  /// 仅测试连接，不影响同步状态里的时间
  Future<String> testConnection({
    required WebDavConfig config,
    required String password,
  }) async {
    final client = WebDavClient(config: config, password: password);
    try {
      await client.testConnection();
      return '连接成功';
    } finally {
      client.close();
    }
  }
}
