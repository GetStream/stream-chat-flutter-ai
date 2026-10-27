import 'dart:async';

import 'package:flutter/widgets.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/components/ai_component_factory.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval_view.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_authorization.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_authorization_view.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/dropped_answer_report.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_client_identity.dart';

/// Sends a person's answer to a tool call's question to the agent's backend.
///
/// Complete once the backend has the answer; throw (or complete with an error)
/// when it couldn't be sent, so the person can answer again.
typedef AIToolApprovalDecider = Future<void> Function(AIToolCallPart call, AIToolApprovalDecision decision);

/// Answers the question an [AIToolApprovalView] is showing, from its content:
/// [AIToolApprovalDecision.allowed] or [AIToolApprovalDecision.declined].
typedef AIToolApprovalAnswer = void Function(AIToolApprovalDecision decision);

/// Builds your own content for an [AIToolApprovalView] in place of
/// [AIComponentBuilders.toolApproval].
///
/// [approval] is the call's question, or `null` when the call awaits approval
/// without one — ask in your own words then. [state] says where the answer
/// is; [answer] sends one, and does nothing while an answer is on its way or
/// has been sent.
typedef AIToolApprovalContentBuilder =
    Widget Function(
      BuildContext context,
      AIToolApproval? approval,
      AIToolApprovalState state,
      AIToolApprovalAnswer answer,
    );

/// Opens a tool call's sign-in page, [url], and completes once the person is
/// back: `true` when the page came back saying the account is connected (its
/// return URL has `status=connected` in its query), `false` when they came
/// back without connecting, or when your app can't tell.
///
/// Throw (or complete with an error) when the page couldn't be opened, so the
/// person can try again.
typedef AIToolSignInConnector = Future<bool> Function(AIToolCallPart call, Uri url);

/// Tells the agent's backend the person won't sign in for a tool call now.
///
/// Complete once the backend has it; throw (or complete with an error) when
/// it couldn't be sent, so the person can answer again.
typedef AIToolSignInDecliner = Future<void> Function(AIToolCallPart call);

/// Opens or turns down the sign-in an [AIToolAuthorizationView] is showing,
/// from its content.
typedef AIToolAuthorizationAction = void Function();

/// Builds your own content for an [AIToolAuthorizationView] in place of
/// [AIComponentBuilders.toolAuthorization].
///
/// [authorization] is the call's sign-in. [state] says where the person's
/// answer is; [connect] opens the sign-in and [decline] sends their "not now",
/// each doing nothing while it can't be pressed.
typedef AIToolAuthorizationContentBuilder =
    Widget Function(
      BuildContext context,
      AIToolAuthorization authorization,
      AIToolAuthorizationState state,
      AIToolAuthorizationAction connect,
      AIToolAuthorizationAction decline,
    );

/// How the person signs in on this device when a tool call waits for their
/// account at a provider, and how their "not now" reaches the agent's backend,
/// which holds the call until one or the other.
///
/// This package doesn't open the sign-in page itself, so it needs no browser
/// plugin: Connect hands the call's [AIToolAuthorization.launchUrl] to
/// [connect], and your app opens it, such as with `flutter_web_auth_2`. The
/// page goes back to the return URL your backend gave the session, with
/// `status=connected` in its query once the account is connected. By then the
/// backend has the grant and has moved the call on, so the app sends nothing
/// back; the call's step changing is what hides the sign-in.
///
/// ```dart
/// final authorizer = AIToolAuthorizer(
///   connect: (call, url) async {
///     try {
///       final back = await FlutterWebAuth2.authenticate(url: '$url', callbackUrlScheme: 'com.example.app');
///       return Uri.parse(back).queryParameters['status'] == 'connected';
///     } on PlatformException catch (e) {
///       if (e.code == 'CANCELED') return false; // closed without connecting
///       rethrow; // "couldn't be opened"
///     }
///   },
///   decline: (call) => backend.declineSignIn(call.id),
/// );
/// ```
///
/// Give it to an [AIToolApprover] to offer sign-ins.
@immutable
class AIToolAuthorizer {
  /// Creates an [AIToolAuthorizer].
  const AIToolAuthorizer({required this.connect, required this.decline});

