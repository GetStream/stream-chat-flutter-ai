import 'dart:async';

import 'package:flutter/widgets.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_assistant_message_view.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_action.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_component.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_document.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_entrance.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_renderer.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_stage.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_client_tool_result.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_client_tool_runner.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_tool_definition.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

/// Sends an [AIUIAction] to the agent as the person's next message, and
/// completes once it is sent.
typedef AIUIActionSender = Future<void> Function(AIUIAction action);

/// Opens a link the person tapped in generated UI.
typedef AIUILinkOpener = void Function(Uri url);

/// The services that renderers and components can use: the app's components,
/// sending actions to the agent, running the app's tools, opening links, and
/// keeping each reply's UI state.
///
/// [AIUIHost] implements it.
///
/// A host of your own, such as a fake one in tests, should mix it in or extend
/// it rather than implementing it. Members added in later versions come with a
/// default, so it keeps compiling, while a class that `implements` it would
/// break.
abstract mixin class AIUIHosting {
  /// The app's components, which any renderer can place.
  List<AIUIComponent<Object?>> get components;

  /// The app's component with this [name], or `null` if there is none.
  AIUIComponent<Object?>? component(String name) => components.where((component) => component.name == name).firstOrNull;

  /// Sends [action] to the agent as the person's next message.
  ///
  /// Completes once it is sent, or with the error if sending failed, so the UI
  /// can, for example, disable a button meanwhile or say the action didn't
  /// reach the agent. Ignoring the result is fine.
  Future<void> send(AIUIAction action);

  /// Runs the app's tool called [name] on this device, such as to load data the
  /// UI shows, and completes with the tool's output.
  ///
  /// Set [userInitiated] when the person asked for it, such as by tapping a
  /// button, rather than the UI running it on its own while it shows. Without
  /// it, only a read-only tool ([AIToolDefinition.isReadOnly]) runs, so a
  /// renderer runs a tool that changes something, such as sending an email,
  /// only when the person asks. The host can't check either side of this:
  /// renderers must set [userInitiated] only for the person's own actions, and
  /// the app must mark only tools that change nothing as read-only.
  ///
  /// Throws an [AIUIToolException] if there is no tool with that name, if it
  /// isn't read-only and [userInitiated] is `false`, or if the tool fails.
  Future<Object?> runTool(
    String name, {
    Map<String, Object?> arguments = const {},
    bool userInitiated = false,
  });

  /// Opens a link the person tapped in generated UI.
  void open(Uri url);

  /// The UI state saved for the reply [messageId], such as a form's values, or
  /// `null` if none was saved.
  Object? state(String messageId);

  /// Saves [state] for the reply [messageId], or clears it when [state] is
  /// `null`.
  void setState(String messageId, Object? state);
}

/// Manages generated UI for one conversation: the renderers for the formats
/// the agent writes, the app's components and tools, and where the person's
/// actions are sent.
///
/// Pass it to [AIConversationView.ui]. A reply whose [AIUIDocument] is in a
/// format one of the [renderers] reads then shows that UI instead of its text.
///
/// Create one host per conversation and keep it for as long as the
/// conversation is shown, so each reply's UI keeps its state. Call [dispose]
/// when the conversation is closed.
///
/// ```dart
/// final ui = AIUIHost(
///   components: const [PlaceCardComponent()],
///   // The app's renderers: this package ships none.
///   renderers: [MyA2UIRenderer(), MyOpenUIRenderer()],
///   send: (action) => channel.sendMessage(Message(text: action.label, extraData: action.toCustomData())),
/// );
///
/// AIConversationView(messages: messages, ui: ui)
/// ```
final class AIUIHost with AIUIHosting {
  /// Creates an [AIUIHost].
  ///
  /// For each reply, the first of the [renderers] that reads its format shows
  /// its UI. The renderers can place the app's [components].
  ///
  /// `send` is called with each action the person takes, and should send it to
  /// the agent as their next message.
  ///
  /// `tools` are the app's tools that generated UI may run, such as to load
  /// data on this device. A read-only tool ([AIToolDefinition.isReadOnly])
  /// runs whenever the UI asks; any other only when the person asks for it,
  /// such as by tapping a button. They are separate from the tools the agent
  /// itself calls, and renderers can describe them to the agent through
  /// [capabilities]. If two tools have the same name, the first is used.
  ///
  /// `open` is called when the person taps a link in generated UI. By default,
  /// only web links to a host and email links open, in the browser or mail
  /// app. Other links, such as `tel:` or another app's link, are ignored,
  /// because the agent wrote them.
  AIUIHost({
    List<AIUIComponent<Object?>> components = const [],
    List<AIResultClientTool> tools = const [],
    required List<AIUIRenderer> renderers,
    required AIUIActionSender send,
    AIUILinkOpener? open,
  }) : components = List.unmodifiable(components),
       renderers = List.unmodifiable(renderers),
       _tools = {for (final tool in tools.reversed) tool.definition.name: tool},
       _sendAction = send,
       _openLink = open ?? _openIfWebOrEmail;

