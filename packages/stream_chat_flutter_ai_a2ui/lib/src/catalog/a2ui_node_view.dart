part of 'a2ui_component_scope.dart';

/// The widget of one component of a surface: what its type's builder in the
/// surface's catalog builds for it, brought in with an [AIUIEntrance] and
/// given the component's accessibility attributes.
///
/// It draws nothing while the component is on its way or its type has no
/// builder; a type with no builder, such as one the app took out of the
/// catalog, is logged once in debug builds. It builds again when the component's properties or children
/// change. A builder that throws draws nothing either: the error goes to
/// [FlutterError.reportError], and to the processor's `onError` as an
/// `EXECUTION_ERROR` once the frame is done.
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
    final surfaceScope = A2UISurfaceScope.of(context);
    final catalog = surfaceScope.catalog;
    final onOpenLink = surfaceScope.onOpenLink;
    final openModal = A2UIModalOpener.maybeOf(context);
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        if (!node.isResolved) return const SizedBox.shrink();
        final builder = catalog[node.type];
        if (builder == null) {
          _logNoBuilder(node.type);
          return const SizedBox.shrink();
        }
        return AIUIEntrance(
          child: _A2UIAccessibility(
            node: node,
            child: Builder(
              builder: (context) => _build(context, builder, _NodeScope(node, catalog, onOpenLink, openModal)),
            ),
          ),
        );
      },
    );
  }

  // What [builder] builds for the component, or nothing when it throws.
  Widget _build(BuildContext context, A2UIComponentBuilder builder, A2UIComponentScope scope) {
    try {
      return builder(context, scope);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stream_chat_flutter_ai_a2ui',
          context: ErrorDescription("while building the A2UI component '${node.id}' of type '${node.type}'"),
        ),
      );
      // Reported after the frame, as the app may rebuild in its `onError`.
      WidgetsBinding.instance.addPostFrameCallback((_) => node.reportBuildError(error));
      return const SizedBox.shrink();
    }
  }
}

// Logs, once per type and in debug builds only, that the catalog has no
// builder for [type], as the app may have taken it out on purpose.
void _logNoBuilder(String type) {
  a2uiDebugLogOnce("The catalog has no builder for the component type '$type', so it draws nothing.");
}

// The scope of [_node] for its builder.
final class _NodeScope extends A2UIComponentScope {
  const _NodeScope(this._node, this._catalog, this._onOpenLink, this._openModal) : super._();

  final A2UINode _node;
  final A2UICatalog _catalog;
  final A2UIOpenLink? _onOpenLink;
  // What opens the sheet of the `Modal` whose trigger holds this component.
  final VoidCallback? _openModal;

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
  // builder. A type without one is logged.
  bool _shows(A2UINode node) {
    if (!node.isResolved) return false;
    if (_catalog[node.type] != null) return true;
    _logNoBuilder(node.type);
    return false;
  }

  @override
  Widget build(A2UIChild child) => A2UINodeView(node: child._node);

  @override
  void write(String name, Object? value) => _node.write(name, value);

  @override
  bool get hasAction => _node.writtenProperty('action') != null;

  @override
  Future<void> performAction() {
    _openModal?.call();
    return _node.act('action', onOpenLink: _onOpenLink);
  }

  @override
  List<String> get validationErrors {
    return [
      for (final failure in _node.failingChecks)
        if (failure.severity == A2UICheckSeverity.error)
          if (failure.message ?? failure.code case final message?) message,
    ];
  }

  @override
  bool get isValid => !_node.failingChecks.any((failure) => failure.severity == A2UICheckSeverity.error);
}

/// The checks of the component [scope] reads that fail now, of every
/// severity, in the order the agent wrote them; see
/// [A2UIComponentScope.validationErrors].
///
/// Internal to the package.
@internal
List<A2UICheckFailure> a2uiCheckFailuresOf(A2UIComponentScope scope) {
  return switch (scope) {
    _NodeScope(:final _node) => _node.failingChecks,
  };
}

/// The accessibility label and description the agent gave the component
/// [scope] reads, each `null` when it gave none or an empty one.
///
/// A component a person interacts with puts them on the part the person
/// interacts with.
///
/// Internal to the package.
@internal
({String? label, String? description}) a2uiAccessibilityOf(A2UIComponentScope scope) {
  return switch (scope) {
    _NodeScope(:final _node) => (
      label: _A2UIAccessibilityState._labelOf(_node),
      description: _A2UIAccessibilityState._descriptionOf(_node),
    ),
  };
}

/// Whether the component [child] holds fills the width it is given, as the
/// basic catalog draws a `TextField`, a `Slider`, a `DateTimeInput` and a
/// `ChoicePicker` with a filter field.
///
/// Internal to the package.
@internal
bool a2uiFillsWidth(A2UIChild child) {
  final node = child._node;
  return switch (node.type) {
    'TextField' || 'Slider' || 'DateTimeInput' => true,
    'ChoicePicker' => _NodeScope._boolean(node.property('filterable')) ?? false,
    _ => false,
  };
}

/// Whether [child] fills the height it is given, as a vertical `Divider`
/// does, so a row gives it the row's height whatever its `align`.
///
/// Internal to the package.
@internal
bool a2uiFillsHeight(A2UIChild child) => child._node.type == 'Divider' && child._node.property('axis') == 'vertical';

/// The type of the component [child] holds, such as `Button`.
///
/// Internal to the package.
@internal
String a2uiTypeOf(A2UIChild child) => child._node.type;

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

  // Components a person interacts with. Their builders put the label and the
  // description on the part the person interacts with, so it is read as one
  // control rather than as a label around a control.
  static const _interactiveTypes = {
    'Button',
    'TextField',
    'CheckBox',
    'ChoicePicker',
    'Slider',
    'DateTimeInput',
    'Modal',
  };

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

  static String? _announcementOf(A2UINode node) => _labelOf(node) ?? a2uiText(node.property('text'));

  static String? _labelOf(A2UINode node) => _nonEmpty(a2uiText(_attributes(node)?['label']));

  static String? _descriptionOf(A2UINode node) => _nonEmpty(a2uiText(_attributes(node)?['description']));

  static String? _nonEmpty(String? text) => text == null || text.isEmpty ? null : text;

  @override
  Widget build(BuildContext context) {
    final hidden = _isHidden(_attributes(widget.node));
    final isInteractive = _interactiveTypes.contains(widget.node.type);
    final label = isInteractive ? null : _labelOf(widget.node);
    final description = isInteractive ? null : _descriptionOf(widget.node);
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