  /// Opens the sign-in page and says whether the person connected. Until it
  /// completes, and after it completes with `true`, the sign-in reads
  /// connecting; `false` lets them connect again, and an error says the page
  /// couldn't be opened. It must not hang: a person who never comes back can
  /// still answer "not now", but can't connect again until it completes.
  final AIToolSignInConnector connect;

  /// Sends the person's "not now". Until the call's step changes the sign-in
  /// reads declining; an error lets them answer again.
  final AIToolSignInDecliner decline;
}

/// The person answering tool calls' questions on this device, how their
/// answers reach the agent's backend, and where each answer is.
///
/// **Create it once and keep it** — in a `State`, a provider or a service, not
/// in `build` — and [dispose] it when done. It remembers each call's
/// [AIToolApprovalState], so a question scrolled out of a lazy list and back
/// still shows its answer as sent, and a failure arriving meanwhile isn't lost.
///
/// ```dart
/// late final approver = AIToolApprover(
///   identity: AIClientIdentity(userId: currentUser.id, clientId: installId),
///   decide: (call, decision) => backend.answerToolCall(call.id, decision.value),
/// );
///
/// AIMessagePartsView(parts: parts, approver: approver)
/// ```
///
/// The backend should accept an answer only from the call's targeted person
/// (and install, when the call names one), only while the call waits, and only
/// once. It then updates the call's step: allowed, the call goes on; declined,
/// it is cancelled. Until that update arrives the answer stays
/// [AIToolApprovalSent], with the buttons disabled — for at most [sentTimeout]
/// when one is set, which bounds sending the answer as well.
///
/// With an [authorizer], it also asks this person to sign in when a call waits
/// for their account at a provider (status `awaiting_authorization`), through
/// an [AIToolAuthorizationView], and keeps where each sign-in is
/// ([authorizationStateOf]). Without one, no sign-in is offered here.
class AIToolApprover extends ChangeNotifier {
  /// Creates an [AIToolApprover] for [identity].
  ///
  /// The [identity] and [authorizer] are fixed: make a new approver when the
  /// signed-in person changes.
  AIToolApprover({required this.identity, required this.decide, this.sentTimeout, this.authorizer})
    : assert(sentTimeout == null || sentTimeout > Duration.zero, 'sentTimeout must be positive');

  /// Who is answering, and on which install.
  final AIClientIdentity identity;

  /// Sends an answer. A thrown error, or a future completing with one, makes
  /// the answer [AIToolApprovalFailed] and lets the person answer again; it is
  /// reported through [FlutterError.reportError] and never rethrown, even after
  /// the approver is disposed. Without a [sentTimeout] it must not hang: the
  /// answer stays [AIToolApprovalSending] until it completes.
  final AIToolApprovalDecider decide;

  /// The longest an answer may take to send, and then stay
  /// [AIToolApprovalSent] while the call's step still waits. Past either, the
  /// answer turns [AIToolApprovalFailed] with a [TimeoutException], so the
  /// person sees something went wrong and can answer again. `null`, the
  /// default, waits for as long as it takes.
  ///
  /// A slow send is reported through [FlutterError.reportError] right away. A
  /// call still waiting past the timeout is reported once [stateOf] next sees
  /// it waiting — the backend may have moved it on while no
  /// [AIToolApprovalView] showed it — and not at all if it no longer does.
  final Duration? sentTimeout;

  /// How this person signs in when a call waits for their account at a
  /// provider. Without one, no sign-in is offered here.
  final AIToolAuthorizer? authorizer;

  final _entries = <String, _Entry>{};
  final _signIns = <String, _SignIn>{};
  bool _disposed = false;

  /// Where the answer to [call] is. A call that no longer waits for this
  /// person is forgotten, and reads [AIToolApprovalIdle].
  AIToolApprovalState stateOf(AIToolCallPart call) {
    if (!identity.canApprove(call)) {
      _entries.remove(call.id)?.timer?.cancel();
      return const AIToolApprovalIdle();
    }
    final entry = _entries[call.id];
    // A sent timeout is only a backend bug if the call still waits, which
    // [call] now confirms. Reported after this read, as it runs from build.
    if (entry?.unreportedTimeout case (final error, final stackTrace)) {
      entry!.unreportedTimeout = null;
      scheduleMicrotask(() => _report(error, stackTrace, call));
    }
    return entry?.state ?? const AIToolApprovalIdle();
  }