  /// The renderers for the formats the agent writes, tried in order.
  final List<AIUIRenderer> renderers;

  @override
  final List<AIUIComponent<Object?>> components;

  final Map<String, AIResultClientTool> _tools;
  final AIUIActionSender _sendAction;
  final AIUILinkOpener _openLink;
  // The engines its renderers made, by each renderer's position among them.
  final _engines = <int, AIUIEngine>{};
  final _states = <String, Object?>{};
  final _received = <String, AIUIDocument>{};
  // The widget each reply's engine built for its latest document, so the
  // conversation and the reply's row agree on whether the reply shows UI.
  final _built = <String, (AIUIDocument, Widget?)>{};
  Future<void> _lastSend = Future<void>.value();
  bool _isDisposed = false;

  /// Whether one of the [renderers] reads [document]'s format and version.
  ///
  /// This doesn't mean the reply shows UI: the renderer's engine can still
  /// build nothing for it, such as before an A2UI reply has a surface. Use
  /// [AIUIView.canShow] to tell whether a reply's UI actually shows.
  bool canShow(AIUIDocument document) => _positionOf(document) != null;

  /// Sends [action] to the agent, waiting for earlier actions to be sent first
  /// so the agent gets them in the order they happened.
  ///
  /// Completes once it is sent. If sending fails, it completes with the
  /// error, which is also reported to [FlutterError.onError], and later
  /// actions are still sent.
  ///
  /// Does nothing once the host is disposed.
  @override
  Future<void> send(AIUIAction action) {
    if (_isDisposed) return Future<void>.value();
    final sent = _lastSend.then((_) => _sendAction(action));
    // The next action waits for this one, whether it was sent or not.
    _lastSend = sent.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) => FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stream_chat_flutter_ai',
          context: ErrorDescription("while sending what the person did in a reply's UI"),
        ),
      ),
    );
    return sent;
  }

  @override
  Future<Object?> runTool(
    String name, {
    Map<String, Object?> arguments = const {},
    bool userInitiated = false,
  }) async {
    if (_isDisposed) throw AIUIToolException("Can't run $name: the host was disposed");
    final tool = _tools[name];
    if (tool == null) throw AIUIToolException('No tool named $name');
    if (!userInitiated && !tool.definition.isReadOnly) {
      throw AIUIToolException("$name isn't read-only, so it runs only when the person asks for it");
    }
    final call = AIToolCallPart(
      id: const Uuid().v4(),
      name: name,
      status: AIToolCallStatus.awaitingClient,
      executor: AIToolExecutor.client,
      arguments: deepUnmodifiable(arguments)! as Map<String, Object?>,
    );
    final AIClientToolResult result;
    try {
      result = await tool.run(call);
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stream_chat_flutter_ai',
          context: ErrorDescription("while running the tool $name for a reply's UI"),
        ),
      );
      throw AIUIToolException('$name failed');
    }
    return switch (result) {
      AIClientToolCompleted(:final output) => output,
      AIClientToolFailed(:final reason) => throw AIUIToolException(reason),
    };
  }

  @override
  void open(Uri url) => _openLink(url);

  /// The UI state saved for the reply [messageId], such as a form's values, or
  /// `null` if none was saved.
  ///
  /// It's kept for as long as the host is alive and the reply is in the
  /// conversation.
  @override
  Object? state(String messageId) => _states[messageId];

  @override
  void setState(String messageId, Object? state) {
    if (state == null) {
      _states.remove(messageId);
    } else {
      _states[messageId] = state;
    }
  }

  /// Passes the generated UI of the conversation's [messages] to the
  /// renderers' engines: each new or changed one, oldest first, including
  /// replies that are off screen.
  ///
  /// It also tells the engines about replies that left the conversation or
  /// lost their UI, and clears their saved state.
  ///
  /// [AIConversationView] calls this itself. An app that shows replies with
  /// [AIUIView] instead calls it each time the conversation's messages
  /// change.
  ///
  /// Does nothing once the host is disposed.
  void receive(List<AIMessage> messages) {
    assert(!_isDisposed, 'AIUIHost.receive was called after the host was disposed.');
    if (_isDisposed) return;
    final documents = [
      for (final message in messages)
        if (message.role != AIMessageRole.user)
          if (message.uiDocument case final document?) (message.id, document),
    ];
    final current = {for (final (id, _) in documents) id};
    for (final MapEntry(key: messageId, value: document) in _received.entries.toList()) {
      if (current.contains(messageId)) continue;
      _received.remove(messageId);
      _built.remove(messageId);
      _states.remove(messageId);
      if (_positionOf(document) case final position?) {
        _guarded(_kRemoving, () => _engine(position).remove(messageId));
      }
    }
    for (final (messageId, document) in documents) {
      final previous = _received[messageId];
      if (previous == document) continue;
      _received[messageId] = document;
      final position = _positionOf(document);
      // A reply whose UI another renderer now reads, or none does, is gone
      // from the engine that had it.
      final had = previous == null ? null : _positionOf(previous);
      if (had != null && had != position) _guarded(_kRemoving, () => _engine(had).remove(messageId));
      if (position != null) _guarded(_kReceiving, () => _engine(position).receive(document, messageId));
    }
  }

  /// A JSON description of what this app can show: the formats its renderers
  /// read, with any extra information each renderer adds (see
  /// [AIUIRenderer.capabilities]), such as instructions that list the app's
  /// tools, and the definitions of its components.
  ///
  /// The app can send this to its agent backend, so the model knows which
  /// formats and components it may use.
  ///
  /// ```json
  /// {
  ///   "v": 1,
  ///   "renderers": [{ "format": "openui", ... }],
  ///   "components": [{ "name": "place_card", "description": "...", "parameters": {...}, "events": [...] }]
  /// }
  /// ```
  ///
  /// The result is a new copy each time, so changing it doesn't affect the
  /// host.
  Map<String, Object?> get capabilities => <String, Object?>{
    'v': _kCapabilitiesVersion,
    'renderers': [
      for (final renderer in renderers)
        <String, Object?>{
          ...deepCopy(renderer.capabilities(components, _toolDefinitions))! as Map<String, Object?>,
          'format': renderer.format,
        },
    ],
    'components': [for (final component in components) component.definition.toJson()],
  };

  // The definitions of the app's tools, by name.
  List<AIToolDefinition> get _toolDefinitions => List.unmodifiable(
    [for (final tool in _tools.values) tool.definition]..sort((a, b) => a.name.compareTo(b.name)),
  );

  /// Releases the renderers' engines.
  ///
  /// Afterwards the host shows no UI and sends no actions, and [runTool]
  /// throws an [AIUIToolException].
  void dispose() {
    _isDisposed = true;
    for (final engine in _engines.values) {
      engine.dispose();
    }
    _engines.clear();
    _built.clear();
  }

  // The widget of a reply's document from the first renderer that reads its
  // format and version. The engine is asked once per document, and a document
  // it throws on shows nothing.
  Widget? _content(AIUIDocument document, String messageId) {
    if (_isDisposed) return null;
    if (_built[messageId] case (final built, final content) when built == document) return content;
    final position = _positionOf(document);
    final content = position == null ? null : _guarded(_kBuilding, () => _engine(position).view(document, messageId));
    _built[messageId] = (document, content);
    return content;
  }

  // Calls a renderer's engine, reporting what it throws to
  // [FlutterError.onError] rather than letting one reply's UI break the
  // conversation. Returns `null` when it throws.
  static T? _guarded<T>(String doing, T Function() call) {
    try {
      return call();
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stream_chat_flutter_ai',
          context: ErrorDescription(doing),
        ),
      );
      return null;
    }
  }

  int? _positionOf(AIUIDocument document) {
    final position = renderers.indexWhere((renderer) => _reads(renderer, document));
    return position < 0 ? null : position;
  }

  static bool _reads(AIUIRenderer renderer, AIUIDocument document) =>
      renderer.format == document.format && renderer.supports(document.version);

  // The engine of the renderer at [position], made the first time it is needed.
  AIUIEngine _engine(int position) {
    assert(!_isDisposed, 'An AIUIHost was used after it was disposed.');
    if (_isDisposed) throw StateError('An AIUIHost was used after it was disposed.');
    return _engines.putIfAbsent(position, () => renderers[position].createEngine(this));
  }

  @override
  String toString() =>
      'AIUIHost(renderers: [${renderers.map((renderer) => renderer.format).join(', ')}], components: $components)';
}

