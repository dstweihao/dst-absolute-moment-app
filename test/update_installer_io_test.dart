import 'dart:async';
import 'dart:io';

import 'package:absolute_moment_app/data/updates/update_installer_io.dart';
import 'package:absolute_moment_app/domain/models/update_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// LinkDelegate 没被主库重新导出，单独引
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _MockHttpClient extends Mock implements http.Client {}

/// 临时目录是插件通道给的，测试里换成一颗真·临时目录
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launched = [];
  bool result = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return result;
  }
}

const _downloadUrl = 'https://example.com/download/asset';

/// 三个桌面平台的安装包都给全，这样断言与跑测试的机器无关
ReleaseInfo _desktopRelease() => const ReleaseInfo(
      tagName: 'v1.2.0',
      htmlUrl: 'https://example.com/releases/v1.2.0',
      assets: [
        ReleaseAsset(
            name: 'AbsoluteMoment-1.2.0.exe', browserDownloadUrl: _downloadUrl),
        ReleaseAsset(
            name: 'AbsoluteMoment-1.2.0.dmg', browserDownloadUrl: _downloadUrl),
        ReleaseAsset(
            name: 'AbsoluteMoment-1.2.0.AppImage',
            browserDownloadUrl: _downloadUrl),
      ],
    );

const _candidateNames = {
  'AbsoluteMoment-1.2.0.exe',
  'AbsoluteMoment-1.2.0.dmg',
  'AbsoluteMoment-1.2.0.AppImage',
};

void main() {
  late _MockHttpClient httpClient;
  late _FakeUrlLauncher launcher;
  late Directory tempDir;

  setUpAll(() => registerFallbackValue(http.Request('GET', Uri())));

  setUp(() {
    httpClient = _MockHttpClient();
    launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;

    tempDir = Directory.systemTemp.createTempSync('am_update_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void stubStream(
    int statusCode, {
    List<List<int>> chunks = const [],
    int? contentLength,
  }) {
    when(() => httpClient.send(any())).thenAnswer(
      (_) async => http.StreamedResponse(
        Stream.fromIterable(chunks),
        statusCode,
        contentLength: contentLength,
      ),
    );
  }

  List<File> writtenFiles() =>
      tempDir.listSync().whereType<File>().toList(growable: false);

  test('下载安装包：边收边写盘，进度一路涨到 100%', () async {
    stubStream(
      200,
      chunks: [
        List.filled(4, 0x41),
        List.filled(6, 0x42),
      ],
      contentLength: 10,
    );

    final progress = <double?>[];
    final result = await installUpdate(
      _desktopRelease(),
      httpClient: httpClient,
      onProgress: progress.add,
    );

    expect(result.outcome, InstallOutcome.launched);
    expect(result.isSuccess, true);
    expect(progress, [0.4, 1.0], reason: '进度按已收字节算，不是按块数');

    final files = writtenFiles();
    expect(files, hasLength(1));
    expect(_candidateNames, contains(files.single.uri.pathSegments.last),
        reason: '文件名取自附件名，且只留 basename');
    expect(files.single.lengthSync(), 10, reason: '字节数要和流一致');
  });

  test('安装包没有 Content-Length：进度给 null，不假装知道总量', () async {
    stubStream(200, chunks: [
      List.filled(3, 1),
    ]);

    final progress = <double?>[];
    await installUpdate(
      _desktopRelease(),
      httpClient: httpClient,
      onProgress: progress.add,
    );

    expect(progress, [null]);
  });

  test('下载不是 200：报错，不留下半截文件', () async {
    stubStream(404);

    final result = await installUpdate(
      _desktopRelease(),
      httpClient: httpClient,
    );

    expect(result.outcome, InstallOutcome.failed);
    expect(result.message, contains('404'));
    expect(writtenFiles(), isEmpty,
        reason: '状态码不对时连临时文件都不该创建');
  });

  test('下载超时与网络中断各自映射成可读提示', () async {
    when(() => httpClient.send(any())).thenThrow(TimeoutException('slow'));
    var result =
        await installUpdate(_desktopRelease(), httpClient: httpClient);
    expect(result.message, contains('下载超时'));

    when(() => httpClient.send(any()))
        .thenThrow(http.ClientException('boom'));
    result = await installUpdate(_desktopRelease(), httpClient: httpClient);
    expect(result.message, contains('网络中断'));
  });

  test('系统打不开下载好的安装包：算失败并说清楚', () async {
    stubStream(200, chunks: [
      List.filled(1, 0),
    ], contentLength: 1);
    launcher.result = false;

    final result =
        await installUpdate(_desktopRelease(), httpClient: httpClient);

    expect(result.outcome, InstallOutcome.failed);
    expect(result.message, contains('没能打开'));
  });

  test('这个版本没有本平台的安装包：退回到 Release 页', () async {
    const release = ReleaseInfo(
      tagName: 'v1.2.0',
      htmlUrl: 'https://example.com/releases/v1.2.0',
      assets: [
        ReleaseAsset(
            name: 'readme.txt', browserDownloadUrl: 'https://example.com/a.txt'),
      ],
    );

    final result = await installUpdate(release, httpClient: httpClient);

    expect(result.outcome, InstallOutcome.openedInBrowser);
    expect(launcher.launched, [release.htmlUrl]);
    expect(writtenFiles(), isEmpty);
    verifyNever(() => httpClient.send(any()));
  });

  group('openReleasePage', () {
    test('成功时报告已送到浏览器，且用外部程序打开', () async {
      final result = await openReleasePage('https://example.com/releases');

      expect(result.outcome, InstallOutcome.openedInBrowser);
      expect(launcher.launched, ['https://example.com/releases']);
    });

    test('没有下载页链接时不当成「已打开」', () async {
      final result = await openReleasePage('');

      expect(result.outcome, InstallOutcome.failed);
      expect(launcher.launched, isEmpty);
    });

    test('浏览器拒绝打开：算失败', () async {
      launcher.result = false;

      final result = await openReleasePage('https://example.com/releases');

      expect(result.outcome, InstallOutcome.failed);
      expect(result.message, contains('无法打开'));
    });
  });
}
