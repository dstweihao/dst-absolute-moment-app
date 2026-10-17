/// 文件存储错误分类
///
/// 分类的意义：不同错误要给用户完全不同的指引 ——
/// 权限不足该改目录权限，超时该检查磁盘/网络盘，空间不足该清理。
enum FileStoreErrorKind {
  unavailable,
  permissionDenied,
  notFound,
  conflict,
  noSpace,
  locked,
  notConfigured,
  readonly,
  unknown;

  String get userMessage => switch (this) {
        FileStoreErrorKind.unavailable => '存储目录无法访问 —— 请确认该文件夹存在且可读写',
        FileStoreErrorKind.permissionDenied => '没有权限访问该文件夹，请换一个目录或调整权限',
        FileStoreErrorKind.notFound => '路径不存在',
        FileStoreErrorKind.conflict => '目标已存在',
        FileStoreErrorKind.noSpace => '磁盘空间不足',
        FileStoreErrorKind.locked => '文件被其他程序占用，请稍后重试',
        FileStoreErrorKind.notConfigured => '尚未选择数据文件夹，请先到设置里选定',
        FileStoreErrorKind.readonly => '该位置为只读，无法写入',
        FileStoreErrorKind.unknown => '发生未知错误',
      };

  bool get isRetryable => switch (this) {
        FileStoreErrorKind.unavailable ||
        FileStoreErrorKind.locked =>
          true,
        _ => false,
      };
}

class FileStoreException implements Exception {
  final FileStoreErrorKind kind;
  final String detail;
  final String? path;

  const FileStoreException(
    this.kind, {
    this.detail = '',
    this.path,
  });

  String get message => kind.userMessage;

  @override
  String toString() => 'FileStoreException(${kind.name}'
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

  const StoreEntry({
    required this.path,
    required this.name,
    this.isDirectory = false,
    this.size = 0,
    this.lastModified,
  });

  @override
  String toString() => 'StoreEntry($path, dir=$isDirectory, size=$size)';
}

/// 文件存储抽象
///
/// 把「数据放哪」与「业务怎么用」隔开。当前唯一实现是 [LocalFileStore]
/// （读写用户指定的本地文件夹，由坚果云/OneDrive 等客户端负责同步）。
///
/// 保留抽象层的理由：日后若要做「手机端也走云盘」或「Web 端接 OPFS」，
/// 只需新增实现，四个 repository 零改动。
///
/// 路径约定：一律使用**以 `/` 开头的逻辑路径**（如 `/AbsoluteMoment/config.yaml`），
/// 由实现负责映射到真实位置。不要传 Windows 反斜杠路径。
abstract class FileStore {
  /// 设置页展示用
  String get description;

  /// 目录存在且可读写才算通过。失败抛 [FileStoreException]。
  Future<void> testConnection();

  /// 不存在时抛 [FileStoreErrorKind.notFound]
  Future<String> read(String path);

  /// 不存在时返回 null，供「首次运行」判断
  Future<String?> readOrNull(String path);

  /// 自动创建所需的父目录
  Future<void> write(String path, String content);

  Future<void> delete(String path);

  Future<bool> exists(String path);

  /// 已存在则静默跳过
  Future<void> ensureDirectory(String path);

  Future<List<StoreEntry>> list(String path);

  /// 不存在返回 null
  Future<StoreEntry?> stat(String path);
}
