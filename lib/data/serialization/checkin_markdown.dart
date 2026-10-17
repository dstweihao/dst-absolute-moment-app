import '../../domain/models/action_card.dart';
import '../../domain/models/checkin.dart';
import 'frontmatter.dart';

/// 打卡记录 ↔ Markdown 双向转换
///
/// 存储形态见计划文档。设计要点：
/// - **元数据**（日期/难度/用时/标志位）走 YAML 头部，解析稳、机器友好
/// - **正文内容**（你的思考）走 Markdown 章节，人能直接用记事本改
///
/// 这个分工的意义：在电脑上改正文 → 手机下拉刷新就能看到改动，
/// 而不用去动 YAML 头部（普通用户不熟悉 YAML，容易改坏）。
///
/// 容错原则：任何章节缺失、格式错乱都不抛异常，回落到默认值。
class CheckinMarkdown {
  CheckinMarkdown._();

  // ---- 章节标记。编解码共用，改一处即可 ----
  /// 阶段 0 的背景补充。用 ◎ 而不是数字 —— 它在七阶段**之外**，
  /// 是进关卡前的准备动作，编进 ⓪-⑥ 的序号里会让人以为闭环多了一环。
  static const String markerMaterial = '◎';
  static const String markerRecall = '⓪';
  static const String markerQuestioning = '①';
  static const String markerBreakdown = '②';
  static const String markerVerification = '③';
  static const String markerTranslation = '④';
  static const String markerActionCard = '⑤';
  static const String markerSelfRating = '⑥';

  /// 正向字段标签
  static const String labelAssumed = '我原以为';
  static const String labelActual = '但实际上';
  static const String labelWhat = '做什么';
  static const String labelWhen = '几点做';
  static const String labelCriteria = '完成标准';
  static const String labelBusinessValue = '对签单的贡献';
  static const String labelDifficulty = '难度分';
  static const String labelNextSuggestion = '明日建议';

  // ------------------------------------------------------------------
  // 编码
  // ------------------------------------------------------------------

  static String encode(Checkin c) {
    final meta = <String, dynamic>{
      'date': c.date,
      if (c.trackId.isNotEmpty) 'track': c.trackId,
      if (c.nodeId.isNotEmpty) 'node': c.nodeId,
      if (c.nodeTitle.isNotEmpty) 'node_title': c.nodeTitle,
      'duration_minutes': c.durationMinutes,
      'completed': c.completed,
      'ai_assisted': c.aiAssisted,
      if (c.aiRounds > 0) 'ai_rounds': c.aiRounds,
      if (c.recallSkipped) 'recall_skipped': true,
      if (c.difficulty != null) 'difficulty': c.difficulty,
      // 阶段 0 选定的输入源。存路径不存正文 —— 正文在提问时回查文件夹，
      // 物料被改过或删掉之后，记录不会留着一份过期副本。
      if (c.materials.isNotEmpty) 'materials': c.materials,
    };

    final buf = StringBuffer();
    buf.writeln('# ${c.date} 苏格拉底闭环打卡');
    buf.writeln();

    buf.writeln('## $markerMaterial 背景补充');
    buf.writeln();
    if (c.background.trim().isEmpty) {
      buf.writeln('_（未填写）_');
    } else {
      buf.writeln(c.background);
    }
    buf.writeln();

    buf.writeln('## $markerRecall 昨日提取');
    buf.writeln();
    if (c.recallSkipped) {
      buf.writeln('_首次会话，跳过昨日提取。_');
    } else if (c.yesterdayFindings.isEmpty) {
      buf.writeln('_（未填写）_');
    } else {
      for (var i = 0; i < c.yesterdayFindings.length; i++) {
        buf.writeln('${i + 1}. ${c.yesterdayFindings[i]}');
      }
    }
    buf.writeln();

    buf.writeln('## $markerQuestioning 诘问');
    buf.writeln();
    buf.writeln('**问题**：');
    buf.writeln(c.socraticQuestion.isEmpty ? '_（未填写）_' : c.socraticQuestion);
    buf.writeln();
    buf.writeln('**我的第一反应回答**：');
    buf.writeln(c.userAnswer.isEmpty ? '_（未填写）_' : c.userAnswer);
    buf.writeln();

    buf.writeln('## $markerBreakdown 拆解');
    buf.writeln();
    buf.writeln('**最脆弱的假设**：');
    buf.writeln(
        c.weakestAssumption.isEmpty ? '_（未填写）_' : c.weakestAssumption);
    buf.writeln();

    buf.writeln('## $markerVerification 验证');
    buf.writeln();
    if (c.counterEvidence.isEmpty) {
      buf.writeln('_（未找到反方证据）_');
    } else {
      for (var i = 0; i < c.counterEvidence.length; i++) {
        final e = c.counterEvidence[i];
        buf.writeln('**反方证据 ${i + 1}**');
        buf.writeln('- $labelAssumed：${e.assumed}');
        buf.writeln('- $labelActual：${e.actual}');
        buf.writeln();
      }
    }

    buf.writeln('## $markerTranslation 转化');
    buf.writeln();
    buf.writeln('**商业翻译**（对客户/老板怎么说）：');
    buf.writeln(c.businessTranslation.isEmpty
        ? '_（未填写）_'
        : c.businessTranslation);
    buf.writeln();

    buf.writeln('## $markerActionCard 行动卡片');
    buf.writeln();
    final card = c.actionCard;
    if (card == null) {
      buf.writeln('_（未生成行动卡片）_');
    } else {
      buf.writeln('- **$labelWhat**：${card.what}');
      buf.writeln('- **$labelWhen**：${card.whenText}');
      buf.writeln('- **$labelCriteria**：${card.criteria}');
      buf.writeln('- **$labelBusinessValue**：${card.businessValue}');
    }
    buf.writeln();

    buf.writeln('## $markerSelfRating 自评');
    buf.writeln();
    final score = c.difficulty;
    buf.writeln('- **$labelDifficulty**：'
        '${score == null ? '未评分' : '$score/10（${c.difficultyBandLabel}）'}');
    buf.writeln('- **$labelNextSuggestion**：${suggestNext(score)}');
    buf.writeln();

    return Frontmatter(data: meta, body: buf.toString()).compose();
  }

