import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_fill.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// Builds a `Divider`: a line in the border color across the width it is
/// given, or, for the `vertical` axis, down the height it is given, such as
/// the height of the row around it.
///
/// Internal to the package.
@internal
Widget buildA2UIDivider(BuildContext context, A2UIComponentScope scope) {
  final color = A2UISurfaceScope.of(context).theme.border;
  final line = ColoredBox(color: color);
  if (scope.string('axis') == 'vertical') {
    return A2UIFill(
      axis: Axis.vertical,
      child: SizedBox(width: _thickness, child: line),
    );
  }
  return A2UIFill(
    axis: Axis.horizontal,
    child: SizedBox(height: _thickness, child: line),
  );
}

// How thick a divider's line is.
const _thickness = 1.0;
