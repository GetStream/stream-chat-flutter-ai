part of 'openui_component_scope.dart';

/// The widget of one component of a reply's OpenUI: what its type's builder in
/// the view's library builds for it, brought in with an [AIUIEntrance] and
/// kept apart from its neighbours for assistive technologies.
///
/// It draws nothing when the component's type has no builder; in debug
/// builds it reports each such type once per runtime with [debugPrint]. A builder that
/// throws draws nothing either: the error goes to [FlutterError.reportError].
///
/// Internal to the package.
@internal
class OpenUINodeView extends StatelessWidget {
  /// Creates the widget of [node].
  const OpenUINodeView({super.key, required this.node});

  /// The component to draw.
  final ElementNode node;

  @override
  Widget build(BuildContext context) {
    final view = OpenUIViewScope.of(context);
    final builder = view.library[node.typeName];
    if (builder == null) {
      _reportUnknown(view, node.typeName);
      return const SizedBox.shrink();
    }
    return AIUIEntrance(
      child: Semantics(
        container: true,
        child: Builder(builder: (context) => _build(context, builder, _NodeScope(node, view))),
      ),
    );
  }

  // What [builder] builds for the component, or nothing when it throws.
  Widget _build(BuildContext context, OpenUIComponentBuilder builder, OpenUIComponentScope scope) {
    try {
      return builder(context, scope);
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stream_chat_flutter_ai_openui',
          context: ErrorDescription("while building the OpenUI component '${node.typeName}'"),
        ),
      );
      return const SizedBox.shrink();
    }
  }
}

// The widget of a prop's [value]: see [OpenUIComponentScope.buildProp].
class _OpenUIValueView extends StatelessWidget {
  const _OpenUIValueView(this.value, {super.key});

  final OpenUIValue? value;

  @override
  Widget build(BuildContext context) {
    final view = OpenUIViewScope.of(context);
    final theme = OpenUITheme.of(context);
    switch (value) {
      case OpenUIElement(:final node):
        return OpenUINodeView(node: node);
      case OpenUIArray(:final items):
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.spacing!.m!,
          children: [
            for (final (index, item) in items.indexed)
              if (_draws(item, view)) _OpenUIValueView(item, key: _keyOf(item, index, items)),
          ],
        );
      case OpenUIString() || OpenUINumber() || OpenUIBool():
        return Text(JS.stringOf(value), style: TextStyle(color: theme.colors!.textPrimary));
      case OpenUINull() || OpenUIObject() || OpenUIExpression() || null:
        return const SizedBox.shrink();
    }
  }

  // Whether [value] draws something, so a column keeps no space for it.
  static bool _draws(OpenUIValue value, OpenUIViewScope view) {
    return switch (value) {
      OpenUIElement(:final node) when view.library[node.typeName] == null => _reportUnknown(view, node.typeName),
      OpenUIElement() => true,
      OpenUIArray(:final items) => items.any((item) => _draws(item, view)),
      OpenUIString(:final value) => value.isNotEmpty,
      OpenUINumber() || OpenUIBool() => true,
      OpenUINull() || OpenUIObject() || OpenUIExpression() => false,
    };
  }

  // The key of the [item] at [index] of [items]: a component defined by a
  // statement keeps its widgets when an item before it arrives later, as an
  // item that refers to a statement not written yet is left out until then.
  static Key _keyOf(OpenUIValue item, int index, List<OpenUIValue> items) {
    if (item case OpenUIElement(node: ElementNode(:final statementId?))) {
      // The same statement can be placed more than once.
      final earlier = items
          .take(index)
          .where((other) => other is OpenUIElement && other.node.statementId == statementId);
      return ValueKey((statementId, earlier.length));
    }
    return ValueKey(index);
  }
}

final class _NodeScope extends OpenUIComponentScope {
  const _NodeScope(this._node, this._view) : super._();

  final ElementNode _node;
  final OpenUIViewScope _view;

  OpenUIValue? _prop(String name) => _node.props[name];

  @override
  String get type => _node.typeName;

  @override
  bool get isStreaming => _view.isStreaming;

  @override
  Object? value(String name) => _json(_prop(name));

  @override
  String? string(String name) => switch (_prop(name)) {
    OpenUIString(:final value) => value,
    _ => null,
  };

  @override
  String? text(String name) {
    final value = _prop(name);
    return JS.isNullish(value) ? null : JS.stringOf(value);
  }

  @override
  double? number(String name) {
    final number = switch (_prop(name)) {
      OpenUINumber(:final value) => value,
      // An empty string is no number, though JavaScript reads it as 0.
      OpenUIString(:final value) when JS.trim(value).isNotEmpty => JS.stringToNumber(value),
      _ => null,
    };
    return number == null || number.isNaN ? null : number;
  }

  @override
  bool? boolean(String name) => switch (_prop(name)) {
    OpenUIBool(:final value) => value,
    OpenUIString(value: 'true') => true,
    OpenUIString(value: 'false') => false,
    _ => null,
  };

  @override
  List<String> stringList(String name) => [for (final item in _items(name)) JS.toStringOrEmpty(item)];

  @override
  List<double> numberList(String name) => [for (final item in _items(name)) JS.toNumber(item)];

  // The prop [name] as a list: see [stringList].
  List<OpenUIValue> _items(String name) => switch (_prop(name)) {
    OpenUIArray(:final items) => items,
    null || OpenUINull() => const [],
    final value => [value],
  };

  @override
  Widget buildProp(String name) => _OpenUIValueView(_prop(name));

  @override
  Widget buildDefault() {
    final builder = _view.library.replacedBuilderOf(type);
    if (builder == null) return const SizedBox.shrink();
    return Builder(builder: (context) => builder(context, this));
  }

  // [value] as JSON, with `null` for a component or an expression.
  static Object? _json(OpenUIValue? value) {
    return switch (value) {
      OpenUIString(:final value) => value,
      OpenUINumber(:final value) => value,
      OpenUIBool(:final value) => value,
      OpenUIArray(:final items) => [for (final item in items) _json(item)],
      OpenUIObject(:final fields) => {for (final MapEntry(:key, :value) in fields.entries) key: _json(value)},
      OpenUINull() || OpenUIElement() || OpenUIExpression() || null => null,
    };
  }
}

// Reports in debug builds, once per runtime, that the library has no builder
// for [type]; returns `false`, as such a component draws nothing.
bool _reportUnknown(OpenUIViewScope view, String type) {
  if (kDebugMode && view.unknownTypes.add(type)) {
    debugPrint("OpenUI: the library has no builder for '$type', so it draws nothing.");
  }
  return false;
}
