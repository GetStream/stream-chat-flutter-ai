import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// The Stream Chat custom-event type that carries a client-tool invocation.
///
/// Exported because it is the one string that has to agree with the server, and
/// a host filtering events by hand only typos it once:
///
/// ```dart
/// channel.on(kClientToolInvocationEventType).listen(...);
/// ```
///
/// **Verify this against the agent you run.** If the server ever emits a
/// different event type, every host stops receiving tool calls and nothing in
/// this package can detect it — the tools simply never fire.
const kClientToolInvocationEventType = 'custom_client_tool_invocation';

/// The tool an [AIToolInvocation] names, as the event echoes it back.
///
/// Every field but [name] duplicates what the host already declared in its
/// `AIToolDefinition` — until it doesn't. This is the server's copy, and
/// registrations outlive the build that made them, so this is the only
/// description available for a tool the running build no longer registers. A
/// host that wants to say "the assistant tried to use *Greet the user* — update
/// the app" reads it from here.
@immutable
final class AIInvokedTool {
  /// Creates an [AIInvokedTool].
  const AIInvokedTool({
    required this.name,
    this.description,
    this.instructions,
    this.parameters,
  }) : assert(name != '', 'an invoked tool name must not be empty');

  /// The tool's name — what `AIToolRegistry.resolve` matches on.
  final String name;

  /// What the server holds as the tool's description, if it sent one.
  final String? description;

  /// What the server holds as the tool's agent instructions, if it sent any.
  final String? instructions;

  /// The argument schema the server holds for the tool, if it sent one.
  ///
  /// Nullable, where `AIToolDefinition.parameters` defaults to an empty object
  /// schema. The asymmetry is deliberate and worth keeping: absent here means
  /// "the event didn't echo a schema", while an empty schema there means "this
  /// tool declares no arguments". Collapsing the two would lose that.
  ///
  /// Unmodifiable when produced by [AIToolInvocation.tryParse] — at the top
  /// level, as with [AIToolInvocation.args].
  final Map<String, Object?>? parameters;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIInvokedTool &&
          other.name == name &&
          other.description == description &&
          other.instructions == instructions &&
          const DeepCollectionEquality().equals(other.parameters, parameters);

  @override
  int get hashCode => Object.hash(name, description, instructions, const DeepCollectionEquality().hash(parameters));
}

/// A request from the AI agent to run one of the host's client-side tools.
///
/// Built from a `custom_client_tool_invocation` event with [tryParse], then
/// handed to `AIToolRegistry.dispatch`.
///
/// Nothing is returned to the model. A client tool is a side effect — present
/// an alert, navigate, read a sensor — and the protocol has no channel for
/// reporting a result back, so neither does this type.
///
/// [args] and [AIInvokedTool.parameters] are decoded maps rather than raw
/// bytes, which is why [tryParse] can live here instead of in every host.
///
/// A value type: two invocations with the same fields are `==`, [args] and the
/// echoed schema compared deeply.
@immutable
final class AIToolInvocation {
  /// Creates an [AIToolInvocation].
  const AIToolInvocation({
    required this.tool,
    this.channelId,
    this.messageId,
    this.args = const {},
  });

  /// Tries to parse a `custom_client_tool_invocation` payload.
  ///
  /// The documented event shape:
  ///
  /// ```json
  /// {
  ///   "type": "custom_client_tool_invocation",
  ///   "cid": "messaging:general",
  ///   "message_id": "8f3c…",
  ///   "tool": { "name": "openTicket" },
  ///   "args": { "ticketId": "42" }
  /// }
  /// ```
  ///
  /// Returns `null` when [json] carries no usable tool name, when its `type`
  /// names a different event, or when it names arguments that can't be read as
  /// a JSON object. That last case fails the whole parse rather than dropping
  /// the arguments, because a tool run against arguments that quietly vanished
  /// opens the wrong ticket, which is worse than not running.
  ///
  /// A payload that announced itself as an invocation and then failed to parse
  /// is reported to [FlutterError.onError] — a tool the agent asked for is not
  /// going to run, and the agent will not be told, so silence here is a bug a
  /// host has no other way to see. A payload that never claimed to be an
  /// invocation returns `null` quietly, so that a host piping every channel
  /// event through here is not drowned in reports.
  ///
  /// A missing `type` is fine. A host filtering with `channel.on(...)` has the
  /// type on the event object rather than in the payload it passes here, so
  /// insisting on it would break the ordinary path.
  ///
  /// Pass [isInvocationEvent] in that case. It says the caller already
  /// established this is a tool invocation — by filtering the stream — so a
  /// payload carrying no `tool` object is a malformed invocation and is
  /// reported, rather than passed over as an event that was never one. Without
  /// it that distinction rests on whether a `type` key happened to survive into
  /// the map, which for a host merging `Event.extraData` it does not, and the
  /// report this parser promises would go missing exactly when the backend
  /// renamed the key. Filtering on an event type of your own is fine: it is the
  /// filtering, not the name, that this asserts.
  static AIToolInvocation? tryParse(Map<String, Object?> json, {bool isInvocationEvent = false}) {
    final type = json['type'];
    if (type != null && type != kClientToolInvocationEventType) return null;

    // Whether this payload is known to be an invocation, and so can be called
    // malformed rather than passed over: either the caller said so, or the
    // payload named its own type.
    final announced = isInvocationEvent || type != null;

    final rawTool = json['tool'];
    if (rawTool is! Map) {
      if (announced) _reportMalformed(json, 'it carries no "tool" object');
      return null;
    }

    final name = rawTool['name'];
    if (name is! String || name.isEmpty) {
      _reportMalformed(json, 'its "tool" object names no tool');
      return null;
    }

    // Absent args and unreadable args are different answers; only the second
    // one sinks the parse.
    final Map<String, Object?>? args;
    try {
      args = _tryArgs(json['args'] ?? json['arguments']);
    } on FormatException catch (error) {
      _reportMalformed(json, 'its arguments are not valid JSON: ${error.message}');
      return null;
    }
    if (args == null) {
      _reportMalformed(json, 'its arguments are not a JSON object');
      return null;
    }

    return AIToolInvocation(
      tool: AIInvokedTool(
        name: name,
        description: _asString(rawTool['description']),
        instructions: _asString(rawTool['instructions']),
        parameters: _asStringKeyedMap(rawTool['parameters']),
      ),
      // `cid` is what the event wire calls it; `channel_id` is what the
      // registration side calls it. Accept either rather than making a host
      // remember which direction it is holding.
      channelId: _asString(json['cid']) ?? _asString(json['channel_id']),
      messageId: _asString(json['message_id']) ?? _asString(json['messageId']),
      args: args,
    );
  }

