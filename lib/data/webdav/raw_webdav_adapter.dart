import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'nutstore_client.dart';

/// 手工实现的坚果云 WebDAV 客户端
///
/// 为什么不用现成的 `webdav_client` 包：该包最后发布于 2024-05，
/// 已停更两年多，在 Dart 3.13 下能否正常工作无法预先验证。
/// 而本 APP 只需要 5 个动词（PROPFIND / GET / PUT / DELETE / MKCOL），
/// 自己实现约 200 行，换来零依赖风险与完全可控的重试策略。
class RawWebdavAdapter implements FileStore {
  /// WebDAV 服务地址，默认坚果云
  final String baseUrl;

  /// 坚果云注册邮箱
  final String username;

  /// 应用密码（不是登录密码）
  final String appPassword;

  final http.Client _http;

  /// 是否由本实例创建 http.Client（决定 dispose 时是否关闭）
  final bool _ownsClient;

  /// MKCOL 之间的强制间隔 —— 坚果云对建目录有频率限制
  final Duration mkcolDelay;

  /// 单次请求超时
  final Duration timeout;

  /// 最大重试次数（针对可重试错误）
  final int maxRetries;

  RawWebdavAdapter({
    required this.username,
    required this.appPassword,
    this.baseUrl = 'https://dav.jianguoyun.com/dav/',
    http.Client? httpClient,
    this.mkcolDelay = const Duration(milliseconds: 500),
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 2,
  })  : _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  // ------------------------------------------------------------------
  // 公共 API
  // ------------------------------------------------------------------

  @override
  Future<void> testConnection() async {
    // 对根目录做一次 Depth:0 的 PROPFIND —— 最轻量的认证校验
    await _propfind('', depth: 0);
  }

  @override
  Future<String> read(String path) async {
    final content = await readOrNull(path);
    if (content == null) {
      throw FileStoreException(
        FileStoreErrorKind.notFound,
        path: path,
        detail: '文件不存在',
      );
    }
    return content;
  }

  @override
  Future<String?> readOrNull(String path) async {
    final response = await _send(
      'GET',
      path,
      retryable: true,
    );

    if (response.statusCode == 404) return null;
    if (response.statusCode == 200) {
      // 坚果云返回 UTF-8；用 bodyBytes 避免 http 包按 latin1 误解码
      return utf8.decode(response.bodyBytes);
    }
    throw _toException(response, path);
  }

  @override
  Future<void> write(String path, String content) async {
    // 先确保父目录存在
    final parent = _parentOf(path);
    if (parent.isNotEmpty) {
      await ensureDirectory(parent);
    }

    final response = await _send(
      'PUT',
      path,
      body: utf8.encode(content),
      contentType: 'text/markdown; charset=utf-8',
      retryable: true,
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw _toException(response, path);
    }
  }

  @override
  Future<void> delete(String path) async {
    final response = await _send('DELETE', path, retryable: true);
    if (response.statusCode == 404) return; // 已不存在视为成功
    if (response.statusCode != 200 &&
        response.statusCode != 204 &&
        response.statusCode != 207) {
      throw _toException(response, path);
    }
  }

  @override
  Future<bool> exists(String path) async {
    if (path.isEmpty || path == '/') return true;
    try {
      final entry = await stat(path);
      return entry != null;
    } on FileStoreException catch (e) {
      if (e.kind == FileStoreErrorKind.notFound) return false;
      rethrow;
    }
  }

  @override
  Future<void> ensureDirectory(String path) async {
    final normalized = _normalizeDir(path);
    if (normalized.isEmpty || normalized == '/') return;

    // 逐级创建：/a/b/c → /a, /a/b, /a/b/c
    final segments = normalized.split('/').where((s) => s.isNotEmpty).toList();
    var current = '';

    for (final segment in segments) {
      current = '$current/$segment';
      if (await exists(current)) continue;

      final response = await _send('MKCOL', current, retryable: true);

      // 201 创建成功；405 = 已存在（并发情形）；409 = 父目录缺失（下面已逐级创建，不应出现）
      if (response.statusCode != 201 && response.statusCode != 405) {
        throw _toException(response, current);
      }

      // 规避坚果云的建目录频率限制
      await Future<void>.delayed(mkcolDelay);
    }
  }

  @override
  Future<List<StoreEntry>> list(String path) async {
    final response = await _propfind(path, depth: 1);
    if (response.statusCode == 404) {
      throw FileStoreException(
        FileStoreErrorKind.notFound,
        path: path,
        detail: '目录不存在',
      );
    }
    if (response.statusCode != 207) {
      throw _toException(response, path);
    }

    final entries = _parseMultiStatus(response.bodyBytes, path);
    // 过滤掉目录自身
    final selfPath = _normalizeFile(path);
    return entries.where((e) => e.path != selfPath).toList();
  }

