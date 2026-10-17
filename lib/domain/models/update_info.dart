/// GitHub Release 的一个附件
class ReleaseAsset {
  final String name;
  final String browserDownloadUrl;
  final int size;

  const ReleaseAsset({
    required this.name,
    required this.browserDownloadUrl,
    this.size = 0,
  });
}

class ReleaseInfo {
  /// 形如 `v1.2.3`，可能带前缀
  final String tagName;
  final String name;
  final String notes;
  final String htmlUrl;
  final bool isPrerelease;
  final List<ReleaseAsset> assets;

  const ReleaseInfo({
    required this.tagName,
    this.name = '',
    this.notes = '',
    this.htmlUrl = '',
    this.isPrerelease = false,
    this.assets = const [],
  });
}

enum InstallOutcome { launched, openedInBrowser, failed }

class InstallResult {
  final InstallOutcome outcome;
  final String message;

  const InstallResult(this.outcome, {this.message = ''});

  bool get isSuccess => outcome != InstallOutcome.failed;
}

/// 按扩展名优先级挑出该平台的安装包；都不匹配返回 null。
///
/// [extPriority] 顺序即优先级，`.tar.gz` 这类多段后缀按整体匹配。
ReleaseAsset? selectInstallerAsset(
  ReleaseInfo release,
  List<String> extPriority,
) {
  for (final ext in extPriority) {
    for (final asset in release.assets) {
      if (asset.name.toLowerCase().endsWith(ext)) return asset;
    }
  }
  return null;
}

/// 语义化版本比较：返回 -1 / 0 / 1。
///
/// 去 `v` 前缀 → 截断预发布（`-`）与构建号（`+`）→ 逐段数值比较，
/// 段数不同按 0 补齐。非数字段当 0 处理，绝不抛异常。
int compareVersions(String a, String b) {
  final left = _segments(a);
  final right = _segments(b);
  final len = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < len; i++) {
    final x = i < left.length ? left[i] : 0;
    final y = i < right.length ? right[i] : 0;
    if (x != y) return x > y ? 1 : -1;
  }
  return 0;
}

bool isNewerVersion(String latest, String current) =>
    compareVersions(latest, current) > 0;

List<int> _segments(String version) {
  var v = version.trim();
  if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);

  // 预发布与构建号不参与主版本比较
  for (final cut in ['-', '+']) {
    final i = v.indexOf(cut);
    if (i >= 0) v = v.substring(0, i);
  }
  if (v.isEmpty) return const [0];

  return v.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
}
