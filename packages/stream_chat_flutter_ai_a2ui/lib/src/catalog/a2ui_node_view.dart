part of 'a2ui_component_scope.dart';

/// The widget of one component of a surface: what its type's builder in the
/// surface's catalog builds for it, brought in with an [AIUIEntrance] and
/// given the component's accessibility attributes.
///
/// It draws nothing while the component is on its way or its type has no
/// builder, and builds again when the component's properties or children
/// change.
///
/// Internal to the package.
@internal
class A2UINodeView extends StatelessWidget {
  /// Creates the widget of [node].
  A2UINodeView({required this.node}) : super(key: ValueKey(node.key));

  /// The component.
  final A2UINode node;

  @override
  Widget build(BuildContext context) {
    final catalog = A2UISurfaceScope.of(context).catalog;
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        if (!node.isResolved) return const SizedBox.shrink();
        final builder = catalog[node.type];
        if (builder == null) return const SizedBox.shrink();
        return AIUIEntrance(
          child: _A2UIAccessibility(
            node: node,
            child: Builder(builder: (context) => builder(context, _NodeScope(node, catalog))),
          ),
        );
      },
    );
  }
}

// The scope of [_node] for its builder.
final class _NodeScope extends A2UIComponentScope {
  const _NodeScope(this._node, this._catalog) : super._();

  final A2UINode _node;
  final A2UICatalog _catalog;

  @override
  String get id => _node.id;

  @override
  String get type => _node.type;

  @override
  Object? value(String name) => _withChildren(_node.property(name));

  // [value] with each component in it as an [A2UIChild].
  Object? _withChildren(Object? value) {
    return switch (value) {
      final A2UINode node => _shows(node) ? A2UIChild._(node) : null,
      final Map<String, Object?> map => Map<String, Object?>.unmodifiable({
        for (final MapEntry(:key, :value) in map.entries) key: _withChildren(value),
      }),
      final List<Object?> list => List<Object?>.unmodifiable(list.map(_withChildren)),
      _ => value,
    };
  }

  @override
  String? string(String name) => a2uiText(_node.property(name));

  @override
  double? number(String name) {
    final number = switch (_node.property(name)) {
      final num value => value.toDouble(),
      final String value => double.tryParse(value.trim()),
      _ => null,
    };
    if (number == null || !number.isFinite) return null;
    return number;
  }

  @override
  bool? boolean(String name) {
    final value = _node.property(name);
    if (value case {'valid': final Object? valid}) return _boolean(valid);
    return _boolean(value);
  }

  static bool? _boolean(Object? value) {
    return switch (value) {
      final bool value => value,
      final num value => value != 0,
      final String value => switch (value.toLowerCase()) {
        'true' => true,
        'false' => false,
        _ => null,
      },
      _ => null,
    };
  }

  @override
  List<String>? stringList(String name) {
    final value = _node.property(name);
    if (value is! List<Object?>) return null;
    return [
      for (final item in value)
        if (a2uiText(item) case final text?) text,
    ];
  }

  @override
  String? hint(String name) {
    final written = _node.writtenProperty(name);
    return written is String ? written : null;
  }

  @override
  bool isBound(String name) => _node.canWrite(name);

  @override
  A2UIChild? child([String name = 'child']) {
    final value = _node.property(name);
    if (value is! A2UINode || !_shows(value)) return null;
    return A2UIChild._(value);
  }

  @override
  List<A2UIChild> children([String name = 'children']) {
    return [
      for (final node in _node.children(name))
        if (_shows(node)) A2UIChild._(node),
    ];
  }

  // Whether [node] draws something: it has arrived, and its type has a
  // builder.
  bool _shows(A2UINode node) => node.isResolved && _catalog[node.type] != null;

  @override
  Widget build(A2UIChild child) => A2UINodeView(node: child._node);
}

/// What notifies its listeners when [child]'s own properties change, such as
/// its weight.
///
/// Internal to the package.
@internal
Listenable a2uiListenableOf(A2UIChild child) => child._node;

/// The property [name] of the component [scope] reads, as the agent wrote it,
/// with bindings and function calls unread, or `null` when the component
/// doesn't set it.
///
/// Internal to the package.
@internal
Object? a2uiWrittenProperty(A2UIComponentScope scope, String name) {
  return switch (scope) {
    _NodeScope(:final _node) => _node.writtenProperty(name),
  };
}

/// [value] as text: a string as it is, a whole number without a decimal
/// point, a boolean as `true` or `false`, and a list or a map as JSON; `null`
/// for `null`.
///
/// Internal to the package.
@internal
String? a2uiText(Object? value) {
  return switch (value) {
    null => null,
    final String value => value,
    final bool value => '$value',
    final num value => _numberText(value),
    _ => _json(value),
  };
}

