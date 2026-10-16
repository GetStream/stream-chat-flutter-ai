import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 360, child: child),
    ),
  ),
);

/// Turns on the platform's reduced-motion setting for the rest of the test.
void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

const _question = AIToolApproval(
  title: 'Send the summary by email?',
  message: 'It goes to you only.',
  reason: 'to share the meeting notes',
);

AIToolCallPart _call({
  String id = 'call_1',
  String name = 'send_email',
  String? displayTitle,
  AIToolCallStatus status = AIToolCallStatus.awaitingApproval,
  AIToolExecutor executor = AIToolExecutor.server,
  String? targetUserId = 'alice',
  String? targetClientId,
  AIToolApproval? approval = _question,
  bool hasPayloadId = true,
}) => AIToolCallPart(
  id: id,
  name: name,
  displayTitle: displayTitle,
  status: status,
  executor: executor,
  targetUserId: targetUserId,
  targetClientId: targetClientId,
  approval: approval,
  hasPayloadId: hasPayloadId,
);

/// An approver for `alice` on `phone` that records every answer and lets the
/// test finish each one.
class _FakeBackend {
  final answers = <(String, bool)>[];
  final pending = <Completer<void>>[];

  AIToolApprover approver({String userId = 'alice', String? clientId = 'phone'}) => AIToolApprover(
    userId: userId,
    clientId: clientId,
    decide: (call, allowed) {
      answers.add((call.id, allowed));
      final completer = Completer<void>();
      pending.add(completer);
      return completer.future;
    },
  );
}

final _card = find.byType(AIToolApprovalCard);

ButtonStyleButton _button(WidgetTester tester, String label) => tester.widget<ButtonStyleButton>(
  find.ancestor(of: find.text(label), matching: find.bySubtype<ButtonStyleButton>()),
);

bool _enabled(WidgetTester tester, String label) => _button(tester, label).onPressed != null;

