part of 'a2ui_adapter.dart';

// The tests' way into the adapter and the A2UI core: test-only, and the only
// test-only code in `lib/`. The A2UI conformance suites use it, and so do a few
// unit tests. Nothing here is exported, and no production code calls it; the
// production classes don't know it exists.
//
// A conformance case sometimes exercises a part of A2UI that a renderer never
// reaches on its own: a catalog document, a function called by name, a path
// resolved outside a template, a raw action, strict graph checks, the answers
// a renderer sends back to the agent. Each entry point here is the narrowest
// way in for one kind of case, and works in the package's own types, so a
// replacement core has to provide the same ones to pass the same suites.
//
// This file is a part of the adapter's library so it can reach the private
// members of the production classes it builds on. What it needs from them must
// be what they already use themselves, never a member added for a test.

/// Signature for the body of an [A2UIDebugFunction]: what it returns for
/// [args], reading and writing the data model through [scope].
///
/// Only the conformance tests use it.
typedef A2UIDebugFunctionBody = Object? Function(Map<String, Object?> args, A2UIDebugScope scope);

/// A function a conformance case gives a catalog, with the definition a
/// catalog document gives it and a [body] that runs it.
///
/// Only the conformance tests use it.
@internal
final class A2UIDebugFunction {
  /// Creates an [A2UIDebugFunction] named [name].
  const A2UIDebugFunction(this.name, {this.definition = const {}, required this.body});

  /// The name a call gives in `@call`.
  final String name;

  /// What a catalog says of the function: its argument schema under
  /// `parameters` or `schema`, and its `allowedCallers`,
  /// `requiresUserActivation` and `returnType`. An empty map takes any
  /// arguments.
  final Map<String, Object?> definition;

  /// What the function does when it runs.
  final A2UIDebugFunctionBody body;
}

/// The data a running [A2UIDebugFunction] sees.
///
/// Only the conformance tests use it.
@internal
final class A2UIDebugScope {
  A2UIDebugScope._(this._context);

  final core.DataContext _context;

  /// The value at [path], relative to the function's scope.
  Object? read(String path) => _plain(_context.dataModel.get(_context.resolvePath(path)));

  /// Writes [value] at [path], relative to the function's scope.
  void write(String path, Object? value) => _context.dataModel.set(_context.resolvePath(path), value);
}

/// A catalog a conformance case needs, other than the ones a renderer has.
///
/// Only the conformance tests use it.
@internal
final class A2UIDebugCatalog {
  /// The A2UI 1.0 basic catalog under [id], with [functions] added; its
  /// `openUrl` opens nothing.
  const A2UIDebugCatalog.basic(this.id, {this.functions = const []}) : document = null;

  /// The catalog a catalog [document] describes, under [id] or else the
  /// document's own `catalogId`, with [functions] added.
  ///
  /// The document's own functions can be checked against but not run.
  A2UIDebugCatalog.document(Map<String, Object?> this.document, {String? id, this.functions = const []})
    : id = id ?? document['catalogId']! as String;

  /// The id surfaces name the catalog by.
  final String id;

  /// The catalog document, or `null` for the basic catalog.
  final Map<String, Object?>? document;

  /// Functions added to the catalog, which run.
  final List<A2UIDebugFunction> functions;

  core.Catalog<core.ComponentApi, core.FunctionImplementation> _build() {
    final added = [for (final function in functions) _signature(function)];
    final document = this.document;
    if (document == null) {
      // A link opens nowhere: what a case checks is that the action runs.
      final basic = core.BasicCatalog.v1_0(openUrl: (_) {});
      return core.Catalog<core.ComponentApi, core.FunctionImplementation>(
        id: id,
        components: basic.components.values.toList(),
        functions: [
          for (final function in basic.functions.values)
            if (!functions.any((added) => added.name == function.name)) function,
          for (final (index, function) in functions.indexed) _DebugFunction(added[index], function.body),
        ],
        themeSchema: basic.themeSchema,
        protocolVersion: basic.protocolVersion,
        definitions: basic.definitions,
      );
    }
    final catalog = core.Catalog.fromJson({
      ...document,
      'catalogId': id,
      'functions': {
        ...?(document['functions'] as Map<String, Object?>?),
        for (final function in functions) function.name: _definitionOf(function),
      },
    }, protocolVersion: core.A2uiProtocolVersion.v1_0);
    return catalog.withFunctions([
      for (final api in catalog.functions.values) _DebugFunction(api, _bodyOf(api.name)),
    ]);
  }

