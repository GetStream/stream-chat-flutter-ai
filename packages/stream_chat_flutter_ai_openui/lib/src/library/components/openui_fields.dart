import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/components/openui_form.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_actions.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_pickers.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_strings.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// The state of the field [scope] draws, of the type [componentType]: bound
/// to the `$variable` its `value` names, or kept under its `name` in the form
/// it is in.
///
/// Internal to the package.
@internal
StateField openUIFieldState(
  BuildContext context,
  OpenUIComponentScope scope,
  String componentType, {
  bool isSecret = false,
}) {
  return OpenUIViewScope.of(context).runtime.stateField(
    scope.text('name') ?? '',
    binding: scope.prop('value'),
    formName: OpenUIFormScope.maybeOf(context)?.formName,
    componentType: componentType,
    isSecret: isSecret,
  );
}

/// Keeps [value] as the field [name]'s value, of the type [componentType], in
/// the form [context] is in, unless it already has one.
///
/// Internal to the package.
@internal
void saveOpenUIDefault(BuildContext context, String name, String componentType, OpenUIValue? value) {
  if (value == null) return;
  final runtime = OpenUIViewScope.of(context).runtime;
  final formName = context.getInheritedWidgetOfExactType<OpenUIFormScope>()?.formName;
  if (runtime.isStreaming || runtime.fieldValue(formName, name) != null) return;
  runtime.setFieldValue(formName, name, value, componentType: componentType);
}

/// Checks the field [scope] draws now, when it is in a form and has rules.
///
/// Internal to the package.
@internal
void validateOpenUIField(BuildContext context, OpenUIComponentScope scope) {
  final rules = scope.prop('rules');
  if (rules == null || rules is OpenUINull) return;
  // A password is never bound, so it is checked with what was typed.
  final password = scope.type == 'Input' && scope.string('type') == 'password';
  context.getInheritedWidgetOfExactType<OpenUIFormScope>()?.validation.validateField(
    scope.text('name') ?? '',
    rules,
    password ? null : scope.prop('value'),
  );
}

// Keeps the field's own `value`, when it is one and not a `$variable`, as
// its value, so the form checks and sends what the field shows.
void _saveLiteral(BuildContext context, OpenUIComponentScope scope, String componentType) {
  final value = scope.prop('value');
  if (value == null || value is OpenUINull || ReactiveBinding.targetOf(value) != null) return;
  saveOpenUIDefault(context, scope.text('name') ?? '', componentType, value);
}

/// The box a field's value shows in: a sunken surface, outlined in the danger
/// color when the field has an error.
///
/// Internal to the package.
@internal
class OpenUIFieldChrome extends StatelessWidget {
  /// Creates the box around [child].
  const OpenUIFieldChrome({super.key, required this.hasError, required this.child});

  /// Whether the field has an error.
  final bool hasError;

  /// The field's value.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUITheme.of(context);
    final colors = theme.colors!;
    return Container(
      constraints: BoxConstraints(minHeight: openUIScaled(context, 40)),
      padding: EdgeInsets.symmetric(horizontal: theme.spacing!.m!, vertical: 10),
      decoration: BoxDecoration(
        color: colors.sunkenSurface,
        borderRadius: BorderRadius.circular(theme.radius!.small!),
        border: Border.all(color: hasError ? colors.danger! : const Color(0x00000000), width: 1.5),
      ),
      child: child,
    );
  }
}

String? _errorOf(BuildContext context, OpenUIComponentScope scope) =>
    OpenUIFormScope.maybeOf(context)?.validation.errorOf(scope.text('name') ?? '');

/// Builds an `Input`: a one-line text field with its `placeholder`, of the
/// `type` `text`, `email`, `url`, `number` or `password`.
///
/// It shows and writes the field's value (see the `Form`), checks its
/// `rules` when it loses focus and hides its error while it is edited. A
/// password is obscured and kept out of what an action sends. It can't be
/// edited while the reply streams.
///
/// Internal to the package.
@internal
Widget buildOpenUIInput(BuildContext context, OpenUIComponentScope scope) =>
    _OpenUITextField(scope: scope, multiline: false);

