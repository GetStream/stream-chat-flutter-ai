// Cross-references below to the stream-chat-swift-ai library, to MCP, and to the
// reference `/register-tools` in `chat-ai-samples` describe those sources as of
// September 2026. Neither repository is vendored here, so no check in this one
// re-verifies them.

import 'package:flutter/foundation.dart';

/// The JSON Schema a tool that takes no arguments declares.
const _kEmptyObjectSchema = <String, Object?>{'type': 'object', 'properties': <String, Object?>{}};

/// What the AI agent is told about one of the host's client-side tools.
///
/// This is the registration half of the tool subsystem. The host builds a
/// definition per tool, registers it with an `AIToolRegistry`, and POSTs
/// `registrationPayloads()` to **its own** backend, which hands them to the
/// agent SDK. See the README for the full round trip.
///
/// The one step worth knowing here: the agent SDK **persists** registrations
/// server-side and re-applies them the next time the channel's agent starts.
/// That is why an invocation can name a tool the running build knows nothing
/// about — a registration made by an older version outlives that version. See
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
/// This type has no `==`/`hashCode`, and neither does `AIToolInvocation`.
/// [parameters] is a map, so a correct pair needs deep comparison — a
/// `collection` dependency this package doesn't take — and a shallow pair would
/// compare two identical schemas as different. Comparing definitions in a test
/// means comparing [toJson] results, which are plain maps and compare deeply.
///
/// Collapses the `Tool`/`ToolRegistrationPayload` pair the stream-chat-swift-ai
/// library carries — see [toJson].
@immutable
final class AIToolDefinition {
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
  /// Required here, where MCP's `Tool.description` — which the Swift library
  /// embeds — is optional and falls back to its `instructions` when absent. A
  /// tool the model can't tell apart from the others is not useful, and
  /// backfilling this from a field written for a different audience produces a
  /// worse description than asking for one.
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
  /// arguments declares. Note the asymmetry with `AIInvokedTool.parameters`,
  /// which is nullable because absent there means "the event echoed no schema"
  /// rather than "this tool declares no arguments".
  final Map<String, Object?> parameters;

  /// Whether the agent should signal that it is consulting external sources
  /// while this tool runs.
  ///
  /// Passed through to the backend; **this package never reads it**. Acting on
  /// it is the server's job — it is what makes the agent report a "checking
  /// external sources" state, which a host can render by passing that caption
  /// to `AITypingIndicatorView`, whose `text` is an arbitrary string.
  final bool showExternalSourcesIndicator;

  /// This tool's registration payload, ready for `jsonEncode`.
  ///
  /// Keys are camelCase, and a null [instructions] is omitted rather than sent
  /// as null — both matching what the Swift library's synthesized `Encodable`
  /// produces, and what the reference `/register-tools` in `chat-ai-samples`
  /// reads.
  ///
  /// **Verify this against your own backend.** The endpoint that consumes it is
  /// the host's, not Stream's, so the casing it wants is ultimately the host's
  /// to decide — and a mismatch fails quietly, as a tool that simply never
  /// fires. The result is a plain map, so remapping the keys is a couple of
  /// lines if yours differ.
  ///
  /// [parameters] is copied out rather than aliased, so a host that rewrites
  /// its payload before sending does not also rewrite the definition it
  /// registered.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'description': description,
    if (instructions case final instructions?) 'instructions': instructions,
    'parameters': Map<String, Object?>.of(parameters),
    'showExternalSourcesIndicator': showExternalSourcesIndicator,
  };

  /// A copy of this definition with the given fields replaced.
  ///
  /// A null argument means "keep what is there", so this cannot clear
  /// [instructions] — construct a new definition for that.
  AIToolDefinition copyWith({
    String? name,
    String? description,
    String? instructions,
    Map<String, Object?>? parameters,
    bool? showExternalSourcesIndicator,
  }) => AIToolDefinition(
    name: name ?? this.name,
    description: description ?? this.description,
    instructions: instructions ?? this.instructions,
    parameters: parameters ?? this.parameters,
    showExternalSourcesIndicator: showExternalSourcesIndicator ?? this.showExternalSourcesIndicator,
  );
}