  A2UIDebugFunctionBody? _bodyOf(String name) {
    for (final function in functions) {
      if (function.name == name) return function.body;
    }
    return null;
  }

  // Built with the constructor, as a catalog in code is, so a case can give
  // a function the definition a catalog document may not have, such as
  // `requiresUserActivation` with `rendererOrAgent`.
  static core.FunctionApi _signature(A2UIDebugFunction function) {
    final definition = function.definition;
    final arguments = definition['parameters'] ?? definition['schema'] ?? const <String, Object?>{'type': 'object'};
    // A malformed fixture fails instead of passing against any arguments.
    if (arguments is! Map<String, Object?>) {
      throw ArgumentError.value(arguments, 'parameters', "Function '${function.name}' has no schema object");
    }
    return core.FunctionApi(
      name: function.name,
      argumentSchema: Schema.fromMap(arguments),
      returnType: core.A2uiReturnType.fromJson((definition['returnType'] as String?) ?? 'any'),
      allowedCallers: switch (definition['allowedCallers']) {
        final String callers => core.AllowedCallers.fromJson(callers),
        _ => null,
      },
      requiresUserActivation: definition['requiresUserActivation'] as bool?,
    );
  }

  static Map<String, Object?> _definitionOf(A2UIDebugFunction function) {
    return {
      'type': 'object',
      'properties': {
        '@call': {'const': function.name},
        'args': function.definition['parameters'] ?? function.definition['schema'] ?? {'type': 'object'},
      },
      'required': ['@call'],
      for (final key in ['allowedCallers', 'requiresUserActivation', 'returnType'])
        if (function.definition[key] case final Object value) key: value,
    };
  }
}

// A conformance case's function: the core's signature, and a body that runs it,
// or none for a function that can only be checked against.
final class _DebugFunction extends core.FunctionImplementation {
  _DebugFunction(core.FunctionApi api, this._body)
    : super(
        name: api.name,
        argumentSchema: api.argumentSchema,
        returnType: api.returnType,
        description: api.description,
        allowedCallers: api.allowedCallers,
        requiresUserActivation: api.requiresUserActivation,
        definition: api.definition,
      );

  final A2UIDebugFunctionBody? _body;

  @override
  Object? execute(Map<String, dynamic> args, core.DataContext context, [core.CancellationSignal? cancellationSignal]) {
    final body = _body;
    if (body == null) throw UnsupportedError("Function '$name' can be checked against but not run.");
    return body(_plainMap(args), A2UIDebugScope._(context));
  }
}

/// The graph checks a processor makes of each message, which a renderer
/// doesn't make: a strict one rejects a message that leaves its surface without
/// a root, with a reference to no component, or with a component the root
/// doesn't reach.
///
/// Only the conformance tests use it.
@internal
final class A2UIDebugChecks {
  /// Creates checks, each strict unless [allowOrphans], [allowDangling] or
  /// [allowMissingRoot] allows what it checks.
  const A2UIDebugChecks({this.allowOrphans = false, this.allowDangling = false, this.allowMissingRoot = false});

  /// Whether a component the root doesn't reach is allowed.
  final bool allowOrphans;

  /// Whether a reference to a component that doesn't exist is allowed.
  final bool allowDangling;

  /// Whether a surface without a root is allowed.
  final bool allowMissingRoot;

  core.ValidationConfig get _config {
    return core.ValidationConfig(
      allowOrphanComponents: allowOrphans,
      allowDanglingReferences: allowDangling,
      allowMissingRoot: allowMissingRoot,
    );
  }
}

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

/// The catalogs a conformance case needs, the first of which is the app's.
///
/// Only the conformance tests use it.
A2UICatalogs debugCatalogs(List<A2UIDebugCatalog> catalogs) {
  return A2UICatalogs._(catalogs.first.id, [for (final catalog in catalogs) catalog._build()]);
}

