import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'tool_sign_in_fakes.dart';

void main() {
  group('AIToolAuthorizationState', () {
    test('is busy while connecting or declining', () {
      expect(const AIToolAuthorizationState().isBusy, isFalse);
      expect(const AIToolAuthorizationState(isConnecting: true).isBusy, isTrue);
      expect(const AIToolAuthorizationState(isDeclining: true).isBusy, isTrue);
      expect(const AIToolAuthorizationState(connectFailed: true).isBusy, isFalse);
      expect(const AIToolAuthorizationState(declineFailed: true).isBusy, isFalse);
    });

    test('offers Connect unless busy or expired', () {
      expect(const AIToolAuthorizationState().canConnect, isTrue);
      expect(const AIToolAuthorizationState(connectFailed: true).canConnect, isTrue);
      expect(const AIToolAuthorizationState(isConnecting: true).canConnect, isFalse);
      expect(const AIToolAuthorizationState(isDeclining: true).canConnect, isFalse);
      expect(const AIToolAuthorizationState(isExpired: true).canConnect, isFalse);
    });

    test('has value equality', () {
      expect(const AIToolAuthorizationState(isConnecting: true), const AIToolAuthorizationState(isConnecting: true));
      expect(const AIToolAuthorizationState(), isNot(const AIToolAuthorizationState(connectFailed: true)));
    });
  });

  group('AIToolApprover sign-in', () {
    test('asks only with an authorizer, for the targeted person, while the call waits, for oauth', () {
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);
      final withoutAuthorizer = fake.approver(withAuthorizer: false);
      addTearDown(withoutAuthorizer.dispose);

      expect(approver.signInFor(signInCall()), signIn);
      expect(withoutAuthorizer.signInFor(signInCall()), isNull);
      expect(approver.signInFor(signInCall(targetUserId: 'bob')), isNull);
      expect(approver.signInFor(signInCall(status: AIToolCallStatus.running)), isNull);
      expect(approver.signInFor(signInCall(noAuthorization: true)), isNull);
      expect(
        approver.signInFor(signInCall(authorization: signIn.copyWith(kind: const AIToolAuthorizationKind('device')))),
        isNull,
      );
      expect(
        approver.signInFor(signInCall(authorization: signIn.copyWith(status: AIToolAuthorizationStatus.declined))),
        isNull,
      );
    });

    testWidgets('connect opens the launch url and stays connecting once connected', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);
      var notified = 0;
      approver
        ..addListener(() => notified++)
        ..connect(signInCall());
      expect(fake.opened, [('call_1', signIn.launchUrl)]);
      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(isConnecting: true));
      expect(notified, 1);

      fake.connects.single.complete(true);
      await tester.pump();
      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(isConnecting: true));

      // The step moves on, and the sign-in is forgotten.
      expect(
        approver.authorizationStateOf(signInCall(status: AIToolCallStatus.running)),
        const AIToolAuthorizationState(),
      );
      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState());
      // Let a connected sign-in settle, so no timer is left.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('coming back without connecting lets the person connect again', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver
        ..connect(signInCall())
        ..connect(signInCall()); // ignored while connecting
      expect(fake.opened, hasLength(1));

      fake.connects.single.complete(false);
      await tester.pump();
      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState());

      approver.connect(signInCall());
      expect(fake.opened, hasLength(2));
    });

    testWidgets('a page that could not be opened is reported and can be tried again', (tester) async {
      final errors = captureErrors();
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver.connect(signInCall());
      fake.connects.single.completeError(StateError('no browser'));
      await tester.pump();

      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(connectFailed: true));
      expect(errors.single.exception, isA<StateError>());
      expect(errors.single.context.toString(), contains('opening the sign-in of tool call "call_1"'));

      approver.connect(signInCall());
      expect(fake.opened, hasLength(2));
    });

    testWidgets('a connect that throws synchronously counts as not opened', (tester) async {
      captureErrors();
      final approver = AIToolApprover(
        identity: const AIClientIdentity(userId: 'alice'),
        decide: (_, _) async {},
        authorizer: AIToolAuthorizer(connect: (_, _) => throw StateError('no browser'), decline: (_) async {}),
      );
      addTearDown(approver.dispose);

      approver.connect(signInCall());
      await tester.pump();

      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(connectFailed: true));
    });

    testWidgets('not now is sent once and stays declining until the step changes', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver
        ..declineAuthorization(signInCall())
        ..declineAuthorization(signInCall());
      expect(fake.declined, ['call_1']);
      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(isDeclining: true));

      fake.declines.single.complete();
      await tester.pump();
      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(isDeclining: true));

      // Connect waits while declining.
      approver.connect(signInCall());
      expect(fake.opened, isEmpty);
    });

    testWidgets('a not now that could not be sent is reported and can be sent again', (tester) async {
      final errors = captureErrors();
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver.declineAuthorization(signInCall());
      fake.declines.single.completeError(Exception('offline'));
      await tester.pump();

      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(declineFailed: true));
      expect(errors.single.context.toString(), contains('"not now" for tool call "call_1"'));

      approver.declineAuthorization(signInCall());
      expect(fake.declined, hasLength(2));
    });

    testWidgets('not now may be sent while the sign-in is open, and stays when it comes back', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver
        ..connect(signInCall())
        ..declineAuthorization(signInCall());
      expect(fake.declined, ['call_1']);

      fake.connects.single.complete(false);
      await tester.pump();
      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(isDeclining: true));
    });

    testWidgets('a failed not now while the page is open keeps it connecting, so it opens once', (tester) async {
      captureErrors();
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver
        ..connect(signInCall())
        ..declineAuthorization(signInCall());
      fake.declines.single.completeError(Exception('offline'));
      await tester.pump();

      expect(
        approver.authorizationStateOf(signInCall()),
        const AIToolAuthorizationState(isConnecting: true, declineFailed: true),
      );
      approver.connect(signInCall());
      expect(fake.opened, hasLength(1), reason: 'the first page is still open');

      // Back without connecting: the failed not now still says so, and Connect works again.
      fake.connects.single.complete(false);
      await tester.pump();
      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(declineFailed: true));
      approver.connect(signInCall());
      expect(fake.opened, hasLength(2));
      fake.connects.last.complete(true);
      // Let a connected sign-in settle, so no timer is left.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('after a failed not now, the page coming back connected reads connecting', (tester) async {
      captureErrors();
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver
        ..connect(signInCall())
        ..declineAuthorization(signInCall());
      fake.declines.single.completeError(Exception('offline'));
      await tester.pump();
      fake.connects.single.complete(true);
      await tester.pump();

      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(isConnecting: true));
      // Let a connected sign-in settle, so no timer is left.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('after a failed not now, a page that could not open keeps both failures', (tester) async {
      captureErrors();
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver
        ..connect(signInCall())
        ..declineAuthorization(signInCall());
      fake.declines.single.completeError(Exception('offline'));
      await tester.pump();
      fake.connects.single.completeError(StateError('no browser'));
      await tester.pump();

      expect(
        approver.authorizationStateOf(signInCall()),
        const AIToolAuthorizationState(connectFailed: true, declineFailed: true),
      );
    });

    testWidgets('a not now that fails after the page came back connected keeps it connecting', (tester) async {
      captureErrors();
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver
        ..connect(signInCall())
        ..declineAuthorization(signInCall());
      fake.connects.single.complete(true);
      await tester.pump();
      fake.declines.single.completeError(Exception('offline'));
      await tester.pump();

      expect(
        approver.authorizationStateOf(signInCall()),
        const AIToolAuthorizationState(isConnecting: true, declineFailed: true),
      );
      approver.connect(signInCall());
      expect(fake.opened, hasLength(1), reason: 'the account is connected');

      // The step never changes: Connect is offered again once it has settled.
      await tester.pump(const Duration(seconds: 30));
      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(declineFailed: true));
    });

    testWidgets('a not now sent after connecting that fails keeps it connecting until it settles', (tester) async {
      captureErrors();
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver.connect(signInCall());
      fake.connects.single.complete(true);
      await tester.pump(const Duration(seconds: 10));
      approver.declineAuthorization(signInCall());
      fake.declines.single.completeError(Exception('offline'));
      await tester.pump();

      expect(
        approver.authorizationStateOf(signInCall()),
        const AIToolAuthorizationState(isConnecting: true, declineFailed: true),
      );

      // Settles on the connect's schedule, not a fresh one.
      await tester.pump(const Duration(seconds: 20));
      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(declineFailed: true));
    });

    testWidgets('a page that throws after a not now leaves the not now', (tester) async {
      captureErrors();
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver
        ..connect(signInCall())
        ..declineAuthorization(signInCall());
      fake.connects.single.completeError(StateError('closed'));
      await tester.pump();

      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(isDeclining: true));
    });

    testWidgets('a page coming back for a sign-in since forgotten changes nothing', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);
      var notified = 0;

      approver
        ..connect(signInCall())
        ..authorizationStateOf(signInCall(status: AIToolCallStatus.running))
        ..addListener(() => notified++);
      fake.connects.single.complete(false);
      await tester.pump();

      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState());
      expect(notified, 0);
    });

    testWidgets('a connected sign-in whose step never changes offers Connect again after 30 seconds', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver.connect(signInCall());
      fake.connects.single.complete(true);
      await tester.pump(const Duration(seconds: 29));
      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(isConnecting: true));

      await tester.pump(const Duration(seconds: 1));
      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState());
      approver.connect(signInCall());
      expect(fake.opened, hasLength(2));
      fake.connects.last.complete(false);
      // Let a connected sign-in settle, so no timer is left.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('a not now sent after connecting stays declining once the sign-in would settle', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver.connect(signInCall());
      fake.connects.single.complete(true);
      await tester.pump();
      approver.declineAuthorization(signInCall());
      fake.declines.single.complete();
      await tester.pump(const Duration(minutes: 1));

      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(isDeclining: true));
    });

    testWidgets('a sign-in issued again on the same step starts over', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver.connect(signInCall());
      fake.connects.single.complete(true);
      await tester.pump();
      final again = signInCall(authorization: signIn.copyWith(handoffToken: 'fresh'));

      expect(approver.authorizationStateOf(again), const AIToolAuthorizationState());
      approver.connect(again);
      expect(fake.opened.last.$2, again.authorization!.launchUrl);
      fake.connects.last.complete(false);
      await tester.pump(const Duration(minutes: 1));
      // Let a connected sign-in settle, so no timer is left.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('a sign-in issued again with a new page starts over', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver.connect(signInCall());
      final again = signInCall(authorization: signIn.copyWith(url: Uri.parse('https://agent.example/launch/xyz')));

      expect(approver.authorizationStateOf(again), const AIToolAuthorizationState());
      fake.connects.single.complete(false);
      await tester.pump();
    });

    testWidgets('a new expiry on the same sign-in keeps where it is', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver.connect(signInCall());
      final later = signInCall(authorization: signIn.copyWith(expiresAt: clock.now().add(const Duration(hours: 1))));

      expect(approver.authorizationStateOf(later), const AIToolAuthorizationState(isConnecting: true));
      fake.connects.single.complete(false);
      await tester.pump();
    });

    testWidgets('a page or a not now finishing after the sign-in was issued again changes nothing', (tester) async {
      captureErrors();
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);
      final again = signInCall(authorization: signIn.copyWith(handoffToken: 'fresh'));

      approver
        ..connect(signInCall())
        ..declineAuthorization(signInCall())
        ..authorizationStateOf(again);
      var notified = 0;
      approver.addListener(() => notified++);
      fake.connects.single.complete(true);
      fake.declines.single.completeError(Exception('offline'));
      await tester.pump();

      expect(approver.authorizationStateOf(again), const AIToolAuthorizationState());
      expect(notified, 0);
    });

    testWidgets('an expired sign-in reads expired, and offers only not now', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);
      final expired = signInCall(
        authorization: signIn.copyWith(expiresAt: clock.now().subtract(const Duration(minutes: 1))),
      );

      expect(approver.authorizationStateOf(expired), const AIToolAuthorizationState(isExpired: true));
      expect(approver.authorizationStateOf(expired).canConnect, isFalse);
      approver.connect(expired);
      expect(fake.opened, isEmpty);

      approver.declineAuthorization(expired);
      expect(fake.declined, ['call_1']);
      expect(
        approver.authorizationStateOf(expired),
        const AIToolAuthorizationState(isDeclining: true, isExpired: true),
      );
    });

    testWidgets('a sign-in reads expired once its time passes, even with its page open', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);
      final soon = signInCall(authorization: signIn.copyWith(expiresAt: clock.now().add(const Duration(minutes: 1))));

      approver.connect(soon);
      await tester.pump(const Duration(seconds: 59));
      expect(approver.authorizationStateOf(soon), const AIToolAuthorizationState(isConnecting: true));

      await tester.pump(const Duration(seconds: 1));
      expect(approver.authorizationStateOf(soon), const AIToolAuthorizationState(isExpired: true));
      fake.connects.single.complete(false);
      await tester.pump();
    });

    testWidgets('the sent timeout bounds the not now', (tester) async {
      final errors = captureErrors();
      final fake = FakeSignIn();
      final approver = fake.approver(sentTimeout: const Duration(seconds: 5));
      addTearDown(approver.dispose);

      approver.declineAuthorization(signInCall());
      await tester.pump(const Duration(seconds: 5));

      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(declineFailed: true));
      expect(errors.single.exception, isA<TimeoutException>());
    });

    testWidgets('the sent timeout does not bound the sign-in', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver(sentTimeout: const Duration(seconds: 5));
      addTearDown(approver.dispose);

      approver.connect(signInCall());
      await tester.pump(const Duration(minutes: 5));

      expect(approver.authorizationStateOf(signInCall()), const AIToolAuthorizationState(isConnecting: true));
      fake.connects.single.complete(true);
      // Let a connected sign-in settle, so no timer is left.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('drops a sign-in for a call that does not wait for this person', (tester) async {
      final printed = capturePrints();
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);
      final withoutAuthorizer = fake.approver(withAuthorizer: false);
      addTearDown(withoutAuthorizer.dispose);

      approver
        ..connect(signInCall(targetUserId: 'bob'))
        ..declineAuthorization(signInCall(status: AIToolCallStatus.running));
      withoutAuthorizer.connect(signInCall());

      expect(fake.opened, isEmpty);
      expect(fake.declined, isEmpty);
      expect(printed, hasLength(3));
      expect(printed, everyElement(contains('to sign in')));
    });

    testWidgets('disposed, it drops sign-ins and ignores completions', (tester) async {
      final printed = capturePrints();
      final fake = FakeSignIn();
      final approver = fake.approver()
        ..connect(signInCall())
        ..dispose();

      fake.connects.single.complete(false);
      await tester.pump();
      approver.connect(signInCall());

      expect(fake.opened, hasLength(1));
      expect(printed.single, contains('disposed'));
    });

    testWidgets('disposed while a connected sign-in settles, it leaves no timer', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver()..connect(signInCall());
      fake.connects.single.complete(true);
      await tester.pump();

      // The test fails on a timer still pending when it ends.
      approver.dispose();
    });

    testWidgets('keeps each call its own sign-in', (tester) async {
      final fake = FakeSignIn();
      final approver = fake.approver();
      addTearDown(approver.dispose);

      approver.connect(signInCall());

      expect(approver.authorizationStateOf(signInCall(id: 'call_2')), const AIToolAuthorizationState());
      fake.connects.single.complete(true);
      // Let a connected sign-in settle, so no timer is left.
      await tester.pump(const Duration(seconds: 30));
    });
  });
}
