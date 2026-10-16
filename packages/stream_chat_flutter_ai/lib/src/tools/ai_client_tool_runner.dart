import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_message_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_client_identity.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_client_tool_result.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_tool_invocation.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_tool_registry.dart';

/// Sends this device's [result] for [call] to the agent's backend.
///
/// Complete once the backend has it; throw (or complete with an error) when it
/// couldn't be sent, and the [AIClientToolRunner] tries again.
typedef AIClientToolResultSender = Future<void> Function(AIToolCallPart call, AIClientToolResult result);

/// Called when a client tool, or one of its actions, throws while an
/// [AIClientToolRunner] runs [call]. The call is then answered with a failed
/// result.
typedef AIClientToolCallErrorCallback = void Function(AIToolCallPart call, Object error, StackTrace stack);

/// Called when an [AIClientToolRunner] gave up sending [result] for [call]:
/// the last of its attempts failed with [error].
typedef AIClientToolDeliveryErrorCallback =
    void Function(AIToolCallPart call, AIClientToolResult result, Object error, StackTrace stack);

/// A client tool that returns a result to the agent, for the
/// [AIClientToolRunner] round trip.
///
/// Extend it rather than implementing [AIClientTool] directly when the model
/// should learn what the tool found — a location, a picked contact — or that it
/// couldn't run:
///
/// ```dart
/// class LocationTool extends AIResultClientTool {
///   @override
///   AIToolDefinition get definition => const AIToolDefinition(
///     name: 'get_location',
///     description: "The user's approximate location",
///   );
///
///   @override
///   Future<AIClientToolResult> run(AIToolCallPart call) async {
///     final position = await locator.approximatePosition();
///     if (position == null) return const AIClientToolResult.failed('Location not shared');
///     return AIClientToolResult.completed(
///       {'lat': position.lat, 'lng': position.lng},
///       summary: 'Shared approximate location',
///     );
///   }
/// }
/// ```
///
/// A plain [AIClientTool] still works with the runner — its actions run and
/// the call completes with no output — so existing tools need no change.
///
/// The same tool also works on the event path, [AIToolRegistry.dispatch]: the
/// default [handleInvocation] runs [run] with a call built from the invocation
/// (no id from the agent, `hasPayloadId: false`), and drops the result, since
/// that path has nowhere to send it.
abstract class AIResultClientTool implements AIClientTool {
  /// Creates an [AIResultClientTool].
  const AIResultClientTool();

  /// Runs [call] and returns what to tell the model.
  ///
  /// Read arguments from `call.arguments`: they are model output, so validate
  /// them before acting on them. A throw is reported and answered with
  /// [AIClientToolResult.failed] — return that yourself for a failure the
  /// model should read in your own words.
  ///
  /// A call whose tool asks the person first reaches the device only once they
  /// allowed it.
  Future<AIClientToolResult> run(AIToolCallPart call);

  /// Runs [run] for an event-path invocation and drops its result.
  @override
  List<AIToolAction> handleInvocation(AIToolInvocation invocation) => [
    () => run(
      AIToolCallPart(
        id: '',
        hasPayloadId: false,
        name: invocation.tool.name,
        executor: AIToolExecutor.client,
        arguments: invocation.args,
      ),
    ),
  ];
}

/// Runs the client tool calls addressed to this device, each once, and sends
/// their results back to the agent.
///
/// This is the round trip for agents that write their tool calls as
/// `ai_tool_call` steps. A call to a device tool waits with `executor: client`
/// and `status: awaiting_client`, addressed to one person (`target_user_id`)
/// and one install (`target_client_id`, the `client_id` the app put in the
/// custom data of the message that triggered it):
///
/// 1. The host registers [registrations] with its backend, and sends its
///    install id as `client_id` on every message.
/// 2. Each time a reply's steps update, the host hands them to [run].
/// 3. The runner runs every call [AIClientIdentity.canRun] says waits for this
///    device, and hands each result to `send`.
/// 4. `send` posts [AIClientToolResult.toJson] to the host's backend, which
///    checks the caller is the targeted person and install, gives the result
///    to the model, and lets the agent carry on.
///
/// ```dart
/// final runner = AIClientToolRunner(
///   identity: AIClientIdentity(userId: currentUser.id, clientId: installId),
///   tools: [LocationTool()],
///   send: (call, result) => backend.post(
///     '/tool-results',
///     result.toJson(toolCallId: call.id, clientId: installId),
///   ),
/// );
///
/// // On every update of an AI reply:
/// unawaited(runner.run(parts));
/// ```
///
/// **Which path?** Use this runner when your agent writes `ai_tool_call` steps
/// and expects the device's result before it goes on. Use
/// [AIToolRegistry.dispatch] for an agent that sends
/// `custom_client_tool_invocation` events instead: those are fire-and-forget,
/// and nothing goes back to the model. Both take the same [AIClientTool]s.
///
/// [run] is safe to call on every update with the whole list of parts: a call
/// id runs at most once per runner, whether it is still running, being sent or
/// done. Keep one runner for as long as the conversation is on screen, or
/// longer — a new runner doesn't know what an old one ran, and would run a call
/// that is still waiting again.
///
/// A call the runner has no tool for is answered with a failed result, so the
/// agent doesn't wait for one that never comes.
///
/// Not a [ChangeNotifier]: nothing renders from a runner. The steps the backend
/// writes in reply are what update the UI.
final class AIClientToolRunner {
  /// Creates an [AIClientToolRunner] for [identity], offering [tools].
  ///
  /// A result `send` fails to deliver is tried again up to [maxAttempts] times
  /// in all, waiting [retryDelay] before the second attempt and twice as long
  /// before each one after that.
  AIClientToolRunner({
    required this.identity,
    required List<AIClientTool> tools,
    required AIClientToolResultSender send,
    this.maxAttempts = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.onToolError,
    this.onDeliveryError,
  }) : assert(maxAttempts >= 1, 'maxAttempts must be at least 1'),
       _send = send {
    for (final tool in tools) {
      _registry.register(tool);
    }
  }

