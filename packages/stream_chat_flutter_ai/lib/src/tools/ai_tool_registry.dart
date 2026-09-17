// Cross-references below to the stream-chat-swift-ai library, to MCP, and to the
// reference `/register-tools` in `chat-ai-samples` describe those sources as of
// September 2026. Neither repository is vendored here, so no check in this one
// re-verifies them.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_tool_definition.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_tool_invocation.dart';

/// A side effect a client tool asks the host to perform.
///
/// Tools return these rather than acting directly, so the host decides when and
/// where they run — queued until the app is foregrounded, dropped because the
/// user has navigated away from that channel, or run immediately by
/// [AIToolRegistry.dispatch].
///
/// The return type is `FutureOr<void>` rather than [VoidCallback], and the
/// difference is not about permitting async work: a `void Function()` already
/// accepts an `async` body. It is so [AIToolRegistry.dispatch] can await the
/// action and catch a throw that happens *after* its first `await`. With a
/// plain `void` return such a throw escapes to the enclosing [Zone] instead,
/// where it is never attributed to the tool that caused it and never reaches
/// [FlutterError.onError] with the context naming it.
///
/// An action must complete on its own. Awaiting user interaction — a
/// `showDialog` that only completes when dismissed — blocks every action after
/// it, and blocks [AIToolRegistry.dispatch]'s future indefinitely.
typedef AIToolAction = FutureOr<void> Function();

/// Called when a client tool, or one of its actions, throws.
///
/// The failure is reported to [FlutterError.onError] regardless; this is the
/// host's chance to tell the *user* that something didn't work, which a global
/// error handler is not positioned to do.
typedef AIToolErrorCallback = void Function(AIToolInvocation invocation, Object error, StackTrace stack);

/// A client-side tool the AI agent can invoke.
///
/// Implement one per capability, then register it with an [AIToolRegistry]:
///
/// ```dart
/// class GreetUserTool implements AIClientTool {
///   GreetUserTool({required this.onGreet});
///
///   final void Function(String message) onGreet;
///
///   @override
///   AIToolDefinition get definition => const AIToolDefinition(
///     name: 'greetUser',
///     description: 'Show the user a native greeting',
///     parameters: {
///       'type': 'object',
///       'properties': {'name': {'type': 'string'}},
///     },
///   );
///
///   @override
///   List<AIToolAction> handleInvocation(AIToolInvocation invocation) {
///     final name = invocation.args['name'] as String? ?? 'there';
///     return [() => onGreet('Hello, $name!')];
///   }
/// }
/// ```
///
/// An interface rather than a `(definition, onInvoke)` pair of arguments,
/// because a real tool needs somewhere to hold the navigator key or repository
/// it acts on.
///
/// Mirrors the `ClientTool` protocol in the stream-chat-swift-ai library.
abstract interface class AIClientTool {
  /// What the agent is told about this tool.
  ///
  /// Must return the same name on every call. [AIToolRegistry] reads this once,
  /// when the tool is registered, and keys the tool under the name it found; a
  /// getter that later reports a different one would announce one name to the
  /// backend and match invocations against another.
  AIToolDefinition get definition;

  /// The actions to perform for [invocation].
  ///
  /// This should *decide*, not act. Returning the work as [AIToolAction]s is
  /// what lets the host run it somewhere a `BuildContext` exists — see
  /// [AIToolAction].
  ///
  /// Read arguments from `invocation.args`, which is already decoded. Returning
  /// an empty list is fine and means the invocation needs nothing done.
  ///
  /// The actions run in order, but one should not depend on an earlier one
  /// having *succeeded*: [AIToolRegistry.dispatch] reports a failure and
  /// carries on, so that one broken action can't strand the rest.
  List<AIToolAction> handleInvocation(AIToolInvocation invocation);
}

