import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/parts/dropped_answer_report.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// The sign-in the sign-in tests ask for.
final signIn = AIToolAuthorization(
  provider: 'linear',
  providerName: 'Linear',
  title: 'Connect Linear',
  message: 'You sign in at Linear, and the agent never sees your password.',
  url: Uri.parse('https://agent.example/launch/abc'),
  handoffToken: 'a+b',
);

/// A call waiting for alice to sign in with [signIn], unless told otherwise.
AIToolCallPart signInCall({
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
  authorization: noAuthorization ? null : authorization ?? signIn,
);

/// A backend and a browser that record every sign-in and "not now", and let
/// the test finish each one.
class FakeSignIn {
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

/// Captures the dropped-answer reports for the rest of the test.
List<String> capturePrints() {
  final printed = <String>[];
  debugDroppedAnswerReporter = printed.add;
  addTearDown(() => debugDroppedAnswerReporter = null);
  return printed;
}

/// Collects what this package reports through [FlutterError.reportError] for
/// the rest of the test.
///
/// Anything else, such as the test framework's own report of a failed
/// expectation, still goes to the previous handler: swallowed, it would turn
/// a failing test into a hang.
List<FlutterErrorDetails> captureErrors() {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) =>
      details.library == 'stream_chat_flutter_ai' ? errors.add(details) : previous?.call(details);
  addTearDown(() => FlutterError.onError = previous);
  return errors;
}
