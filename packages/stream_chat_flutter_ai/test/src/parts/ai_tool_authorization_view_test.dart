import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/parts/dropped_answer_report.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

const _connect = 'Connect';
const _connecting = 'Connecting…';
const _notNow = 'Not now';
const _notOpened = "The sign-in couldn't be opened. Try again.";
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

/// Captures the dropped-answer reports for the rest of the test.
List<String> _capturePrints() {
  final printed = <String>[];
  debugDroppedAnswerReporter = printed.add;
  addTearDown(() => debugDroppedAnswerReporter = null);
  return printed;
}

final _signIn = AIToolAuthorization(
  provider: 'linear',
  providerName: 'Linear',
  title: 'Connect Linear',
  message: 'You sign in at Linear, and the agent never sees your password.',
  url: Uri.parse('https://agent.example/launch/abc'),
  handoffToken: 'a+b',
);

AIToolCallPart _call({
  String id = 'call_1',
  AIToolCallStatus status = AIToolCallStatus.awaitingAuthorization,
  String? targetUserId = 'alice',
  AIToolAuthorization? authorization,
  bool noAuthorization = false,
}) => AIToolCallPart(
  id: id,
  name: 'linear__list_issues',
  displayTitle: 'Using Linear',
  status: status,
  targetUserId: targetUserId,
  authorization: noAuthorization ? null : authorization ?? _signIn,
);

/// A backend and a browser that record every sign-in and "not now", and let
/// the test finish each one.
class _Fake {
  final opened = <(String, Uri)>[];
  final connects = <Completer<bool>>[];
  final declined = <String>[];
  final declines = <Completer<void>>[];

  late final authorizer = AIToolAuthorizer(
    connect: (call, url) {
      opened.add((call.id, url));
      final completer = Completer<bool>();
      connects.add(completer);
      return completer.future;
    },
    decline: (call) {
      declined.add(call.id);
      final completer = Completer<void>();
      declines.add(completer);
      return completer.future;
    },
  );

  AIToolApprover approver({String userId = 'alice', bool withAuthorizer = true, Duration? sentTimeout}) =>
      AIToolApprover(
        identity: AIClientIdentity(userId: userId, clientId: 'phone'),
        decide: (_, _) async {},
        sentTimeout: sentTimeout,
        authorizer: withAuthorizer ? authorizer : null,
      );
}

/// Collects what [FlutterError.reportError] reports for the rest of the test.
List<FlutterErrorDetails> _captureErrors() {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  addTearDown(() => FlutterError.onError = previous);
  return errors;
}

final _card = find.byType(AIToolAuthorizationCard);

bool _enabled(WidgetTester tester, String label) => tester
    .widget<ButtonStyleButton>(find.ancestor(of: find.text(label), matching: find.bySubtype<ButtonStyleButton>()))
    .enabled;