  /// Sends [decision] as the answer to [call] through [decide], unless an
  /// answer is already on its way or sent. An answer for a call that doesn't
  /// wait for this person is dropped (and said so in debug builds).
  void answer(AIToolCallPart call, AIToolApprovalDecision decision) {
    if (_disposed) return reportDroppedAnswer(call, 'its AIToolApprover was disposed');
    if (!identity.canApprove(call)) return reportDroppedAnswer(call, 'it no longer waits for ${identity.userId}');
    final current = stateOf(call);
    if (current is AIToolApprovalSending || current is AIToolApprovalSent) return;

    final entry = _entries[call.id] = _Entry(AIToolApprovalSending(decision));
    notifyListeners();
    unawaited(_send(call, decision, entry));
  }

  Future<void> _send(AIToolCallPart call, AIToolApprovalDecision decision, _Entry entry) async {
    try {
      final sending = Future.sync(() => decide(call, decision));
      await (sentTimeout == null
          ? sending
          : sending.timeout(
              sentTimeout!,
              onTimeout: () => throw TimeoutException('the answer to tool call "${call.id}" took too long to send'),
            ));
      if (!_isCurrent(call, entry)) return;
      entry.state = AIToolApprovalSent(decision);
      if (sentTimeout case final timeout?) {
        entry.timer = Timer(timeout, () {
          if (!_isCurrent(call, entry)) return;
          final error = TimeoutException(
            'tool call "${call.id}" still awaits approval after the answer was sent',
            timeout,
          );
          // Not reported yet: the call may have moved on while no view showed
          // it. The next [stateOf] that sees it waiting reports it.
          entry
            ..state = AIToolApprovalFailed(decision, error)
            ..timer = null
            ..unreportedTimeout = (error, StackTrace.current);
          notifyListeners();
        });
      }
      notifyListeners();
    } catch (error, stackTrace) {
      // The state first: an app whose error handler rethrows must not leave
      // the card sending for good.
      if (_isCurrent(call, entry)) {
        entry.state = AIToolApprovalFailed(decision, error);
        notifyListeners();
      }
      _report(error, stackTrace, call);
    }
  }

  /// The sign-in this person is asked for on [call] here: one the call waits
  /// for them to finish ([AIClientIdentity.canAuthorize]), of a kind this
  /// package shows ([AIToolAuthorizationKind.oauth]), and only with an
  /// [authorizer]. `null` otherwise.
  AIToolAuthorization? signInFor(AIToolCallPart call) {
    final authorization = call.authorization;
    if (authorizer == null || authorization == null) return null;
    if (!identity.canAuthorize(call) || authorization.kind != AIToolAuthorizationKind.oauth) return null;
    return authorization;
  }

  /// Where the person's sign-in for [call] is. A call that no longer waits
  /// for it is forgotten, and reads idle.
  AIToolAuthorizationState authorizationStateOf(AIToolCallPart call) {
    if (signInFor(call) == null) {
      _signIns.remove(call.id);
      return const AIToolAuthorizationState();
    }
    return _signIns[call.id]?.state ?? const AIToolAuthorizationState();
  }

  /// Hands [call]'s sign-in page to the [authorizer], unless an answer is
  /// already under way. Until the person comes back it reads connecting; back
  /// connected, it stays so until the call's step changes.
  void connect(AIToolCallPart call) {
    if (_disposed) return reportDroppedAnswer(call, 'its AIToolApprover was disposed');
    final authorizer = this.authorizer;
    final authorization = signInFor(call);
    if (authorizer == null || authorization == null) {
      return reportDroppedAnswer(call, 'it no longer waits for ${identity.userId} to sign in');
    }
    if (authorizationStateOf(call).isBusy) return;

    final entry = _signIns[call.id] = _SignIn(const AIToolAuthorizationState(isConnecting: true));
    notifyListeners();
    unawaited(_connect(call, authorizer, authorization.launchUrl, entry));
  }

