import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/components/openui_fields.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/components/openui_form.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_actions.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_grid.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_icon_map.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `CheckBoxGroup`: a checkbox for each of its `items`, each with
/// its `label` and `description`.
///
/// Its value is an object with each item's `name` and whether it is checked;
/// an item is checked at first when its `defaultChecked` is `true`, and once
/// the reply ends those defaults are kept as the value when it has none. Each
/// change checks the group's `rules`. It can't be changed while the reply
/// streams.
///
/// Internal to the package.
@internal
Widget buildOpenUICheckBoxGroup(BuildContext context, OpenUIComponentScope scope) =>
    _toggleGroup(context, scope, isSwitch: false);

/// Builds a `SwitchGroup`: a switch for each of its `items`, which works as
/// a `CheckBoxGroup` does, without rules, on the surface its `variant` names.
///
/// Internal to the package.
@internal
Widget buildOpenUISwitchGroup(BuildContext context, OpenUIComponentScope scope) =>
    _toggleGroup(context, scope, isSwitch: true);

Widget _toggleGroup(BuildContext context, OpenUIComponentScope scope, {required bool isSwitch}) {
  final items = scope.elements('items');
  if (items.isEmpty) return const SizedBox.shrink();
  final theme = OpenUIViewScope.of(context).theme;
  final colors = theme;
  final type = isSwitch ? 'SwitchGroup' : 'CheckBoxGroup';
  final name = scope.text('name') ?? '';
  final rules = isSwitch ? null : scope.prop('rules');
  return scope.watchState((context) {
    final field = openUIFieldState(context, scope, type);
    final stored = field.value is OpenUIObject ? (field.value! as OpenUIObject).fields : const <String, OpenUIValue>{};
    final checked = <String, OpenUIValue>{
      for (final item in items.map(scope.scopeOf))
        if (item.text('name') case final itemName?)
          itemName: OpenUIBool(switch (stored[itemName]) {
            OpenUIBool(:final value) => value,
            _ => item.boolean('defaultChecked') ?? false,
          }),
    };
    final rows = <Widget>[];
    for (final (index, node) in items.indexed) {
      final item = scope.scopeOf(node);
      final itemName = item.text('name') ?? '$index';
      final isOn = checked[itemName] == const OpenUIBool(true);
      final onChanged = scope.isStreaming
          ? null
          : (bool value) {
              final next = OpenUIObject({...checked, itemName: OpenUIBool(value)});
              openUIFieldState(context, scope, type).set(next);
              if (rules != null) validateOpenUIField(context, scope);
            };
      if (index > 0 && isSwitch) rows.add(SizedBox(height: 0.5, child: ColoredBox(color: colors.border)));
      rows.add(
        MergeSemantics(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: theme.sSpacing),
            child: Row(
              spacing: theme.mSpacing,
              children: [
                if (!isSwitch) StreamCheckbox(value: isOn, onChanged: onChanged),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTap: onChanged == null ? null : () => onChanged(!isOn),
                    child: _TitleSubtitle(title: item.text('label') ?? itemName, subtitle: item.text('description')),
                  ),
                ),
                if (isSwitch) StreamSwitch(value: isOn, onChanged: onChanged),
              ],
            ),
          ),
        ),
      );
    }
    return OpenUIFieldHost(
      name: name,
      rules: rules,
      binding: scope.prop('value'),
      isStreaming: scope.isStreaming,
      saveDefault: field.isBound || checked.isEmpty
          ? null
          : () => saveOpenUIDefault(context, name, type, OpenUIObject(checked)),
      child: OpenUISurface(
        variant: isSwitch ? scope.string('variant') ?? 'clear' : 'clear',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
      ),
    );
  });
}

