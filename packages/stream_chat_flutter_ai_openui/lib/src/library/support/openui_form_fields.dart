import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/components/openui_choices.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/components/openui_fields.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';

/// The types of the components that hold a form's value.
const _fieldTypes = {
  'Input',
  'TextArea',
  'Select',
  'DatePicker',
  'Slider',
  'CheckBoxGroup',
  'SwitchGroup',
  'RadioGroup',
  'Chips',
  'OptionCards',
};

/// One step on the way to a field that isn't on screen: the item of a
/// container (tabs, an accordion or a foldable section block) that holds it.
///
/// Internal to the package.
@internal
@immutable
class OpenUIRevealStep {
  /// Creates the step to the item [item] of [container].
  const OpenUIRevealStep(this.container, this.item);

  /// The `Tabs`, `Accordion` or `SectionBlock` component.
  final ElementNode container;

  /// The `value` of the item to show.
  final String item;
}

/// A form field read from the component tree of a reply, whether or not it is
/// on screen.
///
/// Internal to the package.
@internal
@immutable
class OpenUIFormField {
  /// Creates the field [name] of the component [node].
  const OpenUIFormField({
    required this.node,
    required this.name,
    required this.rules,
    required this.binding,
    required this.chain,
  });

  /// The field's component.
  final ElementNode node;

  /// The field's `name`.
  final String name;

  /// The field's `rules` prop, or `null` when it has none.
  final OpenUIValue? rules;

  /// The field's `value` prop, which may bind it to a `$variable`; `null` for
  /// a password, which is never bound.
  final OpenUIValue? binding;

  /// The items to show, outermost first, for the field to be on screen.
  final List<OpenUIRevealStep> chain;

  /// Whether the field has `rules` to check.
  bool get hasRules => rules != null && rules is! OpenUINull;
}

/// Whether [a] and [b] are the same component: the same node, or nodes of
/// the same statement and type, as a reply that is written again after the
/// tree was read builds new nodes for what it did not change.
///
/// Internal to the package.
@internal
bool isSameOpenUINode(ElementNode a, ElementNode b) {
  return identical(a, b) || (a.statementId != null && a.statementId == b.statementId && a.typeName == b.typeName);
}

/// The form fields in [root], the `fields` of a form, in the order they are
/// drawn, with what it takes to show each.
///
/// The fields of a nested form belong to it, and a modal's content is only
/// drawn while the modal is open, so neither is read. A carousel's pages are
/// not read as containers either: by the library's schemas a form's `fields`
/// are only `FormControl`s, whose `input` is a field, so a carousel (like tabs
/// or an accordion) can hold a whole `Form`, which owns its fields, but not
/// the fields of another; tabs, accordions and sections are handled here for
/// replies that nest them anyway. Items of tabs, an
/// accordion or sections that the container leaves out, as it does those
/// without a `value`, hold no field.
///
/// Internal to the package.
@internal
List<OpenUIFormField> collectOpenUIFormFields(OpenUIValue? root) {
  final collector = _Collector()..visit(root, const []);
  return collector.fields;
}

class _Collector {
  final fields = <OpenUIFormField>[];

  void visit(OpenUIValue? value, List<OpenUIRevealStep> chain) {
    switch (value) {
      case OpenUIElement(:final node):
        visitNode(node, chain);
      case OpenUIArray(:final items):
        for (final item in items) {
          visit(item, chain);
        }
      case OpenUIObject(:final fields):
        for (final item in fields.values) {
          visit(item, chain);
        }
      default:
    }
  }

  void visitItems(ElementNode container, OpenUIValue? items, List<OpenUIRevealStep> chain, {required bool indexed}) {
    if (items is! OpenUIArray) return;
    final seen = <String>{};
    var index = 0;
    for (final item in items.items) {
      if (item is! OpenUIElement) continue;
      final own = item.node.props['value'];
      final value = own == null || own is OpenUINull ? (indexed ? '$index' : null) : JS.stringOf(own);
      index++;
      if (value == null || !seen.add(value)) continue;
      for (final prop in item.node.props.values) {
        visit(prop, [...chain, OpenUIRevealStep(container, value)]);
      }
    }
  }

  void visitNode(ElementNode node, List<OpenUIRevealStep> chain) {
    final type = node.typeName;
    if (type == 'Form' || type == 'Modal') return;
    if (_fieldTypes.contains(type)) {
      final name = switch (node.props['name']) {
        null || OpenUINull() => '',
        final value => JS.stringOf(value),
      };
      if (name.isEmpty) return;
      final password = type == 'Input' && node.props['type'] == const OpenUIString('password');
      fields.add(
        OpenUIFormField(
          node: node,
          name: name,
          rules: node.props['rules'],
          binding: password ? null : node.props['value'],
          chain: chain,
        ),
      );
      return;
    }
    final itemsProp = switch (type) {
      'Tabs' || 'Accordion' => 'items',
      'SectionBlock' when node.props['isFoldable'] != const OpenUIBool(false) => 'sections',
      _ => null,
    };
    for (final MapEntry(:key, :value) in node.props.entries) {
      if (key == itemsProp) {
        visitItems(node, value, chain, indexed: type == 'SectionBlock');
      } else {
        visit(value, chain);
      }
    }
  }
}

/// What the field [scope] draws shows by default, as it is kept once the
/// reply ends, or `null` when it has none.
///
/// This reads only the component's props, so a field that isn't on screen is
/// kept as the one that is.
///
/// Internal to the package.
@internal
OpenUIValue? openUIFieldDefault(OpenUIComponentScope scope) {
  switch (scope.type) {
    case 'Input' || 'TextArea' || 'Select' || 'DatePicker':
      // A password is never kept, and a `$variable` isn't a default.
      if (scope.type == 'Input' && scope.string('type') == 'password') return null;
      final value = scope.prop('value');
      if (value == null || value is OpenUINull || ReactiveBinding.targetOf(value) != null) return null;
      return value;
    case 'CheckBoxGroup' || 'SwitchGroup':
      final checked = <String, OpenUIValue>{
        for (final item in scope.elements('items').map(scope.scopeOf))
          if (item.text('name') case final name?) name: OpenUIBool(item.boolean('defaultChecked') ?? false),
      };
      return checked.isEmpty ? null : OpenUIObject(checked);
    case 'RadioGroup':
      final value = scope.prop('defaultValue');
      if (JS.isNullish(value)) return null;
      final current = JS.stringOf(value);
      final values = [for (final item in scope.elements('items')) scope.scopeOf(item).text('value') ?? ''];
      return values.contains(current) ? OpenUIString(current) : null;
    case 'Slider':
      final bounds = openUISliderBounds(scope.number('min'), scope.number('max'));
      return openUISliderStored(openUISliderValues(scope.prop('defaultValue'), bounds.lower, bounds.upper));
    case 'Chips' || 'OptionCards':
      final single = openUISelectionIsSingle(scope);
      final values = openUISelectionValues(scope.prop('defaultValue'), single: single);
      if (values == null) return null;
      if (single) return values.isEmpty ? null : OpenUIString(values.first);
      return OpenUIArray([for (final value in values) OpenUIString(value)]);
  }
  return null;
}
