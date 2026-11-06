import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_resolved_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

/// Signature for a function that gives the URL to load an image, a video or
/// an audio clip from, given the URL the agent wrote, or `null` to not load
/// it.
///
/// Internal to the package.
@internal
typedef A2UIMediaUrl = Uri? Function(Uri url);

/// The URL to load the media at [url] from: the URL the agent wrote, parsed,
/// as [mediaUrl] gives it, or `null` when nothing loads.
///
/// Nothing loads for a missing or empty [url], one that doesn't parse, or one
/// without a scheme, such as a file name; [mediaUrl] isn't called for those.
///
/// Internal to the package.
@internal
Uri? a2uiMediaSourceOf(String? url, A2UIMediaUrl mediaUrl) {
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return null;
  return mediaUrl(uri);
}

/// The URL itself when it is a web link, `http` or `https` in any
/// capitalization, or `null` for any other, such as a `file` or `data` URL.
///
/// It is what a surface loads its media through unless it is given another
/// function.
///
/// Internal to the package.
@internal
Uri? a2uiWebMediaUrl(Uri url) {
  final scheme = url.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https') return url;
  return null;
}

/// What the components of one surface are drawn with: its catalog, its theme,
/// the function its media is loaded through and the one that opens its links.
///
/// Internal to the package.
@internal
class A2UISurfaceScope extends InheritedWidget {
  /// Creates an [A2UISurfaceScope].
  const A2UISurfaceScope({
    super.key,
    required this.catalog,
    required this.theme,
    required this.mediaUrl,
    this.onOpenLink,
    required super.child,
  });

  /// The builders of the surface's components.
  final A2UICatalog catalog;

  /// The look of the surface's components.
  final A2UIResolvedTheme theme;

  /// The function the surface's images, videos and audio clips are loaded
  /// through.
  final A2UIMediaUrl mediaUrl;

  /// The function that opens a link a person's action in the surface opens,
  /// or `null` when nothing opens links there.
  final A2UIOpenLink? onOpenLink;

  /// The scope of the surface around [context].
  ///
  /// Only a component of a surface is built with one.
  static A2UISurfaceScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<A2UISurfaceScope>();
    assert(scope != null, 'A2UISurfaceScope.of was called outside a surface.');
    return scope!;
  }

  @override
  bool updateShouldNotify(A2UISurfaceScope oldWidget) {
    return catalog != oldWidget.catalog ||
        theme != oldWidget.theme ||
        mediaUrl != oldWidget.mediaUrl ||
        onOpenLink != oldWidget.onOpenLink;
  }
}
