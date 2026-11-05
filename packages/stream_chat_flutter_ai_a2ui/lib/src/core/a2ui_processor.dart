part of 'a2ui_adapter.dart';

/// Signature for the callback that receives the [A2UIActionEvent]s of a
/// processor's surfaces.
typedef A2UIActionCallback = void Function(A2UIActionEvent event);

/// Signature for the callback that receives the [A2UIError]s a processor
/// finds.
typedef A2UIErrorCallback = void Function(A2UIError error);

/// Signature for the callback that receives what a processor sends the agent,
/// as A2UI writes it.
///
/// Only the conformance tests use it.
typedef A2UIDebugOutboundCallback = void Function(Map<String, Object?> message);

/// One reply's A2UI surfaces, built from the messages applied to it.
///
/// A reply's agent writes A2UI as a series of messages: one creates a surface,
/// others add components to it, fill its data model, or delete it. The [apply]
/// method takes the messages in the order they were written, as
/// [A2UIStream.messages] finds them in the reply. Each message counts on its own: one that can't be
/// applied is skipped, and the messages after it still apply.
///
/// It notifies its listeners when its surfaces change: one is created or
/// deleted, or replaced by another of the same id. A surface's own changes,
/// such as a new root component, notify that [A2UISurface].
///
/// It reads A2UI 1.0 only; see [A2UIVersions].
///
/// ```dart
/// final processor = A2UIProcessor(
///   catalogs: catalogs,
///   onAction: (event) => send(event),
///   onError: (error) => report(error),
/// );
/// processor.apply(A2UIStream.messages(document.content));
/// final surface = processor.surface(processor.surfaceIds.first);
/// ```
///
/// Its creator owns it and calls [dispose] when the reply goes away.
///
/// Internal to the package.
@internal
final class A2UIProcessor extends ChangeNotifier {
  /// Creates a processor with no surfaces, which draws them from `catalogs`.
  ///
  /// A surface that names no catalog, or names it with something other than a
  /// string, is drawn from the app's catalog, [A2UICatalogs.catalogId].
  ///
  /// When a person acts in one of its surfaces in a way the agent should hear
  /// about, such as tapping a button whose action names an event, the event
  /// goes to `onAction`.
  ///
  /// Each distinct problem A2UI reports goes to `onError` once, such as a
  /// message of another version or a component its catalog doesn't have, and
  /// isn't reported again until [reset]. Problems with a message are reported
  /// while [apply] runs. Problems found later, as a surface's components are
  /// resolved or as a surface or node reads, writes or acts, are reported
  /// then.
  ///
  /// A text given to [apply] that isn't a JSON object is skipped and goes to
  /// `onUnreadable` instead of `onError`.
  ///
  /// None of the three is called after [dispose].
  A2UIProcessor({required this._catalogs, this._onAction, this._onError, this._onUnreadable})
    : _defaultsCatalog = true,
      _debugChecks = null,
      _debugOnOutbound = null {
    _core = _makeCore();
  }

  /// Creates a processor as a conformance case needs one: one that gives a
  /// surface naming no catalog none, makes `checks` of each message, and
  /// passes what it sends the agent to `onOutbound`, such as the answer to a
  /// function the agent calls.
  ///
  /// Only the conformance tests use it.
  A2UIProcessor.debug({
    required this._catalogs,
    this._onAction,
    this._onError,
    A2UIDebugChecks? checks,
    A2UIDebugOutboundCallback? onOutbound,
  }) : _onUnreadable = null,
       _defaultsCatalog = false,
       _debugChecks = checks,
       _debugOnOutbound = onOutbound {
    _core = _makeCore();
  }

  final A2UICatalogs _catalogs;
  final A2UIActionCallback? _onAction;
  final A2UIErrorCallback? _onError;
  final VoidCallback? _onUnreadable;
  final bool _defaultsCatalog;
  final A2UIDebugChecks? _debugChecks;
  final A2UIDebugOutboundCallback? _debugOnOutbound;

  late core.MessageProcessor<core.ComponentApi> _core;
  final List<core.Subscription> _coreSubscriptions = [];
  final Map<String, A2UISurface> _surfaces = {};
  final Set<(String, String, String?, String?)> _reported = {};
  bool _disposed = false;