  /// Who is signed in on this device, and which install this is. Only calls
  /// [AIClientIdentity.canRun] accepts are run — so none when its `clientId` is
  /// `null`.
  final AIClientIdentity identity;

  /// How many times a result is offered to `send` before the runner gives up
  /// on it. At least 1.
  final int maxAttempts;

  /// How long to wait before the first retry; each later one waits twice as
  /// long as the one before.
  final Duration retryDelay;

  /// Called when a tool, or one of its actions, throws. The failure goes to
  /// [FlutterError.onError] too; this is the host's chance to tell the user.
  final AIClientToolCallErrorCallback? onToolError;

  /// Called when a result couldn't be sent after [maxAttempts] attempts. The
  /// failure goes to [FlutterError.onError] too. The runner won't send that
  /// result again; the callback gets it in case the host wants to.
  final AIClientToolDeliveryErrorCallback? onDeliveryError;

  final AIClientToolResultSender _send;

  /// Holds the tools, so lookup and [registrations] follow the registry's
  /// rules: the definition is read once, and the last tool under a name wins.
  final _registry = AIToolRegistry();

  /// Every call id this runner has taken on: running, being sent, or done.
  /// Never shrinks, so a call is never run twice.
  final _taken = <String>{};

  /// The calls still running or being sent, by id.
  final _inFlight = <String, Future<void>>{};

  bool _disposed = false;

  /// The names of the tools this device can run, in the order they were given.
  List<String> get toolNames => _registry.toolNames;

  /// How this device's tools are described to the agent, ready for
  /// `jsonEncode`. Send them to your backend so the agent knows it can call
  /// them; see [AIToolRegistry.registrationPayloads].
  List<Map<String, Object?>> get registrations => _registry.registrationPayloads();

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  /// Whether a call is still running or its result is still being sent.
  bool get hasPendingWork => _inFlight.isNotEmpty;

  /// Runs the tool calls among [parts] that wait for this device and haven't
  /// run here before, and sends their results. See [runCalls].
  Future<void> run(Iterable<AIMessagePart> parts) => runCalls(parts.map((part) => part.toolCall).nonNulls);

  /// Runs those of [calls] that wait for this device — [AIClientIdentity.canRun]
  /// — and haven't been taken on by this runner before, and sends their
  /// results.
  ///
  /// Which calls to run is decided synchronously, before this returns, so
  /// calling it again straight away — or on the next update, while the first
  /// calls still run — never runs a call twice.
  ///
  /// The future completes once the calls this call started have been sent, or
  /// given up on; calls already taken on by an earlier [runCalls] aren't
  /// waited for. It never completes with an error — every failure is reported
  /// — so it is safe to drop with `unawaited`.
  ///
  /// Does nothing after [dispose].
  Future<void> runCalls(Iterable<AIToolCallPart> calls) {
    if (_disposed) return Future<void>.value();
    final started = <Future<void>>[];
    for (final call in calls) {
      if (!identity.canRun(call) || !_taken.add(call.id)) continue;
      final id = call.id;
      // A block body, not `=> _inFlight.remove(id)`: that returns the removed
      // future — this one — and whenComplete would wait on itself forever.
      final work = _handle(call).whenComplete(() {
        _inFlight.remove(id);
      });
      _inFlight[id] = work;
      started.add(work);
    }
    return started.isEmpty ? Future<void>.value() : Future.wait(started);
  }

  /// Completes once every call still running or being sent is done — what a
  /// host awaits before tearing down the backend client `send` uses.
  Future<void> whenIdle() async {
    while (_inFlight.isNotEmpty) {
      await Future.wait(_inFlight.values.toList());
    }
  }

