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
/// A surface whose components would expand to more than 5,000, counting a
/// component once for each place it shows and a template's once for each item
/// of its list, or would nest more than 50 levels deep, has no [root] until a
/// message from the agent or a [write] to its data makes it fit; the processor
/// reports it once as `RECURSION_LIMIT_EXCEEDED`. A [write] is checked too, so
/// one that grows a templated list past the limit takes the [root] away.
///
/// Its processor owns it: it is disposed when the agent deletes the surface,
/// and when the processor is reset or disposed. When the agent deletes it, or
/// the processor is reset, it first notifies its listeners that its [root] is
/// gone.
///
/// Internal to the package.
@internal
final class A2UISurface extends ChangeNotifier {
  A2UISurface._(this._model, this._processor, {required bool isTooLarge}) : id = _model.id {
    // A failed call in a binding names its call and no surface.
    _errors = _model.onError.subscribe(
      (error) => _processor._report(
        _errorFromSurface(error, surfaceId: id),
        dedupe: error.functionCallId == null,
      ),
    );
    if (!isTooLarge) _buildTree();
  }

  final core.SurfaceModel<core.ComponentApi> _model;
  final A2UIProcessor _processor;
  late final core.Subscription _errors;
  // The resolved tree, or `null` while the surface is past a limit of
  // `_expansionLimit` and can't be built.
  core.NodeResolver<core.ComponentApi>? _resolver;
  void Function()? _unsubscribeRoot;
  final Expando<A2UINode> _nodes = Expando();
  bool _disposed = false;

  // Whether this surface had a root when it stopped following the core's
  // surface, or `null` while it follows it.
  bool? _hadRootWhenDetached;

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
    final rootNode = _resolver?.rootNode.peek();
    if (rootNode == null) return null;
    return _nodeFor(rootNode);
  }

  // Whether the tree isn't built, because the surface is past a limit of
  // `_expansionLimit`.
  bool get _isTooLarge => _resolver == null;

  void _buildTree() {
    final resolver = _resolver = core.NodeResolver(_model);
    // The signal calls back right away with the current root, which is no
    // change.
    var current = true;
    _unsubscribeRoot = resolver.rootNode.subscribe((_) {
      if (!current) notifyListeners();
    });
    current = false;
  }

  // Releases the tree, so a message that would make it too large doesn't
  // build it. Notifies listeners when there was a root.
  void _releaseTree() {
    final resolver = _resolver;
    if (resolver == null) return;
    final hadRoot = resolver.rootNode.peek() != null;
    _unsubscribeRoot?.call();
    _unsubscribeRoot = null;
    _resolver = null;
    resolver.dispose();
    if (hadRoot) notifyListeners();
  }

  // Builds the tree again once the surface is within the limits of
  // `_expansionLimit` again. Notifies listeners when it has a root.
  void _restoreTree() {
    if (!_isTooLarge) return;
    _buildTree();
    if (_resolver?.rootNode.peek() != null) notifyListeners();
  }

  // The components the agent sent, as it wrote them, by id.
  Map<String, Map<String, Object?>> _componentsById() {
    return {
      for (final component in _model.componentsModel.all)
        component.id: {
          ...component.properties,
          'component': component.type,
          if (component.catalog case final catalog?) 'catalogId': catalog,
        },
    };
  }

  // The value at [path] in the data model, or `null` when there is none or
  // the path can't be read.
  Object? _readData(String path) {
    try {
      return _model.dataModel.get(path);
    } on core.A2uiError {
      return null;
    }
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

  /// The value of the text the button `componentId` shows, or `null` when
  /// it shows none that can be read here.
  ///
  /// The text is the `text` of the component the button's `child` names:
  /// what the agent wrote, or what it is bound to at an absolute path of the
  /// data model. A path relative to a template's item and a function call
  /// give `null`, as does a button whose child isn't there, and so does a
  /// path that holds, is in or is what an `obscured` `TextField` writes, so
  /// a secret the person typed never becomes the button's text.
  Object? buttonTextOf(String componentId) {
    if (_disposed) return null;
    final components = _model.componentsModel;
    final childId = components.get(componentId)?.properties['child'];
    if (childId is! String) return null;
    return switch (components.get(childId)?.properties['text']) {
      {'@path': final String path} when path.startsWith('/') => _readsSecret(path) ? null : read(path),
      final Map<Object?, Object?> _ => null,
      final text => _plain(text),
    };
  }

  // Whether reading the absolute [path] reads what an `obscured` `TextField`
  // of this surface writes: the same path, one that holds it, or one in it.
  bool _readsSecret(String path) {
    final read = _withoutTrailingSlash(path);
    for (final component in _model.componentsModel.values) {
      if (component.type != 'TextField' || component.properties['variant'] != 'obscured') continue;
      final secret = switch (component.properties['value']) {
        {'@path': final String path} when path.startsWith('/') => _withoutTrailingSlash(path),
        _ => null,
      };
      if (secret == null) continue;
      if (read == secret || secret.startsWith('$read/') || read.startsWith('$secret/')) return true;
    }
    return false;
  }

  static String _withoutTrailingSlash(String path) => path.endsWith('/') ? path.substring(0, path.length - 1) : path;

  // A context that reads this surface's data model at [path] as a component
  // of this surface reads it, with problems going to [onError]. A function no
  // catalog has is read from the agent calls [parent], a component's own
  // context, already made, and isn't sent to the agent again.
  core.DataContext _dataContext(
    String path, {
    required core.ExpressionErrorReporter onError,
    core.DataContext? parent,
  }) {
    return core.DataContext(
      _model.dataModel,
      (name, args, context) => _model.resolveCatalog(null).invoke(name, args, context),
      path,
      onError: onError,
      protocolVersion: core.A2uiProtocolVersion.v1_0,
      invokerForCatalog: (catalogId) => _model.resolveCatalog(catalogId).invoke,
      parent: parent,
      // The core's own reading of the same bindings reports missing data.
      onMissingData: (_) {},
    );
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
    _processor._checkSize(id);
  }

  // Stops following the root of the core's surface, which the core is about
  // to dispose.
  void _detach() {
    _hadRootWhenDetached = root != null;
    _unsubscribeRoot?.call();
    _unsubscribeRoot = null;
  }

  // Releases this surface. When [notify] is true, listeners hear first that
  // its root is gone, so a view of a surface the agent deleted shows nothing.
  void _dispose({required bool notify}) {
    if (_disposed) return;
    final hadRoot = _hadRootWhenDetached ?? root != null;
    _disposed = true;
    _errors.unsubscribe();
    _unsubscribeRoot?.call();
    _resolver?.dispose();
    if (notify && hadRoot) notifyListeners();
    dispose();
  }

  @override
  String toString() => '${objectRuntimeType(this, 'A2UISurface')}(id: $id)';
}
