import 'package:absolute_moment_app/data/ai/ai_client.dart';
import 'package:absolute_moment_app/domain/enums/app_enums.dart';
import 'package:absolute_moment_app/domain/models/checkin.dart';
import 'package:absolute_moment_app/features/sop/widgets/ai_chat_panel.dart';
import 'package:absolute_moment_app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 拆塔官面板是**审校门**，不是聊天窗口
///
/// 三条不能破的规矩：面板自己没有输入框；空答案不浪费一次 API 调用；
/// 换阶段一定重新开始（否则会带着上一阶段的 system 指令继续拷问）。
class _FakeClient implements AiClient {
  final List<List<AiMessage>> calls = [];

  @override
  Stream<AiChunk> streamChat(List<AiMessage> messages) async* {
    calls.add(List.of(messages));
    yield const AiChunk('你凭什么这么肯定？');
    yield AiChunk.done;
  }

  @override
  Future<String> chat(List<AiMessage> messages) async => '';

  @override
  Future<void> testConnection() async {}

  @override
  void cancel() {}

  @override
  void dispose() {}
}

Widget _host(
  SopStageType stage,
  Checkin draft, {
  required AiClient client,
}) {
  return ProviderScope(
    overrides: [aiClientProvider.overrideWithValue(client)],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AiChatPanel(
            // 与 sop_session_page 一致：按阶段强制重建
            key: ValueKey(stage),
            stage: stage,
            node: null,
            getDraft: () => draft,
          ),
        ),
      ),
    ),
  );
}

void main() {
  const answered = Checkin(
    date: '2026-10-01',
    userAnswer: '连接池是共享资源，所以要加锁。',
  );

  testWidgets('面板里没有输入框 —— 答案只在阶段自己的框里写', (tester) async {
    await tester.pumpWidget(_host(SopStageType.questioning, answered,
        client: _FakeClient()));

    expect(find.byType(TextField), findsNothing);
    expect(find.text('拷问我的答案'), findsOneWidget);
    expect(find.textContaining('不会给你答案'), findsOneWidget);
  });

  testWidgets('空答案点按钮只提示，不发请求', (tester) async {
    final client = _FakeClient();
    await tester.pumpWidget(
      _host(SopStageType.questioning, const Checkin(date: '2026-10-01'),
          client: client),
    );

    await tester.tap(find.text('拷问我的答案'));
    await tester.pump();

    expect(find.text('先写下这一阶段的答案，再让拆塔官拷问'), findsOneWidget);
    expect(client.calls, isEmpty, reason: '空答案不该消耗一次 AI 调用');
  });

  testWidgets('拷问后只显示拆塔官的话，按钮变成再拷问', (tester) async {
    final client = _FakeClient();
    await tester.pumpWidget(
        _host(SopStageType.questioning, answered, client: client));

    await tester.tap(find.text('拷问我的答案'));
    await tester.pumpAndSettle();

    expect(find.text('你凭什么这么肯定？'), findsOneWidget);
    expect(find.text('基于修改再拷问'), findsOneWidget);
    // 用户侧那条注入的提示词不回显
    expect(find.textContaining('【阶段① 诘问】'), findsNothing);
    expect(client.calls.single.first.role, AiRole.system);
  });

  testWidgets('第二轮只发最新答案，不重发输入源', (tester) async {
    final client = _FakeClient();
    await tester.pumpWidget(
        _host(SopStageType.questioning, answered, client: client));

    await tester.tap(find.text('拷问我的答案'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('基于修改再拷问'));
    await tester.pumpAndSettle();

    expect(client.calls.length, 2);
    final followUp = client.calls.last.last;
    expect(followUp.content, contains('最新版本如下'));
    expect(followUp.content, contains('连接池是共享资源'));
    expect(followUp.content, isNot(contains('【本次输入源】')));
    // 两轮追问都留在面板上
    expect(find.text('你凭什么这么肯定？'), findsNWidgets(2));
  });

  testWidgets('换阶段后对话清空 —— 不带上一阶段的指令继续拷问', (tester) async {
    final client = _FakeClient();
    final draft = answered.copyWith(weakestAssumption: '假设锁是够的。');

    await tester.pumpWidget(_host(SopStageType.questioning, draft,
        client: client));
    await tester.tap(find.text('拷问我的答案'));
    await tester.pumpAndSettle();
    expect(find.text('基于修改再拷问'), findsOneWidget);

    // 同一个位置换成下一个阶段 —— State 必须重建
    await tester.pumpWidget(_host(SopStageType.breakdown, draft,
        client: client));
    await tester.pumpAndSettle();

    expect(find.text('拷问我的答案'), findsOneWidget,
        reason: '新阶段应当回到「首次拷问」');
    expect(find.text('你凭什么这么肯定？'), findsNothing,
        reason: '上一阶段的对话不该出现在这一阶段');
  });
}
