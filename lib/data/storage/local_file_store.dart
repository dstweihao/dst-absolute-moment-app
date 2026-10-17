import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_store.dart';

/// 本地文件夹存储实现（桌面 / 移动端）
///
/// 数据直接读写用户指定的文件夹。同步交给外部工具 ——
/// 用户把该文件夹放进坚果云同步目录，坚果云客户端负责跨设备同步；
/// APP 本身完全不感知"云"的存在，因此**离线也能用**。
///
/// 路径映射：逻辑路径 `/AbsoluteMoment/config.yaml` →
/// `<root>\AbsoluteMoment\config.yaml`
class LocalFileStore implements FileStore {
  /// 存储根目录（绝对路径）
  final String rootPath;

  LocalFileStore(this.rootPath);

  Directory get _root => Directory(rootPath);

  @override
  String get description => rootPath;

  // ------------------------------------------------------------------
  // 路径映射
  // ------------------------------------------------------------------

  /// 逻辑路径 → 本机绝对路径
  ///
  /// 拒绝 `..` 逃逸：所有解析结果必须仍在 root 之内，
  /// 否则一个恶意/写错的路径就能覆盖系统文件。
  String _resolve(String logicalPath) {
    final normalized = logicalPath.replaceAll('\\', '/');
    final relative = normalized.startsWith('/')
        ? normalized.substring(1)
        : normalized;

    final resolved = p.normalize(p.join(rootPath, relative));
    final rootNormalized = p.normalize(rootPath);

    if (resolved != rootNormalized &&
        !p.isWithin(rootNormalized, resolved)) {
      throw FileStoreException(
        FileStoreErrorKind.permissionDenied,
        path: logicalPath,
        detail: '路径越出存储根目录',
      );
    }
    return resolved;
  }

  /// 本机绝对路径 → 逻辑路径（list/stat 回填用）
  String _toLogical(String absolutePath) {
    final rel = p.relative(absolutePath, from: rootPath);
    return '/${rel.replaceAll('\\', '/')}';
  }

  /// 把 dart:io 的异常翻译成带语义的 [FileStoreException]
  Never _fail(Object error, String logicalPath) {
    if (error is FileStoreException) throw error;

    if (error is FileSystemException) {
      final message = error.osError?.message ?? error.message;
      final code = error.osError?.errorCode;

      // Windows: 5=拒绝访问 32=被占用 112=空间不足 3=路径不存在
      // POSIX:  13=EACCES 28=ENOSPC 30=EROFS
      final kind = switch (code) {
        5 || 13 => FileStoreErrorKind.permissionDenied,
        32 => FileStoreErrorKind.locked,
        112 || 28 => FileStoreErrorKind.noSpace,
        30 => FileStoreErrorKind.readonly,
        2 || 3 => FileStoreErrorKind.unavailable,
        _ => FileStoreErrorKind.unknown,
      };
      throw FileStoreException(kind, path: logicalPath, detail: message);
    }
    throw FileStoreException(
      FileStoreErrorKind.unknown,
      path: logicalPath,
      detail: error.toString(),
    );
  }

  // ------------------------------------------------------------------
  // FileStore
  // ------------------------------------------------------------------

  @override
  Future<void> testConnection() async {
    try {
      if (!_root.existsSync()) {
        await _root.create(recursive: true);
      }
      // 真写一次探针，才能确认「可写」而不只是「存在」——
      // 只读盘 / 权限不足只有真写才会暴露。
      final probe = File(p.join(rootPath, '.absolute_moment_probe'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
    } catch (e) {
      _fail(e, '/');
    }
  }

  @override
  Future<String> read(String path) async {
    final file = File(_resolve(path));
    if (!await file.exists()) {
      throw FileStoreException(
        FileStoreErrorKind.notFound,
        path: path,
        detail: '文件不存在',
      );
    }
    try {
      return await file.readAsString();
    } catch (e) {
      _fail(e, path);
    }
  }

  @override
  Future<String?> readOrNull(String path) async {
    final file = File(_resolve(path));
    if (!await file.exists()) return null;
    try {
      return await file.readAsString();
    } catch (e) {
      _fail(e, path);
    }
  }

  @override
  Future<void> write(String path, String content) async {
    final file = File(_resolve(path));
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(content, flush: true);
    } catch (e) {
      _fail(e, path);
    }
  }

  @override
  Future<void> delete(String path) async {
    final target = _resolve(path);
    try {
      final dir = Directory(target);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return;
      }
      final file = File(target);
      if (await file.exists()) {
        await file.delete();
        return;
      }
      throw FileStoreException(
        FileStoreErrorKind.notFound,
        path: path,
        detail: '路径不存在',
      );
    } catch (e) {
      _fail(e, path);
    }
  }

  @override
  Future<bool> exists(String path) async {
    try {
      final target = _resolve(path);
      return await File(target).exists() || await Directory(target).exists();
    } on FileStoreException {
      // 路径越界等 —— 视为不存在，而不是让调用方炸掉
      return false;
    }
  }

  @override
  Future<void> ensureDirectory(String path) async {
    try {
      await Directory(_resolve(path)).create(recursive: true);
    } catch (e) {
      _fail(e, path);
    }
  }

  @override
  Future<List<StoreEntry>> list(String path) async {
    final dir = Directory(_resolve(path));
    if (!await dir.exists()) {
      throw FileStoreException(
        FileStoreErrorKind.notFound,
        path: path,
        detail: '目录不存在',
      );
    }
    try {
      final entries = <StoreEntry>[];
      await for (final entity in dir.list(followLinks: false)) {
        entries.add(await _entryOf(entity));
      }
      entries.sort((a, b) {
        // 目录在前，同类按名称排序 —— 让调用方拿到稳定顺序
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.compareTo(b.name);
      });
      return entries;
    } catch (e) {
      _fail(e, path);
    }
  }

  @override
  Future<StoreEntry?> stat(String path) async {
    final target = _resolve(path);
    final file = File(target);
    if (await file.exists()) return _entryOf(file);

    final dir = Directory(target);
    if (await dir.exists()) return _entryOf(dir);

    return null;
  }

  Future<StoreEntry> _entryOf(FileSystemEntity entity) async {
    final isDir = entity is Directory;
    var size = 0;
    DateTime? modified;

    try {
      final s = await entity.stat();
      modified = s.modified;
      if (!isDir) size = s.size;
    } catch (_) {
      // 拿不到元信息不该让整个 list 失败（同步中的文件常见）
    }

    return StoreEntry(
      path: _toLogical(entity.path),
      name: p.basename(entity.path),
      isDirectory: isDir,
      size: size,
      lastModified: modified,
    );
  }
}