/// Builds a `TextArea`: a text field of at least `rows` lines (2 to 100, 3 by
/// default) with its `placeholder`, which works as an `Input` does.
///
/// Internal to the package.
@internal
Widget buildOpenUITextArea(BuildContext context, OpenUIComponentScope scope) =>
    _OpenUITextField(scope: scope, multiline: true);

class _OpenUITextField extends StatefulWidget {
  const _OpenUITextField({required this.scope, required this.multiline});

  final OpenUIComponentScope scope;
  final bool multiline;

  @override
  State<_OpenUITextField> createState() => _OpenUITextFieldState();
}

class _OpenUITextFieldState extends State<_OpenUITextField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _syncScheduled = false;

  bool get _isPassword => !widget.multiline && widget.scope.string('type') == 'password';

  String get _name => widget.scope.text('name') ?? '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (!mounted) return;
    final validation = context.getInheritedWidgetOfExactType<OpenUIFormScope>()?.validation;
    if (_focus.hasFocus) {
      validation?.clearError(_name);
    } else {
      validateOpenUIField(context, widget.scope);
    }
  }

  StateField _field(BuildContext context) =>
      openUIFieldState(context, widget.scope, widget.multiline ? 'TextArea' : 'Input', isSecret: _isPassword);

  // Shows [text], the field's value, once this frame is built, unless it
  // shows it already.
  void _show(String text) {
    if (_controller.text == text || _syncScheduled) return;
    _syncScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;
      final current = _field(context).value;
      final latest = JS.isNullish(current) ? '' : JS.stringOf(current);
      if (_controller.text != latest) {
        _controller.value = TextEditingValue(
          text: latest,
          selection: TextSelection.collapsed(offset: latest.length),
        );
      }
    });
  }

  void _changed(String text) {
    _field(context).set(OpenUIString(text));
    context.getInheritedWidgetOfExactType<OpenUIFormScope>()?.validation.clearError(_name);
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    final type = scope.string('type') ?? 'text';
    final placeholder = scope.text('placeholder');
    final enabled = !scope.isStreaming;
    final hasError = _errorOf(context, scope) != null;
    final plain = type == 'email' || type == 'url';
    final keyboard = widget.multiline
        ? TextInputType.multiline
        : switch (type) {
            'email' => TextInputType.emailAddress,
            'number' => const TextInputType.numberWithOptions(decimal: true, signed: true),
            'url' => TextInputType.url,
            _ => TextInputType.text,
          };
    final rows = switch (scope.number('rows')) {
      final rows? => rows.clamp(2, 100).toInt(),
      null => 3,
    };
    final componentType = widget.multiline ? 'TextArea' : 'Input';
    return OpenUIFieldHost(
      name: _name,
      rules: scope.prop('rules'),
      // A password is never bound, so it is checked with what was typed.
      binding: _isPassword ? null : scope.prop('value'),
      isStreaming: scope.isStreaming,
      saveDefault: _isPassword ? null : () => _saveLiteral(context, scope, componentType),
      child: scope.watchState((context) {
        final value = _field(context).value;
        _show(JS.isNullish(value) ? '' : JS.stringOf(value));
        if (_isPassword) return _password(context, placeholder, enabled, hasError);
        return StreamTextInput(
          controller: _controller,
          focusNode: _focus,
          enabled: enabled,
          hintText: placeholder,
          helperState: hasError ? StreamHelperState.error : null,
          keyboardType: keyboard,
          autocorrect: !plain,
          textCapitalization: plain ? TextCapitalization.none : TextCapitalization.sentences,
          minLines: widget.multiline ? rows : null,
          maxLines: widget.multiline ? null : 1,
          onChanged: _changed,
        );
      }),
    );
  }

  // Core's text input can't obscure what is typed, so a password is a text
  // field drawn with the theme's colors.
  Widget _password(BuildContext context, String? placeholder, bool enabled, bool hasError) {
    final theme = OpenUITheme.of(context);
    final colors = theme.colors!;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(theme.radius!.medium!),
      borderSide: BorderSide(color: color),
    );
    return Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        enabled: enabled,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        cursorColor: colors.accent,
        style: theme.textStyles!.body!.copyWith(color: colors.textPrimary),
        onChanged: _changed,
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: theme.textStyles!.body!.copyWith(color: colors.textTertiary),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: theme.spacing!.m!, vertical: theme.spacing!.s! + 2),
          enabledBorder: border(hasError ? colors.danger! : colors.border!),
          disabledBorder: border(colors.border!),
          focusedBorder: border(hasError ? colors.danger! : colors.accent!),
        ),
      ),
    );
  }
}

