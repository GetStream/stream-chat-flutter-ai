import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_resolved_theme.dart';

/// Signature for the function a reply's media loads through: the URL to load
/// for [url], or `null` to load nothing.
///
/// Internal to the package.
@internal
typedef OpenUIMediaUrl = Uri? Function(Uri url);

/// Signature for the function that opens a link a person taps in a reply's
/// OpenUI.
///
/// Internal to the package.
@internal
typedef OpenUIOpenLink = void Function(Uri url);

/// Loads [url] when it is a web link, `http` or `https`, and nothing
/// otherwise.
///
/// Internal to the package.
@internal
Uri? openUIWebMediaUrl(Uri url) => _isWeb(url) ? url : null;

/// Opens [href], a link a person tapped in the OpenUI around [context], when
/// it is a web or email link, `http`, `https` or `mailto`.
///
/// Nothing opens outside a reply's OpenUI, when its view has no way to open
/// links, or when [href] is `null` or isn't a URL.
///
/// Internal to the package.
@internal
void openOpenUILink(BuildContext context, String? href) {
  // Read on a tap, outside a build, so without depending on the scope.
  final openLink = context.getInheritedWidgetOfExactType<OpenUIViewScope>()?.openLink;
  if (openLink == null || href == null) return;
  final url = Uri.tryParse(href);
  if (url == null || !(_isWeb(url) || url.isScheme('mailto'))) return;
  openLink(url);
}

bool _isWeb(Uri url) => (url.isScheme('http') || url.isScheme('https')) && url.host.isNotEmpty;

/// What the components of a reply's OpenUI share: the library they are built
/// with, the theme they draw with, how media loads and links open, and
/// whether the reply is still streaming.
///
/// Internal to the package.
@internal
class OpenUIViewScope extends InheritedWidget {
  /// Creates the scope of the OpenUI below [child].
  const OpenUIViewScope({
    super.key,
    required this.library,
    required this.theme,
    required this.mediaUrl,
    required this.openLink,
    required this.isStreaming,
    required this.unknownTypes,
    required super.child,
  });

  /// The library the components are built with.
  final OpenUILibrary library;

  /// The theme the components draw with.
  final OpenUIResolvedTheme theme;

  /// The function media loads through.
  final OpenUIMediaUrl mediaUrl;

  /// The function that opens links, or `null` when none open.
  final OpenUIOpenLink? openLink;

  /// Whether the reply is still streaming.
  final bool isStreaming;

  /// The component types without a builder that the reply's OpenUI has
  /// reported in debug builds, each reported once.
  final Set<String> unknownTypes;

  /// The scope around [context], or `null` outside a reply's OpenUI.
  static OpenUIViewScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OpenUIViewScope>();

  /// The scope around [context].
  static OpenUIViewScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No OpenUIViewScope found: OpenUI components are built inside an OpenUIView.');
    return scope!;
  }

  @override
  bool updateShouldNotify(OpenUIViewScope oldWidget) {
    return library != oldWidget.library ||
        theme != oldWidget.theme ||
        mediaUrl != oldWidget.mediaUrl ||
        openLink != oldWidget.openLink ||
        isStreaming != oldWidget.isStreaming ||
        !identical(unknownTypes, oldWidget.unknownTypes);
  }
}
