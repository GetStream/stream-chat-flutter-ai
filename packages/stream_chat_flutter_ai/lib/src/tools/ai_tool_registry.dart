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
/// plain `void` return such a throw escapes to the enclosing [Zone] — a console
/// line in debug and nothing at all in release — which is the exact failure this
/// package's error handling exists to prevent.
///
/// What this indirection does *not* buy: an action takes no `BuildContext`, so a
/// tool that wants to show a dialog still captures a `GlobalKey<NavigatorState>`
/// or a host callback. Deferring the action moves that problem rather than
/// solving it.
typedef AIToolAction = FutureOr<void> Function();

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
/// An interface rather than a `(definition, onInvoke)` pair of arguments —
/// which would match how the rest of this package takes its seams — because a
/// real tool needs somewhere to hold the navigator key or repository it acts
/// on. A bare closure pushes that into its captures, which is fine for one tool
/// and unpleasant for ten.
///
/// Mirrors the `ClientTool` protocol in the stream-chat-swift-ai library.
abstract class AIClientTool {
  /// What the agent is told about this tool.
  AIToolDefinition get definition;

  /// The actions to perform for [invocation].
  ///
  /// This should *decide*, not act. Returning the work as [AIToolAction]s is
  /// what lets the host run it somewhere a `BuildContext` exists — see
  /// [AIToolAction].
  ///
  /// Read arguments from `invocation.args`, which is already decoded. Returning
  /// an empty list is fine and means the invocation needs nothing done.
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
///   if (invocation != null) registry.dispatch(invocation);
/// });
/// ```
///
/// Not a [ChangeNotifier] and not a singleton: nothing renders from a registry,
/// and because the agent registers tools per channel, one registry per channel
/// is a reasonable shape that a singleton would fight.
///
/// Mirrors `ClientToolRegistry` in the stream-chat-swift-ai library, with
/// [resolve] and [dispatch] in place of its single `handleInvocation`.
class AIToolRegistry {
  /// Creates an empty [AIToolRegistry].
  AIToolRegistry();

  final Map<String, AIClientTool> _toolsByName = {};

  /// The names of the registered tools, in registration order.
  ///
  /// Mostly here for logging: it is what makes a [dispatch] that found no tool
  /// diagnosable, since that outcome is deliberately not reported anywhere else.
  List<String> get toolNames => _toolsByName.keys.toList(growable: false);

  /// Registers [tool] under its definition's name.
  ///
  /// The last registration under a name wins, silently. No assert guards this:
  /// re-registering is usually benign — a `State.initState` that runs again, a
  /// hot reload — and an assert can't tell that apart from two features
  /// colliding on one name, so it would only fire on the harmless case.
  void register(AIClientTool tool) => _toolsByName[tool.definition.name] = tool;

  /// Removes the tool registered under [name].
  ///
  /// Returns whether there was one.
  bool unregister(String name) => _toolsByName.remove(name) != null;

  /// The registration payloads for every registered tool, ready for
  /// `jsonEncode`.
  ///
  /// In registration order, which the Swift library's equivalent is not — its
  /// dictionary values come out unordered. Nothing requires the order, but a
  /// stable one makes the request easier to read and to test.
  ///
  /// These go to the host's own backend; see [AIToolDefinition.toJson] for the
  /// shape and the one thing to verify about it.
  List<Map<String, Object?>> registrationPayloads() =>
      _toolsByName.values.map((tool) => tool.definition.toJson()).toList(growable: false);

  /// The actions [invocation]'s tool produced, without running any of them.
  ///
  /// Returns `null` when no tool is registered under the invoked name, which is
  /// distinct from a registered tool returning no actions (`[]`).
  ///
  /// That `null` is **not** reported through [FlutterError], deliberately.
  /// Registrations persist on the server and are re-applied when the channel's
  /// agent restarts, so a build that has dropped a tool will still receive
  /// invocations for it from a channel an older build registered. That is
  /// expected, outside the app's control, and reporting it would red-screen a
  /// debug build over something it cannot fix. [FlutterError] is this package's
  /// channel for bugs; this isn't one.
  ///
  /// Unlike [dispatch], a tool that throws from
  /// [AIClientTool.handleInvocation] throws through here — this is a lookup, and
  /// a caller reaching for the actions themselves can decide what a failure
  /// means.
  List<AIToolAction>? resolve(AIToolInvocation invocation) {
    final tool = _toolsByName[invocation.tool.name];
    if (tool == null) return null;
    return tool.handleInvocation(invocation);
  }

  /// Resolves [invocation] and runs its actions, in order.
  ///
  /// Returns whether a tool was registered under the invoked name — **coverage,
  /// not success**. A tool that throws, or whose actions throw, still returns
  /// `true`: the failure goes to [FlutterError.onError] instead. Keeping the two
  /// apart is the point, because `false` otherwise conflates "an older build
  /// registered this, nothing is wrong" with "your tool crashed".
  ///
  /// Actions run sequentially, each awaited before the next starts, because
  /// their order is usually meaningful — dismiss the sheet, *then* navigate. One
  /// that fails is reported and the rest still run; stopping partway through
  /// would leave the UI half-updated.
  ///
  /// The returned future is safe to ignore from an event listener, which is the
  /// usual caller:
  ///
  /// ```dart
  /// if (invocation != null) registry.dispatch(invocation);
  /// ```
  Future<bool> dispatch(AIToolInvocation invocation) async {
    // Not `resolve`: this needs the handle call inside a guard, and resolve
    // deliberately lets a tool's throw through.
    final tool = _toolsByName[invocation.tool.name];
    if (tool == null) return false;

    final List<AIToolAction> actions;
    try {
      actions = tool.handleInvocation(invocation);
    } catch (error, stack) {
      _report(error, stack, 'while asking the "${invocation.tool.name}" client tool to handle an invocation');
      return true;
    }

    for (var index = 0; index < actions.length; index++) {
      try {
        await actions[index]();
      } catch (error, stack) {
        _report(
          error,
          stack,
          'while running action ${index + 1} of ${actions.length} '
          'for the "${invocation.tool.name}" client tool',
        );
      }
    }

    return true;
  }

  /// Hands a tool failure to the host's [FlutterError.onError].
  ///
  /// No report-once guard, unlike the one in `CodeBlockView`: an invocation is
  /// handled once and there is no rebuild loop to flood a crash reporter, so
  /// every failure is worth a report.
  void _report(Object error, StackTrace stack, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stream_chat_flutter_ai',
        context: ErrorDescription(context),
      ),
    );
  }
}
