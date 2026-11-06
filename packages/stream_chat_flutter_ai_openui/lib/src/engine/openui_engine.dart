import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_reply_program.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_json.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_renderer.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';

/// The OpenUI replies of one conversation, each run by a runtime of its own
/// that follows the reply's program as the agent writes it.
///
/// A reply's runtime is made the first time its widget is asked for with
/// [view], starting from the state the host kept for it, and is kept until
/// the reply is [remove]d or the engine is disposed.
///
/// The host's components join the renderer's library when the engine is
/// made; one that can't is left out, and reported in debug builds.
///
/// Internal to the package.
@internal
final class OpenUIEngine extends AIUIEngine {
  /// Creates the engine of [_renderer] for one conversation's [_host].
  OpenUIEngine(this._renderer, this._host) {
    library = _libraryWithAppComponents();
    _lifecycle = AppLifecycleListener(onPause: _pauseAll, onResume: _resumeAll);
  }

  final OpenUIRenderer _renderer;
  final AIUIHosting _host;

  /// The renderer's library with the host's components the agent can place.
  late final OpenUILibrary library;

  late final AppLifecycleListener _lifecycle;
  final Map<String, _OpenUIReply> _replies = {};
  // The latest document of each reply that [receive] got during a frame, to
  // apply once it ends.
  final Map<String, AIUIDocument> _received = {};
  // What waits for the frame being built to end, in the order it came.
  final List<VoidCallback> _afterFrame = [];
  bool _disposed = false;

  // The label of an action from a control without one, as iOS and Android
  // label it.
  static const _untitledLabel = 'Continue';

  // The key of an app component's action payload that names the component.
  static const _componentKey = 'component';

  @override
  void receive(AIUIDocument document, String messageId) {
    if (!_replies.containsKey(messageId)) return;
    // The conversation calls this while it builds, and the reply's view may
    // already show, so its change waits for the frame to end.
    _received[messageId] = document;
    _whenNotBuilding(() {
      final latest = _received.remove(messageId);
      if (latest != null) _replies[messageId]?.update(latest);
    });
  }

  @override
  void remove(String messageId) {
    _received.remove(messageId);
    _replies.remove(messageId)?.dispose();
  }

