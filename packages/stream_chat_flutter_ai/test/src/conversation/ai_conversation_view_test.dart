import 'dart:async';
import 'dart:convert';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

class _Message with AIMessage {
  _Message(
    this.id,
    this.role, {
    this.text = '',
    this.isGenerating = false,
    this.parts = const [],
    this.attachments = const [],
  });

  @override
  final String id;

  @override
  final AIMessageRole role;

  @override
  final String text;

  @override
  final bool isGenerating;

  @override
  final List<AIMessagePart> parts;

  @override
  final List<AIMessageAttachment> attachments;
}

_Message _user(String id, [String text = 'A question']) => _Message(id, AIMessageRole.user, text: text);
_Message _reply(String id, {String text = 'An answer', bool generating = false}) =>
    _Message(id, AIMessageRole.assistant, text: text, isGenerating: generating);

/// A conversation of [count] turns, each a question and a tall reply.
List<_Message> _history(int count) => [
  for (var i = 0; i < count; i++) ...[
    _user('u$i', 'Question $i'),
    _reply('r$i', text: List.filled(12, 'Line of answer $i.').join('\n\n')),
  ],
];

Widget _actions(BuildContext context, AIReplyActionsProps props) =>
    Text('actions for ${props.message.id}${props.isLatestReply ? ' (latest)' : ''}');

const _withActions = AIComponentBuilders(replyActions: _actions);

