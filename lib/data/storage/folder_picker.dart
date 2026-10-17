/// 文件夹选择器 —— 按平台在编译期分派
///
/// - 桌面 / 移动端 → [pickFolder]（系统原生「选择文件夹」对话框）
/// - Web           → 始终返回 null（浏览器沙箱无法选本机文件夹）
///
/// 用条件导出而非运行时判断，是为了让 `file_selector` 这个插件
/// 不进 Web 产物 —— 与 [file_store_factory] 同理。
library;

export 'folder_picker_io.dart'
    if (dart.library.js_interop) 'folder_picker_web.dart';
