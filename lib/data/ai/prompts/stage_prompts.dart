import '../../../domain/enums/app_enums.dart';
import '../../../domain/models/checkin.dart';
import '../../../domain/models/source_material.dart';
import '../../../domain/models/node.dart';
import 'personas.dart';

/// 各阶段的提示词模板
///
/// 设计原则：拆塔官人设（[Personas]）提供恒定人格，
/// 本类提供**阶段特定的任务指令**，两者拼接后发给模型。
///
/// 每个阶段对 AI 的约束都不同 —— 例如阶段②只许指出靶心不许给答案，
/// 阶段④只许评估可理解性不许代写。
class StagePrompts {
  StagePrompts._();

  /// 构造某阶段的系统提示词
  static String system(SopStageType stage, {String personaId = Personas.socraticMaster}) {
    final base = Personas.systemPromptFor(personaId);
    final taskSpecific = _taskInstruction(stage);
    if (taskSpecific.isEmpty) return base;
    return '$base\n\n---\n\n## 本次任务\n$taskSpecific';
  }

  /// 构造某阶段的用户提示词（含上下文）
  ///
  /// [materials] 是阶段 0 选定的输入源 —— 拆塔官人设的铁律 5 要求
  /// 「锚定真实业务场景」，这份上下文就是那个锚。没有它，铁律 5 无法执行。
  static String user(
    SopStageType stage, {
    required Node? node,
    required Checkin draft,
    List<SourceMaterial> materials = const [],
  }) {
    final buffer = StringBuffer();

    // 阶段 0 的输入源 —— 放在最前面，它是后面所有提问的地基
    final materialBlock = _materials(materials, draft.background);
    if (materialBlock.isNotEmpty) {
      buffer.writeln(materialBlock);
      buffer.writeln();
    }

    // 节点背景
    if (node != null) {
      buffer.writeln('【当前节点】${node.title}');
      if (node.description.isNotEmpty) {
        buffer.writeln('【节点说明】${node.description}');
      }
      if (node.coreConcepts.isNotEmpty) {
        buffer.writeln('【核心概念】${node.coreConcepts.join('、')}');
      }
      buffer.writeln();
    }

    final context = _stageContext(stage, draft, node: node);
    if (context.isNotEmpty) buffer.writeln(context);

    return buffer.toString().trim();
  }

  /// 后续轮次的用户提示词 —— 用户改完答案，再拷问一次。
  ///
  /// 刻意**只带阶段内容**：输入源与节点上下文在首轮那条消息里还在，
  /// 重复发送既费钱，也会把模型的注意力从「答案哪里变了」引开。
  static String userFollowUp(SopStageType stage, Checkin draft) {
    return '我根据你的追问修改了答案，最新版本如下，请基于它继续拷问：\n\n'
        '${_stageContext(stage, draft)}';
  }

  /// 阶段特定的上下文块 —— 首轮与后续轮共用
  ///
  /// [node] 只用于首轮：诘问池来自节点，而后续轮用户的诘问已经定了。
  static String _stageContext(SopStageType stage, Checkin draft, {Node? node}) {
    final buffer = StringBuffer();

    switch (stage) {
      case SopStageType.recall:
        // 阶段⓪ 不调用 AI
        break;

      case SopStageType.questioning:
        buffer.writeln('【阶段① 诘问】');
        if (draft.socraticQuestion.isNotEmpty) {
          buffer.writeln('已确定的诘问：${draft.socraticQuestion}');
        } else if (node != null && node.questions.isNotEmpty) {
          buffer.writeln('该节点的诘问池：');
          for (final q in node.questions) {
            buffer.writeln('- [${q.id}] ${q.text}');
          }
        }
        buffer.writeln();
        buffer.writeln('用户的第一反应回答：');
        buffer.writeln(draft.userAnswer.isEmpty ? '（尚未作答）' : draft.userAnswer);
        break;

      case SopStageType.breakdown:
        buffer.writeln('【阶段② 拆解】');
        buffer.writeln('用户的诘问回答：');
        buffer.writeln(draft.userAnswer.isEmpty ? '（未填写）' : draft.userAnswer);
        buffer.writeln();
        buffer.writeln('用户自己找出的最脆弱假设：');
        buffer.writeln(draft.weakestAssumption.isEmpty
            ? '（尚未填写）'
            : draft.weakestAssumption);
        break;

      case SopStageType.verification:
        buffer.writeln('【阶段③ 验证】');
        buffer.writeln('用户的诘问回答：');
        buffer.writeln(draft.userAnswer.isEmpty ? '（未填写）' : draft.userAnswer);
        buffer.writeln();
        buffer.writeln('用户找到的反方证据：');
        if (draft.counterEvidence.isEmpty) {
          buffer.writeln('（尚未填写）');
        } else {
          for (var i = 0; i < draft.counterEvidence.length; i++) {
            final e = draft.counterEvidence[i];
            buffer.writeln('${i + 1}. 我原以为：${e.assumed}');
            buffer.writeln('   但实际上：${e.actual}');
          }
        }
        break;

      case SopStageType.translation:
        buffer.writeln('【${stage.label}】');
        buffer.writeln('用户在阶段③找到的反方证据：');
        for (final e in draft.counterEvidence) {
          buffer.writeln('- 我原以为：${e.assumed} → 实际上：${e.actual}');
        }
        buffer.writeln();
        buffer.writeln('用户的底层机制与避坑阐释：');
        buffer.writeln(draft.businessTranslation.isEmpty
            ? '（尚未填写）'
            : draft.businessTranslation);
        break;

      case SopStageType.actionCard:
        buffer.writeln('【${stage.label}】');
        final card = draft.actionCard;
        if (card == null) {
          buffer.writeln('（尚未生成行动卡片）');
        } else {
          buffer.writeln('做什么：${card.what}');
          buffer.writeln('几点做：${card.whenText}');
          buffer.writeln('完成标准：${card.criteria}');
          buffer.writeln('对签单的贡献：${card.businessValue}');
        }
        break;

      case SopStageType.selfRating:
        // 阶段⑥ 不调用 AI
        break;
    }

    return buffer.toString().trim();
  }