  Future<void> _connect(AIToolCallPart call, AIToolAuthorizer authorizer, Uri url, _SignIn entry) async {
    AIToolAuthorizationState? next;
    try {
      final connected = await Future.sync(() => authorizer.connect(call, url));
      // Connected, the call's step changing hides the sign-in; until then it
      // reads connecting.
      if (!connected) next = const AIToolAuthorizationState();
    } catch (error, stackTrace) {
      next = const AIToolAuthorizationState(connectFailed: true);
      _reportError(error, stackTrace, 'while opening the sign-in of tool call "${call.id}"');
    }
    // A "not now" sent meanwhile stays.
    if (next != null && _isCurrentSignIn(call, entry)) {
      entry.state = next;
      notifyListeners();
    }
  }

  /// Sends the person's "not now" for [call] through the [authorizer], unless
  /// one is already on its way or sent. It may be sent while the sign-in is
  /// open, so a sign-in that never comes back leaves the person a way out.
  void declineAuthorization(AIToolCallPart call) {
    if (_disposed) return reportDroppedAnswer(call, 'its AIToolApprover was disposed');
    final authorizer = this.authorizer;
    if (authorizer == null || signInFor(call) == null) {
      return reportDroppedAnswer(call, 'it no longer waits for ${identity.userId} to sign in');
    }
    if (authorizationStateOf(call).isDeclining) return;

    final entry = _signIns[call.id] = _SignIn(const AIToolAuthorizationState(isDeclining: true));
    notifyListeners();
    unawaited(_decline(call, authorizer, entry));
  }

  Future<void> _decline(AIToolCallPart call, AIToolAuthorizer authorizer, _SignIn entry) async {
    try {
      final sending = Future.sync(() => authorizer.decline(call));
      await (sentTimeout == null
          ? sending
          : sending.timeout(
              sentTimeout!,
              onTimeout: () => throw TimeoutException('the "not now" for tool call "${call.id}" took too long to send'),
            ));
      // Sent, the call's step changing hides the sign-in; until then it reads
      // declining.
    } catch (error, stackTrace) {
      // The state first, as for answers.
      if (_isCurrentSignIn(call, entry)) {
        entry.state = const AIToolAuthorizationState(declineFailed: true);
        notifyListeners();
      }
      _reportError(error, stackTrace, 'while sending the "not now" for tool call "${call.id}"');
    }
  }

  /// Whether [entry] is still [call]'s sign-in: not forgotten, nor replaced by
  /// a later answer, nor disposed.
  bool _isCurrentSignIn(AIToolCallPart call, _SignIn entry) => !_disposed && identical(_signIns[call.id], entry);

  void _reportError(Object error, StackTrace stackTrace, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'stream_chat_flutter_ai',
        context: ErrorDescription(context),
      ),
    );
  }

  void _report(Object error, StackTrace stackTrace, AIToolCallPart call) {
    _reportError(error, stackTrace, 'while sending the answer to tool call "${call.id}"');
  }

  /// Whether [entry] is still [call]'s: not forgotten, nor replaced by a
  /// later answer, nor disposed.
  bool _isCurrent(AIToolCallPart call, _Entry entry) => !_disposed && identical(_entries[call.id], entry);

  @override
  void dispose() {
    _disposed = true;
    for (final entry in _entries.values) {
      entry.timer?.cancel();
    }
    _entries.clear();
    _signIns.clear();
    super.dispose();
  }
}

class _SignIn {
  _SignIn(this.state);

  AIToolAuthorizationState state;
}

class _Entry {
  _Entry(this.state);

  AIToolApprovalState state;
  Timer? timer;
  (TimeoutException, StackTrace)? unreportedTimeout;
}

/// Where the person's answer to a tool call's question is: [AIToolApprovalIdle],
/// [AIToolApprovalSending], [AIToolApprovalSent] or [AIToolApprovalFailed].
@immutable
sealed class AIToolApprovalState {
  const AIToolApprovalState();

  /// The answer being sent, sent, or that couldn't be. `null` while idle.
  AIToolApprovalDecision? get decision;

  /// Whether the answer is on its way.
  bool get isSending => this is AIToolApprovalSending;