// What the host was doing when an engine threw, for the error report.
const _kReceiving = "while passing a reply's UI to its renderer";
const _kRemoving = "while removing a reply's UI from its renderer";
const _kBuilding = "while building a reply's UI";

// The version of the capabilities' shape.
const _kCapabilitiesVersion = 1;

// The link schemes a reply's UI opens unless the app opens links itself.
const _kWebAndEmailSchemes = {'http', 'https', 'mailto'};

// Whether [url] is a web link to a host, or an email link.
bool _isWebOrEmail(Uri url) {
  final scheme = url.scheme.toLowerCase();
  if (!_kWebAndEmailSchemes.contains(scheme)) return false;
  return scheme == 'mailto' || url.host.isNotEmpty;
}

void _openIfWebOrEmail(Uri url) {
  if (!_isWebOrEmail(url)) {
    reportPartIssue(() => "A reply's UI asked to open $url, which isn't a web link to a host or an email link.");
    return;
  }
  unawaited(
    launchUrl(url, mode: LaunchMode.externalApplication).then<void>(
      (opened) {
        if (!opened) reportPartIssue(() => "No app could open $url, which a reply's UI asked to open.");
      },
      onError: (Object error, StackTrace stack) => FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stream_chat_flutter_ai',
          context: ErrorDescription("while opening a link from a reply's UI"),
        ),
      ),
    ),
  );
}