  /// Stops taking on new calls: [run] and [runCalls] do nothing from now on.
  ///
  /// Calls already running finish, and their results are still sent, retries
  /// included — the agent is waiting for them, and a result dropped here would
  /// leave it waiting until the backend times out. That holds even when the
  /// widget that owned the runner is gone, so `send` must not depend on that
  /// widget's state. Await [whenIdle] to know when they are done.
  void dispose() => _disposed = true;

  Future<void> _handle(AIToolCallPart call) async {
    final tool = _toolFor(call.name);
    final AIClientToolResult result;
    if (tool == null) {
      _warnUnknownTool(call);
      result = AIClientToolResult.failed('This device has no tool named "${call.name}"');
    } else {
      result = await _execute(tool, call);
    }
    await _deliver(call, result);
  }

  AIClientTool? _toolFor(String name) => _registry.toolNamed(name);

  /// Runs [call] with [tool], turning every throw into a failed result.
  Future<AIClientToolResult> _execute(AIClientTool tool, AIToolCallPart call) async {
    if (tool is AIResultClientTool) {
      try {
        return await tool.run(call);
      } catch (error, stack) {
        _reportToolError(call, error, stack, 'while running the "${call.name}" client tool');
        return AIClientToolResult.failed(error.toString());
      }
    }

    // A plain tool: run its actions here and now, and complete with no output
    // unless one of them failed. Like [AIToolRegistry.runActions], one failing
    // doesn't stop the rest.
    final List<AIToolAction> actions;
    try {
      actions = tool.handleInvocation(
        AIToolInvocation(
          tool: AIInvokedTool(name: call.name),
          args: call.arguments ?? const {},
        ),
      );
    } catch (error, stack) {
      _reportToolError(call, error, stack, 'while asking the "${call.name}" client tool to handle a call');
      return AIClientToolResult.failed(error.toString());
    }

    Object? firstError;
    for (var index = 0; index < actions.length; index++) {
      try {
        await actions[index]();
      } catch (error, stack) {
        firstError ??= error;
        _reportToolError(
          call,
          error,
          stack,
          'while running action ${index + 1} of ${actions.length} for the "${call.name}" client tool',
        );
      }
    }
    return firstError == null ? AIClientToolResult.completed(null) : AIClientToolResult.failed(firstError.toString());
  }

  /// Offers [result] to `send` until it is taken or [maxAttempts] run out.
  Future<void> _deliver(AIToolCallPart call, AIClientToolResult result) async {
    for (var attempt = 1; ; attempt++) {
      try {
        await _send(call, result);
        return;
      } catch (error, stack) {
        if (attempt >= maxAttempts) {
          _reportDeliveryError(call, result, error, stack, attempt);
          return;
        }
      }
      await Future<void>.delayed(retryDelay * (1 << (attempt - 1)));
    }
  }

  void _warnUnknownTool(AIToolCallPart call) {
    assert(() {
      debugPrint(
        'stream_chat_flutter_ai: no client tool is registered under "${call.name}"; '
        'answering call ${call.id} with a failure. Registered: ${toolNames.join(', ')}.',
      );
      return true;
    }(), 'unreachable: the closure always returns true');
  }

  void _reportToolError(AIToolCallPart call, Object error, StackTrace stack, String context) {
    _reportSafely(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stream_chat_flutter_ai',
        context: ErrorDescription(context),
        informationCollector: () => [DiagnosticsProperty<AIToolCallPart>('call', call)],
      ),
    );
    _callSafely(() => onToolError?.call(call, error, stack), call, 'onToolError');
  }

  void _reportDeliveryError(
    AIToolCallPart call,
    AIClientToolResult result,
    Object error,
    StackTrace stack,
    int attempts,
  ) {
    _reportSafely(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stream_chat_flutter_ai',
        context: ErrorDescription(
          'while sending the result of the "${call.name}" client tool; gave up after $attempts attempts',
        ),
        informationCollector: () => [DiagnosticsProperty<AIToolCallPart>('call', call)],
      ),
    );
    _callSafely(() => onDeliveryError?.call(call, result, error, stack), call, 'onDeliveryError');
  }

  /// Runs a host callback, reporting rather than throwing what it throws: it
  /// is called from a catch block, and reporting a failure must not become a
  /// second one.
  static void _callSafely(void Function() callback, AIToolCallPart call, String name) {
    try {
      callback();
    } catch (error, stack) {
      _reportSafely(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stream_chat_flutter_ai',
          context: ErrorDescription('while handing a client-tool failure to $name'),
          informationCollector: () => [DiagnosticsProperty<AIToolCallPart>('call', call)],
        ),
      );
    }
  }

  static void _reportSafely(FlutterErrorDetails details) {
    try {
      FlutterError.reportError(details);
    } catch (_) {
      // Nowhere left to send it: the reporter is what threw.
    }
  }
}
