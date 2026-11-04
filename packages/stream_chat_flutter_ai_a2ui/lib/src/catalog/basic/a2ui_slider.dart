import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_input.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// Builds a `Slider`: its `label` and current `value` over a slider from
/// `min` to `max` that writes the value the person picks, in `steps` equal
/// divisions when it has them.
///
/// A `min` that isn't a number is 0, and a `max` that isn't above it is one
/// more than it. A value outside the range shows at the nearer end. When the
/// value isn't there yet, the slider writes `min` once it shows, so what the
/// person sees is what an action sends.
///
/// Internal to the package.
@internal
Widget buildA2UISlider(BuildContext context, A2UIComponentScope scope) => _A2UISlider(scope: scope);

/// The range a `Slider` with [minimum] and [maximum] covers: from [minimum],
/// or 0 when it is `null`, to [maximum], or one more than the start when
/// [maximum] is `null` or not above it. Both ends are kept within ±10¹⁵, so
/// the range stays one a slider can draw.
///
/// Internal to the package.
@internal
({double min, double max}) a2uiSliderRange(double? minimum, double? maximum) {
  final min = (minimum ?? 0.0).clamp(-_maxMagnitude, _maxMagnitude);
  final upper = maximum?.clamp(-_maxMagnitude, _maxMagnitude);
  return (min: min, max: upper != null && upper > min ? upper : min + 1.0);
}

class _A2UISlider extends StatefulWidget {
  const _A2UISlider({required this.scope});

  final A2UIComponentScope scope;

  @override
  State<_A2UISlider> createState() => _A2UISliderState();
}

class _A2UISliderState extends State<_A2UISlider> {
  @override
  void initState() {
    super.initState();
    _writeShownValueIfMissing();
  }

  @override
  void didUpdateWidget(_A2UISlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _writeShownValueIfMissing();
  }

  // Writes the value the slider shows when there is none, after this frame:
  // the data model can't change while the surface builds.
  void _writeShownValueIfMissing() {
    if (widget.scope.number('value') != null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.scope.number('value') != null) return;
      widget.scope.write('value', _json(_range.min));
    });
  }

  ({double min, double max}) get _range => a2uiSliderRange(widget.scope.number('min'), widget.scope.number('max'));

  // [value] as JSON writes it: a whole number without a fraction. The range
  // keeps it within [_maxMagnitude], where a double holds whole numbers
  // exactly.
  static num _json(double value) => value == value.roundToDouble() ? value.round() : value;

  // The value of the division [picked] is at, computed from the ends so a
  // division of whole ends is a whole number, or [picked] itself without
  // divisions.
  static double _snapped(double picked, ({double min, double max}) range, int? divisions) {
    if (divisions == null) return picked;
    final index = ((picked - range.min) / (range.max - range.min) * divisions).round();
    return (range.min * (divisions - index) + range.max * index) / divisions;
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    final theme = A2UISurfaceScope.of(context).theme;
    final range = _range;
    final value = (scope.number('value') ?? range.min).clamp(range.min, range.max);
    final steps = scope.number('steps');
    final divisions = steps != null && steps >= 1 ? steps.round() : null;
    final label = scope.string('label') ?? '';
    final accessibility = a2uiAccessibilityOf(scope);
    final labelStyle = theme.label.copyWith(color: theme.secondaryText);
    return A2UIInputWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Row(
              spacing: _headerSpacing,
              children: [
                Expanded(child: Text(label, style: labelStyle)),
                Text(
                  a2uiText(_json(value)) ?? '',
                  style: labelStyle.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: theme.accent,
                inactiveTrackColor: theme.border,
                thumbColor: theme.accent,
                overlayColor: theme.accent.withValues(alpha: _overlayOpacity),
                activeTickMarkColor: theme.onAccent,
                inactiveTickMarkColor: theme.secondaryText,
                showValueIndicator: ShowValueIndicator.never,
                // The track lines up with the label above it; the thumb's own
                // half stays inside at each end.
                padding: const EdgeInsets.symmetric(horizontal: _thumbRadius),
              ),
              child: MergeSemantics(
                child: Semantics(
                  label: accessibility.label ?? label,
                  hint: accessibility.description,
                  child: Slider(
                    value: value,
                    min: range.min,
                    max: range.max,
                    divisions: divisions,
                    semanticFormatterCallback: (value) => a2uiText(_json(value)) ?? '',
                    onChanged: (picked) => scope.write('value', _json(_snapped(picked, range, divisions))),
                  ),
                ),
              ),
            ),
          ),
          A2UIValidationMessages(failures: a2uiCheckFailuresOf(scope), theme: theme),
        ],
      ),
    );
  }
}

// The largest magnitude of either end of a slider's range, which keeps the
// range one a slider can draw.
const _maxMagnitude = 1e15;

// The space between the label and the value above the slider.
const _headerSpacing = 8.0;

// Half the width of the slider's thumb.
const _thumbRadius = 10.0;

// How strongly the ring around the thumb shows the accent color while the
// thumb is held.
const _overlayOpacity = 0.12;
