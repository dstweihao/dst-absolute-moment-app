import 'package:absolute_moment_app/data/updates/update_client.dart';
import 'package:absolute_moment_app/domain/models/update_info.dart';

/// 不联网的更新检查器：给什么返回什么，也可以选择抛错。
class FakeUpdateClient extends UpdateClient {
  final ReleaseInfo? release;
  final Object? error;

  FakeUpdateClient({this.release, this.error});

  @override
  Future<ReleaseInfo?> checkLatest() async {
    if (error != null) throw error!;
    return release;
  }
}

ReleaseInfo sampleRelease({
  String tagName = 'v1.2.0',
  String notes = '修了几个一直没空管的边界情况。',
}) {
  return ReleaseInfo(
    tagName: tagName,
    name: '绝对时刻 $tagName',
    notes: notes,
    htmlUrl: 'https://example.com/releases/$tagName',
    assets: [
      ReleaseAsset(
        name: 'AbsoluteMoment-$tagName.exe',
        browserDownloadUrl: 'https://example.com/a.exe',
        size: 1024,
      ),
    ],
  );
}
