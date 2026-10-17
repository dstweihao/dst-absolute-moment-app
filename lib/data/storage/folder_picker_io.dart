import 'package:file_selector/file_selector.dart';

/// 打开系统原生的「选择文件夹」对话框，返回选中的目录路径。
///
/// - Windows / macOS / Linux：原生支持，返回真实文件系统路径。
/// - Android / iOS：`file_selector` 没有目录选择器，会抛
///   [UnimplementedError]；这里吞掉并返回 null，调用方回退到手动输入。
/// - 用户点「取消」同样返回 null。
Future<String?> pickFolder({String? initialDirectory}) async {
  try {
    return await getDirectoryPath(
      initialDirectory: initialDirectory,
      confirmButtonText: '选择此文件夹',
      canCreateDirectories: true,
    );
  } catch (_) {
    return null;
  }
}
