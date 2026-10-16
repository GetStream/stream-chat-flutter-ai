import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_message_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_client_identity.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_client_tool_result.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_tool_invocation.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_tool_registry.dart';

/// Sends this device's [result] for [call] to the agent's backend.
///
/// Complete once the backend has it. Throw when it wasn't accepted — a
/// non-2xx response included — and the [AIClientToolRunner] tries again.
typedef AIClientToolResultSender = Future<void> Function(AIToolCallPart call, AIClientToolResult result);

/// Called when a client tool fails while an [AIClientToolRunner] runs [call]:
/// it threw, timed out, or isn't registered.
typedef AIClientToolCallErrorCallback = void Function(AIToolCallPart call, Object error, StackTrace stack);

/// Called when an [AIClientToolRunner] gave up sending [result] for [call].
typedef AIClientToolDeliveryErrorCallback =
    void Function(AIToolCallPart call, AIClientToolResult result, Object error, StackTrace stack);

/// Words the agent is told when a tool failed with [error] on [call].
typedef AIClientToolFailureMessage = String Function(AIToolCallPart call, Object error);

/// A client tool that returns a result to the agent through an
/// [AIClientToolRunner]. See the README for an example.
///
/// On the event path, [AIToolRegistry.dispatch], the result is dropped; a
/// failed one is reported through the registry's `onToolError`.
abstract class AIResultClientTool implements AIClientTool {
  /// Creates an [AIResultClientTool].
  const AIResultClientTool();

  /// Runs [call] and returns what to tell the model.
  ///
  /// `call.arguments` are model output: validate them. A throw is reported
  /// and answered with a generic failure.
  Future<AIClientToolResult> run(AIToolCallPart call);

  @override
  List<AIToolAction> handleInvocation(AIToolInvocation invocation) => [
    () async {
      final result = await run(
        AIToolCallPart(
          id: '',
          hasPayloadId: false,
          name: invocation.tool.name,
          executor: AIToolExecutor.client,
          arguments: invocation.args,
        ),
      );
      if (result case AIClientToolFailed(:final reason)) {
        throw StateError('The "${invocation.tool.name}" client tool failed: $reason');
      }
    },
  ];
}

/// Runs the client tool calls addressed to this device, each once, and sends
/// their results back to the agent.
///
/// ```dart
/// final runner = AIClientToolRunner(
///   identity: AIClientIdentity(userId: currentUser.id, clientId: installId),
///   tools: [LocationTool()],
///   send: (call, result) => backend.postToolResult(call, result),
/// );
///
/// // On every update of an AI reply:
/// unawaited(runner.handle(parts));
/// ```
///
/// A retried `send` can post the same result twice, so make the backend
/// endpoint idempotent on `tool_call_id`. Keep one runner per conversation: a
/// new one doesn't know what an old one ran. See the README for the protocol.
final class AIClientToolRunner {
  /// Creates an [AIClientToolRunner] for [identity], offering [tools].
  ///
  /// The tools are fixed here; for a duplicate name the last one wins.
  AIClientToolRunner({
    required this.identity,
    required List<AIClientTool> tools,
    required AIClientToolResultSender send,
    this.maxAttempts = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.runTimeout,
    this.sendTimeout,
    this.failureMessage,
    this.onToolError,
    this.onDeliveryError,
  }) : assert(maxAttempts >= 1, 'maxAttempts must be at least 1'),
       assert(retryDelay >= Duration.zero, 'retryDelay must not be negative'),
       _send = send {
    tools.forEach(_registry.register);
  }

  /// The longest wait between two attempts, however many there are.
  static const maxRetryDelay = Duration(seconds: 30);

  /// Who is signed in on this device; only calls [AIClientIdentity.canRun]
  /// accepts are run.
  final AIClientIdentity identity;

  /// How many times a result is offered to `send` before the runner gives up
  /// on it, until a later [handle] sees the call still waiting.
  final int maxAttempts;

  /// The wait before the first retry, doubled for each one after it, up to
  /// [maxRetryDelay].
  final Duration retryDelay;

  /// How long a tool may run before the call is answered with a failure.
  /// `null` waits forever.
  final Duration? runTimeout;

  /// How long one `send` attempt may take before it counts as failed. `null`
  /// waits forever.
  final Duration? sendTimeout;

  /// What the agent is told when a tool fails. Defaults to a generic message
  /// naming the tool; the error itself only goes to [onToolError] and
  /// [FlutterError.onError].
  final AIClientToolFailureMessage? failureMessage;

  /// Called when a tool fails. [FlutterError.onError] hears about it too.
  final AIClientToolCallErrorCallback? onToolError;

  /// Called when the runner gave up sending a result. [FlutterError.onError]
  /// hears about it too.
  final AIClientToolDeliveryErrorCallback? onDeliveryError;

  final AIClientToolResultSender _send;
  final _registry = AIToolRegistry();

  /// Every call id taken on. Never shrinks, so no tool runs twice.
  final _taken = <String>{};

  /// Results the runner gave up sending, kept to send again while their call
  /// still waits.
  final _undelivered = <String, AIClientToolResult>{};

  final _inFlight = <String, Future<void>>{};
  bool _closed = false;

  /// The names of the tools this device can run.
  List<String> get toolNames => _registry.toolNames;

  /// The tools' registration payloads, for your backend. See
  /// [AIToolRegistry.registrationPayloads].
  List<Map<String, Object?>> get registrations => _registry.registrationPayloads();

  /// Whether [close] has been called.
  bool get isClosed => _closed;

  /// Whether a call is still running or its result is still being sent.
  bool get hasPendingWork => _inFlight.isNotEmpty;

  /// Handles the tool calls among [parts]. See [handleCalls].
  Future<void> handle(Iterable<AIMessagePart> parts) => handleCalls(parts.map((part) => part.toolCall).nonNulls);

