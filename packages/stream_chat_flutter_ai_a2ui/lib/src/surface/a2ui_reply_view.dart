import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_view.dart';

/// Shows the surfaces of one reply, one below the other in the order the
/// agent created them, and follows them as the agent creates and deletes
/// them.
///
/// Each surface is drawn with [catalog], [theme] and [mediaUrl], and the
/// links a person's action opens go to [onOpenLink]; see [A2UISurfaceView].
///
/// Internal to the package.
@internal
class A2UIReplyView extends StatelessWidget {
  /// Creates the view of the surfaces of [processor].
  const A2UIReplyView({
    super.key,
    required this.processor,
    required this.catalog,
    this.theme,
    required this.mediaUrl,
    this.onOpenLink,
  });

  /// The reply's surfaces.
  final A2UIProcessor processor;

  /// The builders of the surfaces' components.
  final A2UICatalog catalog;

  /// The look of the surfaces' components, or `null` for the app's Stream
  /// theme.
  final A2UITheme? theme;

  /// The function the surfaces' images, videos and audio clips are loaded
  /// through.
  final A2UIMediaUrl mediaUrl;

  /// The function that opens the links a person's actions open, or `null`.
  final A2UIOpenLink? onOpenLink;

  // The space between two surfaces of a reply.
  static const _spacing = 12.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: processor,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: _spacing,
          children: [
            for (final surfaceId in processor.surfaceIds)
              if (processor.surface(surfaceId) case final surface?)
                A2UISurfaceView(
                  // Keyed by the surface itself, so one the agent deleted and
                  // created again never takes over what the old one showed.
                  key: ValueKey(surface),
                  surface: surface,
                  catalog: catalog,
                  theme: theme,
                  mediaUrl: mediaUrl,
                  onOpenLink: onOpenLink,
                ),
          ],
        );
      },
    );
  }
}
