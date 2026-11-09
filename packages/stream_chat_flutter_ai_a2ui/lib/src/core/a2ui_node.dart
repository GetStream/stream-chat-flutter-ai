part of 'a2ui_adapter.dart';

/// A component of a surface, resolved against the surface's data model: its
/// properties hold values rather than bindings.
///
/// Obtained from [A2UISurface.root], from the [children] of a node, and from
/// inside its [property] values. It notifies its listeners when its own
/// properties change, including when a child that was on its way arrives;
/// changes inside a child notify that child.
///
/// A node is disposed when its component leaves the tree, such as when the
/// agent replaces it or deletes its surface. A disposed node has no properties
/// or children, and writes and acts on nothing.
///
/// Internal to the package.
@internal
final class A2UINode extends ChangeNotifier {
  A2UINode._(this._node, this._surface) {
    // The signal calls back right away with the current properties, which is
    // no change, before anyone can listen.
    _unsubscribeProperties = _node.props.subscribe((_) {
      _failingChecks = null;
      notifyListeners();
    });
    _destroyed = _node.onDestroyed.subscribe((_) => _dispose());
  }

  final core.ComponentNode<core.ComponentApi> _node;
  final A2UISurface _surface;
  late final void Function() _unsubscribeProperties;
  late final core.Subscription _destroyed;
  // The checks that failed when last read, until the properties change.
  List<A2UICheckFailure>? _failingChecks;
  // The keys of the problems [reportOnce] has reported.
  final Set<String> _reported = {};
  bool _disposed = false;

  /// The id of this node's component, as the agent wrote it.
  String get id => _node.componentId;

  /// A key that tells apart the nodes of one component, such as the items of a
  /// list drawn from one template.
  String get key => _node.instanceId;

  /// The type of this node's component, such as `Text` or `Button`.
  String get type => _node.type;

  /// Whether this node's component is ready to draw: `false` while it is still
  /// on its way, when its catalog doesn't have its type, or when it would hold
  /// itself.
  bool get isResolved => _node.state == core.NodeState.resolved;

  /// The value of the property [name], with bindings read from the data model,
  /// or `null` when the component doesn't set it.
  ///
  /// The value can't be changed. Components inside it, such as the `child` of
  /// each of a `Tabs`'s `tabs`, are [A2UINode]s. An action gives `null`; it is
  /// run with [act].
  Object? property(String name) {
    if (_disposed) return null;
    return _value(_node.props.peek()[name]);
  }

  /// The property [name] as the agent wrote it, with bindings and function
  /// calls unread, or `null` when the component doesn't set it.
  Object? writtenProperty(String name) {
    if (_disposed) return null;
    return _surface._model.componentsModel.get(id)?.properties[name];
  }

  Object? _value(Object? value) {
    return switch (value) {
      final core.ResolvedBinding<Object?> binding => _plain(binding.value),
      final core.ComponentNode<core.ComponentApi> node => _surface._nodeFor(node),
      final Map<Object?, Object?> map => Map<String, Object?>.unmodifiable({
        for (final entry in map.entries) '${entry.key}': _value(entry.value),
      }),
      final List<Object?> list => List<Object?>.unmodifiable(list.map(_value)),
      final Function _ => null,
      _ => _plain(value),
    };
  }

  /// The nodes the property [name] holds, such as a `Column`'s `children` or a
  /// `Card`'s `child`, in order, or an empty list when it holds none.
  List<A2UINode> children(String name) {
    if (_disposed) return const [];
    return switch (_node.props.peek()[name]) {
      final core.ComponentNode<core.ComponentApi> node => [_surface._nodeFor(node)],
      final List<Object?> list => [
        for (final item in list)
          if (item is core.ComponentNode<core.ComponentApi>) _surface._nodeFor(item),
      ],
      _ => const [],
    };
  }

  /// Whether the property [name] is bound to the data model, so [write] can
  /// change it.
  bool canWrite(String name) {
    if (_disposed) return false;
    return _node.props.peek()[name] is core.WritableBinding<Object?>;
  }

  /// Writes [value] to the data model path the property [name] is bound to,
  /// which updates every component bound to that path.
  ///
  /// Does nothing when the property isn't bound; see [canWrite]. A path that
  /// can't be written, such as one below a string, is reported through the
  /// processor's `onError` and changes nothing.
  void write(String name, Object? value) {
    if (_disposed) return;
    final binding = _node.props.peek()[name];
    if (binding is! core.WritableBinding<Object?>) return;
    try {
      binding.set(value);
    } on core.A2uiError catch (error) {
      _surface._processor._report(_errorFromCore(error, surfaceId: _surface.id));
    }
    _surface._processor._checkSize(_surface.id);
  }

