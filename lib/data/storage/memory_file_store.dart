import 'file_store.dart';

/// 内存存储实现（Web 端兜底）
///
/// 浏览器沙箱里没有用户可见的「本地文件夹」，`dart:io` 也不可用。
/// 这里提供一个纯内存实现，保证 Web 端**能编译、能运行、能走完全流程**，
/// 代价是刷新页面后数据丢失。
///
/// ⚠️ 这是有意的取舍，不是遗漏：Web 端定位为「预览 / 演示」，
/// 真正落盘使用请用桌面端或移动端。
class MemoryFileStore implements FileStore {
  final Map<String, String> _files = {};
  final Set<String> _dirs = {'/'};

  @override
  String get description => '浏览器内存（刷新后清空）';

  // ------------------------------------------------------------------

  /// 规范化逻辑路径：统一分隔符、去掉末尾斜杠、折叠 `.` 与 `..`
  String _norm(String path) {
    final parts = <String>[];
    for (final seg in path.replaceAll('\\', '/').split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (parts.isNotEmpty) parts.removeLast();
        continue;
      }
      parts.add(seg);
    }
    return '/${parts.join('/')}';
  }

  String? _parentOf(String path) {
    final i = path.lastIndexOf('/');
    if (i <= 0) return null;
    return path.substring(0, i);
  }

  void _mkdirs(String path) {
    var current = path;
    while (current.isNotEmpty && current != '/') {
      _dirs.add(current);
      final parent = _parentOf(current);
      if (parent == null) break;
      current = parent;
    }
    _dirs.add('/');
  }

  // ------------------------------------------------------------------

  @override
  Future<void> testConnection() async {
    // 内存存储永远可用
  }

  @override
  Future<String> read(String path) async {
    final key = _norm(path);
    final content = _files[key];
    if (content == null) {
      throw FileStoreException(
        FileStoreErrorKind.notFound,
        path: key,
        detail: '文件不存在',
      );
    }
    return content;
  }

  @override
  Future<String?> readOrNull(String path) async => _files[_norm(path)];

  @override
  Future<void> write(String path, String content) async {
    final key = _norm(path);
    final parent = _parentOf(key);
    if (parent != null) _mkdirs(parent);
    _files[key] = content;
  }

  @override
  Future<void> delete(String path) async {
    final key = _norm(path);
    if (_files.remove(key) != null) return;

    // 目录删除：连同子树一起清掉
    if (_dirs.contains(key)) {
      _dirs.removeWhere((d) => d == key || d.startsWith('$key/'));
      _files.removeWhere((f, _) => f.startsWith('$key/'));
      return;
    }
    throw FileStoreException(
      FileStoreErrorKind.notFound,
      path: key,
      detail: '路径不存在',
    );
  }

  @override
  Future<bool> exists(String path) async {
    final key = _norm(path);
    return _files.containsKey(key) || _dirs.contains(key);
  }

  @override
  Future<void> ensureDirectory(String path) async => _mkdirs(_norm(path));

  @override
  Future<List<StoreEntry>> list(String path) async {
    final key = _norm(path);
    if (!_dirs.contains(key)) {
      throw FileStoreException(
        FileStoreErrorKind.notFound,
        path: key,
        detail: '目录不存在',
      );
    }

    final prefix = key == '/' ? '/' : '$key/';
    final seen = <String, StoreEntry>{};

    void consider(String child) {
      if (!child.startsWith(prefix) || child == key) return;
      final rest = child.substring(prefix.length);
      if (rest.isEmpty || rest.contains('/')) return; // 只看直接子项
      seen[child] = StoreEntry(
        path: child,
        name: rest,
        isDirectory: true,
      );
    }

    _dirs.forEach(consider);
    for (final file in _files.keys) {
      consider(file);
      if (seen.containsKey(file) && _files.containsKey(file)) {
        seen[file] = StoreEntry(
          path: file,
          name: file.substring(file.lastIndexOf('/') + 1),
          size: _files[file]!.length,
        );
      }
    }

    final entries = seen.values.toList()
      ..sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    return entries;
  }

  @override
  Future<StoreEntry?> stat(String path) async {
    final key = _norm(path);
    final content = _files[key];
    if (content != null) {
      return StoreEntry(
        path: key,
        name: key.substring(key.lastIndexOf('/') + 1),
        size: content.length,
      );
    }
    if (_dirs.contains(key)) {
      return StoreEntry(
        path: key,
        name: key == '/' ? '/' : key.substring(key.lastIndexOf('/') + 1),
        isDirectory: true,
      );
    }
    return null;
  }
}
