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
  ///
  /// The `value` of a `TextField` the agent wrote as `obscured` is a secret,
  /// such as a password: what is written there stays on the device, so the
  /// surface's actions, their events and the functions they call read it as
  /// `null`; see [A2UISurface.readWithoutSecrets].
  void write(String name, Object? value) {
    if (_disposed) return;
    final binding = _node.props.peek()[name];
    if (binding is! core.WritableBinding<Object?>) return;
    if (name == 'value' && type == 'TextField' && writtenProperty('variant') == 'obscured') {
      // The binding holds its path as the agent wrote it, which may be
      // relative to the item of a template the field is in.
      final path = _node.context?.dataContext.resolvePath(binding.path) ?? binding.path;
      _surface._secretPaths.add(path);
    }
    try {
      binding.set(value);
    } on core.A2uiError catch (error) {
      _surface._processor._report(_errorFromCore(error, surfaceId: _surface.id));
    }
  }

  /// Runs the action in the property [name], such as a `Button`'s `action`, as
  /// the person's own act.
  ///
  /// An action reads the data model without what the person typed into
  /// obscured fields; see [write]. One that names an event reaches the
  /// processor's `onAction`. One that calls a function runs it when the
  /// surface's catalog can, and otherwise sends it to the agent; a function
  /// that fails is reported through the processor's `onError`, as is any
  /// other problem. Completes once the action has run, and does nothing when
  /// the property holds no action.
  ///
  /// A link the action opens, such as with `openUrl`, goes to [onOpenLink],
  /// and only while the action runs. Without [onOpenLink], the link is
  /// reported as not opened.
  Future<void> act(String name, {A2UIOpenLink? onOpenLink}) async {
    final action = _node.props.peek()[name];
    if (action is! Future<void> Function()) return;
    try {
      await runZoned(
        () => _dispatchWithoutSecrets(name) ?? action(),
        zoneValues: {_openLinkKey: onOpenLink},
      );
    } on core.A2uiError catch (error) {
      _surface._processor._report(_errorFromCore(error, surfaceId: _surface.id));
    }
  }

  // Runs the action in the property [name] with its values read without the
  // surface's secrets, as the core would run it with them, or returns `null`
  // when the core's own action can run: the surface has no secrets, or the
  // action isn't one the core can read, which the core reports. A function
  // the action calls is the agent's to choose, such as a link to open, so it
  // doesn't read the secrets either.
  Future<void>? _dispatchWithoutSecrets(String name) {
    if (_surface._secretPaths.isEmpty) return null;
    final context = _node.context;
    if (context == null) return null;
    final written = writtenProperty(name);
    final call = written is Map<String, Object?> && written['functionCall'] is Map ? written['functionCall'] : written;
    final shared = _surface._dataContext(
      _node.dataPath,
      model: _surface._dataModelWithoutSecrets(),
      // A function no catalog has goes to the agent, as the core sends it.
      callsAgent: true,
    );
    // A function call comes first, as the core reads an action.
    if (context.dataContext.isFunctionCall(call)) return _callWithoutSecrets(shared, call! as Map);
    final resolved =
        shared.resolveAction(written) ??
        (shared.isDataBinding(written) ? shared.resolveAction(shared.resolveDynamicValue(written)) : null);
    if (resolved == null) return null;
    return context.dispatchAction(resolved);
  }

  // Runs [call] in [shared] as the person's own act, reporting a failure as
  // the core reports one of an action's function: on the surface, or on the
  // agent's function call when the agent's answer failed.
  Future<void> _callWithoutSecrets(core.DataContext shared, Map<Object?, Object?> call) async {
    try {
      await shared.withUserActivation().evaluateFunctionCall(Map<String, Object?>.from(call));
    } catch (error) {
      final functionCallId = error is core.A2uiRpcError ? error.functionCallId : null;
      await _surface._model.dispatchError(
        core.A2uiRendererError(
          code: A2UIErrorCode.executionError,
          surfaceId: functionCallId == null ? _surface.id : null,
          functionCallId: functionCallId,
          message: "Function '${call['@call'] ?? call['call']}' failed in component '$id': $error",
        ),
      );
    }
  }

  /// The checks of this node's component that fail now, in the order the
  /// agent wrote them.
  ///
  /// A check whose condition reads nothing yet passes, so a form isn't
  /// blocked while its data arrives. One whose condition can't be evaluated,
  /// such as one calling a function that fails, fails with its own message,
  /// or "This value could not be checked.". Otherwise a failing check gives
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
    // they are only counted here.
    var failures = 0;
    final context = _surface._dataContext(
      _node.dataPath,
      model: _surface._model.dataModel,
      onError: (_) => failures += 1,
    );
    return List.unmodifiable(_failingChecksOf(rules, context, () => failures));
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
