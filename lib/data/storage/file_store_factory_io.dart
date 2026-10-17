import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'file_store.dart';
import 'local_file_store.dart';

/// 桌面 / 移动端：支持用户自选文件夹
const bool supportsCustomFolder = true;

/// 按根目录同步创建存储
///
/// 刻意保持同步：仓库层因此可以同步拿到 [FileStore]，
/// 目录解析（可能异步的 path_provider）统一放在启动期完成。
FileStore createFileStore(String rootPath) => LocalFileStore(rootPath);

/// 默认数据文件夹
///
/// 桌面端优先落在坚果云同步根目录 —— 打卡记录等放进同步盘，
/// 手机与电脑自然共用同一份数据；找不到就退到「文档/AbsoluteMoment」。
///
/// 注意：这里只决定**数据**放哪。学习路线是另一个独立设置
/// （见 `learningRootProvider`），不从这个目录读取。
Future<String> defaultRootPath() async {
  if (Platform.isWindows) {
    const syncRoot = r'C:\我的坚果云';
    if (Directory(syncRoot).existsSync()) return syncRoot;
  }

  final docs = await getApplicationDocumentsDirectory();
  return p.join(docs.path, 'AbsoluteMoment');
}
