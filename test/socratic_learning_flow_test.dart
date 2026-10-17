import 'package:flutter_test/flutter_test.dart';
import 'package:absolute_moment_app/data/ai/ai_client.dart';
import 'package:absolute_moment_app/data/ai/prompts/personas.dart';
import 'package:absolute_moment_app/data/ai/sensitive_content_guard.dart';

void main() {
  group('Socratic AI Learning Engine Tests', () {
    test('Persona prompt contains strict Socratic rules and industry standard layout', () {
      final prompt = Personas.systemPromptFor(Personas.socraticMaster);

      // 验证绝不给答案
      expect(prompt, contains('永远不要直接给出正确的代码'));
      expect(prompt, contains('绝对不给答案'));
      
      // 验证 DeepSeek 官方工程风格规范
      expect(prompt, contains('核心矛盾'));
      expect(prompt, contains('物理现实'));
      expect(prompt, contains('单点反诘'));
    });

    test('Progress score regex extracts score correctly and handles variations', () {
      final regex = RegExp(r'\[PROGRESS:\s*(\d+)%?\]', caseSensitive: false);

      final reply1 = '**【推导诊断】**\n思维有偏差。\n\n> 💡 **核心追问**\n> 寄存器叫什么？\n\n[PROGRESS: 45%]';
      final match1 = regex.firstMatch(reply1);
      expect(match1, isNotNull);
      expect(match1!.group(1), equals('45'));

      final reply2 = '推导已完全闭环！\n[PROGRESS: 100]';
      final match2 = regex.firstMatch(reply2);
      expect(match2, isNotNull);
      expect(match2!.group(1), equals('100'));
    });

    test('Clean bubble content removes internal [PROGRESS: xx%] tag cleanly', () {
      final raw = '''**【推导诊断】**
语法层面的省略不等于底层无作为。

**【底层透视】**
函数退出前寄存器必须完成归零。

> 💡 **核心追问**
> 现代 C++ 编译器在 `main` 结尾偷偷塞入了哪条汇编指令来清空 eax？

[PROGRESS: 50%]''';

      final clean = raw.replaceAll(RegExp(r'\[PROGRESS:\s*\d+%?\]', caseSensitive: false), '').trim();

      expect(clean, isNot(contains('[PROGRESS:')));
      expect(clean, contains('**【推导诊断】**'));
      expect(clean, contains('> 💡 **核心追问**'));
      expect(clean, endsWith('清空 eax？'));
    });

    test('Progress monotonicity: higher scores update, lower scores ignored', () {
      double currentProgress = 0.35;

      double evaluateNew(int score) {
        final newProg = (score / 100.0).clamp(0.0, 1.0);
        if (newProg > currentProgress) {
          currentProgress = newProg;
        }
        return currentProgress;
      }

      expect(evaluateNew(20), equals(0.35)); // 不降级
      expect(evaluateNew(60), equals(0.60)); // 正常升级
      expect(evaluateNew(50), equals(0.60)); // 不降级
      expect(evaluateNew(100), equals(1.0)); // 满级通关
    });

    test('Vague / unknown answer blocking locks progress to 0% and rejects inflation', () {
      const vagueTokens = [
        '不知道', '不会', '不清楚', '报错', '没看懂', '不晓得', '没有', '没想法', '求教', '怎么做', '啥', '啥意思', '不明白'
      ];

      bool isVagueAnswer(String answer) {
        final t = answer.trim().toLowerCase();
        return vagueTokens.any((kw) => t.contains(kw)) || t.length <= 3;
      }

      expect(isVagueAnswer('不知道'), isTrue);
      expect(isVagueAnswer('我不会啊'), isTrue);
      expect(isVagueAnswer('报错了'), isTrue);
      expect(isVagueAnswer('abc'), isTrue);
      expect(isVagueAnswer('返回给操作系统内核的 eax 寄存器并通过 wait4 接收'), isFalse);
    });

    test('Anti-inflation progression step clamping (prevents 0 -> 15% leap)', () {
      double currentProgress = 0.0;

      double evaluateStepped(int score, bool isVague) {
        if (isVague) return currentProgress;

        final targetProg = (score / 100.0).clamp(0.0, 1.0);
        if (targetProg <= currentProgress) return currentProgress;

        const maxStep = 0.10; // 单步最多递增 10%
        final newProg = (targetProg >= 1.0)
            ? 1.0
            : (currentProgress + maxStep < targetProg
                ? currentProgress + maxStep
                : targetProg);

        if (newProg > currentProgress) {
          currentProgress = newProg;
        }
        return currentProgress;
      }

      // 1. 回答“不知道”：严格保持 0.0，即使模型打 15 分
      expect(evaluateStepped(15, true), equals(0.0));

      // 2. 正常回答获得 15 分：通过 10% 步长平滑约束，只涨到 0.10，绝不直接暴涨到 0.15
      expect(evaluateStepped(15, false), equals(0.10));

      // 3. 下一轮答出更深底层，获得 30 分：平滑递进到 0.20
      expect(evaluateStepped(30, false), equals(0.20));

      // 4. 彻底攻破闭环直通 100 分：直达 1.0 解锁通关
      expect(evaluateStepped(100, false), equals(1.0));
    });

    test('Persona system prompt enforces Chinese double quotes and strict progress rubrics', () {
      final prompt = Personas.systemPromptFor(Personas.socraticMaster);

      expect(prompt, contains('中文双引号“……”'));
      expect(prompt, contains('严禁给 15% 起步分'));
      expect(prompt, contains('Sacrifice grammar for the sake of concision'));
    });

    test('SensitiveContentGuard detects vulgarity and content filter errors', () {
      // 1. 常见粗口与违禁词拦截
      expect(SensitiveContentGuard.isSensitive('草草草'), isTrue);
      expect(SensitiveContentGuard.isSensitive('卧槽'), isTrue);
      expect(SensitiveContentGuard.isSensitive('傻逼'), isTrue);
      expect(SensitiveContentGuard.isSensitive('操'), isTrue);
      expect(SensitiveContentGuard.isSensitive('fuck'), isTrue);

      // 正常技术问题放行
      expect(SensitiveContentGuard.isSensitive('int main 的返回值由哪个寄存器传递？'), isFalse);
      expect(SensitiveContentGuard.isSensitive('草稿纸上推导了汇编指令'), isFalse);

      // 2. 服务端合规报错识别
      expect(SensitiveContentGuard.isContentFilterError('The response was filtered by content_filter policy'), isTrue);
      expect(SensitiveContentGuard.isContentFilterError('包含违规敏感内容，已被系统拦截'), isTrue);
      expect(SensitiveContentGuard.isContentFilterError('Connection timeout'), isFalse);

      // 3. 错误消息与枚举定义
      expect(AiErrorKind.contentFilter.userMessage, contains('敏感词'));
      expect(AiErrorKind.contentFilter.isRetryable, isFalse);
    });

    test('Node switching preserves independent conversation histories without resetting', () {
      final Map<String, String> storage = {};

      void persistNode(String nodeId, String historyJson) {
        storage['node_chat_$nodeId'] = historyJson;
        storage['absolute_moment_active_node_id'] = nodeId;
      }

      String? loadNode(String nodeId) {
        return storage['node_chat_$nodeId'];
      }

      // 1. 关卡 1 进行中推导
      persistNode('cpp-01', '[{"role":"user","content":"main 返回值存在 eax"}]');
      expect(loadNode('cpp-01'), contains('eax'));

      // 2. 切换到关卡 2
      persistNode('cpp-02', '[{"role":"user","content":"栈帧基址是 rbp"}]');
      expect(loadNode('cpp-02'), contains('rbp'));

      // 3. 切回关卡 1：历史必须完好无损，绝不重置
      final restored01 = loadNode('cpp-01');
      expect(restored01, isNotNull);
      expect(restored01, contains('eax'));

      // 4. 点击当前关卡：保持原样
      expect(storage['absolute_moment_active_node_id'], equals('cpp-02'));
    });

    test('Legacy score cleanup cleans false starter scores <= 15%', () {
      double cleanLegacyProgress(double storedScore, bool isPassed) {
        if (isPassed) return 1.0;
        if (storedScore <= 0.15) {
          return 0.0;
        }
        return storedScore;
      }

      expect(cleanLegacyProgress(0.15, false), equals(0.0)); // 历史遗留 15% 虚分清零
      expect(cleanLegacyProgress(0.10, false), equals(0.0)); // 历史遗留 10% 虚分清零
      expect(cleanLegacyProgress(0.40, false), equals(0.40)); // 真实推导 40% 保留
      expect(cleanLegacyProgress(0.15, true), equals(1.0)); // 已通关保持 100%
    });

    test('Error formatting routes content filter and auth errors to correct guidance', () {
      String formatError(AiErrorKind kind, String detail) {
        switch (kind) {
          case AiErrorKind.notConfigured:
            return '尚未配置 DeepSeek API Key';
          case AiErrorKind.unauthorized:
            return 'API Key 无效或鉴权失败';
          case AiErrorKind.contentFilter:
            return '内容触发安全审查或敏感词过滤';
          case AiErrorKind.rateLimited:
            return '官方服务频次超限或额度不足';
          case AiErrorKind.network:
            return '网络连接异常';
          default:
            return '调用异常';
        }
      }

      // 违规/敏感词：绝不包含 API Key 误导词
      final contentFilterMsg = formatError(AiErrorKind.contentFilter, 'sensitive');
      expect(contentFilterMsg, contains('敏感词过滤'));
      expect(contentFilterMsg, isNot(contains('API Key')));

      // 鉴权异常：才提示检查 API Key
      final authMsg = formatError(AiErrorKind.unauthorized, 'invalid_api_key');
      expect(authMsg, contains('API Key'));
    });
  });
}
