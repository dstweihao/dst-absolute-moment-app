/// 安装器 —— 按平台在编译期分派
///
/// - 桌面 → [installUpdate]（下载安装包并拉起系统安装程序）
/// - Web  → 打开 Release 页（浏览器沙箱没法落地安装包）
///
/// 用条件导出而非运行时判断，是为了让 `dart:io` / `path_provider`
/// 不出现在 Web 产物里 —— 一旦被引用整个 Web 编译就会失败。
library;

export 'update_installer_io.dart'
    if (dart.library.js_interop) 'update_installer_web.dart';