  /// 难度校准建议 —— 刻意练习的校准器
  ///
  /// 甜蜜点 3-7 分（猜对 50-70%）：太简单则加难度，太难则降维拆解。
  static String suggestNext(int? score) {
    if (score == null) return '未评分，明日维持';
    if (score <= 2) return '太简单，明日加难度';
    if (score >= 8) return '太难，明日降维拆解';
    return '维持';
  }

  // ------------------------------------------------------------------
  // 解码
  // ------------------------------------------------------------------

  static Checkin decode(String markdown) {
    final fm = Frontmatter.parse(markdown);
    final meta = fm.data;
    final sections = _splitSections(fm.body);

    final materialSection = sections[markerMaterial] ?? '';
    final rawMaterials = meta['materials'];
    final materials = <String>[];
    if (rawMaterials is List) {
      materials.addAll(rawMaterials.map((e) => e.toString()));
    }

    final recallRaw = sections[markerRecall] ?? '';
    final recallSkipped = recallRaw.contains('跳过昨日提取');

    final questioning = sections[markerQuestioning] ?? '';
    final breakdown = sections[markerBreakdown] ?? '';
    final verification = sections[markerVerification] ?? '';
    final translation = sections[markerTranslation] ?? '';
    final actionSection = sections[markerActionCard] ?? '';

    final date = (meta['date'] ?? '').toString();

    final card = _parseActionCard(actionSection, date);

    return Checkin(
      date: date,
      trackId: (meta['track'] ?? '').toString(),
      nodeId: (meta['node'] ?? '').toString(),
      nodeTitle: (meta['node_title'] ?? '').toString(),
      durationMinutes: _toInt(meta['duration_minutes']),
      completed: _toBool(meta['completed']),
      aiAssisted: _toBool(meta['ai_assisted']),
      aiRounds: _toInt(meta['ai_rounds']),
      materials: materials,
      background: _stripPlaceholder(materialSection),
      recallSkipped: recallSkipped || _toBool(meta['recall_skipped']),
      yesterdayFindings: recallSkipped ? const [] : _parseNumberedList(recallRaw),
      socraticQuestion: _parseAfterLabel(questioning, '**问题**：'),
      userAnswer: _parseAfterLabel(questioning, '**我的第一反应回答**：'),
      weakestAssumption:
          _parseAfterLabel(breakdown, '**最脆弱的假设**：'),
      counterEvidence: _parseEvidence(verification),
      businessTranslation:
          _parseAfterLabel(translation, '**商业翻译**（对客户/老板怎么说）：'),
      actionCard: card,
      difficulty:
          meta['difficulty'] == null ? null : _toInt(meta['difficulty']),
    );
  }

  // ---- 章节切分 ----

  /// 按 `## ` 行切分，key 为章节里出现的阶段标记符（⓪-⑥）
  static Map<String, String> _splitSections(String body) {
    const markers = [
      markerMaterial,
      markerRecall,
      markerQuestioning,
      markerBreakdown,
      markerVerification,
      markerTranslation,
      markerActionCard,
      markerSelfRating,
    ];

    final result = <String, String>{};
    final lines = body.split('\n');

    String? currentMarker;
    final buffer = StringBuffer();

    void flush() {
      if (currentMarker != null) {
        result[currentMarker] = buffer.toString().trim();
      }
      buffer.clear();
    }

    for (final line in lines) {
      final isHeader = line.startsWith('## ');
      if (isHeader) {
        final matched = markers.firstWhere(
          (m) => line.contains(m),
          orElse: () => '',
        );
        if (matched.isNotEmpty) {
          flush();
          currentMarker = matched;
          continue;
        }
        // 是标题但不属于已知阶段 —— 结束当前章节
        flush();
        currentMarker = null;
        continue;
      }
      if (currentMarker != null) {
        buffer.writeln(line);
      }
    }
    flush();

    return result;
  }

