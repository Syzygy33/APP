import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_service.dart';

/// WebDAV 连接设置。
///
/// 地址可以是**目录**（`https://dav.example.com/notonote/`），也可以是
/// **完整文件地址**（`.../notonote/backup.json`）；以 `.json` 结尾就当作文件。
class WebDavConfig {
  const WebDavConfig({
    this.baseUrl = '',
    this.username = '',
    this.password = '',
    this.fileName = defaultFileName,
  });

  static const defaultFileName = 'notonote-backup.json';

  final String baseUrl;
  final String username;
  final String password;
  final String fileName;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  /// 真正 PUT / GET 的那个地址。
  Uri? get targetUri {
    final raw = baseUrl.trim();
    if (raw.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      return null;
    }
    if (uri.path.toLowerCase().endsWith('.json')) {
      return uri;
    }
    final dir = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return uri.replace(path: '$dir$fileName');
  }

  /// 目录地址（测试连接时 PROPFIND 它）。
  Uri? get directoryUri {
    final target = targetUri;
    if (target == null) {
      return null;
    }
    final index = target.path.lastIndexOf('/');
    final path = index < 0 ? '/' : target.path.substring(0, index + 1);
    return target.replace(path: path);
  }

  WebDavConfig copyWith({
    String? baseUrl,
    String? username,
    String? password,
    String? fileName,
  }) => WebDavConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    username: username ?? this.username,
    password: password ?? this.password,
    fileName: fileName ?? this.fileName,
  );

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'username': username,
    'password': password,
    'fileName': fileName,
  };

  static WebDavConfig fromJson(Map<String, dynamic> json) => WebDavConfig(
    baseUrl: json['baseUrl'] as String? ?? '',
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    fileName: json['fileName'] as String? ?? defaultFileName,
  );
}

/// WebDAV 设置与「上次备份时间」的持久化。
///
/// 与本地备份分开存：两者互不联动，各自记自己的状态。
class WebDavStore {
  const WebDavStore();

  static const _configKey = 'noto_note.webdav.config.v1';
  static const _lastBackupKey = 'noto_note.webdav.last.v1';

  Future<WebDavConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null) {
      return const WebDavConfig();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return WebDavConfig.fromJson(Map<String, dynamic>.from(decoded));
      }
    } on FormatException {
      // 配置损坏就当没配过
    }
    return const WebDavConfig();
  }

  Future<void> saveConfig(WebDavConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }

  /// 解绑：删掉配置。「上一次备份时间」一并清掉，免得留着上一账号的痕迹。
  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
    await prefs.remove(_lastBackupKey);
  }

  Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    return DateTime.tryParse(prefs.getString(_lastBackupKey) ?? '');
  }

  Future<void> markBackedUp(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupKey, at.toIso8601String());
  }
}

/// 极简 WebDAV 客户端：只用到 PUT / GET / PROPFIND 三个方法。
///
/// 走 `package:http`（纯 Dart），Web 端由浏览器发请求，所以服务端要允许跨域。
class WebDavClient {
  WebDavClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers(WebDavConfig config) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (config.username.isNotEmpty || config.password.isNotEmpty) {
      final token = base64Encode(
        utf8.encode('${config.username}:${config.password}'),
      );
      headers['Authorization'] = 'Basic $token';
    }
    return headers;
  }

  /// 测试连接：PROPFIND 目录，返回 207 / 200 即可。
  Future<void> ping(WebDavConfig config) async {
    final uri = config.directoryUri;
    if (uri == null) {
      throw const BackupException('WebDAV 地址不合法');
    }
    final request = http.Request('PROPFIND', uri)
      ..headers.addAll(_headers(config))
      ..headers['Depth'] = '0';
    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const BackupException('账号或密码不对（服务器拒绝了认证）');
      }
      if (response.statusCode == 404) {
        throw const BackupException('远端目录不存在，先在网盘里建好这个目录');
      }
      if (response.statusCode >= 400 && response.statusCode != 405) {
        throw BackupException('服务器返回 ${response.statusCode}');
      }
    } on BackupException {
      rethrow;
    } catch (error) {
      throw BackupException(_friendly(error));
    }
  }

  /// 把快照写到远端文件。
  Future<void> upload(WebDavConfig config, String payload) async {
    final uri = config.targetUri;
    if (uri == null) {
      throw const BackupException('WebDAV 地址不合法');
    }
    try {
      final response = await _client
          .put(uri, headers: _headers(config), body: utf8.encode(payload))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const BackupException('账号或密码不对（服务器拒绝了认证）');
      }
      if (response.statusCode == 404) {
        throw const BackupException('远端目录不存在');
      }
      if (response.statusCode >= 300) {
        throw BackupException('上传失败：HTTP ${response.statusCode}');
      }
    } on BackupException {
      rethrow;
    } catch (error) {
      throw BackupException(_friendly(error));
    }
  }

  /// 从远端读快照。
  Future<String> download(WebDavConfig config) async {
    final uri = config.targetUri;
    if (uri == null) {
      throw const BackupException('WebDAV 地址不合法');
    }
    try {
      final response = await _client
          .get(uri, headers: _headers(config))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 404) {
        throw const BackupException('远端还没有备份文件');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const BackupException('账号或密码不对（服务器拒绝了认证）');
      }
      if (response.statusCode >= 300) {
        throw BackupException('下载失败：HTTP ${response.statusCode}');
      }
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } on BackupException {
      rethrow;
    } catch (error) {
      throw BackupException(_friendly(error));
    }
  }

  /// 网络层的异常翻成中文，避免把 `ClientException` 直接甩给用户。
  String _friendly(Object error) {
    final text = '$error';
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('ClientException')) {
      return '连不上服务器，检查地址和网络';
    }
    if (text.contains('TimeoutException')) {
      return '请求超时';
    }
    if (text.contains('XMLHttpRequest') || text.contains('CORS')) {
      return '浏览器跨域被拦，服务端要允许跨域';
    }
    return text;
  }

  void close() => _client.close();
}
