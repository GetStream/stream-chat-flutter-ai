import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// Shows one surface of a reply's A2UI: its components from the root down,
/// each built by its type's builder in [catalog] and drawn with [theme].
///
/// It shows nothing until the surface's root component arrives, and follows
/// the surface as the agent changes it. Each component comes in with an
/// [AIUIEntrance], so placed in an [AIUIView] it animates as the reply's UI
/// does.
///
/// Internal to the package.
@internal
class A2UISurfaceView extends StatelessWidget {
  /// Creates the view of [surface].
  ///
  /// Without a [theme], the surface is drawn with the one
  /// [A2UITheme.fromStream] makes from the [StreamTheme] around it.
  ///
  /// Media whose URL has a scheme loads from the URL [mediaUrl] gives for it:
  /// an image, a video's poster, a video and an audio clip. Only web links
  /// load unless it is given another function.
  ///
  /// A link a person's action opens, such as a button whose action is the
  /// agent's `openUrl`, goes to [onOpenLink]; only web links do. Without
  /// [onOpenLink], no link opens, and the surface's processor reports each
  /// one it couldn't open.
  const A2UISurfaceView({
    super.key,
    required this.surface,
    this.catalog = A2UICatalog.basic,
    this.theme,
    this.mediaUrl = a2uiWebMediaUrl,
    this.onOpenLink,
  });

  /// The surface to show.
  final A2UISurface surface;

  /// The builders of the surface's components.
  final A2UICatalog catalog;

  /// The look of the surface's components, or `null` for the app's Stream
  /// theme.
  final A2UITheme? theme;

  /// The function the surface's images, videos and audio clips are loaded
  /// through.
  final A2UIMediaUrl mediaUrl;

  /// The function that opens the links a person's actions open, or `null`.
  final A2UIOpenLink? onOpenLink;

  // The size of icons, as A2UI's basic catalog draws them.
  static const _iconSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = this.theme ?? A2UITheme.fromStream(StreamTheme.of(context));
    return A2UISurfaceScope(
      catalog: catalog,
      theme: theme,
      mediaUrl: mediaUrl,
      onOpenLink: onOpenLink,
      child: DefaultTextStyle.merge(
        style: theme.body.copyWith(color: theme.text),
        child: IconTheme.merge(
          data: IconThemeData(color: theme.text, size: _iconSize),
          child: ListenableBuilder(
            listenable: surface,
            builder: (context, _) {
              final root = surface.root;
              if (root == null) return const SizedBox.shrink();
              return A2UINodeView(node: root);
            },
          ),
        ),
      ),
    );
  }
}
