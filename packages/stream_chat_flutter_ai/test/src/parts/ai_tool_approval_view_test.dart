import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/parts/dropped_answer_report.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

const _allow = AIToolApprovalDecision.allowed;
const _decline = AIToolApprovalDecision.declined;
const _notSent = "Your answer couldn't be sent. Try again.";

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

/// Captures the dropped-answer reports for the rest of the test.
List<String> _capturePrints() {
  final printed = <String>[];
  debugDroppedAnswerReporter = printed.add;
  addTearDown(() => debugDroppedAnswerReporter = null);
  return printed;
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

/// The call once the backend recorded [decision]: no longer waiting.
AIToolCallPart _answered([AIToolApprovalDecision decision = _allow]) => _call(
  status: AIToolCallStatus.running,
  approval: _question.copyWith(decision: decision),
);

/// A backend that records every answer and lets the test finish each one.
class _FakeBackend {
  final answers = <(String, AIToolApprovalDecision)>[];
  final pending = <Completer<void>>[];

  AIToolApprover approver({String userId = 'alice', String? clientId = 'phone', Duration? sentTimeout}) =>
      AIToolApprover(
        identity: AIClientIdentity(userId: userId, clientId: clientId),
        sentTimeout: sentTimeout,
        decide: (call, decision) {
          answers.add((call.id, decision));
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
  group('AIClientIdentity', () {
    const identity = AIClientIdentity(userId: 'alice', clientId: 'phone');

    test('has value equality', () {
      expect(identity, const AIClientIdentity(userId: 'alice', clientId: 'phone'));
      expect(identity.hashCode, const AIClientIdentity(userId: 'alice', clientId: 'phone').hashCode);
      expect(identity, isNot(const AIClientIdentity(userId: 'alice')));
      expect(identity.toString(), contains('alice'));
    });

    test('rejects an empty user id', () {
      expect(() => AIClientIdentity(userId: ''.trim()), throwsAssertionError);
    });

    test("canApprove matches any of the person's devices when the call names no install", () {
      expect(identity.canApprove(_call()), isTrue);
      expect(const AIClientIdentity(userId: 'alice').canApprove(_call()), isTrue);
      expect(identity.canApprove(_call(targetClientId: 'phone')), isTrue);
      expect(identity.canApprove(_call(targetClientId: 'tablet')), isFalse);
      expect(const AIClientIdentity(userId: 'alice').canApprove(_call(targetClientId: 'phone')), isFalse);
      expect(const AIClientIdentity(userId: 'bob').canApprove(_call()), isFalse);
    });

    test('canRun needs an install id and an exact match', () {
      AIToolCallPart clientCall({String? targetClientId = 'phone'}) => _call(
        executor: AIToolExecutor.client,
        status: AIToolCallStatus.awaitingClient,
        targetClientId: targetClientId,
        approval: null,
      );

      expect(identity.canRun(clientCall()), isTrue);
      expect(identity.canRun(clientCall(targetClientId: 'tablet')), isFalse);
      expect(identity.canRun(clientCall(targetClientId: null)), isFalse, reason: 'no install named, nobody runs it');
      expect(const AIClientIdentity(userId: 'alice').canRun(clientCall()), isFalse, reason: 'no install id');
      expect(const AIClientIdentity(userId: 'bob', clientId: 'phone').canRun(clientCall()), isFalse);
      expect(identity.canRun(_call(targetClientId: 'phone')), isFalse, reason: 'awaiting approval, not the device');
    });
  });

  group('AIToolApprovalState', () {
    test('reports where the answer is', () {
      const idle = AIToolApprovalIdle();
      const sending = AIToolApprovalSending(_allow);
      const sent = AIToolApprovalSent(_decline);
      final error = StateError('offline');
      final failed = AIToolApprovalFailed(_decline, error);

      expect(
        [idle.isSending, idle.isSent, idle.hasFailed, idle.isBusy, idle.decision],
        [
          false,
          false,
          false,
          false,
          null,
        ],
      );
      expect([sending.isSending, sending.isBusy, sending.decision], [true, true, _allow]);
      expect([sent.isSent, sent.isBusy, sent.decision], [true, true, _decline]);
      expect([failed.hasFailed, failed.isBusy, failed.decision, failed.error], [true, false, _decline, error]);
    });

    test('has value equality', () {
      expect(const AIToolApprovalIdle(), const AIToolApprovalIdle());
      expect(const AIToolApprovalSending(_allow), const AIToolApprovalSending(_allow));
      expect(const AIToolApprovalSending(_allow), isNot(const AIToolApprovalSending(_decline)));
      expect(const AIToolApprovalSending(_allow), isNot(const AIToolApprovalSent(_allow)));
      expect(const AIToolApprovalSent(_allow).hashCode, const AIToolApprovalSent(_allow).hashCode);
      expect(const AIToolApprovalFailed(_allow, 'x'), const AIToolApprovalFailed(_allow, 'x'));
      expect(const AIToolApprovalFailed(_allow, 'x'), isNot(const AIToolApprovalFailed(_allow, 'y')));
      expect(const AIToolApprovalSent(_decline).toString(), 'AIToolApprovalSent(declined)');
    });
  });

  group('AIToolApprover', () {
    testWidgets('moves an answer from idle to sending to sent, notifying each step', (tester) async {
      final backend = _FakeBackend();
      final approver = backend.approver();
      var notified = 0;
      approver.addListener(() => notified++);
      final call = _call();

      expect(approver.stateOf(call), const AIToolApprovalIdle());
      approver.answer(call, _decline);
      expect(approver.stateOf(call), const AIToolApprovalSending(_decline));
      expect(notified, 1);

      approver.answer(call, _allow);
      expect(backend.answers, [('call_1', _decline)], reason: 'one answer at a time');

      backend.pending.single.complete();
      await tester.pump();
      expect(approver.stateOf(call), const AIToolApprovalSent(_decline));
      expect(notified, 2);

      approver.answer(call, _allow);
      expect(backend.answers, hasLength(1), reason: 'nothing more once sent');

      expect(approver.stateOf(_answered(_decline)), const AIToolApprovalIdle(), reason: 'forgotten once answered');
      expect(approver.stateOf(call), const AIToolApprovalIdle());
      approver.dispose();
    });

    testWidgets('keeps the error of a failed answer, and lets the person answer again', (tester) async {
      final backend = _FakeBackend();
      final approver = backend.approver();
      final call = _call();
      final error = StateError('offline');

      approver.answer(call, _allow);
      backend.pending.single.completeError(error);
      await tester.pump();
      expect(tester.takeException(), same(error));
      expect(approver.stateOf(call), AIToolApprovalFailed(_allow, error));

      approver.answer(call, _decline);
      expect(approver.stateOf(call), const AIToolApprovalSending(_decline));
      approver.dispose();
    });

    testWidgets('a late failure for an answer since forgotten changes nothing', (tester) async {
      final backend = _FakeBackend();
      final approver = backend.approver()..answer(_call(), _allow);

      // The call stops waiting, and is asked again; the person answers again.
      expect(approver.stateOf(_answered()), const AIToolApprovalIdle());
      approver.answer(_call(), _decline);
      expect(backend.answers, [('call_1', _allow), ('call_1', _decline)]);

      backend.pending.first.completeError(StateError('late'));
      await tester.pump();
      expect(tester.takeException(), isA<StateError>());
      expect(approver.stateOf(_call()), const AIToolApprovalSending(_decline), reason: 'still the second answer');

      backend.pending.last.complete();
      await tester.pump();
      expect(approver.stateOf(_call()), const AIToolApprovalSent(_decline));
      approver.dispose();
    });

    testWidgets('an answer for a call that does not wait for this person is dropped', (tester) async {
      final printed = _capturePrints();
      final backend = _FakeBackend();
      final approver = backend.approver(userId: 'bob')..answer(_call(), _allow);
      expect(backend.answers, isEmpty);
      expect(printed.single, contains('dropped an answer to tool call "call_1"'));
      approver.dispose();
    });

    testWidgets('a sent answer turns failed after the sent timeout', (tester) async {
      final backend = _FakeBackend();
      final approver = backend.approver(sentTimeout: const Duration(seconds: 5));
      final call = _call();

      approver.answer(call, _allow);
      backend.pending.single.complete();
      await tester.pump();
      expect(approver.stateOf(call), const AIToolApprovalSent(_allow));

      await tester.pump(const Duration(seconds: 4));
      expect(approver.stateOf(call).isSent, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: 'not before something sees the call still waiting');
      final state = approver.stateOf(call);
      expect(state, isA<AIToolApprovalFailed>());
      expect((state as AIToolApprovalFailed).error, isA<TimeoutException>());
      await tester.pump();
      expect(tester.takeException(), isA<TimeoutException>(), reason: 'a timeout is reported, likely a backend bug');
      approver.stateOf(call);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'reported once');
      approver.dispose();
    });

    testWidgets('a send that hangs turns failed after the sent timeout', (tester) async {
      final backend = _FakeBackend();
      final approver = backend.approver(sentTimeout: const Duration(seconds: 5));
      final call = _call();

      approver.answer(call, _allow);
      await tester.pump(const Duration(seconds: 5));
      expect(approver.stateOf(call), isA<AIToolApprovalFailed>());
      expect(tester.takeException(), isA<TimeoutException>());
      approver.dispose();
    });

    testWidgets('answering one call leaves another call idle', (tester) async {
      final backend = _FakeBackend();
      final approver = backend.approver();
      final first = _call();
      final second = _call().copyWith(id: 'call_2');

      approver.answer(first, _allow);
      expect(approver.stateOf(first), isA<AIToolApprovalSending>());
      expect(approver.stateOf(second), const AIToolApprovalIdle());
      backend.pending.single.completeError(StateError('offline'));
      await tester.pump();
      expect(tester.takeException(), isA<StateError>());
      expect(approver.stateOf(first), isA<AIToolApprovalFailed>());
      expect(approver.stateOf(second), const AIToolApprovalIdle());
      approver.dispose();
    });

    testWidgets('a send that succeeds after the call moved on changes nothing', (tester) async {
      final backend = _FakeBackend();
      final approver = backend.approver();
      final call = _call();

      approver.answer(call, _allow);
      expect(approver.stateOf(_answered()), const AIToolApprovalIdle(), reason: 'the step moved on');
      backend.pending.single.complete();
      await tester.pump();
      expect(approver.stateOf(call), const AIToolApprovalIdle());
      approver.dispose();
    });

    testWidgets('the sent timeout is cancelled once the call stops waiting', (tester) async {
      final backend = _FakeBackend();
      final approver = backend.approver(sentTimeout: const Duration(seconds: 5));
      var notified = 0;
      approver
        ..addListener(() => notified++)
        ..answer(_call(), _allow);
      backend.pending.single.complete();
      await tester.pump();
      approver.stateOf(_answered());
      notified = 0;
      await tester.pump(const Duration(seconds: 10));
      expect(notified, 0);
      approver.dispose();
    });

    testWidgets('disposed, it drops answers and ignores completions', (tester) async {
      final printed = _capturePrints();
      final backend = _FakeBackend();
      final approver = backend.approver()
        ..answer(_call(), _allow)
        ..dispose();
      backend.pending.single.complete();
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'no notify after dispose');

      approver.answer(_call(), _allow);
      expect(backend.answers, hasLength(1));
      expect(printed.single, contains('disposed'));
    });
  });

  group('AIToolApprovalView', () {
    late _FakeBackend backend;
    late AIToolApprover approver;
    setUp(() {
      backend = _FakeBackend();
      approver = backend.approver();
    });

    group('shows', () {
      testWidgets('for the targeted person while the call waits', (tester) async {
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        expect(_card, findsOneWidget);
        expect(find.text('Send the summary by email?'), findsOneWidget);
      });

      testWidgets('on the install the call names', (tester) async {
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(targetClientId: 'phone'),
              approver: approver,
            ),
          ),
        );
        expect(_card, findsOneWidget);
      });

      testWidgets("for a client tool naming no install, on any of the person's devices", (tester) async {
        final call = _call(executor: AIToolExecutor.client);
        for (final clientId in ['phone', 'tablet', null]) {
          await tester.pumpWidget(
            _wrap(
              AIToolApprovalView(
                call: call,
                approver: backend.approver(clientId: clientId),
              ),
            ),
          );
          expect(_card, findsOneWidget, reason: '$clientId');
        }
      });
    });

    group('hides', () {
      final cases = <String, (AIToolCallPart, AIToolApprover Function(_FakeBackend))>{
        'when the call is not awaiting approval': (_call(status: AIToolCallStatus.running), (b) => b.approver()),
        'when the call has finished': (_call(status: AIToolCallStatus.completed), (b) => b.approver()),
        'for someone else': (_call(), (b) => b.approver(userId: 'bob')),
        'when the call targets no one': (_call(targetUserId: null), (b) => b.approver()),
        'on another install': (_call(targetClientId: 'tablet'), (b) => b.approver()),
        'on a device without an install id when the call names one': (
          _call(targetClientId: 'phone'),
          (b) => b.approver(clientId: null),
        ),
        'when the call has no id from the agent': (_call(hasPayloadId: false), (b) => b.approver()),
        'once answered': (_answered(), (b) => b.approver()),
      };

      for (final MapEntry(key: description, value: (call, approver)) in cases.entries) {
        testWidgets(description, (tester) async {
          await tester.pumpWidget(_wrap(AIToolApprovalView(call: call, approver: approver(_FakeBackend()))));
          expect(_card, findsNothing);
          expect(find.byType(FilledButton), findsNothing);
          expect(tester.getSize(find.byType(AIToolApprovalView)).height, 0);
        });
      }
    });

    group('the default card', () {
      List<String?> texts(WidgetTester tester) =>
          tester.widgetList<Text>(find.descendant(of: _card, matching: find.byType(Text))).map((t) => t.data).toList();

      testWidgets('shows the question, the reason as a sentence, the message and the buttons', (tester) async {
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        expect(texts(tester), [
          'Send the summary by email?',
          'To share the meeting notes.',
          'It goes to you only.',
          'Allow',
          "Don't Allow",
        ]);
      });

      testWidgets('adds no full stop to a reason that already ends a sentence', (tester) async {
        for (final reason in ['you asked for it!', 'is that ok?', 'as discussed.', 'and so on…']) {
          await tester.pumpWidget(
            _wrap(
              AIToolApprovalView(
                call: _call(approval: AIToolApproval(reason: reason)),
                approver: approver,
              ),
            ),
          );
          expect(texts(tester)[1], reason[0].toUpperCase() + reason.substring(1));
        }
      });

      testWidgets("uses the agent's button titles", (tester) async {
        final call = _call(
          approval: _question.copyWith(allowTitle: 'Send it', declineTitle: 'Not now'),
        );
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: call, approver: approver)));
        expect(find.text('Send it'), findsOneWidget);
        expect(find.text('Not now'), findsOneWidget);
      });

      testWidgets('falls back to the tool name without an approval, not the display title', (tester) async {
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(approval: null, displayTitle: 'Sending the summary'),
              approver: approver,
            ),
          ),
        );
        expect(find.text('Allow “send email”?'), findsOneWidget);
        expect(find.text('Allow'), findsOneWidget);
        expect(find.text("Don't Allow"), findsOneWidget);

        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(approval: null, name: ''),
              approver: approver,
            ),
          ),
        );
        expect(find.text('Allow this tool to run?'), findsOneWidget);
      });

      testWidgets('falls back for blank titles too', (tester) async {
        final call = _call(
          approval: const AIToolApproval(title: '  ', allowTitle: ' ', declineTitle: '\n'),
        );
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: call, approver: approver)));
        expect(texts(tester), ['Allow “send email”?', 'Allow', "Don't Allow"]);
      });

      testWidgets('reads the translations in scope', (tester) async {
        await tester.pumpWidget(
          _wrap(
            AITranslationsScope(
              translations: const _DutchTranslations(),
              child: AIToolApprovalView(call: _call(approval: null), approver: approver),
            ),
          ),
        );
        expect(find.text('“send email” toestaan?'), findsOneWidget);
        expect(find.text('Toestaan'), findsOneWidget);
      });
    });

    group('semantics', () {
      testWidgets('the card is a container with labelled buttons', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));

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
        final container = tester.getSemantics(_card);
        expect(container.label, isEmpty, reason: 'a container, not one merged label');
        semantics.dispose();
      });

      testWidgets('while sending, the buttons are disabled and the pressed one says so', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        await tester.tap(find.text('Allow'));
        await tester.pump();

        final allow = tester.getSemantics(find.byType(FilledButton));
        expect(allow.label, contains('Sending your answer…'));
        expect(allow.flagsCollection.isEnabled, Tristate.isFalse);
        expect(tester.getSemantics(find.byType(OutlinedButton)).flagsCollection.isEnabled, Tristate.isFalse);
        semantics.dispose();
      });

      testWidgets('the failure line is a live region', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        await tester.tap(find.text('Allow'));
        await tester.pump();
        backend.pending.single.completeError(StateError('offline'));
        await tester.pump();
        tester.takeException();

        expect(tester.getSemantics(find.text(_notSent)).flagsCollection.isLiveRegion, isTrue);
        semantics.dispose();
      });
    });

    group('answering', () {
      testWidgets('declining sends once, disabling the buttons while it is on its way', (tester) async {
        _reduceMotion(tester);
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));

        await tester.tap(find.text("Don't Allow"));
        await tester.pump();
        expect(backend.answers, [('call_1', _decline)]);
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

      testWidgets('allowing shows a spinner on the allow button with motion on', (tester) async {
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        await tester.tap(find.text('Allow'));
        await tester.pump();
        expect(backend.answers, [('call_1', _allow)]);
        expect(
          find.descendant(of: find.byType(FilledButton), matching: find.byType(CircularProgressIndicator)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: find.byType(OutlinedButton), matching: find.byType(CircularProgressIndicator)),
          findsNothing,
        );
      });

      testWidgets('a double tap in one frame sends once', (tester) async {
        late AIToolApprovalAnswer answer;
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(),
              approver: approver,
              builder: (context, approval, state, a) {
                answer = a;
                return const SizedBox();
              },
            ),
          ),
        );

        answer(_allow);
        answer(_allow);
        answer(_decline);
        expect(backend.answers, [('call_1', _allow)]);
      });

      for (final (label, decision) in [('Allow', _allow), ("Don't Allow", _decline)]) {
        testWidgets('on failure to send "$label", says so and lets the person answer again', (tester) async {
          await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));

          await tester.tap(find.text(label));
          await tester.pump();
          backend.pending.single.completeError(StateError('offline'));
          await tester.pump();

          expect(tester.takeException(), isA<StateError>(), reason: 'reported, not rethrown');
          expect(find.text(_notSent), findsOneWidget);
          expect(_enabled(tester, 'Allow'), isTrue);
          expect(_enabled(tester, "Don't Allow"), isTrue);

          await tester.tap(find.text(label));
          await tester.pump();
          expect(backend.answers, [('call_1', decision), ('call_1', decision)]);
          expect(find.text(_notSent), findsNothing);
          expect(_enabled(tester, 'Allow'), isFalse);
        });
      }

      testWidgets('a decide that throws synchronously counts as a failure', (tester) async {
        final approver = AIToolApprover(
          identity: const AIClientIdentity(userId: 'alice'),
          decide: (_, _) => throw StateError('no network'),
        );
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));

        await tester.tap(find.text('Allow'));
        await tester.pump();
        expect(tester.takeException(), isA<StateError>());
        expect(find.text(_notSent), findsOneWidget);
      });

      testWidgets('once sent, says so and stays disabled until the call stops waiting', (tester) async {
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));

        await tester.tap(find.text('Allow'));
        await tester.pump();
        expect(find.text('Sent'), findsNothing, reason: 'not while it is on its way');
        backend.pending.single.complete();
        await tester.pump();
        expect(find.text('Sent'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'no spinner once sent');
        expect(_enabled(tester, 'Allow'), isFalse, reason: 'sent, but the step has not changed yet');

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
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _answered(), approver: approver)));
        expect(_card, findsNothing);

        // Asked again later, it starts fresh.
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        expect(_enabled(tester, 'Allow'), isTrue);
      });

      testWidgets('an answer a builder kept never goes to another call', (tester) async {
        final approver = backend.approver();
        AIToolApprovalAnswer? kept;
        Widget build(AIToolCallPart call) => _wrap(
          AIToolApprovalView(
            call: call,
            approver: approver,
            builder: (context, approval, state, answer) {
              kept ??= answer;
              return const SizedBox();
            },
          ),
        );

        await tester.pumpWidget(build(_call()));
        await tester.pumpWidget(build(_call().copyWith(id: 'call_2')));
        kept!(_allow);
        await tester.pump();
        expect(backend.pending, isEmpty, reason: 'call_1 is not shown any more, and call_2 was never answered');
      });

      testWidgets('the sent timeout lets the person answer again', (tester) async {
        final approver = backend.approver(sentTimeout: const Duration(seconds: 3));
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        await tester.tap(find.text('Allow'));
        await tester.pump();
        backend.pending.single.complete();
        await tester.pump();
        expect(find.text('Sent'), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isA<TimeoutException>());
        await tester.pump();
        expect(find.text('Sent'), findsNothing);
        expect(find.text(_notSent), findsOneWidget);
        expect(_enabled(tester, 'Allow'), isTrue);
      });

      testWidgets('a sent timeout while no view shows the call is not reported if the call moved on', (tester) async {
        final approver = backend.approver(sentTimeout: const Duration(seconds: 3));
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        await tester.tap(find.text('Allow'));
        await tester.pump();
        backend.pending.single.complete();
        await tester.pump();
        expect(find.text('Sent'), findsOneWidget);

        // The person leaves the chat; meanwhile the backend moves the call on.
        await tester.pumpWidget(_wrap(const SizedBox()));
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull, reason: 'nothing says the call still waits');

        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _answered(), approver: approver)));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_card, findsNothing);
      });

      testWidgets('a sent timeout while no view shows the call is reported once it shows still waiting', (
        tester,
      ) async {
        final approver = backend.approver(sentTimeout: const Duration(seconds: 3));
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        await tester.tap(find.text('Allow'));
        await tester.pump();
        backend.pending.single.complete();
        await tester.pump();

        await tester.pumpWidget(_wrap(const SizedBox()));
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        await tester.pump();
        expect(tester.takeException(), isA<TimeoutException>(), reason: 'the backend never moved the call on');
        expect(find.text(_notSent), findsOneWidget);
        expect(_enabled(tester, 'Allow'), isTrue);

        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(displayTitle: 'Again'),
              approver: approver,
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'reported once');
      });

      testWidgets('a late failure for an earlier round changes nothing', (tester) async {
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        await tester.tap(find.text('Allow'));
        await tester.pump();

        // The call stops waiting, is asked again, and the person answers again.
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _answered(), approver: approver)));
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        expect(_enabled(tester, 'Allow'), isTrue, reason: 'asked again, it starts idle');
        await tester.tap(find.text('Allow'));
        await tester.pump();

        backend.pending.first.completeError(StateError('late'));
        await tester.pump();
        expect(tester.takeException(), isA<StateError>());
        expect(find.text(_notSent), findsNothing);
        expect(_enabled(tester, 'Allow'), isFalse, reason: 'the second answer is still on its way');

        backend.pending.last.complete();
        await tester.pump();
        expect(find.text('Sent'), findsOneWidget);
      });

      testWidgets('keeps a sent answer when scrolled away in a lazy list and back', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                child: ListView.builder(
                  controller: controller,
                  itemCount: 30,
                  itemBuilder: (context, index) => index == 0
                      ? AIToolApprovalView(call: _call(), approver: approver)
                      : SizedBox(height: 100, child: Text('row $index')),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Allow'));
        await tester.pump();

        controller.jumpTo(2000);
        await tester.pump();
        expect(_card, findsNothing, reason: 'scrolled out and disposed');
        backend.pending.single.complete();
        await tester.pump();

        controller.jumpTo(0);
        await tester.pump();
        expect(find.text('Sent'), findsOneWidget);
        expect(_enabled(tester, 'Allow'), isFalse);
      });

      testWidgets('keeps a failure that arrived while scrolled away', (tester) async {
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        await tester.tap(find.text('Allow'));
        await tester.pump();

        await tester.pumpWidget(_wrap(const SizedBox()));
        backend.pending.single.completeError(StateError('offline'));
        await tester.pump();
        expect(tester.takeException(), isA<StateError>(), reason: 'still reported');
        expect(tester.takeException(), isNull, reason: 'no setState after dispose');

        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        expect(find.text(_notSent), findsOneWidget);
      });

      testWidgets('an approver swap mid-send shows each approver its own state', (tester) async {
        final bob = backend.approver(userId: 'bob');
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        await tester.tap(find.text('Allow'));
        await tester.pump();

        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: bob)));
        expect(_card, findsNothing, reason: 'not for bob');

        backend.pending.single.complete();
        await tester.pump();
        await tester.pumpWidget(_wrap(AIToolApprovalView(call: _call(), approver: approver)));
        expect(find.text('Sent'), findsOneWidget, reason: "alice's answer was kept");

        // The view listens to the approver it shows now, not the old one.
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(targetUserId: 'bob'),
              approver: bob,
            ),
          ),
        );
        expect(_enabled(tester, 'Allow'), isTrue);
        bob.answer(_call(targetUserId: 'bob'), _decline);
        await tester.pump();
        expect(_enabled(tester, 'Allow'), isFalse);
      });

      testWidgets('an answer kept past its question is dropped', (tester) async {
        final printed = _capturePrints();
        late AIToolApprovalAnswer answer;
        Widget view(AIToolCallPart call) => _wrap(
          AIToolApprovalView(
            call: call,
            approver: approver,
            builder: (context, approval, state, a) {
              answer = a;
              return const SizedBox();
            },
          ),
        );

        await tester.pumpWidget(view(_call()));
        final stale = answer;
        await tester.pumpWidget(view(_answered()));

        stale(_decline);
        expect(backend.answers, isEmpty);
        expect(printed.single, contains('no longer waits'));
      });

      testWidgets('an answer given mid-build is re-checked after the frame', (tester) async {
        final printed = _capturePrints();
        late AIToolApprovalAnswer answer;
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(),
              approver: approver,
              builder: (context, approval, state, a) {
                answer = a;
                return const SizedBox();
              },
            ),
          ),
        );
        final captured = answer;

        // Answered while building the frame in which the call stops waiting.
        await tester.pumpWidget(
          _wrap(
            Column(
              children: [
                AIToolApprovalView(call: _answered(), approver: approver),
                Builder(
                  builder: (context) {
                    captured(_allow);
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        );
        expect(backend.answers, isEmpty);
        expect(printed, isNotEmpty);

        // Answered while building the frame in which the view goes away.
        printed.clear();
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(),
              approver: approver,
              builder: (_, _, _, a) {
                answer = a;
                return const SizedBox();
              },
            ),
          ),
        );
        final doomed = answer;
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) {
                doomed(_allow);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(backend.answers, isEmpty);
        expect(printed.single, contains('disposed'));
      });
      testWidgets('an answer given mid-frame is sent once the frame ends', (tester) async {
        late AIToolApprovalAnswer answer;
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(),
              approver: approver,
              builder: (context, approval, state, a) {
                answer = a;
                return const SizedBox();
              },
            ),
          ),
        );

        SchedulerPhase? phase;
        var sentRightAway = true;
        SchedulerBinding.instance.scheduleFrameCallback((_) {
          scheduleMicrotask(() {
            phase = SchedulerBinding.instance.schedulerPhase;
            answer(_allow);
            sentRightAway = backend.answers.isNotEmpty;
          });
        });
        await tester.pump();
        expect(phase, SchedulerPhase.midFrameMicrotasks);
        expect(sentRightAway, isFalse, reason: 'waits for the frame to end');
        expect(backend.answers, [('call_1', _allow)]);
      });
    });

    group('builder', () {
      testWidgets('replaces the card and gets the approval, the state and answer', (tester) async {
        final states = <AIToolApprovalState>[];
        final approvals = <AIToolApproval?>[];
        Widget view(AIToolCallPart call) => _wrap(
          AIToolApprovalView(
            call: call,
            approver: approver,
            builder: (context, approval, state, answer) {
              approvals.add(approval);
              states.add(state);
              return TextButton(onPressed: () => answer(_allow), child: const Text('Mine'));
            },
          ),
        );

        await tester.pumpWidget(view(_call()));
        expect(_card, findsNothing);
        expect(approvals.last, _question);
        expect(states.last, const AIToolApprovalIdle());

        await tester.tap(find.text('Mine'));
        await tester.pump();
        expect(backend.answers, [('call_1', _allow)]);
        expect(states.last, const AIToolApprovalSending(_allow));

        final error = StateError('offline');
        backend.pending.single.completeError(error);
        await tester.pump();
        expect(tester.takeException(), same(error));
        expect(states.last, AIToolApprovalFailed(_allow, error));

        await tester.pumpWidget(view(_call(approval: null)));
        expect(approvals.last, isNull, reason: 'a call awaiting approval without one');
      });

      testWidgets('may answer while building', (tester) async {
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(),
              approver: approver,
              builder: (context, approval, state, answer) {
                if (state is AIToolApprovalIdle) answer(_allow);
                return Text(state.toString());
              },
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.pump();
        expect(backend.answers, [('call_1', _allow)]);
        expect(find.text('AIToolApprovalSending(allowed)'), findsOneWidget);
      });
    });

    group('theme', () {
      Color? background(WidgetTester tester) {
        final box = tester.widget<DecoratedBox>(find.descendant(of: _card, matching: find.byType(DecoratedBox)).first);
        return (box.decoration as BoxDecoration).color;
      }

      testWidgets('defaults derive from the color scheme', (tester) async {
        final theme = ThemeData();
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(call: _call(), approver: approver),
            theme: theme,
          ),
        );
        expect(background(tester), theme.colorScheme.surfaceContainerLow);
        final title = tester.widget<Text>(find.text('Send the summary by email?'));
        expect(title.style?.color, theme.colorScheme.onSurface);
        expect(title.style?.fontWeight, FontWeight.w600);
        final allow = _button(tester, 'Allow').style!;
        expect(allow.backgroundColor?.resolve({}), theme.colorScheme.primary);
        expect(allow.foregroundColor?.resolve({}), theme.colorScheme.onPrimary);
      });

      testWidgets('resolves the widget, then the scope, then AITheme', (tester) async {
        await tester.pumpWidget(
          _wrap(
            ToolApprovalTheme(
              data: const ToolApprovalThemeData(
                backgroundColor: Color(0xFF000002),
                titleStyle: TextStyle(fontSize: 30),
              ),
              child: AIToolApprovalView(
                call: _call(),
                approver: approver,
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

      testWidgets('a light accent gets black labels', (tester) async {
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(),
              approver: approver,
              theme: const ToolApprovalThemeData(accentColor: Color(0xFFFFEB3B)),
            ),
          ),
        );
        expect(_button(tester, 'Allow').style!.foregroundColor?.resolve({}), Colors.black);
      });

      testWidgets('an inherit: false style replaces the base but keeps a color', (tester) async {
        final theme = ThemeData();
        await tester.pumpWidget(
          _wrap(
            AIToolApprovalView(
              call: _call(),
              approver: approver,
              theme: const ToolApprovalThemeData(messageStyle: TextStyle(inherit: false, fontSize: 9)),
            ),
            theme: theme,
          ),
        );
        final message = tester.widget<Text>(find.text('It goes to you only.')).style!;
        expect(message.inherit, isFalse);
        expect(message.fontSize, 9);
        expect(message.color, theme.colorScheme.onSurfaceVariant);
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
                    onAnswer: (_) {},
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
              GoldenTestScenario(name: 'idle', child: card(theme, const AIToolApprovalIdle())),
              GoldenTestScenario(name: 'sending', child: card(theme, const AIToolApprovalSending(_allow))),
              GoldenTestScenario(name: 'sent', child: card(theme, const AIToolApprovalSent(_allow))),
              GoldenTestScenario(name: 'failed', child: card(theme, const AIToolApprovalFailed(_allow, 'offline'))),
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
