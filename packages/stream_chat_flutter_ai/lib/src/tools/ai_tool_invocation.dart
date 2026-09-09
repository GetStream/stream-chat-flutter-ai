import 'dart:convert';

/// The Stream Chat custom-event type that carries a client-tool invocation.
///
/// Exported because it is the one string that has to agree with the server, and
/// a host filtering events by hand only typos it once:
///
/// ```dart
/// channel.on(kClientToolInvocationEventType).listen(...);
/// ```
const kClientToolInvocationEventType = 'custom_client_tool_invocation';

/// The tool an [AIToolInvocation] names, as the event echoes it back.
///
/// Every field but [name] duplicates what the host already declared in its
/// `AIToolDefinition` — until it doesn't. This is the server's copy, and
/// registrations outlive the build that made them, so this is the only
/// description available for a tool the running build no longer registers. A
/// host that wants to say "the assistant tried to use *Greet the user* — update
/// the app" reads it from here.
class AIInvokedTool {
  /// Creates an [AIInvokedTool].
  const AIInvokedTool({
    required this.name,
    this.description,
    this.instructions,
    this.parameters,
  });

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
  final Map<String, Object?>? parameters;
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
/// Mirrors `ClientToolInvocation` in the stream-chat-swift-ai library. [args]
/// and [AIInvokedTool.parameters] are decoded maps rather than the raw bytes
/// that library carries, which is why [tryParse] can live here instead of in
/// every host.
class AIToolInvocation {
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
  /// does the *wrong* thing — greets the wrong person, opens the wrong ticket
  /// — which is worse than not running.
  ///
  /// A missing `type` is fine. A host filtering with `channel.on(...)` has the
  /// type on the event object rather than in the payload it passes here, so
  /// insisting on it would break the ordinary path.
  static AIToolInvocation? tryParse(Map<String, Object?> json) {
    try {
      final type = json['type'];
      if (type != null && type != kClientToolInvocationEventType) return null;

      final rawTool = json['tool'];
      if (rawTool is! Map) return null;

      final name = rawTool['name'];
      if (name is! String || name.isEmpty) return null;

      // Absent args and unreadable args are different answers; only the second
      // one sinks the parse.
      final args = _tryArgs(json['args'] ?? json['arguments']);
      if (args == null) return null;

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
    } catch (_) {
      return null;
    }
  }

  /// The tool this invocation names.
  final AIInvokedTool tool;

  /// The channel the invocation came from — the event's `cid`.
  ///
  /// A plain string, where the Swift library carries an `AnyHashable` wrapping
  /// its own `ChannelId` type. This package has no Stream Chat dependency, and
  /// `cid` is a string on the wire.
  final String? channelId;

  /// The message being generated when the tool was invoked.
  final String? messageId;

  /// The arguments the model called the tool with, matching the schema the tool
  /// declared.
  ///
  /// Empty when the invocation carried none, never null.
  final Map<String, Object?> args;

  // No `==`/`hashCode`, and adding a shallow pair would be worse than none:
  // [args] and [AIInvokedTool.parameters] are maps, so correct equality means
  // deep comparison, which means a `collection` dependency this package
  // doesn't take. Nothing here compares invocations.

  @override
  String toString() {
    // Argument *keys* only. Args carry whatever the user was talking about, and
    // a `toString` that spills those into a host's logs is a privacy problem
    // rather than a debugging convenience.
    final keys = args.keys.join(', ');
    return 'AIToolInvocation(${tool.name}, channelId: $channelId, messageId: $messageId, argKeys: [$keys])';
  }

  /// The arguments in [raw], or `null` if it names some this parser can't read.
  ///
  /// A JSON-encoded string is accepted alongside an object because that is what
  /// the Anthropic and OpenAI tool-calling APIs emit — `arguments` as a string
  /// — and agents built on those pass it straight through. Same reasoning as
  /// `USpecParser` accepting the Chart.js vocabulary next to its own.
  static Map<String, Object?>? _tryArgs(Object? raw) {
    if (raw == null) return const {};

    if (raw is Map) return _asStringKeyedMap(raw);

    if (raw is String) {
      final trimmed = raw.trim();
      // An agent sending `"args": ""` for a tool that takes none means none.
      if (trimmed.isEmpty) return const {};
      final decoded = jsonDecode(trimmed);
      return decoded is Map ? _asStringKeyedMap(decoded) : null;
    }

    return null;
  }

  static String? _asString(Object? raw) => raw is String ? raw : null;

  static Map<String, Object?>? _asStringKeyedMap(Object? raw) {
    if (raw is! Map) return null;
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
}