Future<void> _pump(
  WidgetTester tester,
  List<AIMessage> messages, {
  AIPendingMessage? pending,
  bool isThinking = false,
  Future<void> Function()? loadOlder,
  AIComponentBuilders builders = _withActions,
  Widget? footer,
  Widget? empty,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(400, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AIComponentFactory(
      builders: builders,
      child: MaterialApp(
        home: MediaQuery(
          // No typewriter, so a reply is on screen at once.
          data: const MediaQueryData(size: Size(400, 600), disableAnimations: true),
          child: Scaffold(
            body: AIConversationView(
              messages: messages,
              pendingMessage: pending,
              isThinking: isThinking,
              loadOlderMessages: loadOlder,
              footer: footer,
              emptyContent: empty,
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // A spinner in view never settles.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
}

Finder _text(String text) => find.textContaining(text, findRichText: true);

/// Pumps [frames] frames of [step], for views that never settle.
Future<void> _frames(WidgetTester tester, Duration step, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

void main() {
  group('AIConversationView', () {
    testWidgets('shows its empty content while there are no messages', (tester) async {
      await _pump(tester, const [], empty: const Text('How can I help?'));
      expect(find.text('How can I help?'), findsOneWidget);
    });

    testWidgets("shows the person's messages and the agent's replies", (tester) async {
      await _pump(tester, [_user('u1', 'Where is my order?'), _reply('r1', text: 'On its way.')]);
      expect(find.byType(AIUserMessageView), findsOneWidget);
      expect(find.byType(AIAssistantMessageView), findsOneWidget);
      expect(find.text('Where is my order?'), findsOneWidget);
      expect(_text('On its way.'), findsOneWidget);
    });

    testWidgets('shows the agent thinking until its reply shows something', (tester) async {
      await _pump(tester, [_user('u1'), _reply('r1', text: '', generating: true)]);
      expect(find.byType(AIThinkingView), findsOneWidget);
      expect(find.byType(AIAssistantMessageView), findsNothing, reason: 'a reply with nothing to show is left out');

      await _pump(tester, [_user('u1'), _reply('r1', text: 'Here', generating: true)]);
      expect(find.byType(AIThinkingView), findsNothing);
      expect(find.byType(AIAssistantMessageView), findsOneWidget);
    });

    testWidgets('shows a message on its way at once', (tester) async {
      await _pump(tester, const [], pending: AIPendingMessage(text: 'Hello?'));
      expect(find.text('Hello?'), findsOneWidget);
      expect(find.byType(AIThinkingView), findsOneWidget);
    });

    testWidgets('shows a footer under the latest turn', (tester) async {
      await _pump(tester, [_user('u1'), _reply('r1')], footer: const Text('Working on it'));
      expect(find.text('Working on it'), findsOneWidget);
    });

    testWidgets('shows reply actions only once a reply is finished', (tester) async {
      await _pump(tester, [_user('u1'), _reply('r1', generating: true)]);
      expect(find.textContaining('actions for'), findsNothing);

      await _pump(tester, [_user('u1'), _reply('r1')]);
      expect(find.text('actions for r1 (latest)'), findsOneWidget);
    });

    testWidgets('tells the actions which reply is the latest', (tester) async {
      await _pump(tester, [_user('u1'), _reply('r1'), _user('u2'), _reply('r2')]);
      await tester.drag(find.byType(Scrollable), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.text('actions for r1'), findsOneWidget);
    });

    testWidgets('makes the latest turn at least as tall as the list', (tester) async {
      await _pump(tester, [_user('u1'), _reply('r1')]);
      final list = tester.getSize(find.byType(AIConversationView));
      final turn = tester.getRect(
        find.ancestor(of: find.byType(AIUserMessageView), matching: find.byType(ConstrainedBox)).first,
      );
      expect(turn.height, greaterThanOrEqualTo(list.height));
    });

    testWidgets('opens a long conversation at its end', (tester) async {
      await _pump(tester, _history(6));
      expect(find.text('Question 5'), findsOneWidget);
      expect(find.text('Question 0'), findsNothing);
      expect(find.byTooltip('Scroll to latest'), findsOneWidget);
      final button = tester.widget<IgnorePointer>(
        find.ancestor(of: find.byTooltip('Scroll to latest'), matching: find.byType(IgnorePointer)).first,
      );
      expect(button.ignoring, isTrue, reason: 'the end is in view');
    });

    testWidgets('scrolls a question the person sends to the top', (tester) async {
      final history = _history(3);
      await _pump(tester, history);
      await _pump(tester, [...history, _user('u3', 'A new question')]);
      final top = tester.getTopLeft(find.byType(AIConversationView)).dy;
      expect(tester.getTopLeft(find.text('A new question')).dy - top, lessThan(40));
    });

    testWidgets('offers to scroll back to the end once it is out of view', (tester) async {
      await _pump(tester, _history(6));
      await tester.drag(find.byType(Scrollable), const Offset(0, 1500));
      await tester.pumpAndSettle();
      bool ignoring() => tester
          .widget<IgnorePointer>(
            find.ancestor(of: find.byTooltip('Scroll to latest'), matching: find.byType(IgnorePointer)).first,
          )
          .ignoring;
      expect(ignoring(), isFalse);

      await tester.tap(find.byTooltip('Scroll to latest'));
      await tester.pumpAndSettle();
      expect(ignoring(), isTrue);
      expect(find.text('Question 5'), findsOneWidget);
    });

    testWidgets('loads older messages at its start, keeping what is on screen in place', (tester) async {
      var loads = 0;
      var messages = _history(2).sublist(2);
      Future<void> loadOlder() async => loads++;
      await _pump(tester, messages, loadOlder: loadOlder, settle: false);
      // The only turn fills the list, so the spinner above it is out of view.
      await tester.pump(const Duration(seconds: 1));
      expect(loads, 0);

      await tester.drag(find.byType(Scrollable), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(loads, 1);

      final before = tester.getTopLeft(find.text('Question 1'));
      messages = _history(2);
      await _pump(tester, messages, loadOlder: loadOlder, settle: false);
      expect(tester.getTopLeft(find.text('Question 1')), before);
    });

    testWidgets('a message that stops being passed before it arrives leaves the list alone', (tester) async {
      final history = _history(3);
      await _pump(tester, history);
      await _pump(tester, history, pending: AIPendingMessage(text: 'Lost'));
      await _pump(tester, history);
      await tester.drag(find.byType(Scrollable), const Offset(0, 600));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final ignoring = tester
          .widget<IgnorePointer>(
            find.ancestor(of: find.byTooltip('Scroll to latest'), matching: find.byType(IgnorePointer)).first,
          )
          .ignoring;
      expect(ignoring, isFalse, reason: 'the person scrolled away and stays there');
    });

    testWidgets('loads again while the spinner stays in view', (tester) async {
      var loads = 0;
      await _pump(tester, const [], loadOlder: () async => loads++, settle: false);
      await _pump(tester, [_user('u1', 'Short')], loadOlder: () async => loads++, settle: false);
      await tester.drag(find.byType(Scrollable), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(loads, greaterThanOrEqualTo(2));
    });

    testWidgets('reports a failed load', (tester) async {
      await _pump(tester, [_user('u1')], loadOlder: () async => throw StateError('offline'), settle: false);
      await tester.drag(find.byType(Scrollable), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isA<StateError>());
    });

    testWidgets('a conversation replacing the one shown opens at its end', (tester) async {
      await _pump(tester, _history(2));
      await _pump(tester, [
        for (var i = 0; i < 6; i++) ...[
          _user('x$i', 'Other $i'),
          _reply('y$i', text: List.filled(12, 'Line.').join('\n\n')),
        ],
      ]);
      expect(find.text('Other 5'), findsOneWidget);
      expect(find.text('Other 0'), findsNothing);
    });

    testWidgets('builds a finished reply again only when what it shows changes', (tester) async {
      var builds = 0;
      final counting = AIComponentBuilders(
        assistantMessage: (context, props) {
          builds++;
          return AIAssistantMessageView(text: props.text, isGenerating: props.isGenerating, parts: props.parts);
        },
      );
      await _pump(tester, [
        _user('u1'),
        _reply('r1'),
        _user('u2'),
        _reply('r2', text: 'A', generating: true),
      ], builders: counting);
      final first = builds;
      await _pump(tester, [
        _user('u1'),
        _reply('r1'),
        _user('u2'),
        _reply('r2', text: 'AB', generating: true),
      ], builders: counting);
      expect(builds - first, 1, reason: 'only the streaming reply');
    });

    testWidgets("a reply's first step with only a summary opens to that summary", (tester) async {
      final reply = _Message(
        'r1',
        AIMessageRole.assistant,
        text: 'The answer',
        parts: AIMessagePart.parseAll([
          (type: 'ai_reasoning', payload: const {'id': 'step1', 'status': 'completed', 'summary': 'Compared plans'}),
        ]),
      );
      // Seen thinking, so the step takes over the thinking's count.
      await _pump(tester, [_user('u1')], isThinking: true, settle: false);
      await _frames(tester, const Duration(milliseconds: 100), 5);
      await _pump(tester, [_user('u1'), reply]);

      await tester.tap(_text('Thought for'));
      await tester.pumpAndSettle();
      expect(_text('Compared plans'), findsOneWidget, reason: 'as StreamingReasoningView.part shows it');
    });

    testWidgets('builds a reply again only when its attachments change, not when decoded again', (tester) async {
      var builds = 0;
      final counting = AIComponentBuilders(
        assistantMessage: (context, props) {
          builds++;
          return AIAssistantMessageView(text: props.text, attachments: props.attachments);
        },
      );
      List<AIMessage> conversation(String title) {
        final raw = jsonDecode('{"type": "athena_image", "artifact_id": "a1", "meta": {"title": "$title"}}');
        return [
          _user('u1'),
          _Message(
            'r1',
            AIMessageRole.assistant,
            text: 'Here it is',
            attachments: [AIMessageAttachment(kind: const AIMessageAttachmentKind('athena_image'), extraData: raw)],
          ),
        ];
      }

      await _pump(tester, conversation('Chart'), builders: counting);
      final first = builds;
      await _pump(tester, conversation('Chart'), builders: counting);
      expect(builds, first, reason: 'an equal payload decoded again');
      await _pump(tester, conversation('Table'), builders: counting);
      expect(builds, first + 1);
    });

    group('layout', () {
      Rect turnOf(WidgetTester tester, String text) =>
          tester.getRect(find.ancestor(of: find.text(text), matching: find.byType(ConstrainedBox)).first);

      testWidgets('leaves 8 between turns', (tester) async {
        await _pump(tester, [_user('u1', 'Q1'), _reply('r1'), _user('u2', 'Q2'), _reply('r2')]);
        await tester.drag(find.byType(Scrollable), const Offset(0, 200));
        await tester.pumpAndSettle();
        expect(turnOf(tester, 'Q2').top - turnOf(tester, 'Q1').bottom, 8);
      });

      testWidgets("sets the person's bubble 40 in, padded 16 by 12, 8 under its attachments", (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: AIUserMessageView(
                  text: List.filled(20, 'A long question').join(' '),
                  attachments: [AIMessageAttachment.file(Uri.parse('https://x.io/receipt.pdf'))],
                ),
              ),
            ),
          ),
        );
        final bubble = find.ancestor(of: find.textContaining('A long question'), matching: find.byType(DecoratedBox));
        final rect = tester.getRect(bubble.first);
        final text = tester.getRect(find.textContaining('A long question'));
        expect(rect.left, 40);
        expect(text.left - rect.left, 16);
        expect(text.top - rect.top, 12);
        expect(rect.bottom - text.bottom, 12);
        final decoration = tester.widget<DecoratedBox>(bubble.first).decoration as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(20));
        expect(rect.top - tester.getRect(find.byType(AIMessageAttachmentView)).bottom, 8);
      });

      testWidgets('leaves 8 between an answer and its actions', (tester) async {
        await _pump(tester, [_user('u1'), _reply('r1')]);
        final answer = tester.getRect(find.byType(AIAssistantMessageView));
        expect(tester.getTopLeft(find.text('actions for r1 (latest)')).dy - answer.bottom, 8);
      });

      testWidgets('shows a 20 dp spinner while older messages load', (tester) async {
        await _pump(tester, _history(1), loadOlder: () => Completer<void>().future, settle: false);
        await tester.drag(find.byType(Scrollable), const Offset(0, 1500));
        await _frames(tester, const Duration(milliseconds: 16), 5);
        expect(tester.getSize(find.byType(CircularProgressIndicator)), const Size.square(20));
        expect(tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).strokeWidth, 2);
      });

      testWidgets('gives the scroll-to-latest button a 40 dp circle in a 48 dp tap target', (tester) async {
        await _pump(tester, _history(6));
        await tester.drag(find.byType(Scrollable), const Offset(0, 1500));
        await tester.pumpAndSettle();
        final button = find.byTooltip('Scroll to latest');
        final circle = find.ancestor(
          of: button,
          matching: find.byWidgetPredicate((w) => w is Material && w.shape is CircleBorder),
        );
        expect(tester.getSize(circle), const Size.square(40));

        // Just outside the circle, inside the target.
        await tester.tapAt(tester.getCenter(button) + const Offset(23, 0));
        await tester.pumpAndSettle();
        expect(find.text('Question 5'), findsOneWidget);
        expect(
          tester.widget<IgnorePointer>(find.ancestor(of: button, matching: find.byType(IgnorePointer)).first).ignoring,
          isTrue,
        );
      });

      testWidgets('shows the scroll-to-latest button once the end is more than 24 out of view', (tester) async {
        await _pump(tester, _history(6));
        final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
        final button = find.byTooltip('Scroll to latest');
        double scale() =>
            tester.widget<AnimatedScale>(find.ancestor(of: button, matching: find.byType(AnimatedScale))).scale;
        expect(scale(), 0.8);

        position.jumpTo(position.maxScrollExtent - 24);
        await tester.pumpAndSettle();
        expect(scale(), 0.8);

        position.jumpTo(position.maxScrollExtent - 25);
        await tester.pumpAndSettle();
        expect(scale(), 1);
        expect(
          tester.widget<AnimatedScale>(find.ancestor(of: button, matching: find.byType(AnimatedScale))).duration,
          Duration.zero,
          reason: 'reduced motion shows it at once',
        );
      });
    });

    group('goldens', () {
      Widget conversation(ThemeData theme) => Theme(
        data: theme,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(360, 420), disableAnimations: true),
          child: ColoredBox(
            color: theme.colorScheme.surface,
            child: SizedBox(
              width: 360,
              height: 420,
              child: AIConversationView(
                messages: [
                  _Message(
                    'u1',
                    AIMessageRole.user,
                    text: 'Can I return order A-1043?',
                    attachments: [
                      AIMessageAttachment.file(Uri.parse('https://x.io/receipt.pdf'), size: 245000),
                    ],
                  ),
                  _Message(
                    'r1',
                    AIMessageRole.assistant,
                    text: 'Yes — it was delivered on **2 September**, so you have until 2 October.',
                    parts: AIMessagePart.parseAll([
                      (
                        type: 'ai_tool_call',
                        payload: {
                          'id': 'c1',
                          'name': 'lookup_order',
                          'display_title': 'Looking up your order',
                          'status': 'completed',
                          'duration_ms': 320,
                        },
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      goldenTest('light', fileName: 'ai_conversation_view_light', builder: () => conversation(ThemeData()));

      goldenTest(
        'dark',
        fileName: 'ai_conversation_view_dark',
        builder: () => conversation(ThemeData(brightness: Brightness.dark)),
      );
    });
  });
}
