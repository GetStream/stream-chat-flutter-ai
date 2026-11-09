import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_flex.dart';

/// Builds a `List`: its children one below the other, or side by side in a
/// row that scrolls for the `horizontal` direction, with `align` placing
/// them across.
///
/// A vertical list grows with its children and doesn't scroll; the
/// conversation around it does.
///
/// Internal to the package.
@internal
Widget buildA2UIList(BuildContext context, A2UIComponentScope scope) {
  final isHorizontal = scope.hint('direction') == 'horizontal';
  final children = [
    for (final child in scope.children())
      A2UIFlexChild(
        key: ValueKey(child.key),
        weight: null,
        fillsHeight: isHorizontal && a2uiFillsHeight(child),
        child: scope.build(child),
      ),
  ];
  final list = A2UIFlex(
    axis: isHorizontal ? Axis.horizontal : Axis.vertical,
    justify: null,
    align: scope.hint('align'),
    children: children,
  );
  if (!isHorizontal) return list;
  return SingleChildScrollView(scrollDirection: Axis.horizontal, child: list);
}