/// A processor as a conformance case needs one: it gives a surface naming no
/// catalog none, makes [checks] of each message, and passes what it sends the
/// agent to [onOutbound], such as the answer to a function the agent calls.
///
/// [A2UIProcessor.reset] gives it a production core again, without [checks]
/// or [onOutbound]. Only tests use it.
A2UIProcessor debugProcessor({
  required A2UICatalogs catalogs,
  A2UIActionCallback? onAction,
  A2UIErrorCallback? onError,
  A2UIDebugChecks? checks,
  A2UIDebugOutboundCallback? onOutbound,
}) {
  final processor = A2UIProcessor(catalogs: catalogs, onAction: onAction, onError: onError);
  debugReplaceCore(
    processor,
    (catalogs, onAction) => core.MessageProcessor<core.ComponentApi>(
      catalogs: catalogs,
      validationConfig: checks?._config,
      onAction: onAction,
      defaultTimeout: A2UIProcessor.agentFunctionTimeout,
      outboundListener: onOutbound == null ? null : (message) => onOutbound(_plainMap(message.toJson())),
    ),
  );
  return processor;
}

/// Makes [processor] apply messages with the core [makeCore] makes, in place
/// of the one it has. Call it before any message is applied.
///
/// [A2UIProcessor.reset] gives it a production core again. Only tests use it.
void debugReplaceCore(A2UIProcessor processor, A2UIDebugCoreFactory makeCore) {
  assert(processor.surfaceIds.isEmpty, 'debugReplaceCore was called on a processor with surfaces.');
  A2UIProcessor._disposeSurfaces(processor._releaseCore(), notify: false);
  processor._attachCore(makeCore(processor._catalogs._catalogs, processor._handleAction));
}

/// A component of a surface as the agent wrote it, not resolved.
///
/// Only the conformance tests use it.
@internal
typedef A2UIDebugComponent = ({String type, Map<String, Object?> properties, Map<String, Object?>? metadata});

/// The parts of a template [input] such as `Hello, ${/user/name}!`: literal
/// text, and `{path}` or `{call, args, returnType}` objects for what it
/// interpolates.
///
/// Returns an [A2UIError] when [input] doesn't parse. Only the conformance
/// tests use it.
Object debugParseExpression(String input) {
  try {
    return _plain(core.ExpressionParser().parse(input))!;
  } on core.A2uiError catch (error) {
    return _errorFromCore(error);
  }
}

/// The [path] resolved against [contextPath], such as `/user/name` for `name`
/// against `/user`.
///
/// Only the conformance tests use it.
String debugResolvePath(String path, {String contextPath = '/'}) {
  final model = core.DataModel();
  try {
    return core.DataContext(model, (_, _, _) => null, contextPath).resolvePath(path);
  } finally {
    model.dispose();
  }
}

/// The value the function [name] of the A2UI 1.0 basic catalog gives for
/// [args], over [dataModel], run as the person's own act.
///
/// With [catalogs], the call runs on a surface that holds them, with
/// [surfaceCatalogId] as its default catalog, and names [catalogId] when given;
/// such a call is the person's act only when [userActivation] is true.
///
/// Returns an [A2UIError] for a call that fails. Only the conformance tests use
/// it.
Future<Object?> debugEvaluateFunction(
  String name,
  Map<String, Object?> args, {
  Map<String, Object?> dataModel = const {},
  String locale = 'en-US',
  List<A2UIDebugCatalog>? catalogs,
  String? surfaceCatalogId,
  String? catalogId,
  bool userActivation = false,
}) async {
  final errors = <A2UIError>[];
  final model = core.DataModel(dataModel);
  core.SurfaceModel<core.ComponentApi>? surface;
  try {
    final Object? value;
    if (catalogs == null) {
      // A link opens nowhere: what the case checks is the URL the function
      // accepts.
      final basic = core.BasicCatalog.v1_0(locale: locale, openUrl: (_) {});
      final function = basic.functions[name];
      if (function == null) return _errorFromCore(core.A2uiCatalogResolutionError("Function '$name' not found."));
      final context = core.DataContext(
        model,
        basic.invoke,
        '/',
        protocolVersion: core.A2uiProtocolVersion.v1_0,
        isUserActivated: true,
        onError: (error) => errors.add(_errorFromCore(error)),
      );
      value = function.execute(args, context);
    } else {
      final built = [for (final catalog in catalogs) catalog._build()];
      final defaultCatalog = [
        for (final catalog in built)
          if (catalog.id == surfaceCatalogId) catalog,
      ].firstOrNull;
      final onSurface = core.SurfaceModel<core.ComponentApi>(
        'conformance',
        defaultCatalog: defaultCatalog,
        availableCatalogs: built,
        protocolVersion: core.A2uiProtocolVersion.v1_0.jsonValue,
      );
      surface = onSurface;
      final context = core.DataContext(
        model,
        (name, args, context) => onSurface.resolveCatalog(null).invoke(name, args, context),
        '/',
        protocolVersion: core.A2uiProtocolVersion.v1_0,
        invokerForCatalog: (id) => onSurface.resolveCatalog(id).invoke,
        isUserActivated: userActivation,
        onError: (error) => errors.add(_errorFromCore(error)),
      );
      value = context.resolveDynamicValue({'@call': name, 'catalogId': ?catalogId, 'args': args});
    }
    final settled = await _settle(value);
    if (errors.isNotEmpty) return errors.first;
    return settled;
  } on core.A2uiError catch (error) {
    return _errorFromCore(error);
  } finally {
    surface?.dispose();
    model.dispose();
  }
}

