import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/conversation/conversation_state.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

const _answer = 'Sunny, 24°C.';
const _thought = 'Weighing the options.';

// How long a first step that arrived done stays open before it folds.
const _shown = Duration(milliseconds: 1600);

// How long the answer waits for it: the time it is open, then the time it
// takes to fold.
const _untilAnswer = Duration(milliseconds: 2050);

List<AIMessagePart> _steps({String status = 'completed'}) => AIMessagePart.parseAll([
  (type: 'ai_reasoning', payload: {'id': 'r1', 'status': status, 'preview': _thought}),
]);

List<AIMessagePart> _stepsWithoutText() => AIMessagePart.parseAll([
  (type: 'ai_reasoning', payload: {'id': 'r1', 'status': 'completed'}),
]);

List<AIMessagePart> _twoSteps({String firstStatus = 'completed'}) => AIMessagePart.parseAll([
  (type: 'ai_reasoning', payload: {'id': 'r1', 'status': firstStatus, 'preview': _thought}),
  (type: 'ai_reasoning', payload: {'id': 'r2', 'status': 'completed', 'preview': 'Checking the forecast.'}),
]);

class _Reply with AIMessage {
  @override
  String get id => 'a1';
  @override
  AIMessageRole get role => AIMessageRole.assistant;
  @override
  String get text => _answer;
  @override
  bool get isGenerating => false;
  @override
  List<AIMessagePart> get parts => _steps();
  @override
  List<AIMessageAttachment> get attachments => const [];
}

class _Question with AIMessage {
  @override
  String get id => 'q1';
  @override
  AIMessageRole get role => AIMessageRole.user;
  @override
  String get text => 'Weather?';
  @override
  bool get isGenerating => false;
  @override
  List<AIMessagePart> get parts => const [];
  @override
  List<AIMessageAttachment> get attachments => const [];
}

// What `_play` advances: a fold, plus a moment, since a controller completes
// only on the frame after it reaches its end.
const _played = Duration(milliseconds: 451);

// Lets the fold that starts in the current frame play out.
Future<void> _play(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_played);
}

// A clock whose turn thought for eight seconds, until its reply arrived.
Future<ThinkingClock> _thoughtUntilReply(WidgetTester tester) async {
  final clock = ThinkingClock()..update(latest: 't1', isThinking: true);
  await tester.pump(const Duration(seconds: 8));
  return clock..update(latest: 't1', isThinking: false, hasReplies: true);
}

Widget _inTurn(ThinkingClock clock, Widget reply, {bool reduceMotion = false, StreamComponentBuilders? builders}) {
  Widget child = MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(
      body: ThinkingTurnScope(clock: clock, turn: 't1', child: reply),
    ),
  );
  if (builders != null) child = StreamComponentFactory(builders: builders, child: child);
  return MaterialApp(home: child);
}

Widget _message({String text = _answer, bool isGenerating = false}) =>
    AIAssistantMessageView(text: text, isGenerating: isGenerating, parts: _steps());

