import 'package:absolute_moment_app/data/repositories/track_repository.dart';
import 'package:absolute_moment_app/data/seed/standard_curriculum.dart';
import 'package:absolute_moment_app/data/repositories/resource_scanner.dart';
import 'package:absolute_moment_app/data/storage/memory_file_store.dart';
import 'package:absolute_moment_app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 内置标准路线的节点数 —— 单一事实来源，避免多处硬编码漂移。
const int kMainlineNodes = 37;
const int kTotalNodes = kMainlineNodes + 1; // + 1 个 Bonus 综合节点

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('内置标准 C++ 路线：37 主线 + 1 Bonus，顺序与 next_node 链自洽', () async {
    final nodes = await StandardCurriculum.loadNodes(
      StandardCurriculum.cppTrackId,
    );

    final mainline = nodes.where((n) => !n.isBonus).toList();
    final bonus = nodes.where((n) => n.isBonus).toList();

    expect(mainline.length, kMainlineNodes);
    expect(bonus.length, 1, reason: '应含 1 个 Bonus 综合节点');

    // 每个主线节点都有标题与至少一个诘问 —— 兜底课程必须完整可用
    for (final n in mainline) {
      expect(n.id, isNotEmpty);
      expect(n.title, isNotEmpty);
      expect(n.questions, isNotEmpty, reason: '${n.id} 缺少诘问');
      expect(n.acceptanceCriteria, isNotEmpty, reason: '${n.id} 缺少验收标准');
    }

    // next_node 链自洽：顺着 next_node 走，应恰好覆盖全部主线，且无重复
    final byId = {for (final n in nodes) n.id: n};
    final seen = <String>{};
    var cur = nodes.firstWhere((n) => n.order == 1).id;
    while (cur.isNotEmpty && cur != 'null') {
      expect(seen.add(cur), true, reason: '节点 $cur 被 next_node 重复指向');
      final node = byId[cur]!;
      if (node.isBonus) break;
      cur = node.nextNodeId ?? '';
    }
    expect(seen.length, nodes.length,
        reason: 'next_node 链应串联全部节点（$kMainlineNodes 主线 + 1 Bonus）');
  });

  test('本地文件夹为空时，仓库回落到内置标准课程', () async {
    final repo = TrackRepository(ResourceScanner(MemoryFileStore()));
    final nodes = await repo.loadNodes(StandardCurriculum.cppTrackId);

    expect(nodes.length, kTotalNodes);
    expect(nodes.where((n) => !n.isBonus).length, kMainlineNodes);
  });

  test('内置标准路线已去个性化：不出现业务专属词', () async {
    final nodes = await StandardCurriculum.loadNodes(
      StandardCurriculum.cppTrackId,
    );

    final banned = ['EMS', 'BMS', '储能', '新能源', '物联网', '工商业'];
    for (final n in nodes) {
      final text = '${n.title} ${n.description} '
          '${n.questions.map((q) => q.text).join(' ')} '
          '${n.acceptanceCriteria.join(' ')}';
      for (final word in banned) {
        expect(text.contains(word), false,
            reason: '节点 ${n.id} 不应包含个性化词「$word」');
      }
    }
  });

  test('内置标准路线紧贴当前标准：确实覆盖 C++23 / C++26', () async {
    final nodes = await StandardCurriculum.loadNodes(
      StandardCurriculum.cppTrackId,
    );

    final all = [
      for (final n in nodes)
        '${n.title} ${n.description} ${n.coreConcepts.join(' ')} '
            '${n.questions.map((q) => q.text).join(' ')}',
    ].join(' ');

    // 路线必须自称"现代"，且这个自称要有具体的语言/库特性兜底。
    const markers = [
      'C++23',
      'C++26',
      'std::expected',
      'std::span',
      'std::execution',
      'concepts',
      'ranges',
      'coroutine',
      'jthread',
      'io_uring',
      'CMakePresets',
      'std::simd',
    ];
    for (final m in markers) {
      expect(all.contains(m), true,
          reason: '标准路线应覆盖 2026 年的现实：缺少「$m」');
    }
  });

  test('一个关卡一个内容：每关只有 1 个概念、1 个诘问、1 条验收', () async {
    final nodes = await StandardCurriculum.loadNodes(
      StandardCurriculum.cppTrackId,
    );

    for (final n in nodes) {
      expect(n.coreConcepts.length, 1, reason: '${n.id} 应只讲一个核心概念');
      expect(n.questions.length, 1, reason: '${n.id} 应只抛一个诘问');
      expect(n.acceptanceCriteria.length, 1, reason: '${n.id} 应只有一条验收标准');
      // 拦截条件只保留最低通过线与失败处置，不再有判定维度清单
      expect(n.interception.minimumPassLine, isNotEmpty,
          reason: '${n.id} 缺少最低通过线');
      expect(n.interception.onFailure, isNotEmpty,
          reason: '${n.id} 缺少未通过处置');
      expect(n.interception.judgmentDimensions, isEmpty,
          reason: '${n.id} 不应再堆判定维度');
    }
  });

  test('内置标准路线结构自洽：order 连续、进度区间单调递增到 100%', () async {
    final nodes = await StandardCurriculum.loadNodes(
      StandardCurriculum.cppTrackId,
    );

    final mainline =
        nodes.where((n) => !n.isBonus).toList()..sort((a, b) => a.order.compareTo(b.order));

    expect(
      mainline.map((n) => n.order).toList(),
      List.generate(kMainlineNodes, (i) => i + 1),
      reason: '主线 order 必须从 1 连续排到 $kMainlineNodes',
    );

    var prevEnd = 0.0;
    for (final n in mainline) {
      expect(n.progressStart, greaterThanOrEqualTo(prevEnd),
          reason: '${n.id} 的起点不应小于上一关的终点（进度不可倒退）');
      expect(n.progressEnd, greaterThan(n.progressStart),
          reason: '${n.id} 的进度区间必须为正');
      prevEnd = n.progressEnd;
    }
    expect(prevEnd, 100, reason: '主线应恰好推进到 100%');
    expect(nodes.singleWhere((n) => n.isBonus).progressStart, 100);

    // 阶段号必须是 1-5 且单调不减（节点页按阶段分组渲染）
    final phases = nodes.map((n) => n.phase).toList();
    expect(phases, orderedEquals(List.of(phases)..sort()));
    expect(phases.every((p) => p >= 1 && p <= 5), true);
  });

  test('路线从零基础起步：第一关是「第一个程序」，基础阶段 16 关', () async {
    final nodes = await StandardCurriculum.loadNodes(
      StandardCurriculum.cppTrackId,
    );

    final first = nodes.firstWhere((n) => n.order == 1);
    expect(first.phase, 1);
    expect(first.phaseName, 'C++ 基础', reason: '零基础阶段必须排在语言核心之前');
    expect(first.prerequisites, isEmpty, reason: '第一关不能有任何前置门槛');

    // 基础阶段的最后一关应直接接上「对象生命周期」，不能有断链
    final basics = nodes.where((n) => n.phaseName == 'C++ 基础').toList();
    expect(basics.length, 16, reason: '基础阶段一关一个知识块');
    final last = basics.reduce((a, b) => a.order > b.order ? a : b);
    expect(last.nextNodeId, '00-memory-model');
  });

  test('关卡标题不许出现「与」：一关只讲一个知识块', () async {
    final nodes = await StandardCurriculum.loadNodes(
      StandardCurriculum.cppTrackId,
    );

    for (final n in nodes) {
      expect(n.title.contains('与'), false,
          reason: '${n.id} 的标题「${n.title}」把两个知识块挤在了一起');
    }
  });

  // ------------------------------------------------------------------
  // 个性化资源文件夹：与数据文件夹解耦 + 任意结构递归扫描 + 只补充不替换
  // ------------------------------------------------------------------

  group('个性化资源文件夹（补充，不替换）', () {
    /// 一份最小的可用节点 YAML
    String nodeYaml({
      required String id,
      required String title,
      int order = 1,
      int phase = 1,
      String phaseName = '自有阶段',
    }) =>
        '''
id: "$id"
title: "$title"
phase: $phase
phase_name: "$phaseName"
progress_range: [0, 10]
order: $order
socratic_questions:
  - id: Q0
    level: "基础"
    text: "这一块你怎么讲清楚？"
acceptance_criteria:
  - "能不看笔记复述"
''';

    test('未设置个性化资源文件夹时，就是纯内置标准课程', () async {
      final repo = TrackRepository(ResourceScanner(null));
      final nodes = await repo.loadNodes(StandardCurriculum.cppTrackId);

      expect(nodes.length, kTotalNodes, reason: '未配置时应走内置标准路线');
      expect(nodes.where((n) => !n.isBonus).length, kMainlineNodes);
      expect(nodes.any((n) => n.isSupplementary), false);
    });

    test('任意嵌套深度都能被递归扫描到，作为补充关追加在内置之后', () async {
      final store = MemoryFileStore();
      // 刻意埋到很深的、非约定的目录结构里
      await store.write(
        '/some/deeply/nested/随便一层/我的路线/x-01.yaml',
        nodeYaml(id: 'x-01', title: '埋得很深的一关'),
      );
      await store.write(
        '/tracks/cpp/nodes/x-02.yaml',
        nodeYaml(id: 'x-02', title: '约定结构的一关', order: 2),
      );

      final repo = TrackRepository(ResourceScanner(store));
      final nodes = await repo.loadNodes(StandardCurriculum.cppTrackId);

      expect(nodes.length, kTotalNodes + 2,
          reason: '内置路线原样保留，个人节点作为补充关追加在末尾');
      expect(nodes.map((n) => n.id), containsAll(['x-01', 'x-02']));

      // 前 kTotalNodes 个必须是内置内容（补充关不许插队到主线中间）
      expect(nodes.take(kTotalNodes).any((n) => n.isSupplementary), false);
      final tail = nodes.skip(kTotalNodes).toList();
      expect(tail.every((n) => n.isSupplementary), true,
          reason: '追加的节点必须全部标记为补充关');
    });

    test('无关 YAML 被忽略，一个有效补充节点都没有时只剩内置课程', () async {
      final store = MemoryFileStore();
      await store.write('/notes/readme.yaml', 'title: 随手记\nfoo: bar\n');
      await store.write('/notes/deep/config.yml', 'a: 1\n');

      final repo = TrackRepository(ResourceScanner(store));
      final nodes = await repo.loadNodes(StandardCurriculum.cppTrackId);

      expect(nodes.length, kTotalNodes, reason: '解析不出节点 → 不影响内置标准课程');
    });

    test('个性化内容不受内置禁词约束 —— 自定义内容照常作为补充关采用', () async {
      final store = MemoryFileStore();
      await store.write(
        '/my/tracks/cpp/nodes/custom-01.yaml',
        nodeYaml(id: 'custom-01', title: '自定义高并发调度内核'),
      );

      final repo = TrackRepository(ResourceScanner(store));
      final nodes = await repo.loadNodes(StandardCurriculum.cppTrackId);

      expect(nodes.length, kTotalNodes + 1);
      final customNode = nodes.singleWhere((n) => n.id == 'custom-01');
      expect(customNode.title, contains('自定义'),
          reason: '禁词只约束内置标准课程；个人资源是用户自己的内容');
      expect(customNode.isSupplementary, true, reason: '个人节点必须标记为补充关');
    });

    test('补充关不计入主线进度，也不参与今日选题', () async {
      final store = MemoryFileStore();
      await store.write(
        '/my/x-extra.yaml',
        nodeYaml(id: 'x-extra', title: '额外练习', order: 99),
      );

      final repo = TrackRepository(ResourceScanner(store));
      final nodes = await repo.loadNodes(StandardCurriculum.cppTrackId);

      expect(repo.overallProgress(nodes, const {}), 0,
          reason: '一个都没通过时进度为 0，补充关不该把分母撑大');

      final passedOnlyExtra = {'x-extra'};
      expect(repo.overallProgress(nodes, passedOnlyExtra), 0,
          reason: '通过补充关不该让主线进度前进');

      final today = repo.nextNode(nodes, const {});
      expect(today?.isSupplementary, false,
          reason: '今日攻坚只能是主线/ Bonus，补充关要用户自己去点');
    });

    test('个性化资源与数据文件夹解耦：数据目录里的课程不再被读取', () async {
      // 场景还原：数据文件夹里遗留了旧的课程，
      // 而个性化资源文件夹没设置。
      final dataStore = MemoryFileStore();
      await dataStore.write(
        '/AbsoluteGauge-Platform/tracks/cpp/nodes/custom-01.yaml',
        nodeYaml(id: 'custom-01', title: '自定义遗留课程'),
      );

      final container = ProviderContainer(
        overrides: [
          initialStorageRootProvider.overrideWithValue(''),
          fileStoreProvider.overrideWithValue(dataStore),
          initialLearningRootProvider.overrideWithValue(''),
        ],
      );
      addTearDown(container.dispose);

      final nodes = await container
          .read(trackRepositoryProvider)
          .loadNodes(StandardCurriculum.cppTrackId);

      expect(nodes.length, kTotalNodes,
          reason: '数据文件夹里有遗留课程，也不该混进学习路线');
      expect(nodes.any((n) => n.title.contains('EMS')), false,
          reason: '数据文件夹里的遗留课程不应再影响学习路线');
    });
  });
}
