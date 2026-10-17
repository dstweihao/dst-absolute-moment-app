import 'package:absolute_moment_app/domain/models/update_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersions / isNewerVersion', () {
    test('忽略 v 前缀，按数值而非字符串比较', () {
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('v1.0.0', '1.0.0'), 0);
      expect(compareVersions('1.0.1', '1.0.0'), 1);
      expect(compareVersions('1.1.0', '1.0.9'), 1);
      expect(compareVersions('2.0.0', '1.9.9'), 1);
      expect(compareVersions('1.0.0', '1.0.1'), -1);
    });

    test('段数不同按 0 补齐', () {
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('1.10', '1.9'), 1, reason: '10 大于 9，不能被当成字符串');
      expect(compareVersions('1.0.0.1', '1.0.0'), 1);
    });

    test('预发布与构建号不参与主版本比较', () {
      expect(compareVersions('1.0.0-beta', '1.0.0'), 0);
      expect(compareVersions('1.0.0+7', 'v1.0.0'), 0);
      expect(compareVersions('1.2.0-rc.1', '1.1.0'), 1);
    });

    test('非数字段当 0 处理，绝不抛异常', () {
      expect(compareVersions('abc', '0'), 0);
      expect(compareVersions('', '0'), 0);
      expect(compareVersions('1.x.0', '1.0.0'), 0);
    });

    test('isNewerVersion 即 compareVersions > 0', () {
      expect(isNewerVersion('v1.2.3', '1.0.0'), true);
      expect(isNewerVersion('1.0.0', '1.0.0'), false);
      expect(isNewerVersion('0.9.9', '1.0.0'), false);
    });
  });

  group('selectInstallerAsset', () {
    const release = ReleaseInfo(
      tagName: 'v1.0.0',
      assets: [
        ReleaseAsset(name: 'app.tar.gz', browserDownloadUrl: 'u4'),
        ReleaseAsset(name: 'app.zip', browserDownloadUrl: 'u3'),
        ReleaseAsset(name: 'app.msi', browserDownloadUrl: 'u2'),
        ReleaseAsset(name: 'app.exe', browserDownloadUrl: 'u1'),
      ],
    );

    test('按优先级取，与 assets 自身的排列顺序无关', () {
      expect(
        selectInstallerAsset(release, const ['.exe', '.msi', '.zip'])!.name,
        'app.exe',
      );
      expect(
        selectInstallerAsset(release, const ['.msi', '.exe'])!.name,
        'app.msi',
      );
      expect(selectInstallerAsset(release, const ['.zip'])!.name, 'app.zip');
    });

    test('匹配忽略大小写', () {
      const upper = ReleaseInfo(
        tagName: 'v1',
        assets: [ReleaseAsset(name: 'App.EXE', browserDownloadUrl: 'u')],
      );
      expect(selectInstallerAsset(upper, const ['.exe'])!.name, 'App.EXE');
    });

    test('.tar.gz 按整体后缀匹配，不会被 .zip 抢走', () {
      expect(
        selectInstallerAsset(release, const ['.tar.gz', '.zip'])!.name,
        'app.tar.gz',
      );
    });

    test('都不匹配时返回 null', () {
      expect(selectInstallerAsset(release, const ['.dmg', '.pkg']), isNull);
      expect(selectInstallerAsset(release, const []), isNull);
    });
  });
}
