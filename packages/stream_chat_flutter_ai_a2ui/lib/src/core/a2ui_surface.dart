part of 'a2ui_adapter.dart';

/// One surface of a reply's A2UI: a tree of components drawn from a catalog,
/// and the data model its components read and write.
///
/// Obtained from [A2UIProcessor.surface]. Its components are resolved against
/// its data model as they arrive, and problems in them, such as a type the
/// catalog doesn't have, are reported through the processor's `onError`
/// shortly after.
///
/// It notifies its listeners when its [root] changes, such as when the root
/// component arrives or is replaced. Changes inside the tree notify the
/// [A2UINode]s they affect.
///
/// Its processor owns it: it is disposed when the agent deletes the surface,
/// and when the processor is reset or disposed.
///
/// Internal to the package.
@internal
final class A2UISurface extends ChangeNotifier {
  A2UISurface._(this._model, this._processor) : id = _model.id, _resolver = core.NodeResolver(_model) {
    _errors = _model.onError.subscribe((error) => _processor._report(_errorFromSurface(error)));
    // The signal calls back right away with the current root, which is no
    // change, before anyone can listen.
    _unsubscribeRoot = _resolver.rootNode.subscribe((_) => notifyListeners());
  }

  final core.SurfaceModel<core.ComponentApi> _model;
  final A2UIProcessor _processor;
  final core.NodeResolver<core.ComponentApi> _resolver;
  late final core.Subscription _errors;
  late final void Function() _unsubscribeRoot;
  final Expando<A2UINode> _nodes = Expando();
  bool _disposed = false;

  /// The id the agent gave this surface.
  final String id;

  /// Whether the agent asked for this surface's data model to come back with
  /// the person's actions.
  bool get sendDataModel => _model.sendDataModel;

  /// The resolved component at the root of this surface, or `null` until the
  /// agent has sent a component with the id `root`, and after this surface is
  /// disposed.
  A2UINode? get root {
    if (_disposed) return null;
    final rootNode = _resolver.rootNode.peek();
    if (rootNode == null) return null;
    return _nodeFor(rootNode);
  }

  // The same core node always gives the same node, so listeners stay attached
  // across rebuilds.
  A2UINode _nodeFor(core.ComponentNode<core.ComponentApi> node) => _nodes[node] ??= A2UINode._(node, this);

  /// The value at [path] in this surface's data model, or `null` when there is
  /// none.
  ///
  /// The [path] is a JSON pointer, such as `/form/email`; `/` is the whole
  /// model. A path that can't be read, such as one with a `~` that isn't `~0`
  /// or `~1`, is reported through the processor's `onError` and gives `null`.
  /// After this surface is disposed, every path gives `null`.
  Object? read(String path) {
    if (_disposed) return null;
    try {
      return _plain(_model.dataModel.get(path));
    } on core.A2uiError catch (error) {
      _processor._report(_errorFromCore(error, surfaceId: id));
      return null;
    }
  }

  /// Writes [value] at [path] in this surface's data model, and updates the
  /// components bound to it.
  ///
  /// A `null` [value] clears what is there: a key is removed, and an item of a
  /// list becomes `null`. A [path] that can't be written, such as one below a
  /// string, is reported through the processor's `onError` and changes
  /// nothing.
  void write(String path, Object? value) {
    // A disposed data model can't be written.
    if (_disposed) return;
    try {
      _model.dataModel.set(path, value);
    } on core.A2uiError catch (error) {
      _processor._report(_errorFromCore(error, surfaceId: id));
    }
  }

  void _dispose() {
    if (_disposed) return;
    _disposed = true;
    _errors.unsubscribe();
    _unsubscribeRoot();
    _resolver.dispose();
    dispose();
  }

  @override
  String toString() => '${objectRuntimeType(this, 'A2UISurface')}(id: $id)';
}
