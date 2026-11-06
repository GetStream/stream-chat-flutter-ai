import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_stream_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Shows the OpenUI of one reply: the components of [runtime]'s program from
/// its root down, each built by its type's builder in [library] and drawn
/// with [theme].
///
/// It shows nothing while the program has no root, and follows the program
/// as the reply streams and its state changes. While a query of the program
/// is loading, the whole view is dimmed, with a small spinner at its top end.
/// A component whose type has no builder shows nothing; in debug builds,
/// each such type is reported once per runtime with [debugPrint]. Each
/// component comes in with an [AIUIEntrance], so placed in an [AIUIView]
/// it animates as the reply's UI does.
///
/// Internal to the package.
@internal
class OpenUIView extends StatelessWidget {
  /// Creates the view of [runtime]'s program.
  ///
  /// The components are drawn with [theme] over the [OpenUITheme] around;
  /// what neither sets comes from the [StreamTheme] around.
  ///
  /// Media loads from the URL [mediaUrl] gives for it; only web links load
  /// unless it is given another function. A web or email link a person taps
  /// goes to [onOpenLink]; without it, no link opens.
  const OpenUIView({
    super.key,
    required this.runtime,
    required this.library,
    this.theme,
    this.mediaUrl = openUIWebMediaUrl,
    this.onOpenLink,
  });

  /// The runtime of the reply's program.
  final OpenUIRuntime runtime;

  /// The builders of the program's components.
  final OpenUILibrary library;

  /// The look of the components, over the [OpenUITheme] around, or `null`.
  final OpenUIThemeData? theme;

  /// The function the program's media is loaded through.
  final OpenUIMediaUrl mediaUrl;

  /// The function that opens the links a person taps, or `null`.
  final OpenUIOpenLink? onOpenLink;

  // The component types without a builder each runtime has reported.
  static final _unknownTypes = Expando<Set<String>>();

  /// How opaque the view is while a query is loading.
  static const loadingOpacity = 0.7;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUITheme.of(context).merge(this.theme);
    return OpenUITheme(
      data: theme,
      child: OpenUIStreamTheme(
        theme: theme,
        child: DefaultTextStyle.merge(
          style: theme.textStyles!.body!.copyWith(color: theme.colors!.textPrimary),
          child: IconTheme.merge(
            data: IconThemeData(color: theme.colors!.textPrimary),
            child: ValueListenableBuilder(
              valueListenable: runtime.root,
              builder: (context, root, _) {
                if (root == null) return const SizedBox.shrink();
                return OpenUIViewScope(
                  runtime: runtime,
                  library: library,
                  mediaUrl: mediaUrl,
                  openLink: onOpenLink,
                  isStreaming: runtime.isStreaming,
                  unknownTypes: _unknownTypes[runtime] ??= {},
                  child: _QueryLoading(
                    isLoading: runtime.isQueryLoading,
                    spacing: theme.spacing!.s!,
                    child: OpenUINodeView(node: root),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Dims [child] and shows a spinner at its top end while [isLoading] is true.
// Only the dim and the spinner build again when it changes.
class _QueryLoading extends StatelessWidget {
  const _QueryLoading({required this.isLoading, required this.spacing, required this.child});

  final ValueListenable<bool> isLoading;
  final double spacing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: isLoading,
      child: child,
      builder: (context, isLoading, child) {
        return Stack(
          children: [
            AnimatedOpacity(
              opacity: isLoading ? OpenUIView.loadingOpacity : 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: child,
            ),
            PositionedDirectional(
              top: spacing,
              end: spacing,
              child: Visibility(
                visible: isLoading,
                child: StreamLoadingSpinner(size: StreamLoadingSpinnerSize.xs),
              ),
            ),
          ],
        );
      },
    );
  }
}
