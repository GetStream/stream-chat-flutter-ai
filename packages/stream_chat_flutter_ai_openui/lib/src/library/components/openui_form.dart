import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_actions.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `Form`: its `fields` and then its `buttons`, the fields' values
/// kept under its `name`.
///
/// A primary button in it checks the fields' `rules` before its action runs,
/// and shows the errors of those that fail.
///
/// Internal to the package.
@internal
Widget buildOpenUIForm(BuildContext context, OpenUIComponentScope scope) => _OpenUIForm(scope: scope);

class _OpenUIForm extends StatefulWidget {
  const _OpenUIForm({required this.scope});

  final OpenUIComponentScope scope;

  @override
  State<_OpenUIForm> createState() => _OpenUIFormState();
}

class _OpenUIFormState extends State<_OpenUIForm> {
  OpenUIFormValidation? _validation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = OpenUIViewScope.of(context).runtime;
    (_validation ??= OpenUIFormValidation(runtime, widget.scope.text('name'))).runtime = runtime;
  }

  @override
  void didUpdateWidget(_OpenUIForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validation!.formName = widget.scope.text('name');
  }

  @override
  void dispose() {
    _validation!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = OpenUITheme.of(context);
    return OpenUIFormScope(
      validation: _validation!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.lSpacing!,
        children: [widget.scope.buildProp('fields'), widget.scope.buildProp('buttons')],
      ),
    );
  }
}

/// Builds a `FormControl`: its `label`, marked `*` when its `input` is
/// required, the `input`, and under it the input's error or, without one,
/// the control's `hint`.
///
/// Internal to the package.
@internal
Widget buildOpenUIFormControl(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUITheme.of(context);
  final colors = theme;
  final input = scope.elements('input').firstOrNull;
  final name = input == null ? null : scope.scopeOf(input).text('name');
  final error = name == null ? null : OpenUIFormScope.maybeOf(context)?.validation.errorOf(name);
  final hint = scope.text('hint') ?? '';
  final label = theme.bodySmall!.copyWith(fontWeight: FontWeight.w500);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: theme.sSpacing!,
    children: [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: scope.text('label') ?? '',
              style: label.copyWith(color: colors.text),
            ),
            if (input != null && openUIIsRequired(input.props['rules']))
              TextSpan(
                text: ' *',
                style: label.copyWith(color: colors.error),
              ),
          ],
        ),
      ),
      scope.buildProp('input'),
      if (error != null)
        Semantics(
          liveRegion: true,
          child: StreamHelperText(text: error, state: StreamHelperState.error),
        )
      else if (hint.isNotEmpty)
        Text(hint, style: theme.caption!.copyWith(color: colors.secondaryText)),
    ],
  );
}

/// Whether [rules], a field's `rules` prop, make it required.
///
/// Internal to the package.
@internal
bool openUIIsRequired(OpenUIValue? rules) {
  return switch (rules) {
    OpenUIObject(:final fields) => fields['required'] == const OpenUIBool(true),
    OpenUIArray(:final items) => items.contains(const OpenUIString('required')),
    _ => false,
  };
}

/// [child], a form field named [name], checked with [rules] by the form it is
/// in while it shows and the reply isn't streaming.
///
/// Once the reply isn't streaming, [saveDefault] runs after the frame, to
/// keep the value the field shows by default.
///
/// Internal to the package.
@internal
class OpenUIFieldHost extends StatefulWidget {
  /// Creates the host of the field [name].
  const OpenUIFieldHost({
    super.key,
    required this.name,
    required this.rules,
    required this.binding,
    required this.isStreaming,
    required this.child,
    this.saveDefault,
  });

  /// The field's name.
  final String name;

  /// The field's `rules` prop.
  final OpenUIValue? rules;

  /// The field's `value` prop, which may bind it to a `$variable`.
  final OpenUIValue? binding;

  /// Whether the reply is still streaming.
  final bool isStreaming;

  /// Keeps the value the field shows by default, or `null` when it has none.
  final VoidCallback? saveDefault;

  /// The field.
  final Widget child;

  @override
  State<OpenUIFieldHost> createState() => _OpenUIFieldHostState();
}

class _OpenUIFieldHostState extends State<OpenUIFieldHost> {
  OpenUIFormValidation? _validation;
  String? _registered;

  @override
  void initState() {
    super.initState();
    if (!widget.isStreaming) _scheduleDefault();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(OpenUIFieldHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
    if (oldWidget.isStreaming && !widget.isStreaming) _scheduleDefault();
  }

  @override
  void dispose() {
    if (_registered case final name?) _validation?.unregister(name, this);
    super.dispose();
  }

  void _register() {
    final validation = context.getInheritedWidgetOfExactType<OpenUIFormScope>()?.validation;
    if (_registered case final name?) _validation?.unregister(name, this);
    _registered = null;
    _validation = validation;
    final rules = widget.rules;
    if (validation == null || widget.isStreaming || rules == null || rules is OpenUINull) return;
    validation.register(widget.name, rules, widget.binding, this);
    _registered = widget.name;
  }

  void _scheduleDefault() {
    if (widget.saveDefault == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.isStreaming) widget.saveDefault?.call();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
