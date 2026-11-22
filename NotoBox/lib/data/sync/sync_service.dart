import 'backup_service.dart';
import 'webdav_client.dart';

/// 一次同步的结果
class SyncOutcome {
  /// 从远端合并进本地的结果（远端没有快照时为 null）
  final ImportOutcome? pulled;

  /// 合并后是否已把本地全量上传
  final bool uploaded;

  const SyncOutcome({this.pulled, required this.uploaded});

  String get message {
    if (pulled == null) return '首次同步，已上传本地数据';
    final ImportOutcome p = pulled!;
    if (p.total == 0) return '已是最新，无需变更';
    return '已合并远端：新增 ${p.added}，更新 ${p.updated}';
  }
}

/// 同步编排：拉取远端 → 按 updatedAt 合并进本地 → 上传合并后的全量。
///
/// 之所以「合并后再上传」而不是直接覆盖，是为了多设备场景下不丢任何一方的新数据。
class SyncService {
  final BackupService backup;
  final WebDavClient client;

  Future<SyncOutcome>? _inFlight;

  SyncService({required this.backup, required this.client});

  /// 并发去重：同一时刻只跑一次同步，重复调用复用同一结果
  Future<SyncOutcome> sync() {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _run();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<SyncOutcome> _run() async {
    final remote = await client.downloadSnapshot();
    ImportOutcome? pulled;
    if (remote != null && remote.isNotEmpty) {
      // 合并：同一条目取 updatedAt 较新的，图片随包一并还原
      pulled = await backup.importPackage(remote);
    }
    final package = await backup.buildPackage();
    await client.uploadSnapshot(package);
    return SyncOutcome(pulled: pulled, uploaded: true);
  }

  void dispose() => client.close();
}
