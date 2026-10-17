import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/update_info.dart';

/// Web：浏览器沙箱里没法把安装包落到本机，只能把人送到 Release 页。
///
/// [httpClient] 与 [onProgress] 刻意忽略 —— 这里不 import `dart:io`，
/// 保证 Web 产物干净。
Future<InstallResult> installUpdate(
  ReleaseInfo release, {
  http.Client? httpClient,
  void Function(double? progress)? onProgress,
}) =>
    openReleasePage(release.htmlUrl);

Future<InstallResult> openReleasePage(String htmlUrl) async {
  if (htmlUrl.isEmpty) {
    return const InstallResult(
      InstallOutcome.failed,
      message: '这个版本没有提供下载页',
    );
  }
  final opened = await launchUrl(
    Uri.parse(htmlUrl),
    mode: LaunchMode.externalApplication,
  );
  return opened
      ? const InstallResult(InstallOutcome.openedInBrowser)
      : const InstallResult(
          InstallOutcome.failed,
          message: '无法打开下载页面',
        );
}