  /// Runs each of [calls] that waits for this device and hasn't been taken on
  /// before, and sends its result. A result given up on earlier is sent again,
  /// without rerunning the tool, while its call still waits.
  ///
  /// Safe to call on every update. The future completes when the work this
  /// call started is done, and never with an error. Does nothing after
  /// [close].
  Future<void> handleCalls(Iterable<AIToolCallPart> calls) {
    if (_closed) return Future<void>.value();
    final started = <Future<void>>[];
    for (final call in calls) {
      final id = call.id;
      if (_inFlight.containsKey(id)) continue;
      if (!identity.canRun(call)) {
        _undelivered.remove(id);
        continue;
      }

      final Future<void> work;
      if (_undelivered.remove(id) case final result?) {
        work = _deliver(call, result);
      } else if (_taken.add(id)) {
        work = _runAndDeliver(call);
      } else {
        continue;
      }
      final tracked = work.whenComplete(() {
        _inFlight.remove(id);
      });
      _inFlight[id] = tracked;
      started.add(tracked);
    }
    return started.isEmpty ? Future<void>.value() : Future.wait(started);
  }

  /// Completes once no call is running or being sent, including calls started
  /// while waiting.
  Future<void> whenIdle() async {
    while (_inFlight.isNotEmpty) {
      await Future.wait(_inFlight.values.toList());
    }
  }

  /// Stops taking on calls. Calls already running still finish and send their
  /// results, retries included, so `send` must not depend on a disposed
  /// widget. Await [whenIdle] for them.
  void close() => _closed = true;

  Future<void> _runAndDeliver(AIToolCallPart call) async {
    await _deliver(call, await _run(call));
  }

  /// Runs [call], turning every failure into a generic failed result.
  Future<AIClientToolResult> _run(AIToolCallPart call) async {
    final tool = _registry.toolNamed(call.name);
    if (tool == null) {
      final error = StateError(
        'No client tool is registered under "${call.name}". Registered: ${toolNames.join(', ')}.',
      );
      _reportToolError(call, error, StackTrace.current, 'while looking up a client tool');
      return AIClientToolResult.failed('This device has no tool named "${call.name}"');
    }

    try {
      final work = tool is AIResultClientTool ? tool.run(call) : _runActions(tool, call);
      return await (runTimeout == null ? work : work.timeout(runTimeout!));
    } catch (error, stack) {
      _reportToolError(call, error, stack, 'while running the "${call.name}" client tool');
      return AIClientToolResult.failed(_failureMessageFor(call, error));
    }
  }

  /// Runs a plain tool's actions, all of them, then throws the first failure.
  Future<AIClientToolResult> _runActions(AIClientTool tool, AIToolCallPart call) async {
    final actions = tool.handleInvocation(
      AIToolInvocation(
        tool: AIInvokedTool(name: call.name),
        args: call.arguments ?? const {},
      ),
    );
    (Object, StackTrace)? first;
    for (var index = 0; index < actions.length; index++) {
      try {
        await actions[index]();
      } catch (error, stack) {
        if (first == null) {
          first = (error, stack);
        } else {
          _reportToolError(call, error, stack, 'while running action ${index + 1} of the "${call.name}" client tool');
        }
      }
    }
    if (first case (final error, final stack)) Error.throwWithStackTrace(error, stack);
    return AIClientToolResult.completed(null);
  }

  String _failureMessageFor(AIToolCallPart call, Object error) {
    final fallback = 'The "${call.name}" tool failed on this device';
    final message = failureMessage;
    if (message == null) return fallback;
    try {
      return message(call, error);
    } catch (callbackError, stack) {
      _reportSafely(_details(callbackError, stack, call, 'while building a client-tool failure message'));
      return fallback;
    }
  }

  /// Offers [result] to `send` until it is taken or [maxAttempts] run out;
  /// then keeps it for a later [handleCalls].
  Future<void> _deliver(AIToolCallPart call, AIClientToolResult result) async {
    for (var attempt = 1; ; attempt++) {
      try {
        final sending = _send(call, result);
        await (sendTimeout == null ? sending : sending.timeout(sendTimeout!));
        return;
      } catch (error, stack) {
        if (attempt >= maxAttempts) {
          _undelivered[call.id] = result;
          _reportSafely(
            _details(error, stack, call, 'while sending a client tool result; gave up after $attempt attempts'),
          );
          _callSafely(() => onDeliveryError?.call(call, result, error, stack), call, 'onDeliveryError');
          return;
        }
      }
      final delay = retryDelay * (1 << math.min(attempt - 1, 20));
      await Future<void>.delayed(delay > maxRetryDelay ? maxRetryDelay : delay);
    }
  }

  void _reportToolError(AIToolCallPart call, Object error, StackTrace stack, String context) {
    _reportSafely(_details(error, stack, call, context));
    _callSafely(() => onToolError?.call(call, error, stack), call, 'onToolError');
  }

  static FlutterErrorDetails _details(Object error, StackTrace stack, AIToolCallPart call, String context) =>
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stream_chat_flutter_ai',
        context: ErrorDescription(context),
        informationCollector: () => [DiagnosticsProperty<AIToolCallPart>('call', call)],
      );

  /// Runs a host callback; what it throws is reported, not rethrown.
  static void _callSafely(void Function() callback, AIToolCallPart call, String name) {
    try {
      callback();
    } catch (error, stack) {
      _reportSafely(_details(error, stack, call, 'while handing a client-tool failure to $name'));
    }
  }

  static void _reportSafely(FlutterErrorDetails details) {
    try {
      FlutterError.reportError(details);
    } catch (_) {
      // The reporter itself threw; there is nowhere left to send it.
    }
  }
}