  @override
  Future<StoreEntry?> stat(String path) async {
    final response = await _propfind(path, depth: 0);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 207) {
      throw _toException(response, path);
    }
    final entries = _parseMultiStatus(response.bodyBytes, path);
    return entries.isEmpty ? null : entries.first;
  }

  @override
  void dispose() {
    if (_ownsClient) _http.close();
  }

  // ------------------------------------------------------------------
  // HTTP 发送与重试
  // ------------------------------------------------------------------

  Future<http.Response> _send(
    String method,
    String path, {
    List<int>? body,
    String? contentType,
    Map<String, String>? extraHeaders,
    bool retryable = false,
  }) async {
    final uri = _buildUri(path);
    var attempt = 0;
    var delay = const Duration(milliseconds: 800);

    while (true) {
      attempt++;
      try {
        final request = http.Request(method, uri);
        request.headers.addAll(_baseHeaders);
        if (contentType != null) {
          request.headers['Content-Type'] = contentType;
        }
        if (extraHeaders != null) request.headers.addAll(extraHeaders);
        if (body != null) request.bodyBytes = body;

        final streamed = await _http.send(request).timeout(timeout);
        final response = await http.Response.fromStream(streamed);

        // 可重试的服务端错误
        if (retryable &&
            attempt <= maxRetries &&
            _isRetryableStatus(response.statusCode)) {
          await Future<void>.delayed(delay);
          delay *= 2;
          continue;
        }
        return response;
      } on TimeoutException catch (e) {
        if (attempt > maxRetries) {
          throw FileStoreException(
            FileStoreErrorKind.network,
            path: path,
            detail: '请求超时：$e',
          );
        }
        await Future<void>.delayed(delay);
        delay *= 2;
      } on http.ClientException catch (e) {
        if (attempt > maxRetries) {
          throw FileStoreException(
            FileStoreErrorKind.network,
            path: path,
            detail: e.message,
          );
        }
        await Future<void>.delayed(delay);
        delay *= 2;
      } on Exception catch (e) {
        throw FileStoreException(
          FileStoreErrorKind.network,
          path: path,
          detail: e.toString(),
        );
      }
    }
  }

  Future<http.Response> _propfind(String path, {required int depth}) async {
    const bodyXml = '<?xml version="1.0" encoding="utf-8"?>'
        '<D:propfind xmlns:D="DAV:"><D:prop>'
        '<D:resourcetype/>'
        '<D:getcontentlength/>'
        '<D:getlastmodified/>'
        '<D:getetag/>'
        '</D:prop></D:propfind>';

    return _send(
      'PROPFIND',
      path,
      body: utf8.encode(bodyXml),
      contentType: 'application/xml; charset=utf-8',
      extraHeaders: {'Depth': depth.toString()},
      retryable: true,
    );
  }

  bool _isRetryableStatus(int status) =>
      status == 429 || status == 423 || (status >= 500 && status < 600);

  Map<String, String> get _baseHeaders {
    final credentials = base64Encode(utf8.encode('$username:$appPassword'));
    return {
      'Authorization': 'Basic $credentials',
      'User-Agent': 'AbsoluteMomentApp/1.0',
      'Accept': '*/*',
    };
  }

  // ------------------------------------------------------------------
  // 路径与 URL
  // ------------------------------------------------------------------

  Uri _buildUri(String path) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final relative = _normalizeFile(path).replaceFirst(RegExp(r'^/'), '');
    return Uri.parse('$base${_encodePath(relative)}');
  }

  /// 逐段 URL 编码，保留 `/` 分隔符
  ///
  /// 坚果云要求路径用英文，但用户仍可能填中文目录名 —— 编码后至少不会崩。
  static String _encodePath(String path) {
    return path
        .split('/')
        .map((seg) => Uri.encodeComponent(seg))
        .join('/');
  }

  /// 规范化为以 `/` 开头的文件路径
  static String _normalizeFile(String path) {
    var p = path.trim();
    if (p.isEmpty) return '/';
    if (!p.startsWith('/')) p = '/$p';
    // 去掉末尾斜杠（根目录除外）
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  /// 规范化为目录路径
  static String _normalizeDir(String path) {
    final p = _normalizeFile(path);
    return p == '/' ? '/' : p;
  }

  /// 取父目录，如 `/a/b/c.md` → `/a/b`
  static String _parentOf(String path) {
    final p = _normalizeFile(path);
    final idx = p.lastIndexOf('/');
    if (idx <= 0) return '';
    return p.substring(0, idx);
  }

  // ------------------------------------------------------------------
  // 207 Multi-Status 解析
  // ------------------------------------------------------------------

  List<StoreEntry> _parseMultiStatus(List<int> bytes, String requestPath) {
    final result = <StoreEntry>[];

    XmlDocument doc;
    try {
      doc = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return result;
    }

    // 命名空间前缀各家实现不一（D: / d: / 无前缀），统一按 local name 匹配
    final responses = doc.findAllElements('response');
    for (final response in responses) {
      String? href;
      var isDirectory = false;
      var size = 0;
      DateTime? lastModified;
      String? etag;

      for (final child in response.childElements) {
        switch (child.localName) {
          case 'href':
            href = child.innerText.trim();
            break;
          case 'propstat':
            for (final propstatChild in child.childElements) {
              if (propstatChild.localName == 'status') {
                // 只处理 200 OK 的 propstat
                if (!propstatChild.innerText.contains('200')) {
                  continue;
                }
              }
              if (propstatChild.localName != 'prop') continue;
              for (final prop in propstatChild.childElements) {
                switch (prop.localName) {
                  case 'resourcetype':
                    if (prop.childElements.isNotEmpty) isDirectory = true;
                    break;
                  case 'getcontentlength':
                    size = int.tryParse(prop.innerText.trim()) ?? 0;
                    break;
                  case 'getlastmodified':
                    lastModified =
                        _parseHttpDate(prop.innerText.trim());
                    break;
                  case 'getetag':
                    etag = prop.innerText.trim();
                    break;
                }
              }
            }
            break;
        }
      }

      if (href == null) continue;

      final decoded = _decodeHref(href);
      result.add(StoreEntry(
        path: decoded,
        name: _nameOf(decoded),
        isDirectory: isDirectory,
        size: size,
        lastModified: lastModified,
        etag: etag,
      ));
    }

    return result;
  }

  /// href 是完整 URL 或绝对路径，统一转成以 `/` 开头并 URL 解码
  static String _decodeHref(String href) {
    var h = href;
    if (h.startsWith('http://') || h.startsWith('https://')) {
      final uri = Uri.tryParse(h);
      if (uri != null) h = uri.path;
    }
    try {
      h = Uri.decodeComponent(h);
    } catch (_) {
      // 解码失败则原样使用
    }
    if (!h.startsWith('/')) h = '/$h';
    // 去掉坚果云 base 路径前缀 /dav
    const davPrefix = '/dav';
    if (h == davPrefix) return '/';
    if (h.startsWith('$davPrefix/')) {
      h = h.substring(davPrefix.length);
    }
    while (h.length > 1 && h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    return h;
  }

  static String _nameOf(String path) {
    final idx = path.lastIndexOf('/');
    if (idx < 0 || idx == path.length - 1) return path;
    return path.substring(idx + 1);
  }

  /// 解析 HTTP 日期（RFC 1123），如 `Mon, 29 Sep 2026 06:56:47 GMT`
  static DateTime? _parseHttpDate(String raw) {
    if (raw.isEmpty) return null;
    try {
      return _httpDateFormatter.parse(raw).toUtc();
    } catch (_) {
      return DateTime.tryParse(raw);
    }
  }

  static final _httpDateFormatter = _Rfc1123();

  // ------------------------------------------------------------------
  // 错误映射
  // ------------------------------------------------------------------

  FileStoreException _toException(http.Response response, String path) {
    final kind = switch (response.statusCode) {
      401 => FileStoreErrorKind.unauthorized,
      403 => FileStoreErrorKind.forbidden,
      404 => FileStoreErrorKind.notFound,
      409 => FileStoreErrorKind.conflict,
      423 => FileStoreErrorKind.locked,
      429 => FileStoreErrorKind.rateLimited,
      >= 500 && < 600 => FileStoreErrorKind.server,
      _ => FileStoreErrorKind.unknown,
    };

    return FileStoreException(
      kind,
      statusCode: response.statusCode,
      path: path,
      detail: _snippet(response),
    );
  }

  static String _snippet(http.Response response) {
    try {
      final text = utf8.decode(response.bodyBytes, allowMalformed: true);
      return text.length > 200 ? '${text.substring(0, 200)}…' : text;
    } catch (_) {
      return '';
    }
  }
}

/// 极简 RFC 1123 日期解析器
///
/// 不引 intl 的 DateFormat（其模式串对英文月份缩写支持需要额外 locale 数据），
/// 手写映射更可靠且零依赖。
class _Rfc1123 {
  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  const _Rfc1123();

  DateTime parse(String input) {
    // 形如：Mon, 29 Sep 2026 06:56:47 GMT
    final cleaned = input.replaceAll(',', ' ').trim();
    final parts = cleaned.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

    // 跳过星期缩写
    var i = 0;
    if (parts.isNotEmpty && RegExp(r'^[A-Za-z]{3}$').hasMatch(parts[0])) {
      i = 1;
    }
    if (parts.length < i + 4) {
      throw FormatException('无法解析日期: $input');
    }

    final day = int.parse(parts[i]);
    final month = _months[parts[i + 1].toLowerCase()];
    if (month == null) throw FormatException('未知月份: ${parts[i + 1]}');
    final year = int.parse(parts[i + 2]);

    var hour = 0, minute = 0, second = 0;
    if (parts.length > i + 3) {
      final timeParts = parts[i + 3].split(':');
      hour = int.tryParse(timeParts.elementAtOrNull(0) ?? '') ?? 0;
      minute = int.tryParse(timeParts.elementAtOrNull(1) ?? '') ?? 0;
      second = int.tryParse(timeParts.elementAtOrNull(2) ?? '') ?? 0;
    }

    return DateTime.utc(year, month, day, hour, minute, second);
  }
}

extension _FirstOrNull<T> on List<T> {
  T? elementAtOrNull(int index) =>
      (index >= 0 && index < length) ? this[index] : null;
}
