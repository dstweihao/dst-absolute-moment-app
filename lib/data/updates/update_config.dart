/// 版本更新的全部常量 —— 换仓库只改这一个文件
class UpdateConfig {
  UpdateConfig._();

  static const String gitHubOwner = 'dstweihao';
  static const String gitHubRepo = 'dst-absolute-moment-app';

  static const String apiBase = 'https://api.github.com';

  static String get latestReleaseUrl =>
      '$apiBase/repos/$gitHubOwner/$gitHubRepo/releases/latest';

  static const Duration checkTimeout = Duration(seconds: 10);
  static const Duration downloadTimeout = Duration(minutes: 20);

  /// 安装包扩展名优先级（小写；匹配时忽略大小写）。
  /// `.zip` 一律垫底 —— 它不是安装程序，只能打开压缩包。
  static const List<String> windowsAssetExts = ['.exe', '.msi', '.zip'];
  static const List<String> macosAssetExts = ['.dmg', '.pkg', '.zip'];
  static const List<String> linuxAssetExts = [
    '.appimage',
    '.deb',
    '.rpm',
    '.tar.gz',
  ];

  /// Web 读不到版本、Windows debug 偶发陈旧 —— 用它兜底（与 pubspec 保持一致）
  static const String fallbackVersion = '1.0.0';
}
