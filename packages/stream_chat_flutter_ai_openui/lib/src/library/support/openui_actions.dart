import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_resolved_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';

/// Runs [action], the action of the control labelled [label] that [scope]
/// draws, unless the reply is still streaming.
///
/// The action runs in the form the control is in, if any, unless [inForm] is
/// `false`.
///
/// Internal to the package.
@internal
void triggerOpenUIAction(
  BuildContext context,
  OpenUIComponentScope scope, {
  required String label,
  OpenUIValue? action,
  bool inForm = true,
}) {
  if (scope.isStreaming) return;
  final runtime = OpenUIViewScope.of(context).runtime;
  final formName = inForm ? OpenUIFormScope.maybeOf(context)?.formName : null;
  unawaited(runtime.trigger(label: label, formName: formName, action: action));
}

/// The errors of the fields of one `Form`, and the rules they are checked
/// with.
///
/// A field registers its rules while it shows and the reply isn't streaming,
/// and its error shows under it once it is checked.
///
/// Internal to the package.
@internal
class OpenUIFormValidation extends ChangeNotifier {
  /// Creates the validation of the form [formName] of [runtime].
  OpenUIFormValidation(this.runtime, this.formName);

  /// The runtime the form's state is in.
  OpenUIRuntime runtime;

  /// The form's name, or `null` for a form without one.
  String? formName;

  final _fields = <String, (OpenUIValue?, OpenUIValue?, Object)>{};
  Map<String, String> _errors = const {};

  /// The error of the field [name], or `null` when it has none.
  String? errorOf(String name) => _errors[name];

  /// Checks the field [name] with [rules] when the form is checked; [binding]
  /// is its `value` prop, so a field bound to a `$variable` is checked with
  /// the variable's value. [owner] is what registers it.
  void register(String name, OpenUIValue? rules, OpenUIValue? binding, Object owner) {
    _fields[name] = (rules, binding, owner);
  }

  /// Stops checking the field [name], unless another [owner] registered it
  /// since, such as a field of the same name that replaced it.
  void unregister(String name, Object owner) {
    if (identical(_fields[name]?.$3, owner)) _fields.remove(name);
  }

  /// Checks the field [name] with [rules] now and shows its error; returns
  /// whether it passes.
  bool validateField(String name, OpenUIValue? rules, OpenUIValue? binding) {
    final error = runtime.validate(formName, {name: rules}, bindings: {name: binding})[name];
    _setErrors({..._errors}..update(name, (_) => error ?? '', ifAbsent: () => error ?? ''));
    return error == null;
  }

  /// Checks every registered field and shows their errors; returns whether
  /// the form passes.
  bool validateForm() {
    final errors = runtime.validate(
      formName,
      {for (final MapEntry(:key, :value) in _fields.entries) key: value.$1},
      bindings: {for (final MapEntry(:key, :value) in _fields.entries) key: value.$2},
    );
    _setErrors(errors);
    return errors.isEmpty;
  }

  /// Hides the error of the field [name].
  void clearError(String name) {
    if (_errors.containsKey(name)) _setErrors({..._errors}..remove(name));
  }

  void _setErrors(Map<String, String> errors) {
    errors.removeWhere((_, error) => error.isEmpty);
    if (mapEquals(errors, _errors)) return;
    _errors = Map.unmodifiable(errors);
    notifyListeners();
  }
}

/// The form a field is in: its name, under which the field's value is kept,
/// and its validation.
///
/// Internal to the package.
@internal
class OpenUIFormScope extends InheritedNotifier<OpenUIFormValidation> {
  /// Puts [child] in the form [validation] checks.
  const OpenUIFormScope({super.key, required OpenUIFormValidation validation, required super.child})
    : super(notifier: validation);

  /// The form's validation.
  OpenUIFormValidation get validation => notifier!;

  /// The form's name.
  String? get formName => notifier!.formName;

  /// The form around [context], or `null` when it is in none; [context]
  /// builds again when an error of the form changes.
  static OpenUIFormScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OpenUIFormScope>();
}

/// The gap a layout's `gap` prop gives: a number (0 to 48), a spacing name
/// (`none`, `xs`, `s`, `m`, `l`, `xl`, `2xl`), or the medium spacing.
///
/// Internal to the package.
@internal
double openUIGap(OpenUIResolvedTheme theme, Object? value) {
  return switch (value) {
    num() when value.isFinite => value.toDouble().clamp(0.0, 48.0),
    'none' => 0,
    'xs' => theme.xsSpacing,
    's' => theme.sSpacing,
    'l' => theme.lSpacing,
    'xl' => theme.xlSpacing,
    '2xl' => theme.xxlSpacing,
    _ => theme.mSpacing,
  };
}

/// The widgets of [nodes], components of [scope]'s props, leaving out those
/// whose type the library doesn't draw.
///
/// A component defined by a statement keeps its widgets when one before it
/// arrives later.
///
/// Internal to the package.
@internal
List<Widget> openUIChildWidgets(BuildContext context, OpenUIComponentScope scope, List<ElementNode> nodes) {
  return [
    for (final (node, key) in openUIDrawnNodes(context, nodes)) KeyedSubtree(key: key, child: scope.buildNode(node)),
  ];
}

/// The components of [nodes] the library draws, each with its key: see
/// [openUIChildWidgets].
///
/// Internal to the package.
@internal
List<(ElementNode, Key)> openUIDrawnNodes(BuildContext context, List<ElementNode> nodes) {
  final library = OpenUIViewScope.of(context).library;
  final seen = <String, int>{};
  return [
    for (final (index, node) in nodes.indexed)
      if (library[node.typeName] != null)
        (
          node,
          switch (node.statementId) {
            final id? => ValueKey((id, seen[id] = (seen[id] ?? -1) + 1)),
            null => ValueKey(index),
          },
        ),
  ];
}

/// [child] that runs [onTap] when tapped or activated from the keyboard, and
/// reads as a button; with no [onTap] it is disabled.
///
/// It dims while pressed.
///
/// Internal to the package.
@internal
class OpenUIPressable extends StatefulWidget {
  /// Creates the pressable [child].
  const OpenUIPressable({super.key, required this.onTap, required this.child, this.label, this.selected, this.hint});

  /// What a tap runs, or `null` when it is disabled.
  final VoidCallback? onTap;

  /// What it shows.
  final Widget child;

  /// What it reads as, or `null` for what [child] reads as.
  final String? label;

  /// Whether it is selected, or `null` when it can't be.
  final bool? selected;

  /// What a tap does, as read to assistive technologies.
  final String? hint;

  @override
  State<OpenUIPressable> createState() => _OpenUIPressableState();
}

class _OpenUIPressableState extends State<OpenUIPressable> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed != pressed && mounted) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: widget.selected,
      label: widget.label,
      hint: widget.hint,
      child: FocusableActionDetector(
        enabled: onTap != null,
        mouseCursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        actions: {if (onTap != null) ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onTap())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onTapDown: onTap == null ? null : (_) => _setPressed(true),
          onTapUp: onTap == null ? null : (_) => _setPressed(false),
          onTapCancel: onTap == null ? null : () => _setPressed(false),
          child: Opacity(opacity: _pressed && onTap != null ? 0.85 : 1, child: widget.child),
        ),
      ),
    );
  }
}
