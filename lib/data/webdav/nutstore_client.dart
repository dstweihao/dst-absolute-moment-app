/// WebDAV 错误分类
///
/// 分类的意义：不同错误要给用户完全不同的指引 ——
/// 401 该去重填密码，超时该检查网络，429 该稍等重试。
enum FileStoreErrorKind {
  network,
  unauthorized,
  forbidden,
  notFound,
  rateLimited,
  conflict,
  server,
  locked,
  unknown;

  String get userMessage => switch (this) {
        FileStoreErrorKind.network => '网络连接失败，请检查网络后重试',
        FileStoreErrorKind.unauthorized =>
          '坚果云认证失败 —— 请确认邮箱与应用密码是否正确（注意不是登录密码）',
        FileStoreErrorKind.forbidden => '没有权限访问该路径',
        FileStoreErrorKind.notFound => '路径不存在',
        FileStoreErrorKind.rateLimited => '请求过于频繁，坚果云暂时限流，请稍后重试',
        FileStoreErrorKind.conflict => '目标已存在',
        FileStoreErrorKind.server => '坚果云服务暂时不可用，请稍后重试',
        FileStoreErrorKind.locked => '文件被占用，请稍后重试',
        FileStoreErrorKind.unknown => '发生未知错误',
      };

  bool get isRetryable => switch (this) {
        FileStoreErrorKind.network ||
        FileStoreErrorKind.rateLimited ||
        FileStoreErrorKind.server ||
        FileStoreErrorKind.locked =>
          true,
        _ => false,
      };

  bool get requiresReauth => this == FileStoreErrorKind.unauthorized;
}

class FileStoreException implements Exception {
  final FileStoreErrorKind kind;
  final String detail;
  final int? statusCode;
  final String? path;

  const FileStoreException(
    this.kind, {
    this.detail = '',
    this.statusCode,
    this.path,
  });

  String get message => kind.userMessage;

  @override
  String toString() =>
      'FileStoreException(${kind.name}'
      '${statusCode != null ? ' HTTP $statusCode' : ''}'
      '${path != null ? ' at $path' : ''}'
      '${detail.isNotEmpty ? ': $detail' : ''})';
}

class StoreEntry {
  /// 如 `/AbsoluteMoment/checkins/2026-09-29.md`
  final String path;

  final String name;
  final bool isDirectory;

  /// 目录为 0
  final int size;

  final DateTime? lastModified;

  /// 用于乐观并发控制
  final String? etag;

  const StoreEntry({
    required this.path,
    required this.name,
    this.isDirectory = false,
    this.size = 0,
    this.lastModified,
    this.etag,
  });

  @override
  String toString() =>
      'StoreEntry($path, dir=$isDirectory, size=$size)';
}

/// 坚果云 WebDAV 客户端接口
///
/// 抽象这一层的意义：WebDAV 只是当下的存储选择。若日后改用别的
/// 同步方案（自建网关、其他网盘），只需换实现，上层 repository 零改动。
abstract class FileStore {
  /// 失败时抛 [FileStoreException]，调用方据 kind 给出针对性提示
  Future<void> testConnection();

  /// 不存在时抛 [FileStoreErrorKind.notFound]
  Future<String> read(String path);

  /// 不存在时返回 null，供「首次运行」判断
  Future<String?> readOrNull(String path);

  /// 自动创建所需的父目录
  Future<void> write(String path, String content);

  Future<void> delete(String path);

  Future<bool> exists(String path);

  /// 已存在则静默跳过。
  ///
  /// ⚠️ 坚果云对 MKCOL 有频率限制，实现内部必须逐级创建并加延时。
  Future<void> ensureDirectory(String path);

  Future<List<StoreEntry>> list(String path);

  /// 不存在返回 null
  Future<StoreEntry?> stat(String path);

  void dispose();
}