  /// Whether the answer arrived and the call's step hasn't changed yet.
  bool get isSent => this is AIToolApprovalSent;

  /// Whether the answer couldn't be sent.
  bool get hasFailed => this is AIToolApprovalFailed;

  /// Whether the buttons are disabled: sending or sent.
  bool get isBusy => isSending || isSent;
}

/// Nothing sent yet, so the buttons are enabled.
final class AIToolApprovalIdle extends AIToolApprovalState {
  /// Creates an [AIToolApprovalIdle].
  const AIToolApprovalIdle();

  @override
  AIToolApprovalDecision? get decision => null;

  @override
  bool operator ==(Object other) => other is AIToolApprovalIdle;

  @override
  int get hashCode => (AIToolApprovalIdle).hashCode;

  @override
  String toString() => 'AIToolApprovalIdle()';
}

/// The answer [decision] is on its way.
final class AIToolApprovalSending extends AIToolApprovalState {
  /// Creates an [AIToolApprovalSending].
  const AIToolApprovalSending(this.decision);

  @override
  final AIToolApprovalDecision decision;

  @override
  bool operator ==(Object other) => other is AIToolApprovalSending && other.decision == decision;

  @override
  int get hashCode => Object.hash(AIToolApprovalSending, decision);

  @override
  String toString() => 'AIToolApprovalSending(${decision.value})';
}

/// The answer [decision] arrived; the call's step hasn't changed yet.
final class AIToolApprovalSent extends AIToolApprovalState {
  /// Creates an [AIToolApprovalSent].
  const AIToolApprovalSent(this.decision);

  @override
  final AIToolApprovalDecision decision;

  @override
  bool operator ==(Object other) => other is AIToolApprovalSent && other.decision == decision;

  @override
  int get hashCode => Object.hash(AIToolApprovalSent, decision);

  @override
  String toString() => 'AIToolApprovalSent(${decision.value})';
}

/// The answer [decision] couldn't be sent, because of [error]; the person can
/// answer again.
final class AIToolApprovalFailed extends AIToolApprovalState {
  /// Creates an [AIToolApprovalFailed].
  const AIToolApprovalFailed(this.decision, this.error);

  @override
  final AIToolApprovalDecision decision;

  /// What [AIToolApprover.decide] threw, or a [TimeoutException] past
  /// [AIToolApprover.sentTimeout].
  final Object? error;

  @override
  bool operator ==(Object other) => other is AIToolApprovalFailed && other.decision == decision && other.error == error;

  @override
  int get hashCode => Object.hash(AIToolApprovalFailed, decision, error);

  @override
  String toString() => 'AIToolApprovalFailed(${decision.value}, $error)';
}

/// Where the person's sign-in for a tool call is. Every flag is `false` while
/// nothing is under way, so the buttons are enabled.
@immutable
class AIToolAuthorizationState {
  /// Creates an [AIToolAuthorizationState].
  const AIToolAuthorizationState({
    this.isConnecting = false,
    this.isDeclining = false,
    this.connectFailed = false,
    this.declineFailed = false,
  });

  /// The sign-in is open, or done and the call's step hasn't changed yet.
  final bool isConnecting;

  /// The "not now" is on its way, or arrived and the call's step hasn't
  /// changed yet.
  final bool isDeclining;

  /// The sign-in couldn't be opened, and the person can try again.
  final bool connectFailed;

  /// The "not now" couldn't be sent, and the person can answer again.
  final bool declineFailed;

  /// Whether an answer is under way, so Connect waits.
  bool get isBusy => isConnecting || isDeclining;

  @override
  bool operator ==(Object other) =>
      other is AIToolAuthorizationState &&
      other.isConnecting == isConnecting &&
      other.isDeclining == isDeclining &&
      other.connectFailed == connectFailed &&
      other.declineFailed == declineFailed;

  @override
  int get hashCode => Object.hash(isConnecting, isDeclining, connectFailed, declineFailed);

  @override
  String toString() =>
      'AIToolAuthorizationState(isConnecting: $isConnecting, isDeclining: $isDeclining, '
      'connectFailed: $connectFailed, declineFailed: $declineFailed)';
}
