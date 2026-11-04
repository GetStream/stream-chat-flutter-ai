import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';

/// Signature for a function that gives the URL to load an image from, given
/// the URL the agent wrote, or `null` to not load it.
///
/// Internal to the package.
@internal
typedef A2UIMediaUrl = Uri? Function(Uri url);

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

/// What the components of one surface are drawn with: its catalog, its theme
/// and the function its media is loaded through.
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
    required super.child,
  });

  /// The builders of the surface's components.
  final A2UICatalog catalog;

  /// The look of the surface's components.
  final A2UITheme theme;

  /// The function the surface's images are loaded through.
  final A2UIMediaUrl mediaUrl;

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
    return catalog != oldWidget.catalog || theme != oldWidget.theme || mediaUrl != oldWidget.mediaUrl;
  }
}
