import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/engine/a2ui_engine.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/engine/a2ui_versions.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// Signature for the function that gets a problem with a reply's A2UI, with
/// the id of the reply it is in.
typedef A2UIErrorHandler = void Function(A2UIError error, String messageId);

/// Shows the replies an agent writes in [A2UI](https://a2ui.org) 1.0 in a
/// conversation's generative UI.
///
/// Added to the conversation's [AIUIHost], it shows a reply whose UI is A2UI
/// as its surfaces, the cards, forms and lists the agent wrote, instead of
/// its text:
///
/// ```dart
/// final ui = AIUIHost(
///   renderers: [A2UIRenderer()],
///   send: (action) => channel.sendMessage(
///     Message(text: action.label, extraData: action.toCustomData()),
///   ),
/// );
/// ```
///
/// A backend that takes what the person did beside their message, rather
/// than in the message's custom data, gets `action.label` as the message's
/// text and `action.toJson()` as the action.
///
/// Each reply keeps its own surfaces for as long as the host keeps the reply,
/// so what the person enters in them survives scrolling away and back, and a
/// video or audio clip that started playing keeps playing when the reply
/// finishes. While the agent is still writing a reply, the reply's text shows
/// until its first surface arrives.
///
/// When the person taps a button whose action names an event, the host sends
/// an [AIUIAction] named after the event. Its label, which becomes the
/// person's message, is the text of the button's child, as written or read
/// from the surface's data, or else, such as for an icon or a text that reads
/// an item of a list, the event's name in words, such as "Submit form" for
/// `submit_form`. It is never the agent's
/// own words for the action, which could say something the person didn't
/// choose. Its payload holds the `surfaceId`, the `sourceComponentId` and the
/// `context` the action asked for, the agent's `userMessage` when it wrote
/// one, and the surface's `dataModel` when the agent asked for it with
/// `sendDataModel`.
///
/// A link an action opens goes to [AIUIHosting.open], only from the person's
/// tap, and only a web link with a host. A function no catalog has runs as
/// one of the host's tools, through [AIUIHosting.runTool]: a read-only one
/// whenever the UI calls it, and any other only when the person's tap calls
/// it.
///
/// See also:
///
///  * [A2UICatalog], which draws each component.
///  * [A2UITheme], which holds the look of every component.
class A2UIRenderer extends AIUIRenderer {
  /// Creates a renderer for A2UI 1.0.
  ///
  /// The components of a reply's surfaces are drawn by [catalog] with
  /// [theme], or with the theme [A2UITheme.fromStream] makes from the app's
  /// Stream theme when [theme] is `null`.
  ///
  /// The agent names the app's catalog [catalogId], and a surface that names
  /// no catalog gets it too.
  ///
  /// An image, a video's poster, a video or an audio clip loads from the URL
  /// [mediaUrl] gives for the one the agent wrote, or not at all when it
  /// gives `null`. By default only web links load; see [webUrl].
  ///
  /// A problem with a reply's A2UI, such as a component its catalog doesn't
  /// have, goes to [onError] with the reply's message id, once for as long as
  /// the reply's messages only grow; a reply whose messages changed starts
  /// again and reports it again. It arrives after the frame being built, if
  /// there is one. Without [onError], problems are reported to
  /// [FlutterError.onError] in debug builds only. A message that isn't a JSON
  /// object, and a finished reply whose components don't form a whole tree,
  /// are reported in debug builds only, with or without [onError].
  const A2UIRenderer({
    this.catalog = A2UICatalog.basic,
    this.catalogId = defaultCatalogId,
    this.theme,
    this.mediaUrl = webUrl,
    this.onError,
  });

  /// The version of A2UI this renderer reads.
  static const String version = A2UIVersions.current;

  /// The label of the fenced block an agent writes a reply's A2UI in.
  static const String fence = 'ui:a2ui@$version';

  /// The id an agent names the app's catalog by, unless the renderer is given
  /// another.
  static const String defaultCatalogId = A2UICatalogs.defaultCatalogId;

  /// The id of the A2UI 1.0 basic catalog, which a surface can name too.
  static const String basicCatalogId = A2UICatalogs.basicCatalogId;

  /// The builders of the components of every reply's surfaces.
  final A2UICatalog catalog;

  /// The id the agent names the app's catalog by.
  final String catalogId;

  /// The look of every reply's surfaces, or `null` for the one made from the
  /// app's Stream theme.
  final A2UITheme? theme;

  /// The function that gives the URL each image, video and audio clip loads
  /// from.
  final Uri? Function(Uri url) mediaUrl;

  /// The function that gets the problems with a reply's A2UI, or `null` to
  /// report them in debug builds only.
  final A2UIErrorHandler? onError;

  /// The `url` itself when it is a web link, `http` or `https` in any
  /// capitalization, or `null` for any other, such as a `file` URL.
  ///
  /// A reply's media loads only from what this gives unless the renderer is
  /// given another `mediaUrl`.
  static Uri? webUrl(Uri url) => a2uiWebMediaUrl(url);

  /// A2UI, the format of the replies this renderer shows.
  @override
  AIUIFormat get format => AIUIFormat.a2ui;

  /// Whether a reply's UI written in A2UI `version` is shown: true for
  /// `null`, `1`, `1.0`, `1.0.0`, `v1` and `v1.0`, the ways agents write 1.0,
  /// and false for any other.
  @override
  bool supports(String? version) => A2UIVersions.supports(version);

  /// What the agent's backend is told about A2UI: the [fence] its model
  /// writes a reply's UI in, under `fence`, and the [catalogId] it names the
  /// app's catalog by, under `catalog_id`.
  @override
  Map<String, Object?> capabilities(List<AIUIComponent<Object?>> components, List<AIToolDefinition> tools) {
    return {'fence': fence, 'catalog_id': catalogId};
  }

  /// Creates the engine that shows the A2UI replies of one conversation.
  ///
  /// The `host` owns the engine and disposes it.
  @override
  AIUIEngine createEngine(AIUIHosting host) => A2UIEngine(this, host);

  @override
  String toString() => '${objectRuntimeType(this, 'A2UIRenderer')}(catalogId: $catalogId)';
}
