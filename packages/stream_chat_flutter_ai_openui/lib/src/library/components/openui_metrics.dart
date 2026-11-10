import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_strings.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `MetricIndicatorInline`: its `value` in the metric style, with its
/// `subtext` below and its `trend` beside it.
///
/// A `value` too wide for the space scales down to fit.
///
/// Internal to the package.
@internal
Widget buildOpenUIMetricIndicatorInline(BuildContext context, OpenUIComponentScope scope) {
  return _metric(context, scope, previous: false);
}

/// Builds a `MetricIndicatorWithStrikethrough`: a `MetricIndicatorInline`
/// whose `previousValue` follows the value, struck through.
///
/// Internal to the package.
@internal
Widget buildOpenUIMetricIndicatorWithStrikethrough(BuildContext context, OpenUIComponentScope scope) {
  return _metric(context, scope, previous: true);
}

Widget _metric(BuildContext context, OpenUIComponentScope scope, {required bool previous}) {
  final theme = OpenUIViewScope.of(context).theme;
  final value = Text(scope.text('value') ?? '', style: theme.metric.copyWith(color: theme.text));
  final previousValue = previous ? scope.text('previousValue') ?? '' : '';
  final subtext = scope.text('subtext') ?? '';
  final trend = _TrendBadge.of(scope.value('trend'));
  return Row(
    mainAxisSize: MainAxisSize.min,
    spacing: theme.sSpacing,
    children: [
      Flexible(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: theme.sSpacing,
              children: [
                Flexible(
                  child: previous
                      ? value
                      : FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: value),
                ),
                if (previousValue.isNotEmpty)
                  Text(
                    previousValue,
                    style: theme.bodySmall.copyWith(
                      color: theme.tertiaryText,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
            if (subtext.isNotEmpty) Text(subtext, style: theme.caption.copyWith(color: theme.secondaryText)),
          ],
        ),
      ),
      ?trend,
    ],
  );
}

/// The change a metric shows: an arrow and a percentage, green for up and red
/// for any other direction.
class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.up, required this.value});

  /// The badge of [trend], a `{direction, value}` object, or `null` when it
  /// has no direction.
  static Widget? of(Object? trend) {
    if (trend is! Map<String, Object?> || trend['direction'] is! String) return null;
    final raw = trend['value'];
    final number = switch (raw) {
      num() => raw.toDouble(),
      String() => double.tryParse(raw.trim()) ?? 0.0,
      _ => 0.0,
    };
    return _TrendBadge(up: trend['direction'] == 'up', value: number.isFinite ? number.abs() : 0);
  }

  final bool up;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    final color = up ? theme.success : theme.error;
    final number = value == value.truncateToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
    final icons = context.streamIcons;
    return Semantics(
      container: true,
      label: up ? OpenUIStrings.trendUp(number) : OpenUIStrings.trendDown(number),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(theme.pillCornerRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              Transform.flip(
                flipY: !up,
                child: Icon(icons.arrowUpRight, size: openUIScaled(context, 12), color: color),
              ),
              Text(
                '$number%',
                style: theme.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
