import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_actions.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_grid.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';

/// Builds a `Stack`: its `children` in a column, or a row when its
/// `direction` is `row`, `gap` apart, aligned by its `align` and `justify`; a
/// row that may `wrap` goes on to more lines.
///
/// Children that are all cards, stacks, forms, tables, callouts or Markdown
/// share a row's width equally, and in a wrapping row make a grid of equal
/// columns. A wrapping row justified `between` starts its lines at the start.
///
/// Internal to the package.
@internal
Widget buildOpenUIStack(BuildContext context, OpenUIComponentScope scope) {
  final nodes = scope.elements('children');
  final wrap = scope.boolean('wrap') ?? false;
  final justify = scope.string('justify');
  return _OpenUIFlex(
    scope: scope,
    nodes: nodes,
    justify: wrap && justify == 'between' ? 'start' : justify,
    flexible: nodes.isNotEmpty && nodes.every((node) => _flexibleTypes.contains(node.typeName)),
  );
}

/// Builds the standard library's `Card`: its `children` laid out as a
/// `Stack` lays out its own, in a column by default, on the surface its
/// `variant` names: `card` (the default), `sunk` or `clear`.
///
/// Its children always share a row's width equally.
///
/// Internal to the package.
@internal
Widget buildOpenUIStandardCard(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUIViewScope.of(context).theme;
  final colors = theme;
  final spacing = theme.lSpacing;
  final content = _OpenUIFlex(
    scope: scope,
    nodes: scope.elements('children'),
    justify: scope.string('justify'),
    flexible: true,
  );
  final decoration = switch (scope.string('variant')) {
    'clear' => null,
    'sunk' => BoxDecoration(
      color: colors.sunkenSurface,
      borderRadius: BorderRadius.circular(theme.mediumCornerRadius),
    ),
    _ => BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(theme.cornerRadius),
      border: Border.all(color: colors.border.withValues(alpha: colors.border.a * 0.6), width: 0.5),
    ),
  };
  if (decoration == null) return content;
  return DecoratedBox(
    decoration: decoration,
    child: Padding(padding: EdgeInsets.all(spacing), child: content),
  );
}

// The types whose components share a stack's row equally.
const _flexibleTypes = {'Card', 'Stack', 'MarkDownRenderer', 'Callout', 'TextCallout', 'Form', 'Table'};

class _OpenUIFlex extends StatelessWidget {
  const _OpenUIFlex({required this.scope, required this.nodes, required this.justify, required this.flexible});

  final OpenUIComponentScope scope;
  final List<ElementNode> nodes;
  final String? justify;
  final bool flexible;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    final gap = openUIGap(theme, scope.value('gap'));
    final align = scope.string('align');
    final children = openUIChildWidgets(context, scope, nodes);
    if (children.isEmpty) return const SizedBox.shrink();
    if (scope.string('direction') != 'row') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: switch (align) {
          'start' => CrossAxisAlignment.start,
          'center' => CrossAxisAlignment.center,
          'end' => CrossAxisAlignment.end,
          _ => CrossAxisAlignment.stretch,
        },
        spacing: gap,
        children: children,
      );
    }
    if (scope.boolean('wrap') ?? false) {
      if (flexible) {
        return OpenUIResponsiveGrid(
          minItemWidth: children.length > 2 ? 140 : 160,
          maxColumns: 4,
          spacing: gap,
          children: children,
        );
      }
      return SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          alignment: switch (justify) {
            'center' => WrapAlignment.center,
            'end' => WrapAlignment.end,
            _ => WrapAlignment.start,
          },
          children: children,
        ),
      );
    }
    final shares = flexible && (justify == null || justify == 'start');
    return Row(
      mainAxisAlignment: switch (justify) {
        'center' => MainAxisAlignment.center,
        'end' => MainAxisAlignment.end,
        'between' => MainAxisAlignment.spaceBetween,
        'around' => MainAxisAlignment.spaceAround,
        'evenly' => MainAxisAlignment.spaceEvenly,
        _ => MainAxisAlignment.start,
      },
      crossAxisAlignment: switch (align) {
        'start' => CrossAxisAlignment.start,
        'end' => CrossAxisAlignment.end,
        'baseline' => CrossAxisAlignment.baseline,
        _ => CrossAxisAlignment.center,
      },
      textBaseline: TextBaseline.alphabetic,
      spacing: gap,
      // A child as wide as it is given, such as a card, gets its share of the
      // row rather than all of it.
      children: [
        for (final child in children)
          if (shares) Expanded(child: child) else Flexible(child: child),
      ],
    );
  }
}