/// The client-side tools a host offers the AI agent, keyed by tool name.
///
/// ```dart
/// final registry = AIToolRegistry()..register(GreetUserTool(onGreet: showSnackBar));
///
/// // Hand the definitions to your own backend, which registers them with the
/// // agent for this channel.
/// await http.post(
///   registerToolsUrl,
///   body: jsonEncode({'channel_id': channel.cid, 'tools': registry.registrationPayloads()}),
/// );
///
/// // Route invocations back to the tool that declared them.
/// channel.on(kClientToolInvocationEventType).listen((event) {
///   final invocation = AIToolInvocation.tryParse({...event.extraData, 'cid': event.cid});
///   if (invocation != null) unawaited(registry.dispatch(invocation));
/// });
/// ```
///
/// Not a [ChangeNotifier] and not a singleton: nothing renders from a registry,
/// and because the agent registers tools per channel, one registry per channel
/// is a reasonable shape that a singleton would fight.
///
/// Mirrors `ClientToolRegistry` in the stream-chat-swift-ai library, with
/// [resolve] and [dispatch] in place of its single `handleInvocation`.
final class AIToolRegistry {
  /// Creates an empty [AIToolRegistry].
  AIToolRegistry({this.onToolError});

  /// Called when a tool, or one of its actions, throws. See
  /// [AIToolErrorCallback].
  final AIToolErrorCallback? onToolError;

  /// The registered tools, with the definition each was registered under.
  ///
  /// The definition is snapshotted rather than re-read from the tool, so the
  /// name this registry announces and the name it matches on cannot drift
  /// apart.
  final Map<String, ({AIToolDefinition definition, AIClientTool tool})> _toolsByName = {};

  /// The names of the registered tools, in first-registration order.
  ///
  /// Re-registering an existing name replaces the tool but keeps its original
  /// position; only [unregister] then [register] moves a name to the end.
  ///
  /// Mostly here for logging: it is what makes a [dispatch] that found no tool
  /// diagnosable, since that outcome is deliberately kept out of
  /// [FlutterError].
  List<String> get toolNames => _toolsByName.keys.toList(growable: false);

  /// Registers [tool] under its definition's name.
  ///
  /// The last registration under a name wins, silently. No assert guards this:
  /// re-registering is usually benign — a `State.initState` that runs again, a
  /// hot reload — and an assert can't tell that apart from two features
  /// colliding on one name, so it would only fire on the harmless case.
  void register(AIClientTool tool) {
    final definition = tool.definition;
    assert(definition.name != '', 'a tool must not register under an empty name');
    _toolsByName[definition.name] = (definition: definition, tool: tool);
  }

  /// Removes the tool registered under [name].
  ///
  /// Returns whether there was one.
  bool unregister(String name) => _toolsByName.remove(name) != null;

  /// The registration payloads for every registered tool, ready for
  /// `jsonEncode`.
  ///
  /// In first-registration order, which the Swift library's equivalent is not —
  /// its dictionary values come out unordered. Nothing requires the order, but
  /// a stable one makes the request easier to read and to test.
  ///
  /// These go to the host's own backend; see [AIToolDefinition.toJson] for the
  /// shape and the one thing to verify about it.
  List<Map<String, Object?>> registrationPayloads() =>
      _toolsByName.values.map((entry) => entry.definition.toJson()).toList(growable: false);

  /// The actions [invocation]'s tool produced, without running any of them.
  ///
  /// Returns `null` when no tool is registered under the invoked name, which is
  /// distinct from a registered tool returning no actions (`[]`).
  ///
  /// That `null` is **not** reported through [FlutterError], deliberately.
  /// Registrations persist on the server and are re-applied when the channel's
  /// agent restarts, so a build that has dropped a tool will still receive
  /// invocations for it from a channel an older build registered. That is
  /// expected and outside the app's control, so routing it to a host's crash
  /// reporter would be noise. A debug-only console line names it instead, for
  /// the case where the name is not stale but mismatched.
  ///
  /// Unlike [dispatch], nothing here is guarded: a tool that throws from
  /// [AIClientTool.handleInvocation] throws through, and the actions come back
  /// unrun and unwrapped. A caller that schedules them itself owns that
  /// guarding — run them with [runActions] to get what [dispatch] does.
  List<AIToolAction>? resolve(AIToolInvocation invocation) {
    final entry = _toolsByName[invocation.tool.name];
    if (entry == null) {
      _warnUnknownTool(invocation);
      return null;
    }
    return entry.tool.handleInvocation(invocation);
  }

