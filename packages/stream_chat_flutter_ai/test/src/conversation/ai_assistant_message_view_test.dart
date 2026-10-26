import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

Widget _view(String text, {required bool isGenerating}) => MaterialApp(
  home: Scaffold(
    body: AIAssistantMessageView(text: text, isGenerating: isGenerating),
  ),
);

/// Advances the clock far enough for the typewriter to reveal the answer.
///
/// Not `pumpAndSettle`, which stops at the first frame with nothing scheduled
/// and so doesn't wait for the typewriter's timer.
Future<void> _typeOut(WidgetTester tester) => tester.pump(const Duration(seconds: 1));

class _Reply with AIMessage {
  _Reply(this.text, {required this.isGenerating});

  @override
  String get id => 'r1';
  @override
  AIMessageRole get role => AIMessageRole.assistant;
  @override
  final String text;
  @override
  final bool isGenerating;
  @override
  List<AIMessagePart> get parts => [AIMessagePart(id: 'step', kind: AIMessagePartKind.reasoning)];
  @override
  List<AIMessageAttachment> get attachments => const [];
}

void main() {
  group('AIAssistantMessageView', () {
    testWidgets('shows a reply from history at once', (tester) async {
      await tester.pumpWidget(_view('An earlier answer.', isGenerating: false));

      expect(find.text('An earlier answer.'), findsOneWidget);
    });

    testWidgets('types a generating answer from its first character', (tester) async {
      await tester.pumpWidget(_view('', isGenerating: true));
      await tester.pumpWidget(_view('Hello, world!', isGenerating: true));

      expect(find.text('Hello, world!'), findsNothing);
      await _typeOut(tester);
      expect(find.text('Hello, world!'), findsOneWidget);
    });

    testWidgets('types an answer that arrives whole with the end of generation', (tester) async {
      // The answer is kept writing for a moment after `isGenerating` turns
      // false, so one that arrives complete in its last update still types.
      const answer = 'The whole answer, in one update.';
      await tester.pumpWidget(_view('', isGenerating: true));
      await tester.pumpWidget(_view(answer, isGenerating: false));

      await tester.pump(const Duration(milliseconds: 25));
      expect(find.text(answer), findsNothing);
      expect(find.text('The w'), findsOneWidget);

      await _typeOut(tester);
      expect(find.text(answer), findsOneWidget);
    });

    testWidgets('types the last chunk that arrives with the end of generation', (tester) async {
      const answer = 'Hello, world! And the rest of it.';
      await tester.pumpWidget(_view('Hello, world!', isGenerating: true));
      await _typeOut(tester);

      await tester.pumpWidget(_view(answer, isGenerating: false));
      await tester.pump(const Duration(milliseconds: 25));
      expect(find.text(answer), findsNothing);

      await _typeOut(tester);
      expect(find.text(answer), findsOneWidget);
    });

    testWidgets('shows a change at once once the answer is done', (tester) async {
      await tester.pumpWidget(_view('Hello', isGenerating: true));
      await tester.pumpWidget(_view('Hello', isGenerating: false));
      await _typeOut(tester);

      await tester.pumpWidget(_view('Hello, edited.', isGenerating: false));
      expect(find.text('Hello, edited.'), findsOneWidget);
    });

    testWidgets('in a conversation, types an answer that arrives whole after a step', (tester) async {
      // A reply showing only a step is on screen before its answer, so the
      // answer arriving with the end of generation still types out.
      const answer = 'The whole answer, in one update.';
      Widget conversation(_Reply reply) => MaterialApp(
        home: Scaffold(body: AIConversationView(messages: [reply])),
      );

      await tester.pumpWidget(conversation(_Reply('', isGenerating: true)));
      await tester.pumpWidget(conversation(_Reply(answer, isGenerating: false)));

      await tester.pump(const Duration(milliseconds: 25));
      expect(find.textContaining(answer, findRichText: true), findsNothing);

      await _typeOut(tester);
      expect(find.textContaining(answer, findRichText: true), findsOneWidget);
    });

    testWidgets('shows a generating answer at once with reduced motion', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(_view('', isGenerating: true));
      await tester.pumpWidget(_view('Hello, world!', isGenerating: false));

      expect(find.text('Hello, world!'), findsOneWidget);
      await _typeOut(tester);
    });
  });
}