/// Builds a `RadioGroup`: a choice of one of its `items`, each with its
/// `label` and `description`, whose `value` it writes.
///
/// The `defaultValue` is chosen at first and, once the reply ends, kept as
/// the value when it has none. Each choice checks the group's `rules`. It
/// can't be changed while the reply streams.
///
/// Internal to the package.
@internal
Widget buildOpenUIRadioGroup(BuildContext context, OpenUIComponentScope scope) {
  final items = scope.elements('items');
  if (items.isEmpty) return const SizedBox.shrink();
  final theme = OpenUIViewScope.of(context).theme;
  final colors = theme;
  final name = scope.text('name') ?? '';
  return scope.watchState((context) {
    final field = openUIFieldState(context, scope, 'RadioGroup');
    final value = JS.isNullish(field.value) ? scope.prop('defaultValue') : field.value;
    final current = JS.isNullish(value) ? null : JS.stringOf(value);
    final values = [for (final item in items) scope.scopeOf(item).text('value') ?? ''];
    final shown = values.contains(current) ? current : null;
    final dot = openUIScaled(context, 20);
    return OpenUIFieldHost(
      name: name,
      rules: scope.prop('rules'),
      binding: scope.prop('value'),
      isStreaming: scope.isStreaming,
      saveDefault: field.isBound || shown == null
          ? null
          : () => saveOpenUIDefault(context, name, 'RadioGroup', OpenUIString(shown)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.sSpacing,
        children: [
          for (final (index, node) in items.indexed)
            if (scope.scopeOf(node) case final item)
              Semantics(
                inMutuallyExclusiveGroup: true,
                checked: values[index] == current,
                child: OpenUIPressable(
                  selected: values[index] == current,
                  onTap: scope.isStreaming
                      ? null
                      : () {
                          openUIFieldState(context, scope, 'RadioGroup').set(OpenUIString(values[index]));
                          validateOpenUIField(context, scope);
                        },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: theme.mSpacing,
                    children: [
                      Container(
                        width: dot,
                        height: dot,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: values[index] == current ? colors.accent : colors.tertiaryText,
                            width: 2,
                          ),
                        ),
                        child: values[index] == current
                            ? Container(
                                width: dot / 2,
                                height: dot / 2,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accent),
                              )
                            : null,
                      ),
                      Expanded(
                        child: _TitleSubtitle(
                          title: item.text('label') ?? values[index],
                          subtitle: item.text('description'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  });
}

/// Builds `Chips`: its `items` as pills to choose, several by default or one
/// when its `type` is `single`.
///
/// Its value is the chosen items' values, or one value (`null` when none is
/// chosen) when single; tapping a chosen item clears it. The `defaultValue`
/// is chosen at first and, once the reply ends, kept as the value when it has
/// none. An item without a `value` is left out, and one that is `disabled`
/// can't be chosen. Each choice checks the field's `rules`. They can't be
/// changed while the reply streams.
///
/// Internal to the package.
@internal
Widget buildOpenUIChips(BuildContext context, OpenUIComponentScope scope) =>
    _OpenUISelection(scope: scope, cards: false);

/// Builds `OptionCards`: its `items` as cards in a grid, each with its
/// `title`, `subtitle` and `topContent`, an icon or image, which work as
/// `Chips` do, one chosen by default.
///
/// Internal to the package.
@internal
Widget buildOpenUIOptionCards(BuildContext context, OpenUIComponentScope scope) =>
    _OpenUISelection(scope: scope, cards: true);

class _OpenUISelection extends StatelessWidget {
  const _OpenUISelection({required this.scope, required this.cards});

  final OpenUIComponentScope scope;
  final bool cards;

  String get _type => cards ? 'OptionCards' : 'Chips';

  bool get _single => (scope.string('type') ?? (cards ? 'single' : 'multiple')) == 'single';

  // The values [value] holds: the first for a single choice, every string
  // otherwise.
  List<String>? _valuesOf(OpenUIValue? value) {
    return switch (value) {
      OpenUIString(:final value) => value.isEmpty ? const [] : [value],
      OpenUIArray(:final items) when _single => switch (items.firstOrNull) {
        OpenUIString(:final value) => value.isEmpty ? const [] : [value],
        _ => null,
      },
      OpenUIArray(:final items) => [
        for (final item in items)
          if (item case OpenUIString(:final value)) value,
      ],
      _ => null,
    };
  }

  // The default value as it is kept: a string for a single choice, a list
  // otherwise.
  OpenUIValue? _storedDefault() {
    final values = _valuesOf(scope.prop('defaultValue'));
    if (values == null) return null;
    if (_single) return values.isEmpty ? null : OpenUIString(values.first);
    return OpenUIArray([for (final value in values) OpenUIString(value)]);
  }

  @override
  Widget build(BuildContext context) {
    final name = scope.text('name') ?? '';
    final items = [
      for (final node in scope.elements('items'))
        if (scope.scopeOf(node) case final item when !JS.isNullish(item.prop('value'))) item,
    ];
    return scope.watchState((context) {
      final runtime = OpenUIViewScope.of(context).runtime;
      final formName = OpenUIFormScope.maybeOf(context)?.formName;
      final stored = runtime.fieldValue(formName, name);
      // A choice cleared to `null` shows nothing, not the default.
      final selection =
          (stored != null ? _valuesOf(stored) : _valuesOf(scope.prop('defaultValue'))) ?? const <String>[];
      final theme = OpenUIViewScope.of(context).theme;
      final widgets = [
        for (final item in items)
          Builder(
            builder: (context) {
              final value = JS.stringOf(item.prop('value'));
              final selected = selection.contains(value);
              final disabled = item.boolean('disabled') ?? false;
              final onTap = scope.isStreaming || disabled
                  ? null
                  : () {
                      final next = _single
                          ? (selected ? const <String>[] : [value])
                          : (selected ? selection.where((each) => each != value).toList() : [...selection, value]);
                      runtime.setFieldValue(
                        formName,
                        name,
                        _single
                            ? (next.isEmpty ? OpenUINull.instance : OpenUIString(next.first))
                            : OpenUIArray([for (final each in next) OpenUIString(each)]),
                        componentType: _type,
                      );
                      validateOpenUIField(context, scope);
                    };
              return Opacity(
                opacity: disabled ? 0.5 : 1,
                child: OpenUIPressable(
                  selected: selected,
                  onTap: onTap,
                  child: cards ? _OptionCard(item: item, selected: selected) : _Chip(item: item, selected: selected),
                ),
              );
            },
          ),
      ];
      return OpenUIFieldHost(
        name: name,
        rules: scope.prop('rules'),
        binding: null,
        isStreaming: scope.isStreaming,
        saveDefault: () => saveOpenUIDefault(context, name, _type, _storedDefault()),
        child: cards
            ? OpenUIResponsiveGrid(minItemWidth: 140, maxColumns: 3, spacing: theme.sSpacing, children: widgets)
            : SizedBox(
                width: double.infinity,
                child: Wrap(spacing: theme.sSpacing, runSpacing: theme.sSpacing, children: widgets),
              ),
      );
    });
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.item, required this.selected});

  final OpenUIComponentScope item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    final colors = theme;
    final color = selected ? colors.accent : colors.text;
    final icon = item.elements('icon').firstOrNull;
    final iconData = icon == null
        ? null
        : openUIIconOf(context.streamIcons, JS.toStringOrEmpty(icon.props['name']), switch (icon.props['category']) {
            OpenUIString(:final value) => value,
            _ => null,
          });
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? colors.accent.withValues(alpha: 0.14) : colors.sunkenSurface,
        borderRadius: BorderRadius.circular(theme.pillCornerRadius),
        border: Border.all(color: selected ? colors.accent : const Color(0x00000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            if (iconData != null)
              ExcludeSemantics(
                child: Icon(iconData, size: openUIScaled(context, 14), color: color),
              ),
            Flexible(
              child: Text(
                item.text('label') ?? JS.stringOf(item.prop('value')),
                style: theme.bodySmall.copyWith(fontWeight: FontWeight.w500, color: color),
              ),
            ),
            if (selected)
              ExcludeSemantics(
                child: Icon(context.streamIcons.checkmark, size: openUIScaled(context, 12), color: color),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.item, required this.selected});

  final OpenUIComponentScope item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    final colors = theme;
    final top = item.elements('topContent').firstOrNull;
    final radius = BorderRadius.circular(theme.mediumCornerRadius);
    Widget? topContent;
    if (top != null) {
      final source = top.props['src'];
      if (source is OpenUIString) {
        topContent = ClipRRect(
          borderRadius: BorderRadius.circular(theme.smallCornerRadius),
          child: SizedBox(
            height: 80,
            width: double.infinity,
            child: OpenUIRemoteImage(source: source.value, alt: JS.toStringOrEmpty(top.props['alt'])),
          ),
        );
      } else if (openUIIconOf(context.streamIcons, JS.toStringOrEmpty(top.props['name'])) case final icon?) {
        final side = openUIScaled(context, 32);
        topContent = Container(
          width: side,
          height: side,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.accent.withValues(alpha: 0.14) : colors.subtleFill,
            borderRadius: BorderRadius.circular(theme.smallCornerRadius),
          ),
          child: ExcludeSemantics(
            child: Icon(icon, size: openUIScaled(context, 16), color: selected ? colors.accent : colors.secondaryText),
          ),
        );
      }
    }
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? colors.accent.withValues(alpha: 0.08) : colors.sunkenSurface,
              borderRadius: radius,
              border: Border.all(color: selected ? colors.accent : const Color(0x00000000), width: 1.5),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(theme.mSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: theme.sSpacing,
            children: [
              ?topContent,
              _TitleSubtitle(
                title: item.text('title') ?? JS.stringOf(item.prop('value')),
                subtitle: item.text('subtitle'),
                bold: true,
              ),
            ],
          ),
        ),
        if (selected)
          PositionedDirectional(
            top: theme.sSpacing,
            end: theme.sSpacing,
            child: ExcludeSemantics(
              child: Icon(context.streamIcons.checkmark, size: openUIScaled(context, 16), color: colors.accent),
            ),
          ),
      ],
    );
  }
}

class _TitleSubtitle extends StatelessWidget {
  const _TitleSubtitle({required this.title, this.subtitle, this.bold = false});

  final String title;
  final String? subtitle;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    final colors = theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 2,
      children: [
        Text(
          title,
          style: theme.bodySmall.copyWith(
            fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
            color: colors.text,
          ),
        ),
        if (subtitle case final subtitle? when subtitle.isNotEmpty)
          Text(subtitle, style: theme.caption.copyWith(color: colors.secondaryText)),
      ],
    );
  }
}