/// Builds a `Select`: the label of its chosen `items` option, or its
/// `placeholder`, that opens a sheet of the options to choose from; `size`
/// `small` draws it smaller.
///
/// An option without a `value` is left out, and one without a `label` shows
/// its value. Choosing an option writes its value and checks the field's
/// `rules`. It can't be changed while the reply streams.
///
/// Internal to the package.
@internal
Widget buildOpenUISelect(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUITheme.of(context);
  final colors = theme.colors!;
  final options = [
    for (final node in scope.elements('items'))
      if (scope.scopeOf(node) case final item)
        if (item.text('value') case final value? when value.isNotEmpty) (value, item.text('label') ?? value),
  ];
  final hasError = _errorOf(context, scope) != null;
  return OpenUIFieldHost(
    name: scope.text('name') ?? '',
    rules: scope.prop('rules'),
    binding: scope.prop('value'),
    isStreaming: scope.isStreaming,
    saveDefault: () => _saveLiteral(context, scope, 'Select'),
    child: scope.watchState((context) {
      final field = openUIFieldState(context, scope, 'Select');
      final selected = JS.isNullish(field.value) ? null : JS.stringOf(field.value);
      final label = options.where((option) => option.$1 == selected).firstOrNull?.$2;
      final style = scope.string('size') == 'small' ? theme.textStyles!.bodySmall! : theme.textStyles!.body!;
      return OpenUIPressable(
        onTap: scope.isStreaming
            ? null
            : () async {
                final value = await pickOpenUIOption(context, options: options, selected: selected);
                if (value == null || !context.mounted) return;
                openUIFieldState(context, scope, 'Select').set(OpenUIString(value));
                validateOpenUIField(context, scope);
              },
        child: OpenUIFieldChrome(
          hasError: hasError,
          child: Row(
            spacing: theme.spacing!.s!,
            children: [
              Expanded(
                child: Text(
                  label ?? scope.text('placeholder') ?? OpenUIStrings.selectPlaceholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(color: label == null ? colors.textTertiary : colors.textPrimary),
                ),
              ),
              ExcludeSemantics(
                child: Icon(
                  context.streamIcons.chevronDown,
                  size: openUIScaled(context, 16),
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }),
  );
}

/// Builds a `DatePicker`: a day the person picks, written `yyyy-MM-dd`, or
/// when its `mode` is `range` a `{from, to}` pair of days.
///
/// A range's end is never before its start: a start after the end moves the
/// end to it, and an end picked first sets the start too. Each pick checks
/// the field's `rules`. It can't be changed while the reply streams.
///
/// Internal to the package.
@internal
Widget buildOpenUIDatePicker(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUITheme.of(context);
  final colors = theme.colors!;
  final range = scope.string('mode') == 'range';
  final hasError = _errorOf(context, scope) != null;
  return OpenUIFieldHost(
    name: scope.text('name') ?? '',
    rules: scope.prop('rules'),
    binding: scope.prop('value'),
    isStreaming: scope.isStreaming,
    saveDefault: () => _saveLiteral(context, scope, 'DatePicker'),
    child: scope.watchState((context) {
      final value = openUIFieldState(context, scope, 'DatePicker').value;
      void write(OpenUIValue next) {
        openUIFieldState(context, scope, 'DatePicker').set(next);
        validateOpenUIField(context, scope);
      }

      Widget row(String title, DateTime? date, ValueChanged<DateTime> onPick, {DateTime? first}) {
        return OpenUIPressable(
          label: title,
          onTap: scope.isStreaming
              ? null
              : () async {
                  final picked = await pickOpenUIDate(context, initial: date ?? first, first: first);
                  if (picked != null && context.mounted) onPick(picked);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              spacing: theme.spacing!.s!,
              children: [
                Expanded(
                  child: Text(title, style: theme.textStyles!.bodySmall!.copyWith(color: colors.textSecondary)),
                ),
                Text(
                  date == null ? OpenUIStrings.chooseDate : openUIDateString(date),
                  style: theme.textStyles!.bodySmall!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: date == null ? colors.accent : colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final Widget content;
      if (range) {
        final fields = value is OpenUIObject ? value.fields : const <String, OpenUIValue>{};
        DateTime? dayOf(String key) => openUIParseDate(fields[key] is OpenUIString ? JS.stringOf(fields[key]) : null);
        final from = dayOf('from');
        final to = dayOf('to');
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.spacing!.s!,
          children: [
            row(OpenUIStrings.dateFrom, from, (date) {
              write(
                OpenUIObject({
                  ...fields,
                  'from': OpenUIString(openUIDateString(date)),
                  if (to != null && to.isBefore(date)) 'to': OpenUIString(openUIDateString(date)),
                }),
              );
            }),
            row(OpenUIStrings.dateTo, to, first: from, (date) {
              write(
                OpenUIObject({
                  ...fields,
                  'to': OpenUIString(openUIDateString(date)),
                  if (from == null) 'from': OpenUIString(openUIDateString(date)),
                }),
              );
            }),
          ],
        );
      } else {
        final date = openUIParseDate(value is OpenUIString ? value.value : null);
        content = row(OpenUIStrings.date, date, (date) => write(OpenUIString(openUIDateString(date))));
      }
      return OpenUIFieldChrome(hasError: hasError, child: content);
    }),
  );
}

/// Builds a `Slider`: a number from `min` (0 by default) to `max` (100 by
/// default, at least `min` + 1), or a range of two when its value or
/// `defaultValue` holds two, with its `label` and the value shown above.
///
/// Values snap to `step`, or to whole numbers when its `variant` is
/// `discrete`, and are kept as a list, rounded to three decimals, when a drag
/// ends; each change checks the field's `rules`. Once the reply ends, the
/// `defaultValue` (or `min`) is kept as the field's value when it has none.
/// It can't be moved while the reply streams.
///
/// Internal to the package.
@internal
Widget buildOpenUISlider(BuildContext context, OpenUIComponentScope scope) => _OpenUISlider(scope: scope);

/// The bounds a slider's [minimum] and [maximum] give.
///
/// Internal to the package.
@internal
({double lower, double upper}) openUISliderBounds(double? minimum, double? maximum) {
  const limit = 1e15;
  double? bounded(double? value) => value != null && value.isFinite ? value.clamp(-limit, limit) : null;
  final lower = bounded(minimum) ?? 0;
  return (lower: lower, upper: math.max(bounded(maximum) ?? 100, lower + 1));
}

/// The step a slider's values snap to, or `null` for none.
///
/// Internal to the package.
@internal
double? openUISliderStep(double? step, {required bool discrete, required double span}) {
  if (step != null && step.isFinite && step > 0) return step <= span ? step : null;
  return discrete && span >= 1 ? 1 : null;
}

/// The values [value], a slider's state, holds within [lower] and [upper]:
/// one, or two in order; [lower] when it holds none.
///
/// Internal to the package.
@internal
List<double> openUISliderValues(OpenUIValue? value, double lower, double upper) {
  final numbers = switch (value) {
    OpenUINumber(:final value) => [value],
    OpenUIString() => [JS.toNumber(value)],
    OpenUIArray(:final items) => [for (final item in items.take(2)) JS.toNumber(item)],
    _ => const <double>[],
  }.where((number) => number.isFinite).map((number) => number.clamp(lower, upper)).toList();
  if (numbers.isEmpty) return [lower];
  if (numbers.length == 2 && numbers[0] > numbers[1]) return [numbers[1], numbers[0]];
  return numbers;
}

class _OpenUISlider extends StatefulWidget {
  const _OpenUISlider({required this.scope});

  final OpenUIComponentScope scope;

  @override
  State<_OpenUISlider> createState() => _OpenUISliderState();
}

class _OpenUISliderState extends State<_OpenUISlider> {
  List<double>? _draft;

  static OpenUIValue _stored(List<double> values) =>
      OpenUIArray([for (final value in values) OpenUINumber((value * 1000).roundToDouble() / 1000)]);

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    final theme = OpenUITheme.of(context);
    final colors = theme.colors!;
    final styles = theme.textStyles!;
    final bounds = openUISliderBounds(scope.number('min'), scope.number('max'));
    final step = openUISliderStep(
      scope.number('step'),
      discrete: scope.string('variant') == 'discrete',
      span: bounds.upper - bounds.lower,
    );
    final name = scope.text('name') ?? '';
    final label = scope.text('label') ?? name;
    final steps = step == null ? null : (bounds.upper - bounds.lower) / step;
    final divisions = steps != null && steps <= 1000 && (steps - steps.roundToDouble()).abs() < 1e-9
        ? steps.round()
        : null;
    return scope.watchState((context) {
      final field = openUIFieldState(context, scope, 'Slider');
      final stored = openUISliderValues(
        JS.isNullish(field.value) ? scope.prop('defaultValue') : field.value,
        bounds.lower,
        bounds.upper,
      );
      final values = _draft ?? stored;
      void commit(List<double> next) {
        setState(() => _draft = null);
        openUIFieldState(context, scope, 'Slider').set(_stored(next));
        validateOpenUIField(context, scope);
      }

      Widget thumb(int index) {
        double snap(double value) {
          if (step == null) return value;
          final snapped = bounds.lower + ((value - bounds.lower) / step).roundToDouble() * step;
          return snapped.clamp(bounds.lower, bounds.upper);
        }

        List<double> setting(double value) {
          final next = [...values];
          if (next.length == 2) {
            next[index] = index == 0 ? math.min(value, next[1]) : math.max(value, next[0]);
          } else {
            next[index] = value;
          }
          return next;
        }

        final thumbLabel = values.length == 2
            ? (index == 0 ? OpenUIStrings.sliderLower(label) : OpenUIStrings.sliderUpper(label))
            : label;
        return Semantics(
          container: true,
          label: thumbLabel,
          child: Slider(
            value: values[index],
            min: bounds.lower,
            max: bounds.upper,
            // Steps that fit the range a whole number of times, and at most
            // 1000, are the slider's divisions, so the keyboard and assistive
            // technologies move by one step.
            divisions: divisions,
            onChanged: scope.isStreaming ? null : (value) => setState(() => _draft = setting(snap(value))),
            onChangeEnd: scope.isStreaming ? null : (value) => commit(setting(snap(value))),
            semanticFormatterCallback: (value) => JS.numberToString(snap(value)),
          ),
        );
      }

      Text number(double value, TextStyle style) =>
          Text(JS.numberToString(value), style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]));
      return OpenUIFieldHost(
        name: name,
        rules: scope.prop('rules'),
        binding: scope.prop('value'),
        isStreaming: scope.isStreaming,
        saveDefault: field.isBound ? null : () => saveOpenUIDefault(context, name, 'Slider', _stored(stored)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.spacing!.xs!,
          children: [
            ExcludeSemantics(
              child: Row(
                spacing: theme.spacing!.s!,
                children: [
                  Expanded(
                    child: Text(label, style: styles.bodySmall!.copyWith(color: colors.textSecondary)),
                  ),
                  Text(
                    values.map(JS.numberToString).join(' – '),
                    style: styles.bodySmall!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: colors.accent,
                  inactiveTrackColor: colors.border,
                  thumbColor: colors.accent,
                  overlayColor: colors.accent!.withValues(alpha: 0.12),
                  disabledActiveTrackColor: colors.textTertiary,
                  disabledInactiveTrackColor: colors.border,
                  disabledThumbColor: colors.textTertiary,
                ),
                child: Column(children: [for (var index = 0; index < values.length; index++) thumb(index)]),
              ),
            ),
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  number(bounds.lower, styles.caption!.copyWith(color: colors.textTertiary)),
                  number(bounds.upper, styles.caption!.copyWith(color: colors.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
