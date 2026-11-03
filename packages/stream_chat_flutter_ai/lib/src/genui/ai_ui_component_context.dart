import 'package:stream_chat_flutter_ai/src/genui/ai_ui_host.dart';

/// Reports a component's `event` to the agent, with a `label` describing what
/// the person did and the event's `payload`.
typedef AIUIEventEmitter = void Function(String event, String label, Map<String, Object?> payload);

/// Information and actions a component can use while it builds: which reply
/// it is in, the conversation's host, and [emit] for reporting events to the
/// agent.
final class AIUIComponentContext {
  /// Creates an [AIUIComponentContext].
  ///
  /// Renderers create one for each component they place. Its events go to
  /// `emit`, which sends them in the renderer's format.
  const AIUIComponentContext({
    required this.messageId,
    required this.isStreaming,
    required this.host,
    required AIUIEventEmitter emit,
  }) : _emit = emit;

  /// The id of the reply whose UI the component is in.
  final String messageId;

  /// Whether the agent is still writing the reply's UI, so the component's
  /// values may still change.
  final bool isStreaming;

  /// The conversation's host, which a component can use to run the app's tools
  /// or open links.
  final AIUIHosting host;

  final AIUIEventEmitter _emit;

  /// Reports that [event] happened, using the event's name from the
  /// component's definition.
  ///
  /// It's sent as the person's next message, whose text is [label], such as
  /// "Tell me more about St. Naum". The [payload] holds the event's details.
  void emit(String event, {required String label, Map<String, Object?> payload = const {}}) =>
      _emit(event, label, payload);

  @override
  String toString() => 'AIUIComponentContext(messageId: $messageId, isStreaming: $isStreaming)';
}