  @override
  Widget? view(AIUIDocument document, String messageId) {
    assert(!_disposed, 'OpenUIEngine.view was called after dispose.');
    if (_disposed) return null;
    if (document.text == null) return null;
    // The document asked for now is the reply's latest.
    _received.remove(messageId);
    final reply = (_replies[messageId] ??= _OpenUIReply(this, messageId))..update(document);
    if (reply.runtime.root.value == null) {
      // A reply written without a root shows its text: its runtime goes,
      // after the problems it found are given, so no query of it runs on.
      if (!document.isStreaming) {
        _whenNotBuilding(() {
          if (_shows(reply) && reply.runtime.root.value == null) remove(messageId);
        });
      }
      return null;
    }
    // A new view for each document, as the view reads whether the reply
    // streams when it builds.
    return OpenUIView(
      runtime: reply.runtime,
      library: library,
      theme: _renderer.theme,
      mediaUrl: _renderer.mediaUrl,
      onOpenLink: _host.open,
      onBuildError: (node, error, stack) => _reportBuildError(reply, node, error, stack),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _lifecycle.dispose();
    _received.clear();
    _afterFrame.clear();
    for (final reply in _replies.values) {
      reply.dispose();
    }
    _replies.clear();
  }

  void _pauseAll() {
    for (final reply in _replies.values) {
      reply.runtime.pause();
    }
  }

  void _resumeAll() {
    for (final reply in _replies.values) {
      reply.runtime.resume();
    }
  }

  // Whether [reply] is still one of this engine's, rather than removed.
  bool _shows(_OpenUIReply reply) => !_disposed && identical(_replies[reply.messageId], reply);

  OpenUILibrary _libraryWithAppComponents() {
    final base = _renderer.library;
    final components = <AIUIComponent<Object?>>[];
    final definitions = <Map<String, Object?>>[];
    for (final component in _host.components) {
      try {
        definitions.add(component.definition.toJson());
        components.add(component);
      } on Object catch (error) {
        _debugReportLeftOut("An app's component can't be placed in OpenUI replies: its definition threw ($error).");
      }
    }
    final placeable = placeableComponents(base.definition, definitions);
    final placed = {for (final (index, _) in placeable) index};
    for (final (index, component) in components.indexed) {
      if (placed.contains(index)) continue;
      _debugReportLeftOut(
        "The app's component '${component.name}' can't be placed in OpenUI replies: its definition can't be read, "
        'or its name is already taken.',
      );
    }
    return base.addingAppComponents([
      for (final (index, schema) in placeable) (schema, _appComponentBuilder(components[index], schema)),
    ]);
  }

  // The builder of the app's [component], which the agent places with the
  // props of [schema].
  //
  // Values that don't fit the component's parameters draw nothing while the
  // reply streams; once it is written, they go to `onError` as a builder's
  // error, or without it are reported in debug builds. Anything the
  // component throws goes where a builder's error goes.
  OpenUIComponentBuilder _appComponentBuilder(AIUIComponent<Object?> component, ComponentSchema schema) {
    return (context, scope) {
      final runtime = OpenUIViewScope.of(context).runtime;
      final reply = _replies.values.where((reply) => identical(reply.runtime, runtime)).firstOrNull;
      // A reply removed while its view still shows draws nothing new.
      if (reply == null) return const SizedBox.shrink();
      final arguments = {
        for (final prop in schema.props)
          if (scope.value(prop.name) case final value?) prop.name: value,
      };
      final Object? read;
      try {
        read = component.readArguments(AIUIArguments(arguments));
      } on FormatException catch (error) {
        if (scope.isStreaming) return const SizedBox.shrink();
        // Without `onError`, values that don't fit are the agent's mistake,
        // reported in debug builds only, as `AIUIComponent.view` does.
        if (_renderer.onError != null) rethrow;
        _debugReport("The values of the app's component '${component.name}' don't fit its parameters ($error).");
        return const SizedBox.shrink();
      }
      return component.build(
        context,
        read,
        AIUIComponentContext(
          messageId: reply.messageId,
          isStreaming: scope.isStreaming,
          host: _host,
          emit: (event, label, payload) {
            // A widget may report an event after its reply left or the
            // engine was disposed, and the agent never hears it.
            if (!_shows(reply)) return Future<void>.value();
            return _host.send(
              AIUIAction(
                messageId: reply.messageId,
                format: AIUIFormat.openUI,
                name: event,
                label: label,
                payload: {...payload, _componentKey: component.name},
              ),
            );
          },
        ),
      );
    };
  }

  void _handle(OpenUIActionEvent event, _OpenUIReply reply) {
    if (!_shows(reply)) return;
    if (event.type == OpenUIActionEvent.openUrl) {
      final url = switch (event.params['url']) {
        OpenUIString(:final value) => Uri.tryParse(value),
        _ => null,
      };
      if (url != null && _isOpenable(url)) _host.open(url);
      return;
    }
    final params = {...event.params}..remove('context');
    final context = event.params['context'];
    final message = event.message;
    final values = event.formName == null ? const <String, OpenUIValue>{} : event.formState;
    // The host reports an action it couldn't send to FlutterError.onError,
    // and the app's own `send` can tell the person.
    unawaited(
      _host.send(
        AIUIAction(
          messageId: reply.messageId,
          format: AIUIFormat.openUI,
          name: event.type,
          label: event.label.isEmpty ? _untitledLabel : event.label,
          payload: {
            if (context != null) 'context': openUIJson(context),
            if (params.isNotEmpty) 'params': openUIJsonObject(params),
            if (message.isNotEmpty && message != event.label) 'message': message,
            if (event.formName case final form?) 'form': form,
            if (values.isNotEmpty) 'values': openUIJsonObject(values),
          },
        ),
      ),
    );
  }

  // Whether [url] is a web link to a host or an email link, the only links a
  // reply's program opens, as on iOS.
  static bool _isOpenable(Uri url) {
    if (url.isScheme('mailto')) return true;
    return (url.isScheme('http') || url.isScheme('https')) && url.host.isNotEmpty;
  }

  void _reportErrors(List<OpenUIError> errors, _OpenUIReply reply) {
    for (final error in errors) {
      if (!reply.reported.add(error)) continue;
      _report(error, reply);
    }
  }

  void _reportBuildError(_OpenUIReply reply, ElementNode node, Object error, StackTrace stack) {
    final onError = _renderer.onError;
    if (onError == null) {
      _reportToFlutter(error, "while building the OpenUI component '${node.typeName}'", stack: stack);
      return;
    }
    // Like the program's problems, given once, and only once the reply is
    // written: a component still arriving may not be drawable yet.
    if (reply.runtime.isStreaming) return;
    final problem = OpenUIError(
      source: OpenUIErrorSource.runtime,
      code: OpenUIErrorCode.renderError,
      message: "The component '${node.typeName}' couldn't be drawn: $error",
      statementId: node.statementId,
      component: node.typeName,
    );
    if (reply.reported.add(problem)) _report(problem, reply);
  }

  // Gives [error] to the renderer's `onError` once the frame ends, or, without
  // one, reports it in debug builds.
  void _report(OpenUIError error, _OpenUIReply reply) {
    final onError = _renderer.onError;
    if (onError == null) {
      if (kDebugMode) _reportToFlutter(error, "while showing the OpenUI of reply '${reply.messageId}'");
      return;
    }
    _whenNotBuilding(() {
      if (_shows(reply)) onError(error, reply.messageId);
    });
  }

  // Runs [work] now, or once the frame being built ends, so nothing the app
  // gave runs while widgets build. Work that waits keeps its order, and later
  // work waits behind it.
  void _whenNotBuilding(VoidCallback work) {
    final isBuilding = switch (SchedulerBinding.instance.schedulerPhase) {
      SchedulerPhase.persistentCallbacks || SchedulerPhase.midFrameMicrotasks => true,
      SchedulerPhase.idle || SchedulerPhase.transientCallbacks || SchedulerPhase.postFrameCallbacks => false,
    };
    if (!isBuilding && _afterFrame.isEmpty) {
      _run(work);
      return;
    }
    _afterFrame.add(work);
    if (_afterFrame.length > 1) return;
    SchedulerBinding.instance.addPostFrameCallback((_) => _runAfterFrame());
    // A post-frame callback only runs on a frame, so one is asked for.
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _runAfterFrame() {
    while (_afterFrame.isNotEmpty && !_disposed) {
      _run(_afterFrame.removeAt(0));
    }
  }

  // Runs [work], reporting what it throws, so the app's own code that throws,
  // such as its `onError`, stops nothing that comes after it.
  static void _run(VoidCallback work) {
    try {
      work();
    } on Object catch (error, stack) {
      _reportToFlutter(error, "while showing a reply's OpenUI", stack: stack);
    }
  }

  static void _debugReport(String message) {
    if (kDebugMode) _reportToFlutter(message, "while showing a reply's OpenUI");
  }

  static void _debugReportLeftOut(String message) {
    if (kDebugMode) _reportToFlutter(message, "while adding the app's components to OpenUI replies");
  }

  static void _reportToFlutter(Object problem, String context, {StackTrace? stack}) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: problem,
        stack: stack,
        library: 'stream_chat_flutter_ai_openui',
        context: ErrorDescription(context),
      ),
    );
  }
}

