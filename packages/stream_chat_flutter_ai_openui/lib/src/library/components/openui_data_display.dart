import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_icon_map.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds an `Icon`: the icon its `name` (a Lucide icon name) and `category`
/// find, in the secondary text color.
///
/// It draws nothing when the design system has no icon for them. It reads as
/// its name, without numbers: `trash-2` as `trash`.
///
/// Internal to the package.
@internal
Widget buildOpenUIIcon(BuildContext context, OpenUIComponentScope scope) {
  final name = scope.string('name') ?? '';
  final icon = openUIIconOf(context.streamIcons, name, scope.string('category'));
  if (icon == null) return const SizedBox.shrink();
  final label = openUIIconLabel(name);
  // Aligned, so a parent that stretches its children doesn't stretch the icon.
  final widget = Align(
    alignment: AlignmentDirectional.centerStart,
    widthFactor: 1,
    child: Icon(icon, size: openUIScaled(context, 20), color: OpenUIViewScope.of(context).theme.secondaryText),
  );
  return label == null
      ? ExcludeSemantics(child: widget)
      : Semantics(
          label: label,
          image: true,
          child: ExcludeSemantics(child: widget),
        );
}

/// Builds a `Tag`: its `text` in a pill, with its `icon` before it, of the
/// color its `variant` names and the size its `size` names.
///
/// Internal to the package.
@internal
Widget buildOpenUITag(BuildContext context, OpenUIComponentScope scope) {
  // Aligned, so a parent that stretches its children doesn't stretch the pill.
  return Align(
    alignment: AlignmentDirectional.centerStart,
    widthFactor: 1,
    child: OpenUITagPill(
      text: scope.text('text') ?? '',
      icon: _iconOf(context, scope),
      size: scope.string('size'),
      variant: scope.string('variant'),
    ),
  );
}

/// Builds a `TagBlock`: its `tags` as neutral pills of its `size`, wrapping
/// onto new lines.
///
/// Internal to the package.
@internal
Widget buildOpenUITagBlock(BuildContext context, OpenUIComponentScope scope) {
  final gap = OpenUIViewScope.of(context).theme.xsSpacing + 2;
  final size = scope.string('size');
  return SizedBox(
    width: double.infinity,
    child: Wrap(
      spacing: gap,
      runSpacing: gap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [for (final tag in scope.stringList('tags')) OpenUITagPill(text: tag, size: size)],
    ),
  );
}

/// Builds an `EntityList`: its `rows` as a left and a right text, with lines
/// between them, under its `header` and above its `footer`.
///
/// With the `size` `small` it has less space around the rows, and draws no
/// `header` or `footer`. A `rightVariant` of `number` gives the right text
/// digits of one width.
///
/// Internal to the package.
@internal
Widget buildOpenUIEntityList(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUIViewScope.of(context).theme;
  final small = scope.string('size') == 'small';
  final rows = [
    for (final row in openUIJsonList(scope.value('rows')))
      if (row is Map<String, Object?>) row,
  ];
  final header = scope.value('header');
  final footer = scope.value('footer');
  final border = theme.border;
  Widget line(double alpha) => SizedBox(
    height: 1,
    child: ColoredBox(color: border.withValues(alpha: alpha)),
  );
  return SizedBox(
    width: double.infinity,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!small && header is Map<String, Object?>) ...[
          _EntityRow(row: header, small: small, emphasized: true),
          line(1),
        ],
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) line(0.6),
          _EntityRow(row: row, small: small),
        ],
        if (!small && footer is Map<String, Object?>) ...[
          line(1),
          _EntityRow(row: footer, small: small, emphasized: true),
        ],
      ],
    ),
  );
}

class _EntityRow extends StatelessWidget {
  const _EntityRow({required this.row, required this.small, this.emphasized = false});

  final Map<String, Object?> row;
  final bool small;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    final base = small ? theme.caption : theme.bodySmall;
    final left = base.copyWith(
      fontWeight: emphasized ? FontWeight.w600 : base.fontWeight,
      color: emphasized ? theme.text : theme.secondaryText,
    );
    final right = base.copyWith(
      fontWeight: emphasized || !small ? FontWeight.w600 : FontWeight.w500,
      color: theme.text,
      fontFeatures: row['rightVariant'] == 'number' ? const [FontFeature.tabularFigures()] : null,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: small ? 5 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(child: Text(openUIJsonText(row['left']), style: left)),
          SizedBox(width: theme.mSpacing + theme.sSpacing),
          Flexible(
            child: Text(openUIJsonText(row['right']), textAlign: TextAlign.end, style: right),
          ),
        ],
      ),
    );
  }
}

// The icon of the `Icon` component in the prop `icon`, or `null`.
IconData? _iconOf(BuildContext context, OpenUIComponentScope scope) {
  final icon = scope.elements('icon').firstOrNull;
  if (icon == null) return null;
  final iconScope = scope.scopeOf(icon);
  return openUIIconOf(context.streamIcons, iconScope.string('name') ?? '', iconScope.string('category'));
}
