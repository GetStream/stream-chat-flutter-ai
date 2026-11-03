import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_component.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_document.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_format.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_host.dart';

/// Shows generated UI written in one format, such as A2UI or OpenUI.
///
/// This package doesn't include any renderer. Apps add one renderer to their
/// [AIUIHost] for each format their agent writes, usually from a separate
/// package.
///
/// The renderer itself only says which format and versions it reads. The
/// [AIUIEngine] it creates does the work of turning each reply's
/// [AIUIDocument] into a widget, placing the app's components by name where
/// the agent asked for them.
///
/// ```dart
/// class CardsRenderer extends AIUIRenderer {
///   @override
///   AIUIFormat get format => const AIUIFormat('cards');
///
///   @override
///   AIUIEngine makeEngine(AIUIHosting host) => CardsEngine(host);
/// }
///
/// class CardsEngine extends AIUIEngine {
///   CardsEngine(this.host);
///
///   final AIUIHosting host;
///
///   @override
///   Widget? view(AIUIDocument document, String messageId) {
///     final title = document.text;
///     if (title == null) return null;
///     return host.component('place_card')?.view(
///       {'title': title},
///       AIUIComponentContext(
///         messageId: messageId,
///         isStreaming: document.isStreaming,
///         host: host,
///         emit: (event, label, payload) => host.send(
///           AIUIAction(messageId: messageId, format: document.format, name: event, label: label, payload: payload),
///         ),
///       ),
///     );
///   }
/// }
/// ```
abstract class AIUIRenderer {
  /// Creates an [AIUIRenderer].
  const AIUIRenderer();

  /// The format it reads.
  AIUIFormat get format;

  /// Whether it reads documents of [version], or of no version when `null`.
  ///
  /// It reads every version by default.
  bool supports(String? version) => true;

  /// Extra information for the agent's backend about this format, such as the
  /// instructions that teach the model to write it, given the app's
  /// [components].
  ///
  /// [AIUIHost.capabilities] includes it. Empty by default.
  Map<String, Object?> capabilities(List<AIUIComponent<Object?>> components) => const {};

  /// Creates the engine that shows this format's documents in one
  /// conversation, for that conversation's [host].
  AIUIEngine makeEngine(AIUIHosting host);
}

/// Turns one format's documents into widgets, for one conversation.
///
/// The host creates one engine per renderer, the first time that renderer is
/// needed, and keeps it until the host is disposed. So an engine can keep
/// state for each reply, such as a form's values, and can follow formats in
/// which a later reply changes an earlier reply's UI.
abstract class AIUIEngine {
  /// Creates an [AIUIEngine].
  AIUIEngine();

  /// Called with each reply's document when it arrives or changes, oldest
  /// reply first, even for replies that are off screen.
  ///
  /// This lets a format in which later replies change earlier ones keep track
  /// of all of them. It's called while the conversation builds, before [view],
  /// so changes to widgets already on screen should wait until after the
  /// frame, such as in a post-frame callback. Does nothing by default.
  void receive(AIUIDocument document, String messageId) {}

  /// Called when a reply is no longer in the conversation, its UI was removed,
  /// or its UI is now in a format another renderer reads, so the engine can
  /// drop what it kept for that reply.
  ///
  /// Does nothing by default.
  void remove(String messageId) {}

  /// Builds the widget for a reply's [document], or returns `null` to show the
  /// reply's text instead, such as for a reply that only changed an earlier
  /// reply's UI.
  ///
  /// It's called again when the reply's document changes, or when the reply is
  /// built from scratch, such as after scrolling back into view. It isn't
  /// called again when other replies change, so a widget that other replies
  /// can update should listen to the engine's state, such as a [Listenable].
  Widget? view(AIUIDocument document, String messageId);

  /// Releases the engine's resources. Called when its host is disposed.
  ///
  /// Does nothing by default.
  void dispose() {}
}