  /// The tool this invocation names.
  final AIInvokedTool tool;

  /// The channel the invocation came from — the event's `cid`.
  ///
  /// A plain string: this package has no Stream Chat dependency, and `cid` is a
  /// string on the wire.
  final String? channelId;

  /// The message being generated when the tool was invoked.
  final String? messageId;

  /// The arguments the model called the tool with, matching the schema the tool
  /// declared.
  ///
  /// Empty when the invocation carried none, never null, and unmodifiable when
  /// produced by [tryParse] — one contract rather than one per input shape.
  ///
  /// Unmodifiable at the top level only. An argument that is itself an object
  /// or a list is the decoded value as it arrived, and nothing stops a host
  /// mutating that; copy it if you intend to.
  final Map<String, Object?> args;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIToolInvocation &&
          other.tool == tool &&
          other.channelId == channelId &&
          other.messageId == messageId &&
          const DeepCollectionEquality().equals(other.args, args);

  @override
  int get hashCode => Object.hash(tool, channelId, messageId, const DeepCollectionEquality().hash(args));

  @override
  String toString() {
    // Argument *keys* only. Args carry whatever the user was talking about, and
    // a `toString` that spills those into a host's logs is a privacy problem
    // rather than a debugging convenience.
    final keys = args.keys.join(', ');
    return 'AIToolInvocation(${tool.name}, channelId: $channelId, messageId: $messageId, argKeys: [$keys])';
  }

  /// Reports a payload that claimed to be an invocation but could not be read.
  ///
  /// Names the payload's *keys* only, on the same reasoning as [toString]: the
  /// values are whatever the user was talking about.
  static void _reportMalformed(Map<String, Object?> json, String reason) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: FormatException('cannot read a client-tool invocation, because $reason'),
        library: 'stream_chat_flutter_ai',
        context: ErrorDescription(
          'while parsing a $kClientToolInvocationEventType payload with keys '
          '[${json.keys.join(', ')}]; the tool the agent asked for will not run',
        ),
      ),
    );
  }

  /// The arguments in [raw], or `null` if it names some this parser can't read.
  ///
  /// A JSON-encoded string is accepted alongside an object because that is what
  /// the Anthropic and OpenAI tool-calling APIs emit — `arguments` as a string
  /// — and agents built on those pass it straight through.
  ///
  /// Throws [FormatException] on a string that isn't JSON, which [tryParse]
  /// turns into a reported parse failure.
  static Map<String, Object?>? _tryArgs(Object? raw) {
    if (raw == null) return const {};

    if (raw is Map) return _asStringKeyedMap(raw);

    // No empty-string exemption: `jsonDecode('')` throws, so an empty string is
    // not a readable JSON object. A tool that takes no arguments omits the key
    // or sends `{}`; an empty string is far more likely an argument stream that
    // was cut short, and running on what survived is the wrong-ticket failure
    // this parser refuses everywhere else.
    if (raw is String) {
      final decoded = jsonDecode(raw);
      return decoded is Map ? _asStringKeyedMap(decoded) : null;
    }

    return null;
  }

  static String? _asString(Object? raw) => raw is String ? raw : null;

  static Map<String, Object?>? _asStringKeyedMap(Object? raw) {
    if (raw is! Map) return null;
    // `key.toString()` would merge `1` and `'1'`, which real JSON can't produce
    // — keys are always strings there.
    return Map<String, Object?>.unmodifiable(raw.map((key, value) => MapEntry(key.toString(), value)));
  }
}