// One reply's runtime, fed the program of each of its documents.
final class _OpenUIReply {
  _OpenUIReply(this._engine, this.messageId) {
    final library = _engine.library.definition;
    final saved = _engine._host.state(messageId);
    runtime = OpenUIRuntime(
      schema: library.schema,
      isBindable: library.isBindable,
      tools: _tools,
      // Any map, as an app may keep the state in a store that loses the
      // key type, such as after decoding it.
      initialState: saved is Map ? {for (final MapEntry(:key, :value) in saved.entries) '$key': value} : null,
    );
    _actions = runtime.actions.listen((event) => _engine._handle(event, this));
    runtime.state.addListener(_saveState);
    runtime.errors.addListener(_reportErrors);
  }

  final OpenUIEngine _engine;
  final String messageId;
  late final OpenUIRuntime runtime;
  late final _tools = _HostTools(_engine._host);
  late final StreamSubscription<OpenUIActionEvent> _actions;
  // The errors given to `onError` already, each given once.
  final Set<OpenUIError> reported = {};

  void update(AIUIDocument document) {
    final text = document.text;
    runtime.update(text == null ? null : openUIProgramOf(text), isStreaming: document.isStreaming);
  }

  void _saveState() => _engine._host.setState(messageId, openUIJsonObject(runtime.state.value));

  void _reportErrors() => _engine._reportErrors(runtime.errors.value, this);

  void dispose() {
    _tools.isClosed = true;
    unawaited(_actions.cancel());
    runtime.state.removeListener(_saveState);
    runtime.errors.removeListener(_reportErrors);
    runtime.dispose();
  }
}

// Runs a program's queries and mutations as the host's tools.
final class _HostTools implements OpenUIToolProvider {
  _HostTools(this._host);

  final AIUIHosting _host;

  /// Whether the reply is gone, so no more tools run for it.
  bool isClosed = false;

  @override
  Future<OpenUIValue> callTool(String name, Map<String, OpenUIValue> args, {required bool userInitiated}) async {
    // A query starts while the conversation builds, so the app's tool runs
    // after it, never inside the build, and not at all once the reply is
    // gone.
    await Future<void>.value();
    if (isClosed) throw StateError("The reply is gone, so the tool $name doesn't run.");
    final output = await _host.runTool(name, arguments: openUIJsonObject(args), userInitiated: userInitiated);
    return OpenUIValue.fromJson(output);
  }
}