void main() {
  group('AIToolAuthorizationState', () {
    test('is busy while connecting or declining', () {
      expect(const AIToolAuthorizationState().isBusy, isFalse);
      expect(const AIToolAuthorizationState(isConnecting: true).isBusy, isTrue);
      expect(const AIToolAuthorizationState(isDeclining: true).isBusy, isTrue);
      expect(const AIToolAuthorizationState(connectFailed: true).isBusy, isFalse);
      expect(const AIToolAuthorizationState(declineFailed: true).isBusy, isFalse);
    });

    test('has value equality', () {
      expect(const AIToolAuthorizationState(isConnecting: true), const AIToolAuthorizationState(isConnecting: true));
      expect(const AIToolAuthorizationState(), isNot(const AIToolAuthorizationState(connectFailed: true)));
    });
  });

  group('AIToolApprover sign-in', () {
    test('asks only with an authorizer, for the targeted person, while the call waits, for oauth', () {
      final fake = _Fake();
      final approver = fake.approver();
      addTearDown(approver.dispose);
      final withoutAuthorizer = fake.approver(withAuthorizer: false);
      addTearDown(withoutAuthorizer.dispose);

      expect(approver.signInFor(_call()), _signIn);
      expect(withoutAuthorizer.signInFor(_call()), isNull);
      expect(approver.signInFor(_call(targetUserId: 'bob')), isNull);
      expect(approver.signInFor(_call(status: AIToolCallStatus.running)), isNull);
      expect(approver.signInFor(_call(noAuthorization: true)), isNull);
      expect(
        approver.signInFor(_call(authorization: _signIn.copyWith(kind: const AIToolAuthorizationKind('device')))),
        isNull,
      );
      expect(
        approver.signInFor(_call(authorization: _signIn.copyWith(status: AIToolAuthorizationStatus.declined))),
        isNull,
      );
    });

    testWidgets('connect opens the launch url and stays connecting once connected', (tester) async {
      final fake = _Fake();
      final approver = fake.approver();
      addTearDown(approver.dispose);
      var notified = 0;
      approver
        ..addListener(() => notified++)
        ..connect(_call());
      expect(fake.opened, [('call_1', _signIn.launchUrl)]);
      expect(approver.authorizationStateOf(_call()), const AIToolAuthorizationState(isConnecting: true));
      expect(notified, 1);

      fake.connects.single.complete(true);
      await tester.pump();
      expect(approver.authorizationStateOf(_call()), const AIToolAuthorizationState(isConnecting: true));

      // The step moves on, and the sign-in is forgotten.
      expect(approver.authorizationStateOf(_call(status: AIToolCallStatus.running)), const AIToolAuthorizationState());
      expect(approver.authorizationStateOf(_call()), const AIToolAuthorizationState());
    });

    testWidgets('coming back without connecting lets the person connect again', (tester) async {
      final fake = _Fake();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver
        ..connect(_call())
        ..connect(_call()); // ignored while connecting
      expect(fake.opened, hasLength(1));

      fake.connects.single.complete(false);
      await tester.pump();
      expect(approver.authorizationStateOf(_call()), const AIToolAuthorizationState());

      approver.connect(_call());
      expect(fake.opened, hasLength(2));
    });

    testWidgets('a page that could not be opened is reported and can be tried again', (tester) async {
      final errors = _captureErrors();
      final fake = _Fake();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver.connect(_call());
      fake.connects.single.completeError(StateError('no browser'));
      await tester.pump();

      expect(approver.authorizationStateOf(_call()), const AIToolAuthorizationState(connectFailed: true));
      expect(errors.single.exception, isA<StateError>());
      expect(errors.single.context.toString(), contains('opening the sign-in of tool call "call_1"'));
    });

    testWidgets('a connect that throws synchronously counts as not opened', (tester) async {
      _captureErrors();
      final approver = AIToolApprover(
        identity: const AIClientIdentity(userId: 'alice'),
        decide: (_, _) async {},
        authorizer: AIToolAuthorizer(connect: (_, _) => throw StateError('no browser'), decline: (_) async {}),
      );
      addTearDown(approver.dispose);

      approver.connect(_call());
      await tester.pump();

      expect(approver.authorizationStateOf(_call()), const AIToolAuthorizationState(connectFailed: true));
    });

    testWidgets('not now is sent once and stays declining until the step changes', (tester) async {
      final fake = _Fake();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver
        ..declineAuthorization(_call())
        ..declineAuthorization(_call());
      expect(fake.declined, ['call_1']);
      expect(approver.authorizationStateOf(_call()), const AIToolAuthorizationState(isDeclining: true));

      fake.declines.single.complete();
      await tester.pump();
      expect(approver.authorizationStateOf(_call()), const AIToolAuthorizationState(isDeclining: true));

      // Connect waits while declining.
      approver.connect(_call());
      expect(fake.opened, isEmpty);
    });

    testWidgets('a not now that could not be sent is reported and can be sent again', (tester) async {
      final errors = _captureErrors();
      final fake = _Fake();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver.declineAuthorization(_call());
      fake.declines.single.completeError(Exception('offline'));
      await tester.pump();

      expect(approver.authorizationStateOf(_call()), const AIToolAuthorizationState(declineFailed: true));
      expect(errors.single.context.toString(), contains('"not now" for tool call "call_1"'));

      approver.declineAuthorization(_call());
      expect(fake.declined, hasLength(2));
    });

    testWidgets('not now may be sent while the sign-in is open, and stays when it comes back', (tester) async {
      final fake = _Fake();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver
        ..connect(_call())
        ..declineAuthorization(_call());
      expect(fake.declined, ['call_1']);

      fake.connects.single.complete(false);
      await tester.pump();
      expect(approver.authorizationStateOf(_call()), const AIToolAuthorizationState(isDeclining: true));
    });

    testWidgets('the sent timeout bounds the not now', (tester) async {
      final errors = _captureErrors();
      final fake = _Fake();
      final approver = fake.approver(sentTimeout: const Duration(seconds: 5));
      addTearDown(approver.dispose);

      approver.declineAuthorization(_call());
      await tester.pump(const Duration(seconds: 5));

      expect(approver.authorizationStateOf(_call()), const AIToolAuthorizationState(declineFailed: true));
      expect(errors.single.exception, isA<TimeoutException>());
    });

    testWidgets('the sent timeout does not bound the sign-in', (tester) async {
      final fake = _Fake();
      final approver = fake.approver(sentTimeout: const Duration(seconds: 5));
      addTearDown(approver.dispose);

      approver.connect(_call());
      await tester.pump(const Duration(minutes: 5));

      expect(approver.authorizationStateOf(_call()), const AIToolAuthorizationState(isConnecting: true));
      fake.connects.single.complete(true);
    });

    testWidgets('drops a sign-in for a call that does not wait for this person', (tester) async {
      final printed = _capturePrints();
      final fake = _Fake();
      final approver = fake.approver();
      addTearDown(approver.dispose);
      final withoutAuthorizer = fake.approver(withAuthorizer: false);
      addTearDown(withoutAuthorizer.dispose);

      approver
        ..connect(_call(targetUserId: 'bob'))
        ..declineAuthorization(_call(status: AIToolCallStatus.running));
      withoutAuthorizer.connect(_call());

      expect(fake.opened, isEmpty);
      expect(fake.declined, isEmpty);
      expect(printed, hasLength(3));
      expect(printed, everyElement(contains('to sign in')));
    });

    testWidgets('disposed, it drops sign-ins and ignores completions', (tester) async {
      final printed = _capturePrints();
      final fake = _Fake();
      final approver = fake.approver()
        ..connect(_call())
        ..dispose();

      fake.connects.single.complete(false);
      await tester.pump();
      approver.connect(_call());

      expect(fake.opened, hasLength(1));
      expect(printed.single, contains('disposed'));
    });

    testWidgets('keeps each call its own sign-in', (tester) async {
      final fake = _Fake();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver.connect(_call());

      expect(approver.authorizationStateOf(_call(id: 'call_2')), const AIToolAuthorizationState());
      fake.connects.single.complete(true);
    });
  });

  group('AIToolAuthorizationView', () {
    late _Fake fake;
    late AIToolApprover approver;
    setUp(() {
      fake = _Fake();
      approver = fake.approver();
    });
    tearDown(() => approver.dispose());

    testWidgets('shows the card for the targeted person while the call waits', (tester) async {
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: _call(), approver: approver)));

      expect(_card, findsOneWidget);
      expect(find.text('Connect Linear'), findsOneWidget);
      expect(find.textContaining('never sees your password'), findsOneWidget);
      expect(_enabled(tester, _connect), isTrue);
      expect(_enabled(tester, _notNow), isTrue);
    });

    for (final (description, call, withAuthorizer) in [
      ('without an authorizer', _call(), false),
      ('to another person', _call(targetUserId: 'bob'), true),
      ('once the call moved on', _call(status: AIToolCallStatus.running), true),
      (
        'for a kind it does not open',
        _call(authorization: _signIn.copyWith(kind: const AIToolAuthorizationKind('x'))),
        true,
      ),
    ]) {
      testWidgets('shows nothing $description', (tester) async {
        final approver = fake.approver(withAuthorizer: withAuthorizer);
        addTearDown(approver.dispose);
        await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: call, approver: approver)));

        expect(_card, findsNothing);
        expect(tester.getSize(find.byType(AIToolAuthorizationView)).height, 0);
      });
    }

    testWidgets('connect says connecting and waits, while not now stays enabled', (tester) async {
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: _call(), approver: approver)));

      await tester.tap(find.text(_connect));
      await tester.pump();

      expect(fake.opened.single.$2, _signIn.launchUrl);
      expect(find.text(_connecting), findsOneWidget);
      expect(_enabled(tester, _connecting), isFalse);
      expect(_enabled(tester, _notNow), isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      fake.connects.single.complete(false);
      await tester.pump();
      expect(find.text(_connect), findsOneWidget);
      expect(_enabled(tester, _connect), isTrue);
    });

    testWidgets('not now disables both buttons while it is on its way', (tester) async {
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: _call(), approver: approver)));

      await tester.tap(find.text(_notNow));
      await tester.pump();

      expect(fake.declined, ['call_1']);
      expect(_enabled(tester, _connect), isFalse);
      expect(_enabled(tester, _notNow), isFalse);
    });

    testWidgets('says when the page could not be opened, as a live region', (tester) async {
      _captureErrors();
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: _call(), approver: approver)));

      await tester.tap(find.text(_connect));
      fake.connects.single.completeError(StateError('no browser'));
      await tester.pump();

      expect(find.text(_notOpened), findsOneWidget);
      expect(tester.getSemantics(find.text(_notOpened)).flagsCollection.isLiveRegion, isTrue);
      expect(_enabled(tester, _connect), isTrue);
    });

    testWidgets('says when the not now could not be sent', (tester) async {
      _captureErrors();
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: _call(), approver: approver)));

      await tester.tap(find.text(_notNow));
      fake.declines.single.completeError(Exception('offline'));
      await tester.pump();

      expect(find.text(_notSent), findsOneWidget);
      expect(_enabled(tester, _notNow), isTrue);
    });

    testWidgets('goes away once the call moves on', (tester) async {
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: _call(), approver: approver)));
      await tester.tap(find.text(_connect));
      fake.connects.single.complete(true);
      await tester.pump();

      await tester.pumpWidget(
        _wrap(
          AIToolAuthorizationView(
            call: _call(status: AIToolCallStatus.running),
            approver: approver,
          ),
        ),
      );

      expect(_card, findsNothing);
    });

    testWidgets('keeps a sign-in in progress when rebuilt from scratch', (tester) async {
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: _call(), approver: approver)));
      await tester.tap(find.text(_connect));
      await tester.pumpWidget(_wrap(const SizedBox()));

      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: _call(), approver: approver)));

      expect(find.text(_connecting), findsOneWidget);
      fake.connects.single.complete(true);
    });

    testWidgets('reduced motion shows a still icon in place of the spinner', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: _call(), approver: approver)));

      await tester.tap(find.text(_connect));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      fake.connects.single.complete(true);
    });

    testWidgets('a callback a builder kept never acts on another call', (tester) async {
      final printed = _capturePrints();
      AIToolAuthorizationAction? kept;
      Widget view(AIToolCallPart call) => _wrap(
        AIToolAuthorizationView(
          call: call,
          approver: approver,
          builder: (context, authorization, state, connect, decline) {
            kept ??= connect;
            return Text(authorization.title);
          },
        ),
      );
      await tester.pumpWidget(view(_call()));
      await tester.pumpWidget(view(_call(id: 'call_2')));

      kept!();

      expect(fake.opened, isEmpty);
      expect(printed.single, contains('shows another call now'));
    });

    testWidgets('a builder replaces the card and gets the sign-in, the state and both callbacks', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIToolAuthorizationView(
            call: _call(),
            approver: approver,
            builder: (context, authorization, state, connect, decline) => Column(
              children: [
                Text('${authorization.providerName} busy: ${state.isBusy}'),
                TextButton(onPressed: connect, child: const Text('Mine')),
                TextButton(onPressed: decline, child: const Text('Nope')),
              ],
            ),
          ),
        ),
      );
      expect(_card, findsNothing);
      expect(find.text('Linear busy: false'), findsOneWidget);

      await tester.tap(find.text('Mine'));
      await tester.pump();
      expect(find.text('Linear busy: true'), findsOneWidget);
      expect(fake.opened, hasLength(1));

      await tester.tap(find.text('Nope'));
      expect(fake.declined, ['call_1']);
    });

    testWidgets('the factory slot replaces the card', (tester) async {
      AIToolAuthorizationProps? seen;
      await tester.pumpWidget(
        _wrap(
          AIComponentFactory(
            builders: AIComponentBuilders(
              toolAuthorization: (context, props) {
                seen = props;
                return TextButton(
                  onPressed: props.onConnect,
                  child: Text('Sign in to ${props.authorization.provider}'),
                );
              },
            ),
            child: AIToolAuthorizationView(call: _call(), approver: approver),
          ),
        ),
      );

      expect(_card, findsNothing);
      expect(seen!.call.id, 'call_1');
      expect(seen!.state, const AIToolAuthorizationState());
      await tester.tap(find.text('Sign in to linear'));
      expect(fake.opened, hasLength(1));
    });

    testWidgets('reads the translations in scope', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AITranslationsScope(
            translations: const _DutchTranslations(),
            child: AIToolAuthorizationView(call: _call(), approver: approver),
          ),
        ),
      );

      expect(find.text('Verbinden'), findsOneWidget);
      expect(find.text('Niet nu'), findsOneWidget);
    });
  });

  group('AIToolAuthorizationCard', () {
    testWidgets('leaves a blank message out', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIToolAuthorizationCard(
            authorization: _signIn.copyWith(message: '  '),
            onConnect: () {},
            onDecline: () {},
          ),
        ),
      );

      expect(find.byType(Text), findsNWidgets(3)); // the title and two labels
    });

    testWidgets('is styled by the approval theme', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIToolAuthorizationCard(
            authorization: _signIn,
            onConnect: () {},
            onDecline: () {},
            theme: const ToolApprovalThemeData(backgroundColor: Color(0xFF123456)),
          ),
        ),
      );

      final box = tester.widget<DecoratedBox>(find.descendant(of: _card, matching: find.byType(DecoratedBox)).first);
      expect((box.decoration as BoxDecoration).color, const Color(0xFF123456));
    });

    group('goldens', () {
      Widget card(ThemeData theme, AIToolAuthorizationState state) => Theme(
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
                  child: AIToolAuthorizationCard(
                    authorization: _signIn,
                    state: state,
                    onConnect: () {},
                    onDecline: () {},
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
          fileName: 'ai_tool_authorization_card_$name',
          builder: () => GoldenTestGroup(
            columns: 1,
            children: [
              GoldenTestScenario(name: 'idle', child: card(theme, const AIToolAuthorizationState())),
              GoldenTestScenario(
                name: 'connecting',
                child: card(theme, const AIToolAuthorizationState(isConnecting: true)),
              ),
              GoldenTestScenario(
                name: 'declining',
                child: card(theme, const AIToolAuthorizationState(isDeclining: true)),
              ),
              GoldenTestScenario(
                name: 'not opened',
                child: card(theme, const AIToolAuthorizationState(connectFailed: true)),
              ),
              GoldenTestScenario(
                name: 'not sent',
                child: card(theme, const AIToolAuthorizationState(declineFailed: true)),
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
  String get toolAuthorizationConnect => 'Verbinden';

  @override
  String get toolAuthorizationDecline => 'Niet nu';
}