// Whole numbers below this size print exactly without a decimal point.
const _maxExactWhole = 9007199254740992.0;

String _numberText(num value) {
  if (value is int) return '$value';
  if (!value.isFinite) return 'null';
  if (value == value.truncateToDouble() && value.abs() < _maxExactWhole) return '${value.toInt()}';
  return '$value';
}

String _json(Object? value) => jsonEncode(_jsonable(value));

// [value] with each whole number as an integer, which JSON writes without a
// decimal point, and each component as its id.
Object? _jsonable(Object? value) {
  return switch (value) {
    null || String() || bool() || int() => value,
    final double value when !value.isFinite => null,
    final double value when value == value.truncateToDouble() && value.abs() < _maxExactWhole => value.toInt(),
    double() => value,
    final A2UIChild child => child.id,
    final A2UINode node => node.id,
    final Map<Object?, Object?> map => {for (final MapEntry(:key, :value) in map.entries) '$key': _jsonable(value)},
    final List<Object?> list => [for (final item in list) _jsonable(item)],
    _ => '$value',
  };
}

// The accessibility attributes the agent gave a component: its label and
// description, whether assistive technologies skip it, and whether changes
// to it are announced.
class _A2UIAccessibility extends StatefulWidget {
  const _A2UIAccessibility({required this.node, required this.child});

  final A2UINode node;
  final Widget child;

  @override
  State<_A2UIAccessibility> createState() => _A2UIAccessibilityState();
}

class _A2UIAccessibilityState extends State<_A2UIAccessibility> {
  // Leaf components whose own text the label replaces. A container keeps its
  // children reachable, so its label is read before them.
  static const _leafTypes = {'Text', 'Image', 'Icon', 'Divider'};

  // What the component announces when it changes, as it was when last seen.
  String? _announcement;
  late FlutterView _view;
  late TextDirection _direction;

  @override
  void initState() {
    super.initState();
    _announcement = _announcementOf(widget.node);
    widget.node.addListener(_handleChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.of(context);
    _direction = Directionality.of(context);
  }

  @override
  void didUpdateWidget(_A2UIAccessibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.node, widget.node)) return;
    oldWidget.node.removeListener(_handleChange);
    widget.node.addListener(_handleChange);
    // The new node is the component built again, such as after its surface
    // was released and restored; it is read as it shows, as on first build.
    _announcement = _announcementOf(widget.node);
  }

  @override
  void dispose() {
    widget.node.removeListener(_handleChange);
    super.dispose();
  }

  // Announces what a live component reads as when it changes: its label, or
  // else its text. A component that shows is read where it is, so nothing is
  // announced until it changes.
  void _handleChange() {
    final announcement = _announcementOf(widget.node);
    if (announcement == _announcement) return;
    _announcement = announcement;
    final assertiveness = switch (_attributes(widget.node)?['live']) {
      'polite' => Assertiveness.polite,
      'assertive' => Assertiveness.assertive,
      _ => null,
    };
    if (assertiveness == null || announcement == null || announcement.isEmpty) return;
    // Assistive technologies skip a hidden component, so it announces nothing.
    if (_isHidden(_attributes(widget.node))) return;
    unawaited(SemanticsService.sendAnnouncement(_view, announcement, _direction, assertiveness: assertiveness));
  }

  static bool _isHidden(Map<String, Object?>? attributes) => _NodeScope._boolean(attributes?['hidden']) ?? false;

  static Map<String, Object?>? _attributes(A2UINode node) {
    final attributes = node.property('accessibility');
    return attributes is Map<String, Object?> ? attributes : null;
  }

  static String? _announcementOf(A2UINode node) {
    return _nonEmpty(a2uiText(_attributes(node)?['label'])) ?? a2uiText(node.property('text'));
  }

  static String? _nonEmpty(String? text) => text == null || text.isEmpty ? null : text;

  @override
  Widget build(BuildContext context) {
    final attributes = _attributes(widget.node);
    final hidden = _isHidden(attributes);
    final label = _nonEmpty(a2uiText(attributes?['label']));
    final description = _nonEmpty(a2uiText(attributes?['description']));
    final replacesOwnLabel = label != null && _leafTypes.contains(widget.node.type);
    // The same widgets whatever the attributes, so a change to them keeps the
    // state of what the component built, such as its selected tab.
    return ExcludeSemantics(
      excluding: hidden,
      child: Semantics(
        container: label != null || description != null,
        label: label,
        hint: description,
        // An image keeps being read as one when its label is replaced.
        image: replacesOwnLabel && widget.node.type == 'Image' ? true : null,
        excludeSemantics: replacesOwnLabel,
        child: widget.child,
      ),
    );
  }
}