  /// 阶段 0 的输入源块。
  ///
  /// 两块内容：从个性化资源文件夹里选中的物料正文，和用户手写补充的背景。
  /// 都为空时返回空串 —— 纯白板也是一种选择，不该往提示词里塞一段废话。
  static String _materials(List<SourceMaterial> materials, String background) {
    final note = background.trim();
    if (materials.isEmpty && note.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('【本次输入源】—— 用户今天手边真实存在的材料，'
        '提问必须落在它们覆盖的范围内');

    for (final m in materials) {
      buffer.writeln();
      buffer.writeln('### ${m.name}（${m.path}）');
      if (m.hasContent) {
        buffer.writeln(m.content.trim());
      } else {
        buffer.writeln('（空文档，只有文件名可供参照）');
      }
    }

    if (note.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### 用户补充说明');
      buffer.writeln(note);
    }

    return buffer.toString().trimRight();
  }

  /// 阶段特定任务指令
  static String _taskInstruction(SopStageType stage) {
    return switch (stage) {
      SopStageType.recall => '',

      SopStageType.questioning => '''
用户在阶段①需要凭**第一反应**回答一个诘问，禁止查资料。

你的任务：只抛出**一个**聚焦的单点问题。
- 如果上下文中已有该节点的诘问池，从中选最贴合用户当前水平的一个抛出，
  可以结合他的实际情况微调措辞，但不要改变考察的靶心。
- 如果用户已经作答，不要给答案，而是针对他回答中最含糊的一处追问一句。
- 绝对不要一次抛出多个问题。
''',

      SopStageType.breakdown => '''
用户在阶段②需要**自己**找出他回答里最脆弱的假设。

你的任务：**只指出靶心在哪，绝不给答案。**
- 先判断用户找出的假设是不是真的最脆弱的那一个。
- 如果不是，用一个反问把他的注意力引到真正的薄弱处
  （例如："你刚才说 X，那 Y 的情况下会发生什么？"）。
- 如果是，追问一句为什么这个假设可能站不住。
- 严禁说出"正确答案应该是……"。
''',

      SopStageType.verification => '''
用户在阶段③需要找到至少一条**反方证据**（"我原以为 X，实际上 Y"）。
这是整个闭环最硬的一关 —— 找不到证据，进度将被锁死，无法进入阶段④。

你的任务：**拷问这条证据是否真的成立。**
- 判断用户写的"实际上 Y"是真的有依据，还是只是换了个说法重复"我原以为 X"。
- 如果证据不成立，用反问让他自己发现漏洞（"你说的 Y，有什么具体现象能证明？"）。
- 如果证据成立，肯定它，然后追问："那这条证据推翻了你之前的哪个结论？"
- **严禁替用户推导出证据。**
''',

      SopStageType.translation => '''
用户在阶段④需要用**清晰准确的工程语言**阐释：理解了这个底层物理机制，
对于解决生产崩溃、设计健壮接口或规避未定义行为有什么关键价值。

你的任务：**评估这段逻辑在因果链条和物理机制上是否严密，但绝不代写。**
- 检查是否准确解释了核心机制（例如栈帧生命周期、移动语义的所有权转移、内存序的同步关系）。
- 检查是否真正分析了工程避坑点，而不是泛泛而谈假大空。
- 用反问指出漏洞（例如："你提到这样做能防崩溃，那如果是跨线程传递该对象呢？"）。
- **严禁直接帮他把机制阐释写好。**
''',

      SopStageType.actionCard => '''
用户在阶段⑤需要输出一张**可验证的 C++ 实践行动卡片**，四要素：做什么、几点做、
完成标准、工程验证价值。

你的任务：**帮他把卡片锐化到编译器/调试器可直接复现的级别，但不替他做决策。**
- 检查"完成标准"是否可验证（"写好代码"不可验证，"在 demo.cpp 里构造最小复现样例，并在 ASan 下确认报错输出"才可验证）。
- 检查"几点做"是否具体到可执行。
- 检查"工程验证价值"是否切中今日所学的物理机制，而不是空谈。
- 用反问指出模糊之处，**不要直接给出一张完整的卡片**。
''',

      SopStageType.selfRating => '',
    };
  }
}