  // The version string the core reads A2UI 1.0 messages by.
  static const _coreVersion = 'v1.0';

  /// The ids of this processor's surfaces, in the order they were created.
  List<String> get surfaceIds => List.unmodifiable(_surfaces.keys);

  /// The surface with [surfaceId], or `null` when this processor has none by
  /// that id.
  A2UISurface? surface(String surfaceId) => _surfaces[surfaceId];

  /// Applies [messages], each the JSON text of one A2UI message, in order.
  ///
  /// A message may also be an object with a `messages` list in place of a
  /// message key, as A2UI writes a batch; each message in the list is applied
  /// on its own.
  ///
  /// A text that isn't a JSON object is skipped (see `onUnreadable`). A message
  /// with no `version`, or with one this package doesn't read, or that its
  /// surfaces can't take, is reported and skipped; see [A2UIVersions.check]
  /// for the versions read and the message keys. Anything else that goes
  /// wrong applying a message is reported with [FlutterError.reportError], and
  /// the messages after it still apply.
  ///
  /// Notifies listeners once, after the last message, if the surfaces changed.
  void apply(List<String> messages) {
    assert(!_disposed, 'A2UIProcessor.apply was called after dispose.');
    if (_disposed) return;
    final before = [..._surfaces.values];
    for (final text in messages) {
      _applyText(text);
      // A callback may have disposed this processor.
      if (_disposed) return;
    }
    if (!_isSame(before)) notifyListeners();
  }

  bool _isSame(List<A2UISurface> before) {
    if (before.length != _surfaces.length) return false;
    var index = 0;
    for (final surface in _surfaces.values) {
      if (!identical(surface, before[index])) return false;
      index += 1;
    }
    return true;
  }