  /// 提取 `**标签**：` 之后的全部内容
  static String _parseAfterLabel(String section, String label) {
    if (section.isEmpty) return '';
    final idx = section.indexOf(label);
    if (idx < 0) {
      // 标签不匹配（可能被用户改过）—— 退化为取整段
      return _stripPlaceholder(section);
    }
    var rest = section.substring(idx + label.length);
    while (rest.startsWith('\n')) {
      rest = rest.substring(1);
    }
    // 同一章节内可能紧跟下一个 `**标签**：` 字段（如 ① 诘问 里
    // 「问题」之后还有「我的第一反应回答」），必须截到那里为止，
    // 否则后一个字段的内容会一起被吞进当前字段。
    final nextLabel = RegExp(r'\n\*\*[^*\n]+\*\*[：:]').firstMatch(rest);
    if (nextLabel != null) {
      rest = rest.substring(0, nextLabel.start);
    }
    return _stripPlaceholder(rest.trim());
  }

  /// 去掉 `_（未填写）_` 这类占位符
  static String _stripPlaceholder(String s) {
    final t = s.trim();
    if (t == '_（未填写）_' ||
        t == '_（未找到反方证据）_' ||
        t == '_（未生成行动卡片）_' ||
        t == '_首次会话，跳过昨日提取。_') {
      return '';
    }
    return t;
  }

  /// 解析数字列表 `1. xxx`
  static List<String> _parseNumberedList(String section) {
    final out = <String>[];
    for (final line in section.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('_')) continue;
      final m = RegExp(r'^\d+[.、]\s*(.+)$').firstMatch(t);
      if (m != null) {
        out.add(m.group(1)!.trim());
      }
    }
    return out;
  }

  /// 解析反方证据块
  static List<CounterEvidence> _parseEvidence(String section) {
    final out = <CounterEvidence>[];
    if (section.isEmpty || section.trim().startsWith('_')) return out;

    String? assumed;
    String? actual;

    void flush() {
      if (assumed != null || actual != null) {
        out.add(CounterEvidence(
          assumed: assumed ?? '',
          actual: actual ?? '',
        ));
      }
      assumed = null;
      actual = null;
    }

    for (final line in section.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;

      if (t.startsWith('**反方证据')) {
        flush();
        continue;
      }
      if (t.contains(labelAssumed)) {
        assumed = _valueAfterColon(t, labelAssumed);
        continue;
      }
      if (t.contains(labelActual)) {
        actual = _valueAfterColon(t, labelActual);
        continue;
      }
    }
    flush();

    return out.where((e) => e.isComplete || e.assumed.isNotEmpty || e.actual.isNotEmpty).toList();
  }

  /// 从 `- 我原以为：内容` 里取出冒号后的内容
  static String _valueAfterColon(String line, String label) {
    final idx = line.indexOf(label);
    if (idx < 0) return '';
    var rest = line.substring(idx + label.length);
    if (rest.startsWith('：') || rest.startsWith(':')) {
      rest = rest.substring(1);
    }
    return rest.trim();
  }

  /// 解析行动卡片
  static ActionCard? _parseActionCard(String section, String date) {
    if (section.isEmpty || section.trim().startsWith('_')) return null;

    final what = _parseBulletValue(section, labelWhat);
    final when = _parseBulletValue(section, labelWhen);
    final criteria = _parseBulletValue(section, labelCriteria);
    final value = _parseBulletValue(section, labelBusinessValue);

    if (what.isEmpty && when.isEmpty && criteria.isEmpty && value.isEmpty) {
      return null;
    }

    return ActionCard(
      id: 'action-$date',
      sourceDate: date,
      what: what,
      whenText: when,
      criteria: criteria,
      businessValue: value,
    );
  }

  /// 解析 `- **标签**：内容` 形式的列表项
  static String _parseBulletValue(String section, String label) {
    for (final line in section.split('\n')) {
      final t = line.trim();
      if (!t.contains(label)) continue;
      final idx = t.indexOf(label);
      var rest = t.substring(idx + label.length);
      rest = rest.replaceFirst(RegExp(r'^\*\*'), '');
      if (rest.startsWith('：') || rest.startsWith(':')) {
        rest = rest.substring(1);
      }
      return rest.trim();
    }
    return '';
  }

  // ---- 类型转换 ----

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static bool _toBool(dynamic v) =>
      v == true || v?.toString().toLowerCase() == 'true';
}
