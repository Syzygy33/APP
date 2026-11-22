import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// 图片文件存储：统一压缩后写入应用私有 `images/` 目录。
///
/// 数据库只保存文件名；绝对路径在启动时初始化一次并缓存在内存里，
/// 这样界面可以同步拿到 [File]，不必为每张图等待异步目录查询。
class ImageStore {
  static String? _dirPath;

  static bool get isReady => _dirPath != null;

  /// 默认压缩参数：长边 1600、JPEG 质量 82（原图动辄数 MB，直接存会撑爆备份）
  static const int defaultMaxSide = 1600;
  static const int defaultQuality = 82;

  static Future<void> init() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/images');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dirPath = dir.path;
  }

  /// 测试或特殊环境下手动指定目录（目录不存在时自动创建）
  static void overrideDir(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dirPath = dir.path;
  }

  /// 仅测试使用：回到未初始化状态
  static void resetForTest() => _dirPath = null;

  static Directory get directory {
    final path = _dirPath;
    if (path == null) {
      throw StateError('ImageStore 尚未初始化');
    }
    return Directory(path);
  }

  static File fileOf(String name) => File('${directory.path}/$name');

  static bool exists(String name) {
    if (!isReady) return false;
    return fileOf(name).existsSync();
  }

  /// 压缩并保存，返回文件名
  static Future<String> save(
    Uint8List bytes, {
    int maxSide = defaultMaxSide,
    int quality = defaultQuality,
  }) async {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('无法识别的图片格式');
    }

    img.Image output = decoded;
    final int longest = max(decoded.width, decoded.height);
    if (longest > maxSide) {
      output = decoded.width >= decoded.height
          ? img.copyResize(
              decoded,
              width: maxSide,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              decoded,
              height: maxSide,
              interpolation: img.Interpolation.average,
            );
    }

    final Uint8List jpg = img.encodeJpg(output, quality: quality);
    final String name =
        '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}.jpg';
    final File file = File('${directory.path}/$name');
    await file.writeAsBytes(jpg, flush: true);
    return name;
  }

  /// 直接写入已压缩好的字节（备份还原时使用，避免二次压缩）
  static Future<void> writeRaw(String name, Uint8List bytes) async {
    final File file = File('${directory.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
  }

  static Future<Uint8List?> readBytes(String name) async {
    if (!isReady) return null;
    final File file = fileOf(name);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static Future<void> delete(String name) async {
    if (!isReady) return;
    final File file = fileOf(name);
    if (!await file.exists()) return;
    try {
      await file.delete();
    } on FileSystemException {
      // 单张删除失败不影响主流程
    }
  }

  /// 清理不在 [keep] 里的图片文件，返回删除数量
  static Future<int> pruneOrphans(Set<String> keep) async {
    if (!isReady) return 0;
    int removed = 0;
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final String name = entity.uri.pathSegments.last;
      if (keep.contains(name)) continue;
      try {
        await entity.delete();
        removed++;
      } on FileSystemException {
        // 忽略被占用的文件
      }
    }
    return removed;
  }

  /// 目录占用体积（字节），用于设置页展示
  static Future<int> totalBytes() async {
    if (!isReady) return 0;
    int total = 0;
    await for (final entity in directory.list()) {
      if (entity is File) {
        try {
          total += await entity.length();
        } on FileSystemException {
          // 忽略
        }
      }
    }
    return total;
  }
}
