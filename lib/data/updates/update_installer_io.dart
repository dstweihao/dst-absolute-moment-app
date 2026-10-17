import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/update_info.dart';
import 'update_client.dart';
import 'update_config.dart';

/// 桌面端：下载该平台的安装包并拉起系统安装程序。
///
/// [onProgress] 收到 0..1；安装包没有 `Content-Length` 时收到 null（不确定进度）。
Future<InstallResult> installUpdate(
  ReleaseInfo release, {
  http.Client? httpClient,
  void Function(double? progress)? onProgress,
}) async {
  final asset = selectInstallerAsset(release, _platformAssetExts());
  if (asset == null) return _openReleasePage(release.htmlUrl);

  final client = httpClient ?? http.Client();
  try {
    final path = await _downloadToTemp(client, asset, onProgress);

    // AppImage 没有执行位就是一块死文件，launchUrl 会静默失败
    if (Platform.isLinux && asset.name.toLowerCase().endsWith('.appimage')) {
      await Process.run('chmod', ['+x', path]);
    }

    final launched = await launchUrl(
      Uri.file(path),
      mode: LaunchMode.externalApplication,
    );
    return launched
        ? const InstallResult(InstallOutcome.launched)
        : const InstallResult(
            InstallOutcome.failed,
            message: '安装包已下载，但系统没能打开它',
          );
  } on UpdateException catch (e) {
    return InstallResult(InstallOutcome.failed, message: e.message);
  } on Object catch (e) {
    return InstallResult(InstallOutcome.failed, message: '更新失败：$e');
  } finally {
    if (httpClient == null) client.close();
  }
}

/// 直接把人送到 Release 页 —— 用户想自己挑安装包时走这条
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

Future<InstallResult> _openReleasePage(String htmlUrl) async {
  final result = await openReleasePage(htmlUrl);
  return result.outcome == InstallOutcome.failed
      ? const InstallResult(
          InstallOutcome.failed,
          message: '这个版本没有提供安装包',
        )
      : result;
}

/// 只认桌面平台。移动端返回空 → 上层退化为打开 Release 页。
List<String> _platformAssetExts() {
  if (Platform.isWindows) return UpdateConfig.windowsAssetExts;
  if (Platform.isMacOS) return UpdateConfig.macosAssetExts;
  if (Platform.isLinux) return UpdateConfig.linuxAssetExts;
  return const [];
}

Future<String> _downloadToTemp(
  http.Client client,
  ReleaseAsset asset,
  void Function(double? progress)? onProgress,
) async {
  // 必须流式写盘：安装包动辄上百 MB，整体缓冲会直接 OOM。
  // 同时 GitHub 的 download 链接是跨域 302，交给 client 自己跟。
  final request = http.Request('GET', Uri.parse(asset.browserDownloadUrl))
    ..followRedirects = true
    ..maxRedirects = 5;

  final http.StreamedResponse response;
  try {
    response = await client.send(request).timeout(UpdateConfig.downloadTimeout);
  } on TimeoutException {
    throw const UpdateException('下载超时，请检查网络后重试');
  } on http.ClientException {
    throw const UpdateException('网络中断，下载失败');
  }

  if (response.statusCode != 200) {
    await response.stream.drain<void>();
    throw UpdateException('下载失败（HTTP ${response.statusCode}）');
  }

  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, p.basename(asset.name)));
  final sink = file.openWrite();
  final total = response.contentLength;
  var received = 0;

  try {
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(
        (total == null || total <= 0)
            ? null
            : (received / total).clamp(0.0, 1.0),
      );
    }
  } finally {
    await sink.close();
  }

  return file.path;
}