Future<Object?> _settle(Object? value) async {
  final resolved = switch (value) {
    final Future<Object?> future => await future,
    final core.ReadonlySignal<Object?> signal => signal.value,
    _ => value,
  };
  return switch (resolved) {
    final core.ValidationResult result => _plain(result.toJson()),
    _ => _plain(resolved),
  };
}

/// A data model on its own, as A2UI defines one, for the conformance cases
/// about data models.
///
/// Its creator owns it and calls [dispose] when done. Only the conformance
/// tests use it.
@internal
final class A2UIDebugDataModel {
  /// Creates a data model holding `initial`.
  A2UIDebugDataModel([Object? initial]) : _model = core.DataModel(initial ?? const <String, Object?>{});

  final core.DataModel _model;
  final List<void Function()> _watches = [];

  /// The value at [path], or an [A2UIError] when [path] can't be read.
  Object? get(String path) {
    try {
      return _plain(_model.get(path));
    } on core.A2uiError catch (error) {
      return _errorFromCore(error);
    }
  }

  /// Writes [value] at [path], and returns the [A2UIError] that keeps it from
  /// being written, or `null`.
  A2UIError? set(String path, Object? value) {
    try {
      _model.set(path, value);
      return null;
    } on core.A2uiError catch (error) {
      return _errorFromCore(error);
    }
  }

  /// Calls [onChange] after each change at [path], or above or below it.
  void watch(String path, VoidCallback onChange) {
    var subscribed = false;
    _watches.add(
      _model.watch<Object?>(path).subscribe((_) {
        if (subscribed) onChange();
      }),
    );
    subscribed = true;
  }

  /// Releases the data model.
  void dispose() {
    for (final unsubscribe in _watches) {
      unsubscribe();
    }
    _model.dispose();
  }
}

/// The data models of [processor]'s surfaces that asked for theirs to be sent,
/// as a renderer sends them to the agent for A2UI [version], or `null` when
/// none did or [version] isn't one this package reads.
///
/// Only the conformance tests use it.
Map<String, Object?>? debugRendererDataModel(A2UIProcessor processor, {required String? version}) {
  if (version != A2UIVersions.current) return null;
  final json = processor._core.getRendererDataModel(version: core.A2uiProtocolVersion.v1_0);
  if (json == null) return null;
  return _plainMap(json);
}

/// The components of [surface] as the agent wrote them, by id.
///
/// Only the conformance tests use it.
Map<String, A2UIDebugComponent> debugComponents(A2UISurface surface) {
  return {
    for (final component in surface._model.componentsModel.all)
      component.id: (
        type: component.type,
        properties: _plainMap(component.properties),
        metadata: switch (component.metadata) {
          final Map<String, Object?> metadata => _plainMap(metadata),
          null => null,
        },
      ),
  };
}

/// The metadata the agent gave [surface], or `null` when it gave none.
///
/// Only the conformance tests use it.
Map<String, Object?>? debugMetadata(A2UISurface surface) {
  return switch (surface._model.metadata) {
    final Map<String, Object?> metadata => _plainMap(metadata),
    null => null,
  };
}

