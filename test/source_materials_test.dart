import 'package:absolute_moment_app/data/ai/prompts/stage_prompts.dart';
import 'package:absolute_moment_app/data/repositories/resource_scanner.dart';
import 'package:absolute_moment_app/data/serialization/checkin_markdown.dart';
import 'package:absolute_moment_app/data/storage/file_store.dart';
import 'package:absolute_moment_app/data/storage/memory_file_store.dart';
import 'package:absolute_moment_app/domain/enums/app_enums.dart';
import 'package:absolute_moment_app/domain/models/checkin.dart';
import 'package:absolute_moment_app/domain/models/source_material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 阶段 0 的输入源 —— 个性化资源文件夹里那些**非节点文档**
///
/// 同一个文件夹养两种东西：YAML 进路线，Markdown / TXT 进 SOP 阶段 0。
/// 这组测试盯的就是这条分界线，以及物料从「勾选」到「进提示词」的全链路。
const _nodeYaml = '''
id: "x-side"
title: "我自己加的一关"
phase: 1
phase_name: "自有阶段"
progress_range: [0, 10]
order: 99
socratic_questions:
  - id: Q0
    level: "基础"
    text: "这一块你怎么讲清楚？"
acceptance_criteria:
  - "能不看笔记复述"
''';

void main() {
  group('ResourceScanner —— 一个文件夹，两个桶', () {
    test('YAML 进节点桶，Markdown / TXT 进物料桶', () async {
      final store = MemoryFileStore();
      await store.write('/res/nodes/x-side.yaml', _nodeYaml);
      await store.write('/res/notes/架构笔记.md', '连接池是共享资源。');
      await store.write('/res/notes/进度.txt', '看到第 12 章。');
      await store.write('/res/notes/设计文档.docx', '二进制垃圾');
      await store.write('/res/notes/书.pdf', '二进制垃圾');

      final scan = await ResourceScanner(store).scan();

      expect(scan.nodes.map((n) => n.id), ['x-side']);
      expect(scan.materials.map((m) => m.name), ['架构笔记', '进度']);
      // 顺序按名字排 —— 清单顺序稳定，用户每次看到的都一样
      expect(scan.materials.map((m) => m.name).toList(), ['架构笔记', '进度']);
    });

    test('物料保留正文与逻辑路径 —— 路径是跨天唯一标识', () async {
      final store = MemoryFileStore();
      await store.write('/res/业务背景.md', '电商订单系统，日单量 200 万。');

      final scan = await ResourceScanner(store).scan();
      final material = scan.materials.single;

      expect(material.path, '/res/业务背景.md');
      expect(material.name, '业务背景');
      expect(material.content, '电商订单系统，日单量 200 万。');
      expect(material.hasContent, isTrue);
    });

    test('空文档只有文件名 —— hasContent 为 false，不再假装它是背景', () async {
      final store = MemoryFileStore();
      await store.write('/res/待填.md', '   \n');

      final material = (await ResourceScanner(store).scan()).materials.single;

      expect(material.name, '待填');
      expect(material.hasContent, isFalse);
    });

    test('超长文档整篇读入 —— 穷尽式读取，一个字都不许吞', () async {
      final store = MemoryFileStore();
      const length = 60000;
      await store.write('/res/巨长.md', 'x' * length);

      final material = (await ResourceScanner(store).scan()).materials.single;

      expect(material.content.length, length);
      expect(material.hasContent, isTrue);
    });

    test('中文长文档按字符数全量读入 —— 不会被字节数或阈值切掉', () async {
      final store = MemoryFileStore();
      final body = '结论：连接池上限必须低于数据库的 max_connections。\n' * 900;
      await store.write('/res/长文.md', body);

      final material = (await ResourceScanner(store).scan()).materials.single;

      expect(material.content.length, body.length);
      expect(material.content.trimRight().endsWith('max_connections。'),
          isTrue,
          reason: '结尾段落必须还在 —— 截断最坏的情况就是吃掉结论');
    });

    test('未设置文件夹时两个桶都是空的', () async {
      final scan = await ResourceScanner(null).scan();

      expect(scan.isEmpty, isTrue);
      expect(scan.nodes, isEmpty);
      expect(scan.materials, isEmpty);
    });

    test('隐藏目录被跳过 —— .git 里的文档不该变成输入源', () async {
      final store = MemoryFileStore();
      await store.write('/res/.git/COMMIT_EDITMSG.txt', 'fix');
      await store.write('/res/正常.md', '正文');

      final scan = await ResourceScanner(store).scan();

      expect(scan.materials.map((m) => m.name), ['正常']);
    });

    test('结果整体缓存 —— 分两次取两个桶也只遍历一遍', () async {
      final store = _CountingStore();
      await store.write('/res/正常.md', '正文');

      final scanner = ResourceScanner(store);
      final first = await scanner.scan();
      final second = await scanner.scan();

      expect(identical(first, second), isTrue);
      // 缓存生效的证据：两次 scan 的遍历次数等于一次
      final afterCachedScans = store.listCalls;

      scanner.invalidate();
      await scanner.scan();
      expect(store.listCalls, afterCachedScans * 2);
    });
  });

  group('Checkin —— 输入源随打卡一起落盘', () {
    test('物料路径与补充说明能原样往返', () {
      const checkin = Checkin(
        date: '2026-10-01',
        nodeId: 'n01',
        nodeTitle: '对象的内存布局',
        materials: ['/res/业务背景.md', '/res/进度.txt'],
        background: '这块代码下周要上生产，我负责连接池。',
      );

      final decoded = CheckinMarkdown.decode(CheckinMarkdown.encode(checkin));

      expect(decoded.materials, ['/res/业务背景.md', '/res/进度.txt']);
      expect(decoded.background, '这块代码下周要上生产，我负责连接池。');
    });

    test('没选物料时不留占位符 —— 纯白板是一种正当选择', () {
      const checkin = Checkin(date: '2026-10-01', nodeId: 'n01');
      final encoded = CheckinMarkdown.encode(checkin);
      final decoded = CheckinMarkdown.decode(encoded);

      expect(decoded.materials, isEmpty);
      expect(decoded.background, isEmpty);
      // 空清单不进 frontmatter —— 别在每天的记录里留一个空数组
      expect(encoded.contains('materials:'), isFalse);
    });
  });

  group('StagePrompts —— 输入源进入提示词', () {
    test('物料正文与补充说明都出现在用户提示词里', () {
      const draft = Checkin(
        date: '2026-10-01',
        background: '我负责其中的连接池。',
      );

      final prompt = StagePrompts.user(
        SopStageType.questioning,
        node: null,
        draft: draft,
        materials: const [
          SourceMaterial(
            path: '/res/业务背景.md',
            name: '业务背景',
            content: '电商订单系统，日单量 200 万。',
          ),
        ],
      );

      expect(prompt, contains('【本次输入源】'));
      expect(prompt, contains('业务背景'));
      expect(prompt, contains('电商订单系统，日单量 200 万。'));
      expect(prompt, contains('我负责其中的连接池。'));
    });

    test('空文档明确告知 AI 只有文件名可参照', () {
      final prompt = StagePrompts.user(
        SopStageType.questioning,
        node: null,
        draft: const Checkin(date: '2026-10-01'),
        materials: const [
          SourceMaterial(path: '/res/待填.md', name: '待填'),
        ],
      );

      expect(prompt, contains('空文档'));
    });

    test('纯白板时不注入输入源区块 —— 铁律 5 会退回通用场景', () {
      final prompt = StagePrompts.user(
        SopStageType.questioning,
        node: null,
        draft: const Checkin(date: '2026-10-01'),
      );

      expect(prompt, isNot(contains('【本次输入源】')));
    });
  });
}

/// 数 `list()` 调用的存储 —— 用来证明两个桶共享同一次遍历
class _CountingStore extends MemoryFileStore {
  int listCalls = 0;

  @override
  Future<List<StoreEntry>> list(String path) {
    listCalls++;
    return super.list(path);
  }
}
