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
/// as the surfaces the agent wrote, instead of its text:
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
/// A reply keeps its surfaces, and what the person entered in them, for as
/// long as the host keeps the reply.
///
/// A tap on a button whose action names an event sends an [AIUIAction]
/// labeled with the button's text, or else the event's name in words, never
/// the agent's own words for it. A link goes to [AIUIHosting.open], and a
/// function no catalog has runs as one of the host's tools.
///
/// The app's own components, the host's [AIUIHosting.components], can be
/// placed by the agent too. It names one in PascalCase, `PlaceCard` for
/// `place_card`, with the component's parameters as its properties, each
/// written as a value or bound to the surface's data, and it is drawn with
/// its [AIUIComponent.readArguments] and [AIUIComponent.build]. Nothing
/// shows while its values don't fit its parameters, such as while the agent
/// is still writing them; once the reply is written, values that don't fit,
/// a required value that is missing or `null`, and anything the component
/// throws reading or building them are reported through [onError].
///
/// An event an app component reports with [AIUIComponentContext.emit] is
/// sent as an [AIUIAction] named after the event, with the label the
/// component gave and its payload, to which `component` (the app's name for
/// it, such as `place_card`), `surfaceId` and `sourceComponentId` are added.
/// An app component holds no other components and no `action`.
///
/// A component the agent can't place, such as one named like a basic
/// component or with a parameter named `id` or `weight`, is left out, and
/// reported in debug builds.
///
/// See also:
///
///  * [A2UICatalog], which draws each component.
///  * [A2UIThemeData], which overrides the look of every component.
final class A2UIRenderer extends AIUIRenderer {
  /// Creates a renderer for A2UI 1.0.
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

  /// The id the agent names the app's catalog by, which a surface that names
  /// no catalog gets too.
  final String catalogId;

  /// Overrides for the look of every reply's surfaces, layered over the
  /// nearest [A2UITheme], or `null` for none.
  ///
  /// What neither sets comes from the app's Stream theme when the reply is
  /// built.
  final A2UIThemeData? theme;

  /// The function that gives the URL each image, video and audio clip loads
  /// from, or `null` to not load it. By default only web links load; see
  /// [webUrl].
  final Uri? Function(Uri url) mediaUrl;

  /// The function that gets the problems with a reply's A2UI, with the
  /// reply's message id, or `null` to report them in debug builds only.
  ///
  /// Each problem arrives once, after the frame being built, and again only
  /// after the reply's messages changed rather than grew.
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

  /// Whether a reply's UI written in A2UI `version` is shown: any way agents
  /// write 1.0, or no version.
  @override
  bool supports(String? version) => A2UIVersions.supports(version);

  /// The [fence] and [catalogId], under `fence` and `catalog_id`.
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
