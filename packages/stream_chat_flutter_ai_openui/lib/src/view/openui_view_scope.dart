import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';

/// Signature for the function a reply's media loads through: the URL to load
/// for [url], or `null` to load nothing.
typedef OpenUIMediaUrl = Uri? Function(Uri url);

/// Signature for the function that opens a link a person taps in a reply's
/// OpenUI.
///
/// Internal to the package.
@internal
typedef OpenUIOpenLink = void Function(Uri url);

/// Signature for the function that gets what the builder of [node] threw.
///
/// Internal to the package.
@internal
typedef OpenUIBuildErrorHandler = void Function(ElementNode node, Object error, StackTrace stack);

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
/// with, how media loads and links open, and whether the reply is still
/// streaming.
///
/// Internal to the package.
@internal
class OpenUIViewScope extends InheritedTheme {
  /// Creates the scope of the OpenUI below [child].
  const OpenUIViewScope({
    super.key,
    required this.runtime,
    required this.library,
    required this.mediaUrl,
    required this.openLink,
    required this.isStreaming,
    required this.unknownTypes,
    this.onBuildError,
    required super.child,
  });

  /// The runtime of the reply's program, whose state components read and
  /// write.
  final OpenUIRuntime runtime;

  /// The library the components are built with.
  final OpenUILibrary library;

  /// The function media loads through.
  final OpenUIMediaUrl mediaUrl;

  /// The function that opens links, or `null` when none open.
  final OpenUIOpenLink? openLink;

  /// Whether the reply is still streaming.
  final bool isStreaming;

  /// The component types without a builder that the reply's OpenUI has
  /// reported in debug builds, each reported once.
  final Set<String> unknownTypes;

  /// The function that gets what a component's builder threw, or `null` to
  /// report it to [FlutterError.reportError].
  final OpenUIBuildErrorHandler? onBuildError;

  /// The scope around [context], or `null` outside a reply's OpenUI.
  static OpenUIViewScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OpenUIViewScope>();

  /// The scope around [context].
  static OpenUIViewScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No OpenUIViewScope found: OpenUI components are built inside an OpenUIView.');
    return scope!;
  }

  // Carried into routes a component opens, such as a modal's sheet, with
  // [InheritedTheme.capture], so what they show is drawn as the view draws.
  @override
  Widget wrap(BuildContext context, Widget child) {
    return OpenUIViewScope(
      runtime: runtime,
      library: library,
      mediaUrl: mediaUrl,
      openLink: openLink,
      isStreaming: isStreaming,
      unknownTypes: unknownTypes,
      onBuildError: onBuildError,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(OpenUIViewScope oldWidget) {
    return runtime != oldWidget.runtime ||
        library != oldWidget.library ||
        mediaUrl != oldWidget.mediaUrl ||
        openLink != oldWidget.openLink ||
        isStreaming != oldWidget.isStreaming ||
        !identical(unknownTypes, oldWidget.unknownTypes) ||
        onBuildError != oldWidget.onBuildError;
  }
}