  /// Reports [message], a problem with what the agent wrote for this node's
  /// component, through the processor's `onError` as a `VALIDATION_FAILED`
  /// that names the component, once for each [key] while the node lasts.
  ///
  /// The report goes out after the build that found the problem, as the app
  /// may rebuild in its `onError`.
  void reportOnce(String key, String message) {
    if (_disposed || !_reported.add(key)) return;
    scheduleMicrotask(() {
      if (_disposed) return;
      _surface._processor._report(
        A2UIError(
          code: A2UIErrorCode.validationFailed,
          message: "Component '$id' of type '$type': $message",
          surfaceId: _surface.id,
        ),
      );
    });
  }

  /// Reports [error], which the builder of this component threw, through the
  /// processor's `onError` as an `EXECUTION_ERROR` that names the component.
  void reportBuildError(Object error) {
    if (_disposed) return;
    _surface._processor._report(
      A2UIError(
        code: A2UIErrorCode.executionError,
        message: "Building component '$id' of type '$type' failed: $error",
        surfaceId: _surface.id,
      ),
    );
  }

  /// Runs the action in the property [name], such as a `Button`'s `action`, as
  /// the person's own act.
  ///
  /// An action that names an event reaches the processor's `onAction`, with
  /// the values it asks for read from the data model, as the agent wrote the
  /// surface to send them. One that calls a function runs it when the
  /// surface's catalog can, and otherwise sends it to the agent. A function
  /// that fails is reported through the processor's `onError`, as is any
  /// other problem, so this doesn't throw. Completes once the action has run,
  /// and does nothing when the property holds no action or this node is
  /// disposed, such as when a button whose surface was just deleted is tapped
  /// before it leaves the screen.
  ///
  /// A link the action opens, such as with `openUrl`, goes to [onOpenLink],
  /// and only while the action runs. Without [onOpenLink], the link is
  /// reported as not opened. A function no catalog has that the action calls
  /// reaches the processor's `onAgentFunction` as the person's own act, as
  /// does one the action sends only once the calls in its arguments answered.
  Future<void> act(String name, {A2UIOpenLink? onOpenLink}) async {
    if (_disposed) return;
    final action = _node.props.peek()[name];
    if (action is! Future<void> Function()) return;
    try {
      // The flag follows every await of the action, so a call the core sends
      // only once the calls in its arguments answered is the person's act too.
      await runZoned(action, zoneValues: {_openLinkKey: onOpenLink, _userActKey: true});
    } catch (error) {
      if (_errorFromAct(error, surfaceId: _surface.id, componentId: id) case final error?) {
        _surface._processor._report(error);
      }
    }
  }

  /// The checks of this node's component that fail now, in the order the
  /// agent wrote them.
  ///
  /// A check whose condition reads nothing yet passes, so a form isn't
  /// blocked while its data arrives, as does one waiting for the agent's
  /// answer to a function it calls. One whose condition can't be evaluated,
  /// such as one calling a function that fails, fails with its own message,
  /// or "This value could not be checked.", as does one whose result is
  /// neither a boolean nor a result with one, which is reported through the
  /// processor's `onError`. Otherwise a failing check gives
  /// its own message ahead of the one of the function its condition calls;
  /// a result read from the data model gives the result's message ahead of
  /// the check's. A disposed node has no failing checks.
  List<A2UICheckFailure> get failingChecks {
    if (_disposed) return const [];
    return _failingChecks ??= _evaluateChecks();
  }

  List<A2UICheckFailure> _evaluateChecks() {
    final rules = writtenProperty('checks');
    if (rules == null) return const [];
    // The core evaluates the same conditions and reports their problems, so
    // they are only counted here. It also sends a function no catalog has to
    // the agent, and its answer is read from there.
    var failures = 0;
    final context = _surface._dataContext(
      _node.dataPath,
      onError: (_) => failures += 1,
      parent: _node.context?.dataContext,
    );
    return List.unmodifiable(_failingChecksOf(rules, context, () => failures, onMalformed: _reportMalformedCheck));
  }

  // Reports a check whose result [value] can't be read as passing or failing,
  // after the build that read it.
  void _reportMalformedCheck(Object? value) {
    scheduleMicrotask(() {
      if (_disposed) return;
      _surface._processor._report(
        A2UIError(
          code: A2UIErrorCode.validationFailed,
          message: "A check of component '$id' gave ${value.runtimeType}, not a boolean or a result with one.",
          surfaceId: _surface.id,
        ),
      );
    });
  }

  void _dispose() {
    if (_disposed) return;
    _disposed = true;
    _unsubscribeProperties();
    _destroyed.unsubscribe();
    dispose();
  }

  @override
  String toString() => '${objectRuntimeType(this, 'A2UINode')}(id: $id, type: $type)';
}
