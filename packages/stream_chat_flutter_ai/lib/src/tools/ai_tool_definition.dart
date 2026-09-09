/// The JSON Schema a tool that takes no arguments declares.
///
/// Private on purpose: it exists to make the no-argument case a default rather
/// than something every host spells out.
const _kEmptyObjectSchema = <String, Object?>{'type': 'object', 'properties': <String, Object?>{}};

/// What the AI agent is told about one of the host's client-side tools.
///
/// This is the registration half of the tool subsystem. The flow it feeds,
/// end to end:
///
/// 1. The host builds a definition per tool and registers it with an
///    `AIToolRegistry`.
/// 2. The host POSTs `registrationPayloads()` to **its own** backend — the
///    reference sample exposes `/register-tools` taking
///    `{channel_id, tools}`. This package holds no HTTP client and no
///    endpoint; that envelope belongs to whatever service the host runs.
/// 3. That backend calls the agent SDK's `registerClientTools(channelId,
///    tools)`, which **persists** the definitions server-side and re-applies
///    them the next time the channel's agent starts.
/// 4. When the model decides to call a tool, the agent emits a
///    `custom_client_tool_invocation` event, which the host parses with
///    `AIToolInvocation.tryParse` and hands back to the registry.
///
/// Step 3 is why an invocation can name a tool the running build knows nothing
/// about: a registration made by an older version outlives that version. See
/// `AIToolRegistry.resolve`, which treats that as a normal outcome rather than
/// an error.
///
/// Example:
///
/// ```dart
/// const AIToolDefinition(
///   name: 'openTicket',
///   description: 'Open a CRM ticket in the dashboard',
///   instructions: 'Use openTicket when the user asks to see a ticket.',
///   parameters: {
///     'type': 'object',
///     'properties': {
///       'ticketId': {'type': 'string'},
///     },
///     'required': ['ticketId'],
///   },
/// );
/// ```
///
/// Mirrors the `ClientTool`/`ToolRegistrationPayload` pair in the
/// stream-chat-swift-ai library, collapsed into one type — see [toJson].
class AIToolDefinition {
  /// Creates an [AIToolDefinition].
  const AIToolDefinition({
    required this.name,
    required this.description,
    this.instructions,
    this.parameters = _kEmptyObjectSchema,
    this.showExternalSourcesIndicator = false,
  }) : assert(name != '', 'a tool name must not be empty');

  /// The tool's name, which the agent uses to invoke it.
  ///
  /// This is the registry's key, and what an invocation's `tool.name` is
  /// matched against, so it has to agree with what was registered server-side.
  final String name;

  /// What the tool does, in the words the model reads when deciding to call it.
  ///
  /// Required here, where the Swift library's is optional and falls back to
  /// [instructions] when absent. A tool the model can't tell apart from the
  /// others is not useful, and backfilling this from a field written for a
  /// different audience produces a worse description than asking for one.
  final String description;

  /// Extra guidance for the agent on when and how to use the tool.
  ///
  /// Distinct from [description]: this is direction for the agent rather than
  /// part of the schema the model is shown. Omitted from [toJson] when null.
  final String? instructions;

  /// The tool's arguments, as a JSON Schema object.
  ///
  /// Passed through verbatim — nothing here validates it, and there is no
  /// schema builder. JSON Schema is large, so a DSL covering a slice of it
  /// would block the rest, and hosts already hold this map: it is the same one
  /// their agent configuration uses.
  ///
  /// Defaults to an empty object schema, which is what a tool taking no
  /// arguments declares.
  final Map<String, Object?> parameters;

  /// Whether the agent should signal that it is consulting external sources
  /// while this tool runs.
  ///
  /// Passed through to the backend; **this package never reads it**. Acting on
  /// it is the server's job — it is what makes the agent emit its
  /// "checking external sources" state, which a host renders with
  /// `AITypingIndicatorView`.
  final bool showExternalSourcesIndicator;

  /// This tool's registration payload, ready for `jsonEncode`.
  ///
  /// Keys are camelCase, and a null [instructions] is omitted rather than sent
  /// as null — both matching what the Swift library's synthesized `Encodable`
  /// produces.
  ///
  /// **Verify this against your own backend.** The endpoint that consumes it is
  /// the host's, not Stream's, so the casing it wants is ultimately the host's
  /// to decide — and a mismatch fails quietly, as a tool that simply never
  /// fires. The result is a plain map, so remapping the keys is a couple of
  /// lines if yours differ.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'description': description,
    if (instructions case final instructions?) 'instructions': instructions,
    'parameters': parameters,
    'showExternalSourcesIndicator': showExternalSourcesIndicator,
  };

  // No `==`/`hashCode`. [parameters] is a map, so a correct pair needs deep
  // comparison — `DeepCollectionEquality`, and a `collection` dependency this
  // package doesn't take — and a shallow pair would compare two identical
  // schemas as different. Nothing here compares definitions.
}
