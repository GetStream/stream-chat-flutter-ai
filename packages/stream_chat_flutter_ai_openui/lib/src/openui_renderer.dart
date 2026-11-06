import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/engine/openui_engine.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';

/// Signature for the function that gets a problem with a reply's OpenUI, with
/// the id of the reply it is in.
typedef OpenUIErrorHandler = void Function(OpenUIError error, String messageId);

/// Shows the replies an agent writes in [OpenUI](https://github.com/thesysdev/openui)
/// Lang in a conversation's generative UI.
///
/// Added to the conversation's [AIUIHost], it shows a reply whose UI is
/// OpenUI as the components the agent's program describes, instead of its
/// text:
///
/// ```dart
/// final ui = AIUIHost(
///   renderers: [OpenUIRenderer()],
///   send: (action) => channel.sendMessage(
///     Message(text: action.label, extraData: action.toCustomData()),
///   ),
/// );
/// ```
///
/// A reply shows nothing of its own until its program has a root component;
/// meanwhile the conversation shows the agent writing, and a reply that ends
/// without one shows its text. A reply keeps the values the person entered
/// for as long as the host keeps the reply.
///
/// A tap on a control sends an [AIUIAction] named after the action, such as
/// `continue_conversation`, labeled with the control's label, or, when it
/// has none, [AITranslations.uiActionUntitled] in the app's language. Its payload holds, when there are any, the action's
/// `context`, its other `params`, the agent's own `message` for it when it
/// differs from the label, and, in a form, the form's name under `form` and
/// its values under `values`, without passwords. A link the program opens,
/// a web or email link only, goes to [AIUIHosting.open] instead. The
/// program's queries and mutations run as the host's tools, queries only
/// once the reply is written. A query's refresh timer pauses while the app is
/// in the background, but not while its reply is scrolled off screen.
///
/// The app's own components, the host's [AIUIHosting.components], can be
/// placed by the agent too, wherever the library's content goes, such as in
/// a chat `Card`. It names one in PascalCase, `PlaceCard` for `place_card`,
/// with the component's parameters as its arguments, and it is drawn with
/// its [AIUIComponent.readArguments] and [AIUIComponent.build]. Nothing shows
/// while its values don't fit its parameters and the reply is still being
/// written. An event it reports with [AIUIComponentContext.emit] is sent as
/// an [AIUIAction] named after the event, with the label the component gave
/// and its payload, to which `component`, the app's name for it, is added. A
/// component whose name is taken by the library, such as `card`, or by an
/// earlier component, is left out, and reported in debug builds.
///
/// See also:
///
///  * [OpenUILibrary], which draws each component.
///  * [OpenUIThemeData], which overrides the look of every component.
final class OpenUIRenderer extends AIUIRenderer {
  /// Creates a renderer for OpenUI Lang.
  ///
  /// The agent writes with [library], or [OpenUILibrary.chat] when it is
  /// `null`.
  const OpenUIRenderer({
    this._library,
    this.instructions,
    this.theme,
    this.mediaUrl = webUrl,
    this.onError,
  });

  /// The label of the fenced block an agent writes a reply's OpenUI in.
  static const String fence = 'openui-lang';

  final OpenUILibrary? _library;

  /// The components the agent writes with, and the builders that draw them.
  OpenUILibrary get library => _library ?? OpenUILibrary.chat;

  /// What the agent's model is told before OpenUI's own instructions, such as
  /// which answers to write as UI and when to use the app's components, or
  /// `null` for nothing; see [capabilities].
  final String? instructions;

  /// Overrides for the look of every reply's components, layered over the
  /// nearest [OpenUITheme], or `null` for none.
  ///
  /// What neither sets comes from the app's Stream theme when the reply is
  /// built.
  final OpenUIThemeData? theme;

  /// The function that gives the URL each image loads from, or `null` to not
  /// load it. By default only web links load; see [webUrl].
  final Uri? Function(Uri url) mediaUrl;

  /// The function that gets the problems with a reply's OpenUI, with the
  /// reply's message id, or `null` to report them in debug builds only.
  ///
  /// It gets the problems with the program once the reply is written, each
  /// once, such as a component the library doesn't have or a query whose
  /// tool failed, so the app can send them back to the agent. It also gets
  /// what a component's builder throws, as a [OpenUIErrorCode.renderError],
  /// which otherwise goes to [FlutterError.reportError]. Each arrives after
  /// the frame being built.
  final OpenUIErrorHandler? onError;

  /// The `url` itself when it is a web link to a host, `http` or `https`, or
  /// `null` for any other, such as a `file` URL.
  ///
  /// A reply's images load only from what this gives unless the renderer is
  /// given another `mediaUrl`.
  static Uri? webUrl(Uri url) => openUIWebMediaUrl(url);

  /// OpenUI, the format of the replies this renderer shows.
  @override
  AIUIFormat get format => AIUIFormat.openUI;

  /// The [fence], under `fence`, and the instructions the agent's model
  /// needs, under `instructions`.
  ///
  /// The instructions are Markdown: the renderer's own [instructions] first,
  /// when they aren't blank, then the system prompt of the [library], with
  /// the app's [components] the agent can place and the app's [tools], each
  /// saying whether a `Query()` may run it. A component taken out with
  /// [OpenUILibrary.removing] isn't in it. The same arguments always give the
  /// same instructions.
  @override
  Map<String, Object?> capabilities(List<AIUIComponent<Object?>> components, List<AIToolDefinition> tools) {
    final definitions = <Map<String, Object?>>[];
    for (final component in components) {
      try {
        definitions.add(component.definition.toJson());
      } on Object {
        // Left out, as the engine leaves it out.
      }
    }
    final library = this.library.definition;
    final prompt = openUIInstructions(
      library,
      appInstructions: instructions,
      components: [for (final (_, schema) in placeableComponents(library, definitions)) schema],
      tools: [
        for (final tool in tools)
          HostTool(
            tool.name,
            description: tool.description,
            isReadOnly: tool.isReadOnly,
            inputSchema: tool.parameters,
          ),
      ],
    );
    return {'fence': fence, 'instructions': prompt};
  }

  /// Creates the engine that shows the OpenUI replies of one conversation.
  ///
  /// The `host` owns the engine and disposes it.
  @override
  AIUIEngine createEngine(AIUIHosting host) => OpenUIEngine(this, host);

  @override
  String toString() => '${objectRuntimeType(this, 'OpenUIRenderer')}(library: $library)';
}