Future<void> _pumpConversation(
  WidgetTester tester,
  List<AIMessage> messages, {
  bool isThinking = false,
}) {
  final withActions = StreamComponentBuilders(
    extensions: streamAIComponentBuilders(replyActions: (context, props) => const Text('reply actions')),
  );
  return tester.pumpWidget(
    StreamComponentFactory(
      builders: withActions,
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 600), disableAnimations: true),
          child: Scaffold(
            body: AIConversationView(messages: messages, isThinking: isThinking),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('A first step that arrives done', () {
    testWidgets('opens', (tester) async {
      final clock = await _thoughtUntilReply(tester);

      await tester.pumpWidget(_inTurn(clock, _message(text: '')));
      await _play(tester);

      expect(find.text(_thought), findsOneWidget);
    });

    testWidgets('folds after 1600 ms', (tester) async {
      final clock = await _thoughtUntilReply(tester);
      await tester.pumpWidget(_inTurn(clock, _message(text: '')));
      await _play(tester);

      await tester.pump(_shown - _played - const Duration(milliseconds: 1));
      expect(find.text(_thought), findsOneWidget, reason: 'open until the 1600 ms are up');

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.text(_thought), findsNothing);
    });

    testWidgets('unfolds as it opens', (tester) async {
      final clock = await _thoughtUntilReply(tester);

      await tester.pumpWidget(_inTurn(clock, _message(text: '')));
      await tester.pump();
      await tester.pump(StreamingReasoningView.foldDuration ~/ 2);
      final halfway = tester.getSize(find.byType(StreamingReasoningView)).height;

      await tester.pump(StreamingReasoningView.foldDuration);
      expect(tester.getSize(find.byType(StreamingReasoningView)).height, greaterThan(halfway));
    });

    testWidgets('that arrives later stays folded', (tester) async {
      final clock = await _thoughtUntilReply(tester);
      await tester.pump(const Duration(seconds: 4));

      await tester.pumpWidget(_inTurn(clock, _message(text: '')));
      await _play(tester);

      expect(find.text(_thought), findsNothing);
      expect(find.text('Thought for 8s'), findsOneWidget);
    });

    testWidgets('that the reader closed and opened again stays open', (tester) async {
      final clock = await _thoughtUntilReply(tester);
      await tester.pumpWidget(_inTurn(clock, _message(text: '')));
      await _play(tester);

      await tester.tap(find.text('Thought for 8s'));
      await _play(tester);
      expect(find.text(_thought), findsNothing);
      await tester.tap(find.text('Thought for 8s'));
      await _play(tester);
      await tester.pump(_shown);
      await tester.pumpAndSettle();

      expect(find.text(_thought), findsOneWidget);
    });

    testWidgets('that the model starts thinking again stays open', (tester) async {
      final clock = await _thoughtUntilReply(tester);
      Widget reply({required String status}) => _inTurn(
        clock,
        AIAssistantMessageView(
          text: '',
          isGenerating: true,
          parts: _steps(status: status),
        ),
      );
      await tester.pumpWidget(reply(status: 'completed'));
      await _play(tester);

      await tester.pumpWidget(reply(status: 'streaming'));
      await tester.pump(_shown);
      await _play(tester);

      expect(find.text(_thought), findsOneWidget);
    });

    testWidgets('keeps showing when the reply is built again', (tester) async {
      final clock = await _thoughtUntilReply(tester);
      await tester.pumpWidget(_inTurn(clock, _message(text: '')));
      await _play(tester);
      await tester.pump(const Duration(milliseconds: 900));

      await tester.pumpWidget(_inTurn(clock, _message(text: '')));
      await tester.pump();

      expect(find.text(_thought), findsOneWidget);
    });

    testWidgets('is the only step of the turn that opens', (tester) async {
      final clock = await _thoughtUntilReply(tester);

      await tester.pumpWidget(_inTurn(clock, AIAssistantMessageView(text: '', parts: _twoSteps())));
      await _play(tester);

      expect(find.text(_thought), findsOneWidget);
      expect(find.text('Checking the forecast.'), findsNothing);
    });

    testWidgets('with reduced motion still opens and folds', (tester) async {
      final clock = await _thoughtUntilReply(tester);

      await tester.pumpWidget(_inTurn(clock, _message(text: ''), reduceMotion: true));
      await tester.pump();
      expect(find.text(_thought), findsOneWidget);

      await tester.pump(_shown - const Duration(milliseconds: 1));
      expect(find.text(_thought), findsOneWidget, reason: 'the timer still runs');

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(_thought), findsNothing);
    });

    testWidgets('that thought in view stays as it is', (tester) async {
      final clock = ThinkingClock()..update(latest: 't1', isThinking: true);
      Widget reply({required String status}) => _inTurn(
        clock,
        AIAssistantMessageView(
          text: '',
          isGenerating: true,
          parts: _steps(status: status),
        ),
      );
      await tester.pumpWidget(reply(status: 'streaming'));
      await tester.pump(const Duration(seconds: 3));
      clock.update(latest: 't1', isThinking: false, hasReplies: true);

      await tester.pumpWidget(reply(status: 'completed'));
      await tester.pumpAndSettle();

      expect(find.text(_thought), findsNothing, reason: 'it showed its reasoning as it came');
    });
  });

  group('An answer in a turn whose first step arrives done', () {
    testWidgets('is held until the step folds', (tester) async {
      final clock = await _thoughtUntilReply(tester);

      await tester.pumpWidget(_inTurn(clock, _message()));
      await tester.pump(_untilAnswer - const Duration(milliseconds: 1));

      expect(find.textContaining('Sunny'), findsNothing);
    });

    testWidgets('types out once released', (tester) async {
      final clock = await _thoughtUntilReply(tester);
      await tester.pumpWidget(_inTurn(clock, _message()));

      await tester.pump(_untilAnswer);
      await tester.pump(const Duration(milliseconds: 25));
      expect(find.text(_answer), findsNothing, reason: 'it types out rather than appears');
      expect(find.textContaining('Su'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(_answer), findsOneWidget);
    });

    testWidgets('is held even while the reply is still generating', (tester) async {
      final clock = await _thoughtUntilReply(tester);

      await tester.pumpWidget(_inTurn(clock, _message(isGenerating: true)));
      await tester.pump(_untilAnswer - const Duration(milliseconds: 1));

      expect(find.textContaining('Sunny'), findsNothing);
    });

    testWidgets('is not held when a custom reasoning builder shows the step', (tester) async {
      final clock = await _thoughtUntilReply(tester);
      final builders = StreamComponentBuilders(
        extensions: streamAIComponentBuilders(reasoning: (context, props) => const Text('Custom reasoning')),
      );

      await tester.pumpWidget(_inTurn(clock, _message(), builders: builders));

      expect(find.text('Custom reasoning'), findsOneWidget);
      expect(find.text(_answer), findsOneWidget);
    });

    testWidgets('is not held for a first step that is still streaming', (tester) async {
      final clock = await _thoughtUntilReply(tester);

      await tester.pumpWidget(
        _inTurn(
          clock,
          AIAssistantMessageView(
            text: _answer,
            isGenerating: true,
            parts: _steps(status: 'streaming'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 25));

      expect(find.textContaining('Su'), findsOneWidget);
    });

    testWidgets('is not held for a later step that arrives done', (tester) async {
      final clock = await _thoughtUntilReply(tester);

      await tester.pumpWidget(
        _inTurn(
          clock,
          AIAssistantMessageView(
            text: _answer,
            isGenerating: true,
            parts: _twoSteps(firstStatus: 'streaming'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 25));

      expect(find.textContaining('Su'), findsOneWidget);
    });

    testWidgets('is not held for a first step with nothing to show', (tester) async {
      final clock = await _thoughtUntilReply(tester);

      await tester.pumpWidget(
        _inTurn(clock, AIAssistantMessageView(text: _answer, isGenerating: true, parts: _stepsWithoutText())),
      );
      await tester.pump(const Duration(milliseconds: 25));

      expect(find.textContaining('Su'), findsOneWidget);
    });

    testWidgets('made again after the step folded shows at once', (tester) async {
      final clock = await _thoughtUntilReply(tester);
      clock
        ..isFirstStep('r1', 't1')
        ..showsFirstStep('t1');
      await tester.pump(const Duration(seconds: 60));

      await tester.pumpWidget(_inTurn(clock, _message()));

      expect(find.text(_answer), findsOneWidget);
    });
  });

  group('The answer-writing signal', () {
    Widget reportingTo(ValueNotifier<bool?> writing, ThinkingClock clock) => _inTurn(
      clock,
      AnswerWritingScope(writing: writing, child: _message()),
    );

    testWidgets('stays true while the answer is held, though the reply has finished', (tester) async {
      final writing = ValueNotifier<bool?>(null);
      addTearDown(writing.dispose);
      final clock = await _thoughtUntilReply(tester);

      await tester.pumpWidget(reportingTo(writing, clock));
      await tester.pump(_untilAnswer - const Duration(milliseconds: 1));

      expect(writing.value, isTrue);
    });

    testWidgets('stays true until the released answer has typed out', (tester) async {
      final writing = ValueNotifier<bool?>(null);
      addTearDown(writing.dispose);
      final clock = await _thoughtUntilReply(tester);
      await tester.pumpWidget(reportingTo(writing, clock));

      await tester.pump(_untilAnswer);
      await tester.pump(const Duration(milliseconds: 25));
      expect(writing.value, isTrue, reason: 'still typing');

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(writing.value, isFalse);
    });

    testWidgets('keeps the reply actions away in the first frame of a held reply', (tester) async {
      await _pumpConversation(tester, [_Question()], isThinking: true);
      await tester.pump(const Duration(seconds: 8));

      await _pumpConversation(tester, [_Question(), _Reply()]);

      expect(find.text('reply actions'), findsNothing);
    });

    testWidgets('keeps the reply actions away while the answer is held', (tester) async {
      await _pumpConversation(tester, [_Question()], isThinking: true);
      await tester.pump(const Duration(seconds: 8));

      await _pumpConversation(tester, [_Question(), _Reply()]);
      await tester.pump();
      await tester.pump(_untilAnswer - const Duration(milliseconds: 1));
      expect(find.text('reply actions'), findsNothing);
      expect(find.textContaining('Sunny'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.text(_answer), findsOneWidget);
      expect(find.text('reply actions'), findsOneWidget);
    });
  });
}