/// Thrown by [AIUIHosting.runTool] when the app has no tool with the given
/// name, when the tool isn't read-only and the person didn't ask for it, or
/// when the tool fails.
final class AIUIToolException implements Exception {
  /// Creates an [AIUIToolException] that says why the tool couldn't run.
  const AIUIToolException(this.message);

  /// Why the tool couldn't run, such as "No tool named list_events" or the
  /// tool's own failure reason.
  final String message;

  @override
  String toString() => 'AIUIToolException: $message';
}

/// Shows one reply's generated UI, built by the first of the host's renderers
/// that reads its format.
///
/// [AIConversationView] uses it for every reply. Use it directly to show a
/// reply's UI somewhere else: when [canShow] is `true`, show it below an
/// [AIAssistantMessageView] with empty text. Otherwise show the reply's text
/// as usual, or nothing while the reply has no text or anything else to show.
///
/// While the agent is still writing the UI, it animates in as it first
/// appears, and so do parts added later (see [AIUIEntrance]).
///
/// ```dart
/// ui.receive(messages);
/// final view = AIUIView(host: ui, document: reply.uiDocument!, messageId: reply.id);
/// return Column(
///   children: [
///     AIAssistantMessageView(text: view.canShow ? '' : reply.text, parts: reply.parts),
///     if (view.canShow) view,
///   ],
/// );
/// ```
///
/// The host asks the renderer's engine for the reply's widget once for each
/// document, and gives every [AIUIView] of that document the same widget.
class AIUIView extends StatelessWidget {
  /// Creates an [AIUIView] that shows [document], the generated UI of the
  /// reply [messageId], with [host]'s renderers.
  AIUIView({super.key, required AIUIHost host, required this.document, required this.messageId})
    : _content = host._content(document, messageId);

  /// The reply's generated UI.
  final AIUIDocument document;

  /// The reply's id.
  final String messageId;

  final Widget? _content;

  /// Whether there's UI to show instead of the reply's text: one of the host's
  /// renderers reads the document and built a widget for it.
  bool get canShow => _content != null;

  @override
  Widget build(BuildContext context) {
    final content = _content;
    if (content == null) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.topStart,
      heightFactor: 1,
      child: AIUIEntering(isStage: true, isStreaming: document.isStreaming, child: content),
    );
  }
}
