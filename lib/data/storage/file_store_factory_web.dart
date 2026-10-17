import 'file_store.dart';
import 'memory_file_store.dart';

/// Web 端：浏览器沙箱内无法访问用户可见的本地文件夹
const bool supportsCustomFolder = false;

/// Web 端固定使用内存存储（根目录参数被忽略）
FileStore createFileStore(String rootPath) => MemoryFileStore();

/// Web 端没有默认目录概念
Future<String> defaultRootPath() async => '';
