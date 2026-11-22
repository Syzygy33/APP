import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// WebDAV 连接配置
class WebDavConfig {
  /// 例如 https://dav.jianguoyun.com/dav/
  final String baseUrl;
  final String username;
  final String remotePath;

  const WebDavConfig({
    this.baseUrl = '',
    this.username = '',
    this.remotePath = 'NotoBox',
  });

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty && username.trim().isNotEmpty;

  /// 规范化：保证 base 以 `/` 结尾，remotePath 去掉首尾斜杠
  String get normalizedBase {
    final b = baseUrl.trim();
    if (b.isEmpty) return '';
    return b.endsWith('/') ? b : '$b/';
  }

  String get normalizedRemote =>
      remotePath.trim().replaceAll(RegExp(r'^/+|/+$'), '');

  /// 远端目录（多级时用 `/` 分隔）
  String get directoryUrl {
    final remote = normalizedRemote;
    return remote.isEmpty ? normalizedBase : '$normalizedBase$remote/';
  }

  /// 快照文件地址
  String get snapshotUrl => '${directoryUrl}notobox-snapshot.zip';

  WebDavConfig copyWith({
    String? baseUrl,
    String? username,
    String? remotePath,
  }) => WebDavConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    username: username ?? this.username,
    remotePath: remotePath ?? this.remotePath,
  );

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'username': username,
    'remotePath': remotePath,
  };

  factory WebDavConfig.fromJson(Map<String, dynamic> j) => WebDavConfig(
    baseUrl: (j['baseUrl'] as String?) ?? '',
    username: (j['username'] as String?) ?? '',
    remotePath: (j['remotePath'] as String?) ?? 'NotoBox',
  );
}

/// WebDAV 调用失败，携带可直接展示给用户的中文原因
class WebDavException implements Exception {
  final String message;
  final int? statusCode;

  const WebDavException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// 最小可用的 WebDAV 客户端：只实现备份同步需要的四个动作
/// （PROPFIND 校验、MKCOL 建目录、PUT 上传、GET 下载），
/// 不引入体积更大的三方 WebDAV 包。
class WebDavClient {
  final WebDavConfig config;
  final String password;
  final http.Client _client;
  final Duration timeout;

  WebDavClient({
    required this.config,
    required this.password,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
    'Authorization':
        'Basic ${base64Encode(utf8.encode('${config.username}:$password'))}',
  };

  Uri _uri(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw const WebDavException('服务器地址格式不正确，请包含 http:// 或 https://');
    }
    return uri;
  }

  /// 校验服务器与账号：PROPFIND 根目录，207/200 视为可用
  Future<void> testConnection() async {
    final uri = _uri(config.directoryUrl);
    try {
      final request = http.Request('PROPFIND', uri)
        ..headers.addAll(_headers)
        ..headers['Depth'] = '0';
      final streamed = await _client.send(request).timeout(timeout);
      final status = streamed.statusCode;
      // 目录可能尚不存在，此时 404 说明账号是可用的
      if (status == 207 || status == 200 || status == 404) return;
      throw _mapError(status);
    } on TimeoutException {
      throw const WebDavException('连接超时，请检查地址与网络');
    } on WebDavException {
      rethrow;
    } on Object catch (e) {
      throw WebDavException('无法连接服务器：${_short(e)}');
    }
  }

  /// 确保远端目录存在（支持多级），已存在时忽略 405
  Future<void> ensureDirectory() async {
    final remote = config.normalizedRemote;
    if (remote.isEmpty) return;
    final segments = remote.split('/').where((s) => s.isNotEmpty);
    var path = config.normalizedBase;
    for (final segment in segments) {
      path = '$path$segment/';
      await _mkcol(path);
    }
  }

  Future<void> _mkcol(String url) async {
    final uri = _uri(url);
    try {
      final request = http.Request('MKCOL', uri)..headers.addAll(_headers);
      final streamed = await _client.send(request).timeout(timeout);
      final status = streamed.statusCode;
      // 201 创建成功；405 已存在；409 父目录缺失（上一级已创建，理论上不会命中）
      if (status == 201 || status == 405 || status == 200 || status == 301) {
        return;
      }
      throw _mapError(status);
    } on TimeoutException {
      throw const WebDavException('创建远端目录超时');
    } on WebDavException {
      rethrow;
    } on Object catch (e) {
      throw WebDavException('创建远端目录失败：${_short(e)}');
    }
  }

  /// 下载远端备份包；不存在时返回 null
  Future<Uint8List?> downloadSnapshot() async {
    final uri = _uri(config.snapshotUrl);
    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(timeout);
      if (response.statusCode == 404) return null;
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      throw _mapError(response.statusCode);
    } on TimeoutException {
      throw const WebDavException('下载超时');
    } on WebDavException {
      rethrow;
    } on Object catch (e) {
      throw WebDavException('下载失败：${_short(e)}');
    }
  }

  /// 上传备份包（覆盖写）
  Future<void> uploadSnapshot(Uint8List bytes) async {
    await ensureDirectory();
    final uri = _uri(config.snapshotUrl);
    try {
      final response = await _client
          .put(
            uri,
            headers: {..._headers, 'Content-Type': 'application/zip'},
            body: bytes,
          )
          .timeout(timeout);
      final status = response.statusCode;
      // 201 新建 / 200 覆盖 / 204 无内容 / 207 部分成功
      if (status == 201 || status == 200 || status == 204 || status == 207) {
        return;
      }
      throw _mapError(status);
    } on TimeoutException {
      throw const WebDavException('上传超时，文件可能较大或网络较慢');
    } on WebDavException {
      rethrow;
    } on Object catch (e) {
      throw WebDavException('上传失败：${_short(e)}');
    }
  }

  void close() => _client.close();

  WebDavException _mapError(int status) {
    final message = switch (status) {
      401 => '账号或密码不正确（401）',
      403 => '账号无权限写入该目录（403）',
      404 => '远端目录不存在（404），请检查路径',
      405 => '服务器不接受该请求（405），请确认地址是 WebDAV 服务',
      409 => '远端目录层级不完整（409）',
      413 => '数据超出服务器容量限制（413）',
      423 => '远端文件被锁定（423），稍后重试',
      507 => '服务器存储空间不足（507）',
      >= 500 => '服务器错误（$status），稍后再试',
      _ => '请求失败（$status）',
    };
    return WebDavException(message, statusCode: status);
  }

  String _short(Object e) {
    final text = e.toString();
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }
}