void main() {
  group('AIToolApprover', () {
    test('carries its identity', () {
      final approver = AIToolApprover(userId: 'alice', clientId: 'phone', decide: (_, _) async {});
      expect(approver.identity, const AIClientIdentity(userId: 'alice', clientId: 'phone'));
      expect(approver.userId, 'alice');
      expect(approver.clientId, 'phone');

      final same = AIToolApprover.forIdentity(approver.identity, decide: (_, _) async {});
      expect(same.isAwaiting(_call()), isTrue);
    });

    test('AIClientIdentity has value equality', () {
      const a = AIClientIdentity(userId: 'alice', clientId: 'phone');
      expect(a, const AIClientIdentity(userId: 'alice', clientId: 'phone'));
      expect(a.hashCode, const AIClientIdentity(userId: 'alice', clientId: 'phone').hashCode);
      expect(a, isNot(const AIClientIdentity(userId: 'alice')));
      expect(a.toString(), contains('alice'));
    });
  });

  group('AIToolApprovalState', () {
    test('reports its phase and answer', () {
      const idle = AIToolApprovalState.idle();
      const sending = AIToolApprovalState.sending(allowed: true);
      const failed = AIToolApprovalState.failed(allowed: false);

      expect([idle.isSending, idle.hasFailed, idle.allowed], [false, false, null]);
      expect([sending.isSending, sending.hasFailed, sending.allowed], [true, false, true]);
      expect([failed.isSending, failed.hasFailed, failed.allowed], [false, true, false]);
      expect(sending, const AIToolApprovalState.sending(allowed: true));
      expect(sending, isNot(const AIToolApprovalState.sending(allowed: false)));
      expect(sending.hashCode, const AIToolApprovalState.sending(allowed: true).hashCode);
      expect(failed.toString(), 'AIToolApprovalState(failed, allowed: false)');
    });
  });

  group('AIToolApprovalView', () {
    group('shows', () {
      testWidgets('for the targeted person while the call waits', (tester) async {
        final backend = _FakeBackend();
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: backend.approver())));
        expect(_card, findsOneWidget);
        expect(find.text('Send the summary by email?'), findsOneWidget);
      });

      testWidgets('on the install the call names', (tester) async {
        final backend = _FakeBackend();
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(targetClientId: 'phone'),
              approver: backend.approver(),
            ),
          ),
        );
        expect(_card, findsOneWidget);
      });

      testWidgets("for a client tool naming no install, on any of the person's devices", (tester) async {
        final backend = _FakeBackend();
        final call = _call(executor: AIToolExecutor.client);
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: call, approver: backend.approver())));
        expect(_card, findsOneWidget);

        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: call,
              approver: backend.approver(clientId: 'tablet'),
            ),
          ),
        );
        expect(_card, findsOneWidget);

        await tester.pumpWidget(_wrap(AIToolApprovalView(call: call, approver: backend.approver(clientId: null))));
        expect(_card, findsOneWidget);
      });
    });

    group('hides', () {
      final cases = <String, (AIToolCallPart, AIToolApprover Function(_FakeBackend))>{
        'when the call is not awaiting approval': (
          _call(status: AIToolCallStatus.running),
          (b) => b.approver(),
        ),
        'when the call has finished': (_call(status: AIToolCallStatus.completed), (b) => b.approver()),
        'for someone else': (_call(), (b) => b.approver(userId: 'bob')),
        'when the call targets no one': (_call(targetUserId: null), (b) => b.approver()),
        'on another install': (_call(targetClientId: 'tablet'), (b) => b.approver()),
        'on a device without an install id when the call names one': (
          _call(targetClientId: 'phone'),
          (b) => b.approver(clientId: null),
        ),
        'when the call has no id from the agent': (_call(hasPayloadId: false), (b) => b.approver()),
        'once answered': (
          _call(approval: _question.copyWith(decision: AIToolApprovalDecision.allowed)),
          (b) => b.approver(),
        ),
      };

      for (final MapEntry(key: description, value: (call, approver)) in cases.entries) {
        testWidgets(description, (tester) async {
          final backend = _FakeBackend();
          await tester.pumpWidget(_wrap(AIToolApprovalView(call: call, approver: approver(backend))));
          expect(_card, findsNothing);
          expect(find.byType(FilledButton), findsNothing);
          expect(tester.getSize(find.byType(AIToolApprovalView)).height, 0);
        });
      }
    });

    group('the default card', () {
      testWidgets('shows the question, the reason as a sentence, the message and the buttons', (tester) async {
        final backend = _FakeBackend();
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: backend.approver())));

        final texts = tester.widgetList<Text>(find.descendant(of: _card, matching: find.byType(Text)));
        expect(texts.map((t) => t.data), [
          'Send the summary by email?',
          'To share the meeting notes.',
          'It goes to you only.',
          'Allow',
          "Don't Allow",
        ]);
      });

      testWidgets("uses the agent's button titles", (tester) async {
        final backend = _FakeBackend();
        final call = _call(
          approval: _question.copyWith(allowTitle: 'Send it', declineTitle: 'Not now'),
        );
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: call, approver: backend.approver())));
        expect(find.text('Send it'), findsOneWidget);
        expect(find.text('Not now'), findsOneWidget);
      });

      testWidgets('falls back to translated wording without an approval', (tester) async {
        final backend = _FakeBackend();
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(approval: null), approver: backend.approver())));
        expect(find.text('Allow “send email”?'), findsOneWidget);
        expect(find.text('Allow'), findsOneWidget);
        expect(find.text("Don't Allow"), findsOneWidget);

        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(approval: null, displayTitle: 'Sending the summary'),
              approver: backend.approver(),
            ),
          ),
        );
        expect(find.text('Allow “Sending the summary”?'), findsOneWidget);

        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(approval: null, name: ''),
              approver: backend.approver(),
            ),
          ),
        );
        expect(find.text('Allow this tool to run?'), findsOneWidget);
      });

      testWidgets('reads the translations in scope', (tester) async {
        final backend = _FakeBackend();
        await tester.pumpWidget(
          _wrap(
            AITranslationsScope(
              translations: const _DutchTranslations(),
              child: AIToolApprovalView(call: _call(approval: null), approver: backend.approver()),
            ),
          ),
        );
        expect(find.text('“send email” toestaan?'), findsOneWidget);
        expect(find.text('Toestaan'), findsOneWidget);
      });

      testWidgets('is a semantics container with labelled buttons', (tester) async {
        final semantics = tester.ensureSemantics();
        final backend = _FakeBackend();
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: backend.approver())));

        expect(
          find.bySemanticsLabel('Allow'),
          findsOneWidget,
          reason: 'the allow button reads its label',
        );
        expect(
          tester.getSemantics(find.text('Allow')),
          matchesSemantics(
            label: 'Allow',
            isButton: true,
            hasTapAction: true,
            isEnabled: true,
            hasEnabledState: true,
            isFocusable: true,
            hasFocusAction: true,
          ),
        );
        semantics.dispose();
      });
    });

    group('answering', () {
      testWidgets('sends the answer once, disabling the buttons while it is on its way', (tester) async {
        _reduceMotion(tester);
        final backend = _FakeBackend();
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: backend.approver())));

        await tester.tap(find.text("Don't Allow"));
        await tester.pump();
        expect(backend.answers, [('call_1', false)]);
        expect(_enabled(tester, 'Allow'), isFalse);
        expect(_enabled(tester, "Don't Allow"), isFalse);
        // The pressed button shows the progress; reduced motion makes it still.
        expect(
          find.descendant(of: find.byType(OutlinedButton), matching: find.byIcon(Icons.more_horiz_rounded)),
          findsOneWidget,
        );
        expect(find.descendant(of: find.byType(FilledButton), matching: find.byType(Icon)), findsNothing);

        await tester.tap(find.text('Allow'), warnIfMissed: false);
        await tester.tap(find.text("Don't Allow"), warnIfMissed: false);
        await tester.pump();
        expect(backend.answers, hasLength(1), reason: 'taps while sending are ignored');
      });

      testWidgets('a double tap in one frame sends once', (tester) async {
        final backend = _FakeBackend();
        late AIToolApprovalDecide decide;
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(),
              approver: backend.approver(),
              builder: (context, approval, state, d) {
                decide = d;
                return const SizedBox();
              },
            ),
          ),
        );

        decide(true);
        decide(true);
        decide(false);
        expect(backend.answers, [('call_1', true)]);
      });

      testWidgets('shows a spinner on the pressed button with motion on', (tester) async {
        final backend = _FakeBackend();
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: backend.approver())));
        await tester.tap(find.text('Allow'));
        await tester.pump();
        expect(
          find.descendant(of: find.byType(FilledButton), matching: find.byType(CircularProgressIndicator)),
          findsOneWidget,
        );
      });

      testWidgets('on failure says so, reports the error and lets the person answer again', (tester) async {
        final backend = _FakeBackend();
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: backend.approver())));

        await tester.tap(find.text('Allow'));
        await tester.pump();
        backend.pending.single.completeError(StateError('offline'));
        await tester.pump();

        expect(tester.takeException(), isA<StateError>(), reason: 'reported, not rethrown');
        expect(find.text("Your answer couldn't be sent. Try again."), findsOneWidget);
        expect(_enabled(tester, 'Allow'), isTrue);
        expect(_enabled(tester, "Don't Allow"), isTrue);

        await tester.tap(find.text('Allow'));
        await tester.pump();
        expect(backend.answers, [('call_1', true), ('call_1', true)]);
        expect(find.text("Your answer couldn't be sent. Try again."), findsNothing);
        expect(_enabled(tester, 'Allow'), isFalse);
      });

      testWidgets('a decide that throws synchronously counts as a failure', (tester) async {
        final approver = AIToolApprover(userId: 'alice', decide: (_, _) => throw StateError('no network'));
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));

        await tester.tap(find.text('Allow'));
        await tester.pump();
        expect(tester.takeException(), isA<StateError>());
        expect(find.text("Your answer couldn't be sent. Try again."), findsOneWidget);
      });

      testWidgets('on success stays disabled until the call stops waiting', (tester) async {
        final backend = _FakeBackend();
        final approver = backend.approver();
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));

        await tester.tap(find.text('Allow'));
        await tester.pump();
        backend.pending.single.complete();
        await tester.pump();
        expect(_enabled(tester, 'Allow'), isFalse, reason: 'sent, but the step has not changed yet');
        expect(find.text("Your answer couldn't be sent. Try again."), findsNothing);

        // An unrelated update to the still-waiting call keeps it disabled.
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(displayTitle: 'Emailing'),
              approver: approver,
            ),
          ),
        );
        expect(_enabled(tester, 'Allow'), isFalse);

        // The backend records the answer: the question goes away.
        final answered = _call(
          status: AIToolCallStatus.running,
          approval: _question.copyWith(decision: AIToolApprovalDecision.allowed),
        );
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: answered, approver: approver)));
        expect(_card, findsNothing);

        // Asked again later, it starts fresh.
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        expect(_enabled(tester, 'Allow'), isTrue);
      });

      testWidgets('a failure for a call that moved on changes nothing', (tester) async {
        final backend = _FakeBackend();
        final approver = backend.approver();
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        await tester.tap(find.text('Allow'));
        await tester.pump();

        // Another call takes this view's place while the answer is in flight.
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(id: 'call_2'),
              approver: approver,
            ),
          ),
        );
        expect(_enabled(tester, 'Allow'), isTrue, reason: 'a new call starts idle');

        backend.pending.single.completeError(StateError('late'));
        await tester.pump();
        expect(tester.takeException(), isA<StateError>());
        expect(find.text("Your answer couldn't be sent. Try again."), findsNothing);
      });

      testWidgets('disposing while sending throws nothing', (tester) async {
        final backend = _FakeBackend();
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: backend.approver())));
        await tester.tap(find.text('Allow'));
        await tester.pump();

        await tester.pumpWidget(_wrap(const SizedBox()));
        backend.pending.single.completeError(StateError('offline'));
        await tester.pump();
        expect(tester.takeException(), isA<StateError>(), reason: 'still reported');
        expect(tester.takeException(), isNull, reason: 'no setState after dispose');

        // Completing successfully after dispose is quiet too.
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: backend.approver())));
        await tester.tap(find.text('Allow'));
        await tester.pump();
        await tester.pumpWidget(_wrap(const SizedBox()));
        backend.pending.last.complete();
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    });

    group('builder', () {
      testWidgets('replaces the card and gets the approval, the state and decide', (tester) async {
        final backend = _FakeBackend();
        final states = <AIToolApprovalState>[];
        final approvals = <AIToolApproval?>[];
        Widget view(AIToolCallPart call) => _wrap(
          AIToolApprovalView(
            call: call,
            approver: backend.approver(),
            builder: (context, approval, state, decide) {
              approvals.add(approval);
              states.add(state);
              return TextButton(onPressed: () => decide(true), child: const Text('Mine'));
            },
          ),
        );

        await tester.pumpWidget(view(_call()));
        expect(_card, findsNothing);
        expect(approvals.last, _question);
        expect(states.last, const AIToolApprovalState.idle());

        await tester.tap(find.text('Mine'));
        await tester.pump();
        expect(backend.answers, [('call_1', true)]);
        expect(states.last, const AIToolApprovalState.sending(allowed: true));

        backend.pending.single.completeError(StateError('offline'));
        await tester.pump();
        tester.takeException();
        expect(states.last, const AIToolApprovalState.failed(allowed: true));

        await tester.pumpWidget(view(_call(approval: null)));
        expect(approvals.last, isNull, reason: 'a call awaiting approval without one');
      });

      testWidgets('may decide while building', (tester) async {
        final backend = _FakeBackend();
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(),
              approver: backend.approver(),
              builder: (context, approval, state, decide) {
                if (state == const AIToolApprovalState.idle()) decide(true);
                return Text(state.toString());
              },
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.pump();
        expect(backend.answers, [('call_1', true)]);
        expect(find.text('AIToolApprovalState(sending, allowed: true)'), findsOneWidget);
      });
    });

    group('theme', () {
      Color? background(WidgetTester tester) {
        final box = tester.widget<DecoratedBox>(find.descendant(of: _card, matching: find.byType(DecoratedBox)).first);
        return (box.decoration as BoxDecoration).color;
      }

      testWidgets('defaults derive from the color scheme', (tester) async {
        final theme = ThemeData();
        final backend = _FakeBackend();
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(call: _call(), approver: backend.approver()),
            theme: theme,
          ),
        );
        expect(background(tester), theme.colorScheme.surfaceContainerLow);
        final title = tester.widget<Text>(find.text('Send the summary by email?'));
        expect(title.style?.color, theme.colorScheme.onSurface);
        expect(title.style?.fontWeight, FontWeight.w600);
      });

      testWidgets('resolves the widget, then the scope, then AITheme', (tester) async {
        final backend = _FakeBackend();
        await tester.pumpWidget(
          _wrap(
            ToolApprovalTheme(
              data: const ToolApprovalThemeData(
                backgroundColor: Color(0xFF000002),
                titleStyle: TextStyle(fontSize: 30),
              ),
              child: AIToolApprovalView(
                call: _call(),
                approver: backend.approver(),
                theme: const ToolApprovalThemeData(titleStyle: TextStyle(color: Color(0xFF000004))),
              ),
            ),
            theme: ThemeData(
              extensions: const [
                AITheme(
                  toolApprovalTheme: ToolApprovalThemeData(
                    backgroundColor: Color(0xFF000001),
                    accentColor: Color(0xFF000003),
                    failureStyle: TextStyle(color: Color(0xFF000005)),
                  ),
                ),
              ],
            ),
          ),
        );

        expect(background(tester), const Color(0xFF000002), reason: 'the scope wins over AITheme');
        final title = tester.widget<Text>(find.text('Send the summary by email?'));
        expect(title.style?.color, const Color(0xFF000004), reason: 'the widget wins');
        expect(title.style?.fontSize, 30, reason: "the widget's style merges over the scope's");
        final allow = _button(tester, 'Allow').style!;
        expect(allow.backgroundColor?.resolve({}), const Color(0xFF000003), reason: 'AITheme fills the rest');
        expect(allow.foregroundColor?.resolve({}), Colors.white, reason: 'white reads on a dark accent');
      });
    });

    group('goldens', () {
      Widget card(ThemeData theme, AIToolApprovalState state) => Theme(
        data: theme,
        child: Builder(
          builder: (context) => MediaQuery(
            // Deterministic: no spinner.
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: ColoredBox(
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 320,
                  child: AIToolApprovalCard(
                    approval: _question,
                    toolName: 'send email',
                    state: state,
                    decide: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      for (final (name, theme) in [
        ('light', ThemeData()),
        ('dark', ThemeData(brightness: Brightness.dark)),
      ]) {
        goldenTest(
          name,
          fileName: 'ai_tool_approval_card_$name',
          builder: () => GoldenTestGroup(
            columns: 1,
            children: [
              GoldenTestScenario(name: 'idle', child: card(theme, const AIToolApprovalState.idle())),
              GoldenTestScenario(
                name: 'sending',
                child: card(theme, const AIToolApprovalState.sending(allowed: true)),
              ),
              GoldenTestScenario(
                name: 'failed',
                child: card(theme, const AIToolApprovalState.failed(allowed: true)),
              ),
            ],
          ),
        );
      }
    });
  });
}

class _DutchTranslations extends DefaultAITranslations {
  const _DutchTranslations();

  @override
  String toolApprovalTitle(String? toolName) => '“$toolName” toestaan?';

  @override
  String get toolApprovalAllow => 'Toestaan';
}
