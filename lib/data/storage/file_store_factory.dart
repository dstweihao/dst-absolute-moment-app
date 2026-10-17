/// 存储工厂 —— 按平台在编译期分派
///
/// - 桌面 / 移动端 → [LocalFileStore]（读写本地文件夹）
/// - Web           → [MemoryFileStore]（内存，刷新即失）
///
/// 用条件导出而非运行时判断，是为了让 `dart:io` 不出现在 Web 产物里 ——
/// Web 上 `dart:io` 不可用，一旦被引用整个编译就会失败。
library;

export 'file_store_factory_io.dart'
    if (dart.library.js_interop) 'file_store_factory_web.dart';
