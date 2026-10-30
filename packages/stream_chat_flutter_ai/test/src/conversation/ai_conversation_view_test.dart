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
  ThemeData? theme,
  EdgeInsets padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  bool settle = true,
  bool reduceMotion = true,
}) async {
  tester.view.physicalSize = const Size(400, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AIComponentFactory(
      builders: builders,
      child: MaterialApp(
        theme: theme,
        home: MediaQuery(
          // By default no typewriter, so a reply is on screen at once.
          data: MediaQueryData(size: const Size(400, 600), disableAnimations: reduceMotion),
          child: Scaffold(
            body: AIConversationView(
              messages: messages,
              pendingMessage: pending,
              isThinking: isThinking,
              loadOlderMessages: loadOlder,
              footer: footer,
              emptyContent: empty,
              padding: padding,
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

final _olderMessagesLoader = find.byWidgetPredicate((widget) => '${widget.runtimeType}' == '_OlderMessagesLoader');

/// Holds the list pulled past its start, so the spinner stays in view until
/// the returned gesture is lifted.
Future<TestGesture> _holdPastStart(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(find.byType(Scrollable)));
  for (var i = 0; i < 10; i++) {
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
  }
  return gesture;
}

Finder _text(String text) => find.textContaining(text, findRichText: true);

/// How far below the top of the list [text] is.
double _below(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy - tester.getTopLeft(find.byType(AIConversationView)).dy;

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

    testWidgets('makes the latest turn and the padding under it at least as tall as the list', (tester) async {
      for (final bottom in [16.0, 200.0]) {
        await _pump(tester, [_user('u1'), _reply('r1')], padding: EdgeInsets.fromLTRB(16, 0, 16, bottom));
        final list = tester.getSize(find.byType(AIConversationView));
        final turn = tester.getRect(
          find.ancestor(of: find.byType(AIUserMessageView), matching: find.byType(ConstrainedBox)).first,
        );
        expect(turn.height + bottom, greaterThanOrEqualTo(list.height));
      }
    });

    testWidgets("shows a new conversation's first question where it shows every later one", (tester) async {
      for (final bottom in [16.0, 200.0]) {
        final padding = EdgeInsets.fromLTRB(16, 0, 16, bottom);
        await _pump(tester, const [], padding: padding);
        final first = [_user('u1', 'A first question')];
        await _pump(tester, first, padding: padding);
        final firstTop = _below(tester, 'A first question');
        await _pump(tester, [...first, _reply('r1')], padding: padding);
        expect(_below(tester, 'A first question'), firstTop, reason: 'its reply leaves it in place');

        await _pump(tester, [...first, _reply('r1'), _user('u2', 'A second question')], padding: padding);
        expect(_below(tester, 'A second question'), firstTop, reason: 'with $bottom under the turns');
        expect(firstTop, greaterThanOrEqualTo(0));
      }
    });

    testWidgets(
      'opens a conversation, and scrolls back to its end, with a short latest turn at the top',
      (tester) async {
        const padding = EdgeInsets.fromLTRB(16, 0, 16, 200);
        final history = [..._history(2), _user('u2', 'The latest question'), _reply('r2', text: 'Short')];
        await _pump(tester, history, padding: padding);
        final opened = _below(tester, 'The latest question');

        await _pump(tester, [...history, _user('u3', 'A new question')], padding: padding);
        expect(_below(tester, 'A new question'), opened, reason: 'where a question sent goes');

        await tester.drag(find.byType(Scrollable), const Offset(0, 1500));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Scroll to latest'));
        await tester.pumpAndSettle();
        expect(_below(tester, 'A new question'), opened);
      },
    );

    testWidgets('keeps the bottom padding under a long latest reply at its end', (tester) async {
      const padding = EdgeInsets.fromLTRB(16, 0, 16, 200);
      await _pump(tester, _history(2), padding: padding);
      final list = tester.getRect(find.byType(AIConversationView));
      final lastLine = tester.getBottomLeft(_text('Line of answer 1.').last).dy;
      expect(lastLine, lessThanOrEqualTo(list.bottom - padding.bottom));
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

    testWidgets(
      'loads again when the first turn changes while the spinner stays in view',
      (tester) async {
        var loads = 0;
        Future<void> loadOlder() async => loads++;
        await _pump(tester, [_user('u1', 'Short')], loadOlder: loadOlder, settle: false);
        final gesture = await _holdPastStart(tester);
        await tester.pump(const Duration(milliseconds: 400));
        expect(loads, 1);

        // A load that brings nothing isn't repeated.
        await tester.pump(const Duration(seconds: 2));
        expect(loads, 1);

        // A short page arrives above and the spinner is still in view: load the next.
        await _pump(tester, [_user('u0', 'Shorter'), _user('u1', 'Short')], loadOlder: loadOlder, settle: false);
        await tester.pump(const Duration(milliseconds: 400));
        expect(loads, 2);
        await gesture.up();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    // A page that only fills in the first turn, such as the question of a
    // reply that opened the list, keeps the number of turns above the anchor,
    // so the spinner keeps its State while the first turn changes.
    testWidgets(
      'loads again when a page fills in the first turn after the load',
      (tester) async {
        var loads = 0;
        Future<void> loadOlder() async => loads++;
        final messages = [_reply('r0', text: 'Short'), _user('u1', 'Short')];
        await _pump(tester, messages, loadOlder: loadOlder, settle: false);
        final gesture = await _holdPastStart(tester);
        await tester.pump(const Duration(milliseconds: 400));
        expect(loads, 1);
        final spinner = tester.state(_olderMessagesLoader);

        await _pump(tester, [_user('u0', 'Shorter'), ...messages], loadOlder: loadOlder, settle: false);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.state(_olderMessagesLoader), same(spinner));
        expect(loads, 2);
        await gesture.up();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'loads again when a page fills in the first turn during the load',
      (tester) async {
        var loads = 0;
        late Completer<void> load;
        Future<void> loadOlder() {
          loads++;
          return (load = Completer<void>()).future;
        }

        final messages = [_reply('r0', text: 'Short'), _user('u1', 'Short')];
        await _pump(tester, messages, loadOlder: loadOlder, settle: false);
        final gesture = await _holdPastStart(tester);
        await tester.pump(const Duration(milliseconds: 400));
        expect(loads, 1);
        final spinner = tester.state(_olderMessagesLoader);

        // The page is on screen before the load completes, such as when the app
        // awaits a cache write after inserting it.
        await _pump(tester, [_user('u0', 'Shorter'), ...messages], loadOlder: loadOlder, settle: false);
        load.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.state(_olderMessagesLoader), same(spinner));
        expect(loads, 2);
        await gesture.up();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('a failed load is retried only once the spinner comes back into view', (tester) async {
      var loads = 0;
      Future<void> loadOlder() async {
        loads++;
        throw StateError('offline');
      }

      await _pump(tester, _history(3), loadOlder: loadOlder, settle: false);
      await tester.drag(find.byType(Scrollable), const Offset(0, 3000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(loads, 1);
      expect(tester.takeException(), isA<StateError>());

      // Waiting or scrolling while the spinner stays in view doesn't retry.
      await tester.pump(const Duration(seconds: 2));
      await tester.drag(find.byType(Scrollable), const Offset(0, -10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(loads, 1);

      // Scrolling it out of view and back does.
      await tester.drag(find.byType(Scrollable), const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(loads, 1);
      await tester.drag(find.byType(Scrollable), const Offset(0, 3000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(loads, 2);
      expect(tester.takeException(), isA<StateError>());
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

      testWidgets('leaves no room under an answer without actions', (tester) async {
        await _pump(
          tester,
          [_user('u1', 'Q1'), _reply('r1'), _user('u2', 'Q2'), _reply('r2')],
          builders: const AIComponentBuilders(),
        );
        await tester.drag(find.byType(Scrollable), const Offset(0, 200));
        await tester.pumpAndSettle();

        final answer = tester.getRect(find.byType(AIAssistantMessageView).first);
        final question = tester.getRect(find.byType(AIUserMessageView).at(1));
        expect(question.top - answer.bottom, 24, reason: '8 between turns and 16 above the question');
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
      });

      testWidgets('scrolls to the latest on a tap just outside the circle', (tester) async {
        await _pump(tester, _history(6));
        await tester.drag(find.byType(Scrollable), const Offset(0, 1500));
        await tester.pumpAndSettle();

        // Just outside the 40 dp circle, inside the 48 dp target.
        await tester.tapAt(tester.getCenter(find.byTooltip('Scroll to latest')) + const Offset(23, 0));
        await tester.pumpAndSettle();
        expect(find.text('Question 5'), findsOneWidget);
      });

      testWidgets("casts the scroll-to-latest button's shadow in the theme's shadow color", (tester) async {
        await _pump(tester, _history(6), theme: ThemeData(shadowColor: const Color(0xFF112233)));
        final box = tester.widget<DecoratedBox>(
          find.ancestor(of: find.byTooltip('Scroll to latest'), matching: find.byType(DecoratedBox)).at(0),
        );
        final shadow = (box.decoration as BoxDecoration).boxShadow!.single;
        expect(shadow.color, const Color(0xFF112233).withValues(alpha: 0.14));
        expect(shadow.offset, const Offset(0, 2));
        expect(shadow.blurRadius, 6);
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
      });

      for (final (description, reduceMotion, duration) in [
        ('shows the scroll-to-latest button at once with reduced motion', true, Duration.zero),
        ('fades and scales the scroll-to-latest button in over 200 ms', false, const Duration(milliseconds: 200)),
      ]) {
        testWidgets(description, (tester) async {
          await _pump(tester, _history(6), reduceMotion: reduceMotion);
          final button = find.byTooltip('Scroll to latest');
          final scale = tester.widget<AnimatedScale>(find.ancestor(of: button, matching: find.byType(AnimatedScale)));
          final fade = tester.widget<AnimatedOpacity>(
            find.ancestor(of: button, matching: find.byType(AnimatedOpacity)),
          );

          expect(scale.duration, duration);
          expect(fade.duration, duration);
          if (!reduceMotion) {
            expect(scale.curve, Curves.easeInOut);
            expect(fade.curve, Curves.easeInOut);
          }
        });
      }
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