  void _applyText(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      _onUnreadable?.call();
      return;
    }
    if (decoded is! Map<String, Object?>) {
      _onUnreadable?.call();
      return;
    }
    if (decoded case {'messages': final List<Object?> batch} when !_namesAMessage(decoded)) {
      for (final (index, item) in batch.indexed) {
        _applyBatchItem(index, item);
        // Messages applied to a disposed core would leave surfaces in it that
        // nothing disposes.
        if (_disposed) return;
      }
      return;
    }
    _applyMessage(decoded);
  }

  // A batch item that isn't an object is a malformed batch, which A2UI reports.
  // The error names the item, so the items of one batch are told apart.
  void _applyBatchItem(int index, Object? item) {
    if (item is Map<String, Object?>) {
      _applyMessage(item);
      return;
    }
    _report(
      A2UIError(
        code: A2UIErrorCode.validationFailed,
        message: "Item ${index + 1} of the A2UI batch isn't an object: it is ${_jsonKind(item)}.",
        path: '',
      ),
    );
  }

  static String _jsonKind(Object? value) {
    return switch (value) {
      null => 'null',
      String() => 'a string',
      num() => 'a number',
      bool() => 'a boolean',
      List<Object?>() => 'a list',
      _ => 'a ${value.runtimeType}',
    };
  }

  static bool _namesAMessage(Map<String, Object?> json) {
    for (final key in _messageKeys) {
      if (json.containsKey(key)) return true;
    }
    return false;
  }

  void _applyMessage(Map<String, Object?> message) {
    switch (A2UIVersions.check(message)) {
      case A2UIRejectedEnvelope(:final error):
        _report(error);
      case A2UIAcceptedEnvelope(:final message):
        try {
          // One message in a list, so a `messages` field beside its message key
          // isn't taken for a batch.
          _core.processMessages([_forCore(message)]);
        } on core.A2uiError catch (error) {
          _report(_errorFromCore(error, message: message));
        } catch (error, stack) {
          // Anything else is a fault of the core rather than of the message,
          // so it isn't reported as A2UI. The messages after it still apply.
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'stream_chat_flutter_ai_a2ui',
              context: ErrorDescription('while applying an A2UI message'),
            ),
          );
        }
    }
  }

  Map<String, Object?> _forCore(Map<String, Object?> message) {
    final createSurface = message['createSurface'];
    if (_defaultsCatalog && createSurface is Map<String, Object?> && createSurface['catalogId'] is! String) {
      return {
        ...message,
        'version': _coreVersion,
        'createSurface': {...createSurface, 'catalogId': _catalogs.catalogId},
      };
    }
    return {...message, 'version': _coreVersion};
  }

  /// Removes every surface, as if no message had been applied, so the messages
  /// can be applied again from the start.
  ///
  /// Problems reported before are reported again when they happen again.
  /// Notifies listeners if there were surfaces.
  void reset() {
    assert(!_disposed, 'A2UIProcessor.reset was called after dispose.');
    if (_disposed) return;
    final hadSurfaces = _surfaces.isNotEmpty;
    final surfaces = _releaseCore();
    _reported.clear();
    _core = _makeCore();
    _disposeSurfaces(surfaces);
    if (hadSurfaces) notifyListeners();
  }

  core.MessageProcessor<core.ComponentApi> _makeCore() {
    final onOutbound = _debugOnOutbound;
    final processor = core.MessageProcessor<core.ComponentApi>(
      catalogs: _catalogs._catalogs,
      validationConfig: _debugChecks?._config,
      onAction: _handleAction,
      outboundListener: onOutbound == null
          ? null
          : (message) => onOutbound(_fromCoreVersion(_plainMap(message.toJson()))),
    );
    _coreSubscriptions
      ..add(processor.model.onSurfaceCreated.subscribe(_handleSurfaceCreated))
      ..add(processor.model.onSurfaceDeleted.subscribe(_handleSurfaceDeleted));
    return processor;
  }

  void _handleSurfaceCreated(core.SurfaceModel<core.ComponentApi> model) {
    _surfaces[model.id] = A2UISurface._(model, this);
  }

  void _handleSurfaceDeleted(String surfaceId) {
    _surfaces.remove(surfaceId)?._dispose();
  }

  void _handleAction(core.A2uiRendererAction action) {
    // An action that was still running when this processor was disposed.
    if (_disposed) return;
    _onAction?.call(
      A2UIActionEvent(
        name: action.name,
        surfaceId: action.surfaceId,
        sourceComponentId: action.sourceComponentId,
        context: _plainMap(action.context),
        userMessage: action.userMessage,
      ),
    );
  }

  // Reports [error] unless it was reported already, since a surface finds the
  // same problem each time its components are resolved again.
  void _report(A2UIError error) {
    if (_disposed) return;
    if (!_reported.add((error.code, error.message, error.surfaceId, error.path))) return;
    _onError?.call(error);
  }

  // Leaves this processor without surfaces and returns them, still to be
  // disposed, so that a listener of one of them already sees the processor in
  // its new state.
  List<A2UISurface> _releaseCore() {
    for (final subscription in _coreSubscriptions) {
      subscription.unsubscribe();
    }
    _coreSubscriptions.clear();
    final surfaces = [..._surfaces.values];
    _surfaces.clear();
    _core.dispose();
    return surfaces;
  }

  static void _disposeSurfaces(List<A2UISurface> surfaces) {
    for (final surface in surfaces) {
      surface._dispose();
    }
  }

  /// Releases the surfaces and stops calling `onAction`, `onError` and
  /// `onUnreadable`.
  ///
  /// The processor's creator calls it when the reply goes away.
  @override
  void dispose() {
    _disposed = true;
    _disposeSurfaces(_releaseCore());
    super.dispose();
  }

  @override
  String toString() => '${objectRuntimeType(this, 'A2UIProcessor')}(surfaceIds: $surfaceIds)';
}

Map<String, Object?> _plainMap(Map<Object?, Object?> map) {
  return Map<String, Object?>.unmodifiable({
    for (final entry in map.entries) '${entry.key}': _plain(entry.value),
  });
}

// The value as plain JSON, unmodifiable, so what leaves the adapter can't reach
// back into the core's state.
Object? _plain(Object? value) {
  return switch (value) {
    final core.ValidationResult result => _plainMap(result.toJson()),
    final Map<Object?, Object?> map => _plainMap(map),
    final List<Object?> list => List<Object?>.unmodifiable(list.map(_plain)),
    _ => value,
  };
}
