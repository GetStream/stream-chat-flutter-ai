import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'tool_sign_in_fakes.dart';

const _connect = 'Connect';
const _connecting = 'Connecting…';
const _notNow = 'Not now';
const _notOpened = "The sign-in couldn't be opened. Try again.";
const _notSent = "Your answer couldn't be sent. Try again.";

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 360, child: child),
    ),
  ),
);

final _card = find.byType(AIToolAuthorizationCard);

bool _enabled(WidgetTester tester, String label) => tester
    .widget<ButtonStyleButton>(find.ancestor(of: find.text(label), matching: find.bySubtype<ButtonStyleButton>()))
    .enabled;

void main() {
  group('AIToolAuthorizationView', () {
    late FakeSignIn fake;
    late AIToolApprover approver;
    setUp(() {
      fake = FakeSignIn();
      approver = fake.approver();
    });
    tearDown(() => approver.dispose());

    testWidgets('shows the card for the targeted person while the call waits', (tester) async {
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: signInCall(), approver: approver)));

      expect(_card, findsOneWidget);
      expect(find.text('Connect Linear'), findsOneWidget);
      expect(find.textContaining('never sees your password'), findsOneWidget);
      expect(_enabled(tester, _connect), isTrue);
      expect(_enabled(tester, _notNow), isTrue);
    });

    for (final (description, call, withAuthorizer) in [
      ('without an authorizer', signInCall(), false),
      ('to another person', signInCall(targetUserId: 'bob'), true),
      ('once the call moved on', signInCall(status: AIToolCallStatus.running), true),
      (
        'for a kind it does not open',
        signInCall(authorization: signIn.copyWith(kind: const AIToolAuthorizationKind('x'))),
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
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: signInCall(), approver: approver)));

      await tester.tap(find.text(_connect));
      await tester.pump();

      expect(fake.opened.single.$2, signIn.launchUrl);
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
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: signInCall(), approver: approver)));

      await tester.tap(find.text(_notNow));
      await tester.pump();

      expect(fake.declined, ['call_1']);
      expect(_enabled(tester, _connect), isFalse);
      expect(_enabled(tester, _notNow), isFalse);
    });

    testWidgets('says when the page could not be opened, as a live region', (tester) async {
      captureErrors();
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: signInCall(), approver: approver)));

      await tester.tap(find.text(_connect));
      fake.connects.single.completeError(StateError('no browser'));
      await tester.pump();

      expect(find.text(_notOpened), findsOneWidget);
      expect(tester.getSemantics(find.text(_notOpened)).flagsCollection.isLiveRegion, isTrue);
      expect(_enabled(tester, _connect), isTrue);
    });

    testWidgets('says when the not now could not be sent', (tester) async {
      captureErrors();
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: signInCall(), approver: approver)));

      await tester.tap(find.text(_notNow));
      fake.declines.single.completeError(Exception('offline'));
      await tester.pump();

      expect(find.text(_notSent), findsOneWidget);
      expect(_enabled(tester, _notNow), isTrue);
    });

    testWidgets('goes away once the call moves on', (tester) async {
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: signInCall(), approver: approver)));
      await tester.tap(find.text(_connect));
      fake.connects.single.complete(true);
      await tester.pump();

      await tester.pumpWidget(
        _wrap(
          AIToolAuthorizationView(
            call: signInCall(status: AIToolCallStatus.running),
            approver: approver,
          ),
        ),
      );

      expect(_card, findsNothing);
      // Let a connected sign-in settle, so no timer is left.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('keeps a sign-in in progress when rebuilt from scratch', (tester) async {
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: signInCall(), approver: approver)));
      await tester.tap(find.text(_connect));
      await tester.pumpWidget(_wrap(const SizedBox()));

      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: signInCall(), approver: approver)));

      expect(find.text(_connecting), findsOneWidget);
      fake.connects.single.complete(true);
      // Let a connected sign-in settle, so no timer is left.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('while declining, screen readers hear that the answer is on its way', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: signInCall(), approver: approver)));

      await tester.tap(find.text(_notNow));
      await tester.pump();
      expect(find.bySemanticsLabel('Sending your answer…'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('while connecting, the spinner adds nothing for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: signInCall(), approver: approver)));

      await tester.tap(find.text(_connect));
      await tester.pump();
      expect(find.bySemanticsLabel('Sending your answer…'), findsNothing);
      expect(find.text(_connecting), findsOneWidget);
      handle.dispose();
      fake.connects.single.complete(true);
      // Let a connected sign-in settle, so no timer is left.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('a callback a builder kept acts on the approver the view has now', (tester) async {
      final other = fake.approver();
      addTearDown(other.dispose);
      VoidCallback? kept;
      Widget view(AIToolApprover approver) => _wrap(
        AIToolAuthorizationView(
          call: signInCall(),
          approver: approver,
          builder: (context, authorization, state, connect, decline) {
            kept ??= connect;
            return Text('busy: ${state.isBusy}');
          },
        ),
      );
      await tester.pumpWidget(view(approver));
      await tester.pumpWidget(view(other));

      kept!();
      await tester.pump();

      expect(other.authorizationStateOf(signInCall()).isConnecting, isTrue);
      expect(approver.authorizationStateOf(signInCall()).isConnecting, isFalse);
      fake.connects.single.complete(true);
      // Let a connected sign-in settle, so no timer is left.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('says when the sign-in expired, and stops offering Connect', (tester) async {
      final expired = signInCall(
        authorization: signIn.copyWith(expiresAt: clock.now().subtract(const Duration(seconds: 1))),
      );
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: expired, approver: approver)));

      expect(find.text('This sign-in expired.'), findsOneWidget);
      expect(_enabled(tester, _connect), isFalse);
      expect(_enabled(tester, _notNow), isTrue);
    });

    testWidgets('stops offering Connect when the sign-in expires while shown', (tester) async {
      final soon = signInCall(
        authorization: signIn.copyWith(expiresAt: clock.now().add(const Duration(seconds: 5))),
      );
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: soon, approver: approver)));
      expect(_enabled(tester, _connect), isTrue);

      await tester.pump(const Duration(seconds: 6));
      expect(find.text('This sign-in expired.'), findsOneWidget);
      expect(_enabled(tester, _connect), isFalse);
    });

    testWidgets('reduced motion shows a still icon in place of the spinner', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(_wrap(AIToolAuthorizationView(call: signInCall(), approver: approver)));

      await tester.tap(find.text(_connect));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      fake.connects.single.complete(true);
      // Let a connected sign-in settle, so no timer is left.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('a callback a builder kept never acts on another call', (tester) async {
      final printed = capturePrints();
      VoidCallback? kept;
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
      await tester.pumpWidget(view(signInCall()));
      await tester.pumpWidget(view(signInCall(id: 'call_2')));

      kept!();

      expect(fake.opened, isEmpty);
      expect(printed.single, contains('shows another call now'));
    });

    testWidgets('a builder replaces the card and gets the sign-in, the state and both callbacks', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIToolAuthorizationView(
            call: signInCall(),
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
            child: AIToolAuthorizationView(call: signInCall(), approver: approver),
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
            child: AIToolAuthorizationView(call: signInCall(), approver: approver),
          ),
        ),
      );

      expect(find.text('Verbinden'), findsOneWidget);
      expect(find.text('Niet nu'), findsOneWidget);
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
