import 'update_info.dart';

/// 更新检查的状态机。
///
/// 刻意不用 `AsyncValue` —— 它分不清「尚未检查」「已是最新」「检查失败」，
/// 也会被下载进度覆盖掉检查结果。
sealed class UpdateStatus {
  const UpdateStatus();
}

class UpdateIdle extends UpdateStatus {
  const UpdateIdle();
}

class UpdateChecking extends UpdateStatus {
  const UpdateChecking();
}

class UpdateUpToDate extends UpdateStatus {
  final String currentVersion;

  /// 仓库里最新发布的版本号（可能比当前低，也用于「已是最新」的说明）
  final String? latestVersion;

  const UpdateUpToDate({required this.currentVersion, this.latestVersion});
}

class UpdateAvailable extends UpdateStatus {
  final String currentVersion;
  final ReleaseInfo release;

  const UpdateAvailable({required this.currentVersion, required this.release});
}

class UpdateCheckFailed extends UpdateStatus {
  final String message;

  const UpdateCheckFailed(this.message);
}
