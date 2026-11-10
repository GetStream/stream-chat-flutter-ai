import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_fill.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// Builds a `Card`: its child on the surface color, with rounded corners,
/// across the width it is given. The child keeps its own size, at the card's
/// start.
///
/// Internal to the package.
@internal
Widget buildA2UICard(BuildContext context, A2UIComponentScope scope) {
  final theme = A2UISurfaceScope.of(context).theme;
  final child = scope.child();
  return A2UIFill(
    axis: Axis.horizontal,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.all(Radius.circular(theme.cornerRadius)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          heightFactor: 1,
          child: child == null ? null : scope.build(child),
        ),
      ),
    ),
  );
}

// The space between a card's edge and its child.
const _padding = 12.0;