  /// Resolves [invocation] and runs its actions, in order.
  ///
  /// Returns whether a tool was registered under the invoked name — **coverage,
  /// not success**. A tool that throws, or whose actions throw, still returns
  /// `true`: the failure goes to [FlutterError.onError] and [onToolError]
  /// instead. Keeping the two apart is the point, because `false` otherwise
  /// conflates "an older build registered this, nothing is wrong" with "your
  /// tool crashed".
  ///
  /// The returned future is safe to ignore from an event listener, which is the
  /// usual caller — every failure inside is caught and reported.
  Future<bool> dispatch(AIToolInvocation invocation) async {
    // Not `resolve`: this needs the handle call inside a guard, and resolve
    // deliberately lets a tool's throw through.
    final entry = _toolsByName[invocation.tool.name];
    if (entry == null) {
      _warnUnknownTool(invocation);
      return false;
    }

    final List<AIToolAction> actions;
    try {
      actions = entry.tool.handleInvocation(invocation);
    } catch (error, stack) {
      _report(
        error,
        stack,
        invocation,
        'while asking the "${invocation.tool.name}" client tool to handle an invocation',
      );
      return true;
    }

    await runActions(invocation, actions);
    return true;
  }

  /// Runs [actions] in order, each awaited before the next starts, reporting
  /// any that fail.
  ///
  /// [dispatch] calls this; it is public so that a host which took the actions
  /// from [resolve] and scheduled them itself gets the same handling rather
  /// than reimplementing it — in particular the `await` that keeps a throw
  /// after an action's first `await` from escaping to the [Zone].
  ///
  /// One that fails is reported and the rest still run. Stopping partway would
  /// strand the actions after it, so a tool's actions should not depend on an
  /// earlier one having succeeded; the report names how many followed.
  Future<void> runActions(AIToolInvocation invocation, List<AIToolAction> actions) async {
    for (var index = 0; index < actions.length; index++) {
      try {
        await actions[index]();
      } catch (error, stack) {
        _report(
          error,
          stack,
          invocation,
          'while running action ${index + 1} of ${actions.length} '
          'for the "${invocation.tool.name}" client tool',
        );
      }
    }
  }

  /// Names an invocation no tool is registered for, in debug builds only.
  ///
  /// Deliberately not a [FlutterError] report: an unknown name is usually a
  /// registration that outlived the build that made it, which a host cannot fix
  /// and should not be paged about. But a name the backend remapped — the
  /// casing warned about on [AIToolDefinition.toJson] — looks exactly the same
  /// from here, and without this line it is invisible in debug too.
  void _warnUnknownTool(AIToolInvocation invocation) {
    assert(() {
      debugPrint(
        'stream_chat_flutter_ai: no client tool is registered under '
        '"${invocation.tool.name}". Registered: ${toolNames.join(', ')}. '
        'This is expected if an older build registered it; otherwise check that '
        'the name your backend registered matches the one you declared.',
      );
      return true;
    }(), 'unreachable: the closure always returns true');
  }

  /// Hands a tool failure to the host's [FlutterError.onError] and
  /// [onToolError].
  ///
  /// No report-once guard: an invocation is handled once and there is no
  /// rebuild loop to flood a crash reporter, so every failure is worth a
  /// report.
  void _report(Object error, StackTrace stack, AIToolInvocation invocation, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stream_chat_flutter_ai',
        context: ErrorDescription(context),
        // Carries the channel and message the failure belongs to, without the
        // argument values — see [AIToolInvocation.toString].
        informationCollector: () => [DiagnosticsProperty<AIToolInvocation>('invocation', invocation)],
      ),
    );
    onToolError?.call(invocation, error, stack);
  }
}
