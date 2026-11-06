part of 'a2ui_adapter.dart';

/// Signature for the callback that receives the [A2UIActionEvent]s of a
/// processor's surfaces.
typedef A2UIActionCallback = void Function(A2UIActionEvent event);

/// Signature for the callback that receives the [A2UIError]s a processor
/// finds.
typedef A2UIErrorCallback = void Function(A2UIError error);

/// Signature for the callback that opens a link a person's action opens, such
/// as one an agent's `openUrl` names.
typedef A2UIOpenLink = void Function(Uri link);

// The zone value through which a running action reaches its [A2UIOpenLink].
final _openLinkKey = Object();

/// Signature for the callback that receives what a processor sends the agent,
/// as A2UI writes it.
///
/// Only the conformance tests use it.
typedef A2UIDebugOutboundCallback = void Function(Map<String, Object?> message);

/// Signature for a function that makes the A2UI core a processor applies
/// messages with, holding `catalogs` and sending its actions to `onAction`.
///
/// Only tests use it, to stand in a core that fails.
typedef A2UIDebugCoreFactory =
    core.MessageProcessor<core.ComponentApi> Function(
      List<core.Catalog<core.ComponentApi, core.FunctionImplementation>> catalogs,
      void Function(core.A2uiRendererAction action) onAction,
    );

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
  /// A function a surface calls that no catalog has, such as one of the app's
  /// tools, goes to `onAgentFunction`, and what it completes with is the
  /// function's value where the surface uses it; a failure is reported through
  /// `onError` as `EXPRESSION_ERROR`. Without `onAgentFunction`, such a
  /// function is missing, and is reported the same way. A call whose surface
  /// is deleted before it is answered is dropped without a report, as is an
  /// answer that arrives after [reset] or [dispose].
  ///
  /// None of the four is called after [dispose].
  ///
  /// None of the four may throw: one that does stops [apply] partway, and
  /// leaves the problem it was given marked as reported. Its creator runs app
  /// code behind its own guard, as the engine does.
  ///
  /// A test can pass a `debugCoreFactory` to make the core it applies messages
  /// with.
  A2UIProcessor({
    required this._catalogs,
    this._onAction,
    this._onError,
    this._onUnreadable,
    this._onAgentFunction,
    @visibleForTesting this._debugCoreFactory,
  }) : _defaultsCatalog = true,
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
       _onAgentFunction = null,
       _debugCoreFactory = null,
       _defaultsCatalog = false,
       _debugChecks = checks,
       _debugOnOutbound = onOutbound {
    _core = _makeCore();
  }

  final A2UICatalogs _catalogs;
  final A2UIActionCallback? _onAction;
  final A2UIErrorCallback? _onError;
  final VoidCallback? _onUnreadable;
  final A2UIAgentFunctionCallback? _onAgentFunction;
  final A2UIDebugCoreFactory? _debugCoreFactory;
  final bool _defaultsCatalog;
  final A2UIDebugChecks? _debugChecks;
  final A2UIDebugOutboundCallback? _debugOnOutbound;

  late core.MessageProcessor<core.ComponentApi> _core;
  final List<core.Subscription> _coreSubscriptions = [];
  final Map<String, A2UISurface> _surfaces = {};
  final Set<(String, String, String?, String?)> _reported = {};
  // The surface the message being applied creates too large to build, if any.
  // The core creates a surface from inside `processMessages`, and tells this
  // processor of it with no way to say it is too large, so it is said here.
  String? _tooLargeSurfaceId;
  // How many of the person's own acts are running their synchronous part
  // now, which is when the core sends the functions they call.
  var _userActs = 0;
  bool _disposed = false;

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
    // Messages that arrive while the person's act runs, such as from the app's
    // code that the act calls, aren't the person's act.
    final userActs = _userActs;
    _userActs = 0;
    try {
      for (final text in messages) {
        _applyText(text);
        // A callback may have disposed this processor.
        if (_disposed) return;
      }
    } finally {
      _userActs = userActs;
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
        final forCore = _forCore(message);
        final surfaceId = _sizedSurfaceId(forCore);
        if (surfaceId != null) _holdTreeIfTooLarge(forCore, surfaceId);
        try {
          // One message in a list, so a `messages` field beside its message key
          // isn't taken for a batch.
          _core.processMessages([forCore]);
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
        } finally {
          _tooLargeSurfaceId = null;
          // Also when the core throws something else, so a tree held back
          // above is built again, or reported, either way.
          if (surfaceId != null) _checkSize(surfaceId);
        }
    }
  }

  // Keeps the tree of surface [surfaceId] from being built while the core
  // applies [message], when the surface would then expand past a limit (see
  // [_expansionLimit]): the core builds every component of the tree as it
  // applies a message. A surface the message creates is created without its
  // tree.
  void _holdTreeIfTooLarge(Map<String, Object?> message, String surfaceId) {
    final existing = message.containsKey('createSurface') ? null : _surfaces[surfaceId];
    if (_expansionAfter(message, existing) == null) return;
    if (existing == null) {
      _tooLargeSurfaceId = surfaceId;
    } else {
      existing._releaseTree();
    }
  }

  // Why the surface [message] changes can't be built once the message is
  // applied to [existing], or to a new surface when [existing] is `null`.
  _Expansion? _expansionAfter(Map<String, Object?> message, A2UISurface? existing) {
    final payload =
        (message['createSurface'] ?? message['updateComponents'] ?? message['updateDataModel'])!
            as Map<String, Object?>;
    final components = {
      ...?existing?._componentsById(),
      if (payload['components'] case final List<Object?> added)
        for (final component in added)
          if (component case {'id': final String id}) id: component as Map<String, Object?>,
    };
    final payloadCatalogId = payload['catalogId'];
    final catalogId = existing?._model.defaultCatalog?.id ?? (payloadCatalogId is String ? payloadCatalogId : null);
    final Object? Function(String path) read;
    if (existing == null) {
      read = _dataReader(() => core.DataModel(payload['dataModel']));
    } else if (message.containsKey('updateDataModel')) {
      final path = payload['path'];
      read = _dataReader(
        () => core.DataModel(existing._model.dataModel.get('/'))..set(path is String ? path : '/', payload['value']),
      );
    } else {
      read = existing._readData;
    }
    return _expansionLimit(
      components,
      (componentCatalogId) => _catalogs._refsOf(componentCatalogId ?? catalogId),
      rootId: 'root',
      read: read,
    );
  }

  // Reads the data model [build] makes, which it only makes when a template
  // needs it. When it can't be made, the core rejects the message too, and
  // nothing is read.
  static Object? Function(String path) _dataReader(core.DataModel Function() build) {
    core.DataModel? data;
    var failed = false;
    return (path) {
      if (failed) return null;
      try {
        data ??= build();
      } on core.A2uiError {
        failed = true;
        return null;
      }
      try {
        return data!.get(path);
      } on core.A2uiError {
        return null;
      }
    };
  }

  // Releases or builds the tree of surface [surfaceId] after a message
  // changed it, by whether it can now be built, and reports a surface that
  // can't.
  void _checkSize(String surfaceId) {
    final surface = _surfaces[surfaceId];
    if (surface == null) return;
    final limit = _expansionLimit(
      surface._componentsById(),
      (catalogId) => _catalogs._refsOf(catalogId ?? surface._model.defaultCatalog?.id),
      rootId: 'root',
      read: surface._readData,
    );
    if (limit == null) {
      surface._restoreTree();
      return;
    }
    surface._releaseTree();
    _report(
      A2UIError(
        code: A2UIErrorCode.recursionLimitExceeded,
        message: switch (limit) {
          _TooManyComponents() =>
            "Surface '$surfaceId' expands to more than $_maxExpandedComponents components. "
                'A component listed as a child more than once, or a template inside a template, multiplies the '
                'components under it.',
          _NestedTooDeep(:final id) => "Component nesting exceeded $_maxDepth levels at '$id'.",
        },
        surfaceId: surfaceId,
      ),
    );
  }

  // The id of the surface [message] adds components or data to, or `null`
  // when it adds neither.
  static String? _sizedSurfaceId(Map<String, Object?> message) {
    final payload = switch (message) {
      {'createSurface': final Map<String, Object?> payload} when payload['components'] is List<Object?> => payload,
      {'updateComponents': final Map<String, Object?> payload} when payload['components'] is List<Object?> => payload,
      {'updateDataModel': final Map<String, Object?> payload} => payload,
      _ => null,
    };
    final surfaceId = payload?['surfaceId'];
    return surfaceId is String ? surfaceId : null;
  }

  Map<String, Object?> _forCore(Map<String, Object?> message) {
    final createSurface = message['createSurface'];
    if (_defaultsCatalog && createSurface is Map<String, Object?> && createSurface['catalogId'] is! String) {
      return {
        ...message,
        'createSurface': {...createSurface, 'catalogId': _catalogs.catalogId},
      };
    }
    return message;
  }

  /// Gives `report` what keeps the tree of each surface from being whole: a
  /// component that holds itself or names a child that doesn't exist, no
  /// component with the id `root`, or components that hold each other in a
  /// circle.
  ///
  /// A component the root doesn't reach is fine, such as one the agent
  /// replaced while it wrote. Nothing is reported through `onError`.
  void checkTopology(A2UIErrorCallback report) {
    assert(!_disposed, 'A2UIProcessor.checkTopology was called after dispose.');
    if (_disposed) return;
    for (final surface in _surfaces.values) {
      _topologyErrors(surface, _catalogs).forEach(report);
    }
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
    _disposeSurfaces(surfaces, notify: true);
    if (hadSurfaces) notifyListeners();
  }

  core.MessageProcessor<core.ComponentApi> _makeCore() {
    final onOutbound = _debugOnOutbound;
    late final core.MessageProcessor<core.ComponentApi> processor;
    processor =
        _debugCoreFactory?.call(_catalogs._catalogs, _handleAction) ??
        core.MessageProcessor<core.ComponentApi>(
          catalogs: _catalogs._catalogs,
          validationConfig: _debugChecks?._config,
          onAction: _handleAction,
          outboundListener: switch ((onOutbound, _onAgentFunction)) {
            (final onOutbound?, _) => (message) => onOutbound(_plainMap(message.toJson())),
            (null, final onAgentFunction?) => (message) => _handleOutbound(message, processor, onAgentFunction),
            (null, null) => null,
          },
        );
    _coreSubscriptions
      ..add(processor.model.onSurfaceCreated.subscribe(_handleSurfaceCreated))
      ..add(processor.model.onSurfaceDeleted.subscribe(_handleSurfaceDeleted));
    return processor;
  }

  void _handleSurfaceCreated(core.SurfaceModel<core.ComponentApi> model) {
    _surfaces[model.id] = A2UISurface._(model, this, isTooLarge: model.id == _tooLargeSurfaceId);
  }

  void _handleSurfaceDeleted(String surfaceId) {
    _surfaces.remove(surfaceId)?._dispose(notify: true);
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

  // Runs a function the agent's UI calls that no catalog has with
  // [onAgentFunction], and answers [asker], the core that called it. A core
  // that was reset or disposed meanwhile has no call waiting for the answer,
  // and drops it. What the core sends the agent otherwise, such as its answer
  // to a function the agent calls, has no one to go to in a chat.
  void _handleOutbound(
    core.RendererToAgentMessage message,
    core.MessageProcessor<core.ComponentApi> asker,
    A2UIAgentFunctionCallback onAgentFunction,
  ) {
    if (message is! core.CallAgentFunctionMessage) return;
    final call = core.FunctionCall.fromJson(message.callFunction);
    final agentCall = A2UIAgentFunctionCall(
      name: call.call,
      surfaceId: message.surfaceId,
      arguments: _plainMap(call.args),
      isUserInitiated: _userActs > 0,
    );
    final functionCallId = message.functionCallId;
    unawaited(
      Future.sync(() => onAgentFunction(agentCall)).then(
        (value) => _answer(asker, core.A2uiFunctionResponse.value(functionCallId, value)),
        onError: (Object error) => _answer(
          asker,
          core.A2uiFunctionResponse.error(
            functionCallId,
            core.A2uiFunctionResponseError(
              code: A2UIErrorCode.executionError,
              message: "Function '${call.call}' failed: $error",
            ),
          ),
        ),
      ),
    );
  }

  static void _answer(core.MessageProcessor<core.ComponentApi> asker, core.A2uiFunctionResponse response) {
    asker.rpc.handleAgentFunctionResponse(
      core.AgentFunctionResponseMessage(version: A2UIVersions.current, response: response),
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
    // The core's dispose removes each surface's root, so the surfaces stop
    // following it first and keep whether they had one; they tell their
    // listeners themselves when they are disposed.
    for (final surface in surfaces) {
      surface._detach();
    }
    _core.dispose();
    return surfaces;
  }

  static void _disposeSurfaces(List<A2UISurface> surfaces, {required bool notify}) {
    for (final surface in surfaces) {
      surface._dispose(notify: notify);
    }
  }

  /// Releases the surfaces and stops calling `onAction`, `onError`,
  /// `onUnreadable` and `onAgentFunction`.
  ///
  /// The processor's creator calls it when the reply goes away.
  @override
  void dispose() {
    _disposed = true;
    _disposeSurfaces(_releaseCore(), notify: false);
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
