import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_input.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `TextField`: its `label` over a field that writes each change the
/// person makes to its `value`.
///
/// The field is the Stream design system's [StreamTextInput], so the builder an
/// app registers for text inputs through [StreamComponentFactory] draws it
/// instead; an `obscured` field never goes to that builder, so a secret stays
/// hidden, and is drawn in the same style.
///
/// The `variant` chooses the field: `longText` for several lines,
/// `number` for a number keyboard, `obscured` for a secret such as a
/// password, whose text is hidden on screen and never suggested or
/// corrected, and `shortText`, the default, for one line. The field shows its
/// `placeholder` while it is empty, and an `obscured` one its label when it has
/// no placeholder.
///
/// The field is read as the design system reads it: by its label, with its
/// placeholder as a hint.
///
/// While the person types, the field keeps what they typed; a change from
/// elsewhere, such as from the agent, replaces it once the field isn't being
/// typed in. A field whose `value` isn't bound to the data model shows its
/// value read-only and fainter. While the field holds text, a failing check
/// outlines the field in the error color and its messages show below it.
///
/// Internal to the package.
@internal
Widget buildA2UITextField(BuildContext context, A2UIComponentScope scope) => _A2UITextField(scope: scope);

class _A2UITextField extends StatefulWidget {
  const _A2UITextField({required this.scope});

  final A2UIComponentScope scope;

  @override
  State<_A2UITextField> createState() => _A2UITextFieldState();
}

class _A2UITextFieldState extends State<_A2UITextField> {
  late final TextEditingController _controller = TextEditingController(text: _value);
  late final FocusNode _focusNode = FocusNode()..addListener(_handleFocusChange);

  String get _value => widget.scope.string('value') ?? '';

  @override
  void didUpdateWidget(_A2UITextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus) _showValue();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Once the person stops typing, the field shows the value of the data
  // model, which may have changed meanwhile.
  void _handleFocusChange() {
    if (!_focusNode.hasFocus) setState(_showValue);
  }

  void _showValue() {
    final value = _value;
    if (_controller.text == value) return;
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _handleChange(String text) {
    widget.scope.write('value', text);
    setState(() {
      // Whether the field holds text decides whether the checks show.
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    final theme = A2UISurfaceScope.of(context).theme;
    final label = scope.string('label') ?? '';
    final placeholder = scope.string('placeholder');
    final variant = scope.hint('variant');
    final failures = _controller.text.isEmpty ? const <A2UICheckFailure>[] : a2uiCheckFailuresOf(scope);
    final hasError = a2uiBlocks(failures);
    final isObscured = variant == 'obscured';
    final isLong = variant == 'longText';
    final canEdit = a2uiCanEdit(scope);
    final hint = placeholder ?? (label.isEmpty ? null : label);
    final labelStyle = theme.label.copyWith(color: hasError ? theme.error : theme.secondaryText);
    return A2UIInputWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The design system's field shows its own label, and is read by it.
          if (isObscured && label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: _labelSpacing),
              child: ExcludeSemantics(child: Text(label, style: labelStyle)),
            ),
          Opacity(
            opacity: canEdit ? 1 : a2uiReadOnlyOpacity,
            child: isObscured
                ? MergeSemantics(
                    child: Semantics(
                      label: label,
                      child: _buildObscured(
                        context,
                        hint: hint,
                        readsHint: placeholder != null,
                        hasError: hasError,
                        canEdit: canEdit,
                      ),
                    ),
                  )
                // The field needs a Material around it, which a surface may
                // not have.
                : Material(
                    type: MaterialType.transparency,
                    child: StreamTextInput(
                      controller: _controller,
                      labelText: label.isEmpty ? null : label,
                      style: StreamTextInputStyle(labelStyle: labelStyle),
                      focusNode: _focusNode,
                      onChanged: _handleChange,
                      readOnly: !canEdit,
                      hintText: placeholder,
                      helperState: hasError ? StreamHelperState.error : null,
                      autocorrect: true,
                      // Whatever the person types is kept as typed.
                      inputFormatters: const [],
                      textCapitalization: TextCapitalization.none,
                      keyboardType: switch (variant) {
                        'number' => const TextInputType.numberWithOptions(signed: true, decimal: true),
                        'longText' => TextInputType.multiline,
                        _ => TextInputType.text,
                      },
                      textInputAction: isLong ? TextInputAction.newline : TextInputAction.done,
                      maxLines: isLong ? null : 1,
                      minLines: isLong ? _longTextMinLines : 1,
                    ),
                  ),
          ),
          A2UIValidationMessages(failures: failures, theme: theme),
        ],
      ),
    );
  }

  // A secret field, drawn as the design system draws fields from its theme,
  // with the design system's defaults where the theme sets nothing, but never
  // by an app's text input builder, which could show the secret.
  Widget _buildObscured(
    BuildContext context, {
    required String? hint,
    required bool readsHint,
    required bool hasError,
    required bool canEdit,
  }) {
    final colors = context.streamColorScheme;
    final text = context.streamTextTheme;
    final style = context.streamTextInputTheme.style;
    final textStyle = WidgetStateProperty.resolveAs<TextStyle?>(style?.textStyle, const {});
    return Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _handleChange,
        readOnly: !canEdit,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        style: textStyle ?? text.bodyDefault.copyWith(color: colors.textPrimary),
        cursorColor: hasError
            ? style?.cursorErrorColor ?? colors.accentError
            : style?.cursorColor ?? colors.accentPrimary,
        cursorWidth: style?.cursorWidth ?? 2,
        cursorHeight: style?.cursorHeight,
        cursorRadius: style?.cursorRadius,
        decoration: a2uiStreamFieldDecoration(context, hint: hint, readsHint: readsHint, hasError: hasError),
      ),
    );
  }
}

// The space between the label and the field.
const _labelSpacing = 4.0;

// The lines a field for several lines shows while it holds fewer.
const _longTextMinLines = 3;
