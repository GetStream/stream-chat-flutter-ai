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
    _unsubscribeProperties = _node.props.subscribe((_) => notifyListeners());
    _destroyed = _node.onDestroyed.subscribe((_) => _dispose());
  }

  final core.ComponentNode<core.ComponentApi> _node;
  final A2UISurface _surface;
  late final void Function() _unsubscribeProperties;
  late final core.Subscription _destroyed;
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
  /// An action that names an event reaches the processor's `onAction`. One
  /// that calls a function runs it when the surface's catalog can; a function
  /// it can't run is reported through the processor's `onError`, as is any
  /// other problem. Completes once the action has run, and does nothing when
  /// the property holds no action or this node is disposed, such as when a
  /// button whose surface was just deleted is tapped before it leaves the
  /// screen.
  Future<void> act(String name) async {
    if (_disposed) return;
    final action = _node.props.peek()[name];
    if (action is! Future<void> Function()) return;
    try {
      await action();
    } on core.A2uiError catch (error) {
      _surface._processor._report(_errorFromCore(error, surfaceId: _surface.id));
    }
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
