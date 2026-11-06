import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_resolved_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_fill.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_input.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `ChoicePicker`: its `label` over its `options`, of which the
/// person picks one, or several with the `multipleSelection` variant; the
/// picked values are written to its `value` as a list.
///
/// The options are rows with a radio button, or with the Stream design system's
/// [StreamCheckbox], as a `CheckBox` has, when several can be picked, or
/// capsules side by side with the `chips` display style, the picked ones in
/// [A2UIThemeData.accent]. Picking the picked option of a single choice keeps it
/// picked. With `filterable`, a search field above the options shows only those
/// whose label holds what the person typed, in any capitalization.
///
/// An option shows its `label`, or its `value` while a label bound to the
/// data model isn't there yet. A pick that isn't among the options, which
/// the person can't see, is left out once they pick. A picker whose `value`
/// isn't bound to the data model shows fainter, and picks nothing. The
/// messages of the picker's failing checks show below it.
///
/// Internal to the package.
@internal
Widget buildA2UIChoicePicker(BuildContext context, A2UIComponentScope scope) => _A2UIChoicePicker(scope: scope);

typedef _Option = ({String label, String value});

class _A2UIChoicePicker extends StatefulWidget {
  const _A2UIChoicePicker({required this.scope});

  final A2UIComponentScope scope;

  @override
  State<_A2UIChoicePicker> createState() => _A2UIChoicePickerState();
}

class _A2UIChoicePickerState extends State<_A2UIChoicePicker> {
  late final TextEditingController _filter = TextEditingController()..addListener(_handleFilterChange);

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _handleFilterChange() {
    setState(() {
      // The options shown follow the filter's text.
    });
  }

  List<_Option> get _options {
    final options = widget.scope.value('options');
    if (options is! List<Object?>) return const [];
    return [
      for (final option in options)
        if (option case {'value': final String value}) (label: a2uiText(option['label']) ?? value, value: value),
    ];
  }

  void _toggle(String value, {required List<String> picked, required bool isMultiple}) {
    if (!isMultiple) {
      widget.scope.write('value', [value]);
      return;
    }
    // Only what the person sees picked stays picked.
    final options = {for (final option in _options) option.value};
    final shown = picked.where(options.contains);
    widget.scope.write(
      'value',
      shown.contains(value) ? [...shown.where((item) => item != value)] : [...shown, value],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    final theme = A2UISurfaceScope.of(context).theme;
    final label = scope.string('label') ?? '';
    final isMultiple = scope.hint('variant') == 'multipleSelection';
    final isChips = scope.hint('displayStyle') == 'chips';
    final isFilterable = scope.boolean('filterable') ?? false;
    final picked = scope.stringList('value') ?? const [];
    final accessibility = a2uiAccessibilityOf(scope);
    final canEdit = a2uiCanEdit(scope);
    final query = _filter.text.trim().toLowerCase();
    final shown = [
      for (final option in _options)
        if (query.isEmpty || option.label.toLowerCase().contains(query)) option,
    ];
    Widget optionOf(_Option option) {
      final isPicked = picked.contains(option.value);
      final handleTap = canEdit ? () => _toggle(option.value, picked: picked, isMultiple: isMultiple) : null;
      if (isChips) {
        return _Chip(option: option, isPicked: isPicked, isMultiple: isMultiple, onTap: handleTap, theme: theme);
      }
      return _Row(option: option, isPicked: isPicked, isMultiple: isMultiple, onTap: handleTap, theme: theme);
    }

    // The options read as one group, named by the picker's label.
    final picker = Semantics(
      container: true,
      explicitChildNodes: true,
      label: accessibility.label ?? (label.isEmpty ? null : label),
      hint: accessibility.description,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _spacing,
        children: [
          if (label.isNotEmpty)
            ExcludeSemantics(
              child: Text(label, style: theme.label.copyWith(color: theme.secondaryText)),
            ),
          if (isFilterable) _filterField(context, theme),
          if (isChips)
            Wrap(spacing: _chipSpacing, children: [for (final option in shown) optionOf(option)])
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final option in shown) optionOf(option)],
            ),
        ],
      ),
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(opacity: canEdit ? 1 : a2uiReadOnlyOpacity, child: picker),
        A2UIValidationMessages(failures: a2uiCheckFailuresOf(scope), theme: theme),
      ],
    );
    if (!isFilterable) return content;
    return A2UIInputWidth(child: content);
  }

  Widget _filterField(BuildContext context, A2UIResolvedTheme theme) {
    return Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: _filter,
        style: theme.body.copyWith(color: theme.text),
        cursorColor: theme.accent,
        textInputAction: TextInputAction.search,
        decoration: a2uiStreamFieldDecoration(
          context,
          hint: MaterialLocalizations.of(context).searchFieldLabel,
          hasError: false,
        ),
      ),
    );
  }
}

// The space between the label, the filter field and the options.
const _spacing = 6.0;

// The space between two chips side by side.
const _chipSpacing = 8.0;

// One option as a row: its radio button or checkbox and its label.
class _Row extends StatelessWidget {
  const _Row({
    required this.option,
    required this.isPicked,
    required this.isMultiple,
    required this.onTap,
    required this.theme,
  });

  final _Option option;
  final bool isPicked;
  final bool isMultiple;
  final VoidCallback? onTap;
  final A2UIResolvedTheme theme;

  // The space between the radio button or checkbox and the label.
  static const _spacing = 8.0;

  @override
  Widget build(BuildContext context) {
    // The row is read, focused and activated as the option, so the box
    // itself is neither, as in a check box.
    final control = isMultiple
        ? ExcludeFocus(
            child: ExcludeSemantics(
              // Drawn enabled when read-only, so the picker's fade alone shows
              // it; it picks nothing then.
              child: StreamCheckbox(value: isPicked, onChanged: (_) => onTap?.call()),
            ),
          )
        : Icon(
            isPicked ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
            color: isPicked ? theme.accent : theme.secondaryText,
          );
    // The whole row is tapped where the picker has a width; where it has
    // none, such as in a row that scrolls, it is as wide as its label.
    return A2UIFill(
      axis: Axis.horizontal,
      child: A2UIPressable(
        onTap: onTap,
        isButton: false,
        checked: isPicked,
        isInMutuallyExclusiveGroup: !isMultiple,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: _spacing,
          children: [
            control,
            Flexible(
              child: Text(option.label, style: theme.body.copyWith(color: theme.text)),
            ),
          ],
        ),
      ),
    );
  }
}

// One option as a capsule with its label.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.option,
    required this.isPicked,
    required this.isMultiple,
    required this.onTap,
    required this.theme,
  });

  final _Option option;
  final bool isPicked;
  final bool isMultiple;
  final VoidCallback? onTap;
  final A2UIResolvedTheme theme;

  // The space between a chip's edge and its label.
  static const _padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  // How strongly a picked chip shows the accent color behind its label.
  static const _pickedOpacity = 0.18;

  @override
  Widget build(BuildContext context) {
    return A2UIPressable(
      onTap: onTap,
      isButton: false,
      checked: isPicked,
      isInMutuallyExclusiveGroup: !isMultiple,
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: isPicked ? theme.accent.withValues(alpha: _pickedOpacity) : theme.subtleSurface,
          ),
          child: Padding(
            padding: _padding,
            child: Text(option.label, style: theme.label.copyWith(color: isPicked ? theme.accent : theme.text)),
          ),
        ),
      ),
    );
  }
}
