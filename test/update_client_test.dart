import 'dart:async';
import 'dart:convert';

import 'package:absolute_moment_app/data/updates/update_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  late _MockHttpClient httpClient;
  late UpdateClient client;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    httpClient = _MockHttpClient();
    client = UpdateClient(httpClient: httpClient);
  });

  void stubStatus(int statusCode, String body) {
    when(() => httpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response.bytes(
              utf8.encode(body),
              statusCode,
            ));
  }

  void stubThrow(Object error) {
    when(() => httpClient.get(any(), headers: any(named: 'headers')))
        .thenThrow(error);
  }

  test('200：解析出 tag / 说明 / 下载页 / 附件', () async {
    stubStatus(
      200,
      jsonEncode({
        'tag_name': 'v1.2.0',
        'name': '绝对时刻 v1.2.0',
        'body': '修了几个边界情况。',
        'html_url': 'https://example.com/releases/v1.2.0',
        'prerelease': false,
        'assets': [
          {
            'name': 'app.exe',
            'browser_download_url': 'https://example.com/app.exe',
            'size': 2048,
          },
          // 没有下载链接的附件要被丢掉，否则会挑中一个死链接
          {'name': 'no-url.bin', 'size': 1},
        ],
      }),
    );

    final release = await client.checkLatest();

    expect(release!.tagName, 'v1.2.0');
    expect(release.name, '绝对时刻 v1.2.0');
    expect(release.notes, '修了几个边界情况。');
    expect(release.htmlUrl, 'https://example.com/releases/v1.2.0');
    expect(release.isPrerelease, false);
    expect(release.assets.length, 1);
    expect(release.assets.single.name, 'app.exe');
    expect(release.assets.single.size, 2048);
  });

  test('404：还没有正式发布 —— 返回 null，不是错误', () async {
    stubStatus(404, '{"message":"Not Found"}');
    expect(await client.checkLatest(), isNull);
  });

  test('403 / 429：限流给出可读提示', () async {
    for (final code in [403, 429]) {
      stubStatus(code, '');
      expect(
        () => client.checkLatest(),
        throwsA(isA<UpdateException>()
            .having((e) => e.message, 'message', '检查过于频繁，请稍后再试')),
        reason: 'HTTP $code 应映射为限流提示',
      );
    }
  });

  test('500：通用失败提示带状态码', () async {
    stubStatus(500, '');
    expect(
      () => client.checkLatest(),
      throwsA(isA<UpdateException>()
          .having((e) => e.message, 'message', contains('500'))),
    );
  });

  test('返回体不是 JSON：报解析失败而不是崩掉', () async {
    stubStatus(200, '<html>not json</html>');
    expect(
      () => client.checkLatest(),
      throwsA(isA<UpdateException>()
          .having((e) => e.message, 'message', '无法解析 GitHub 返回的内容')),
    );
  });

  test('超时与网络异常各自映射', () async {
    stubThrow(TimeoutException('slow'));
    expect(
      () => client.checkLatest(),
      throwsA(isA<UpdateException>()
          .having((e) => e.message, 'message', contains('超时'))),
    );

    stubThrow(http.ClientException('boom'));
    expect(
      () => client.checkLatest(),
      throwsA(isA<UpdateException>()
          .having((e) => e.message, 'message', contains('网络'))),
    );
  });
}