/// Runs [action], the raw `action` of a component with the id
/// [sourceComponentId], against the data model of [surface] at [scope], and
/// returns the value of the function it calls, if it calls one.
///
/// Problems are reported through the processor's `onError`. Only the
/// conformance tests use it.
Future<Object?> debugAct(
  A2UISurface surface,
  Object? action, {
  String scope = '/',
  String sourceComponentId = 'button',
  bool userActivation = true,
}) async {
  final model = surface._model;
  void report(A2UIError error) => surface._processor._report(error);
  final context = core.DataContext(
    model.dataModel,
    model.resolveCatalog(null).invoke,
    scope,
    protocolVersion: core.A2uiProtocolVersion.v1_0,
    isUserActivated: userActivation,
    invokerForCatalog: (id) => model.resolveCatalog(id).invoke,
    callAgentFunction: model.callAgentFunction,
    onError: (error) => report(_errorFromCore(error, surfaceId: surface.id)),
  );
  try {
    final payload = action is Map<String, Object?> ? action : null;
    final call = payload?['functionCall'] ?? (context.isFunctionCall(action) ? action : null);
    if (call is Map<String, Object?>) return _plain(await context.evaluateFunctionCall(call));
    final resolved = context.resolveAction(action);
    if (resolved == null) {
      report(
        A2UIError(
          code: A2UIErrorCode.invalidAction,
          message: "Invalid action payload in component '$sourceComponentId'.",
          surfaceId: surface.id,
        ),
      );
      return null;
    }
    await model.dispatchAction(resolved, sourceComponentId);
    return null;
  } catch (error) {
    // As a person's act reports it.
    if (_errorFromAct(error, surfaceId: surface.id, componentId: sourceComponentId) case final error?) report(error);
    return null;
  }
}

/// Binds [value] to a component of [surface] named [componentId], as a
/// component's property is bound, or as the condition of a check rule when
/// [check] is true. `read` gives its current value: the property's value, or
/// whether the rule passes, with a rule that waits on the agent passing.
/// Reading the value is what evaluates it.
///
/// The caller calls `dispose` when done. Problems are reported through the
/// processor's `onError`. Only the conformance tests use it.
({Object? Function() read, VoidCallback dispose}) debugBind(
  A2UISurface surface,
  Object? value, {
  required String componentId,
  bool check = false,
}) {
  final model = surface._model;
  if (!check) {
    final signal = core.ComponentContext(
      model,
      core.ComponentModel(componentId, 'Probe', const {}),
    ).dataContext.resolveSignal(value);
    return (read: () => signal.value, dispose: () {});
  }
  final component = core.ComponentModel(componentId, 'Probe', {
    'checks': [
      {'condition': value, 'message': 'Check failed'},
    ],
  });
  model.componentsModel.addComponent(component);
  final binder = core.GenericBinder(core.ComponentContext(model, component), core.CommonSchemas.checkable);
  return (read: () => binder.resolvedProps.value['isValid'], dispose: binder.dispose);
}

/// Binds [action], a raw `action`, to a component of [surface] named
/// [componentId], as a button's action is bound, and returns what runs it as
/// the person's own act, as [A2UINode.act] does. The component is drawn from
/// [catalogId], or else the surface's default catalog.
///
/// The caller calls `dispose` when done. Problems are reported through the
/// processor's `onError`. Only the conformance tests use it.
({Future<void> Function() run, VoidCallback dispose}) debugBindAction(
  A2UISurface surface,
  Object? action, {
  required String componentId,
  String? catalogId,
}) {
  final model = surface._model;
  final component = core.ComponentModel(componentId, 'Probe', {'action': action}, catalog: catalogId);
  model.componentsModel.addComponent(component);
  final binder = core.GenericBinder(
    core.ComponentContext(model, component),
    Schema.object(properties: {'action': core.CommonSchemas.action}),
  );
  Future<void> run() async {
    final callback = binder.resolvedProps.peek()['action'];
    if (callback is! Future<void> Function()) return;
    try {
      await runZoned(callback, zoneValues: {_userActKey: true});
    } catch (error) {
      if (_errorFromAct(error, surfaceId: surface.id, componentId: componentId) case final error?) {
        surface._processor._report(error);
      }
    }
  }

  return (run: run, dispose: binder.dispose);
}
