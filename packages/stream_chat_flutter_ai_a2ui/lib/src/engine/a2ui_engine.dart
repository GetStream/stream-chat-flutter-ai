import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_renderer.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/engine/a2ui_action_label.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/engine/a2ui_app_components.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/engine/a2ui_stream.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_reply_view.dart';

/// The A2UI replies of one conversation, each with surfaces of its own, which
/// follow the reply's messages as the agent writes them.
///
/// A reply's surfaces are made the first time its widget is asked for with
/// [view], and are kept until the reply is [remove]d or the engine is
/// disposed, while the reply streams and after it finishes.
///
/// The host's components join the catalogs when the engine is made; one that
/// can't is left out, and reported in debug builds.
///
/// Internal to the package.
@internal
final class A2UIEngine extends AIUIEngine {
  /// Creates the engine of [_renderer] for one conversation's [_host].
  A2UIEngine(this._renderer, this._host) {
    _appComponents = a2uiPlaceableComponents(
      _host.components,
      onLeftOut: (message) => _whenNotBuilding(() => _debugReportLeftOut(message)),
    );
    _catalogs = A2UICatalogs(
      catalogId: _renderer.catalogId,
      locale: WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
      appComponents: {
        for (final (:type, :definition, component: _) in _appComponents) type: definition.parametersSchema,
      },
    );
  }

  final A2UIRenderer _renderer;
  final AIUIHosting _host;
  // The host's components the agent can place, read once, as the catalogs
  // that hold them are made once for every reply.
  late final List<({String type, AIUIComponent<Object?> component, AIUIComponentDefinition definition})> _appComponents;
  late final A2UICatalogs _catalogs;
  final Map<String, _A2UIReply> _replies = {};
  // The latest document of each reply that [receive] got during a frame, to
  // apply once it ends.
  final Map<String, AIUIDocument> _received = {};
  // What waits for the frame being built to end, in the order it came.
  final List<VoidCallback> _afterFrame = [];
  bool _disposed = false;

  // The key of an app component's action payload that names the component.
  static const _componentKey = 'component';

  // The keys of an app component's action payload that name the surface
  // and the component that reported it, as a `Button`'s action does.
  static const _surfaceIdKey = 'surfaceId';
  static const _sourceComponentIdKey = 'sourceComponentId';

  @override
  void receive(AIUIDocument document, String messageId) {
    final reply = _replies[messageId];
    if (reply == null) return;
    // The conversation calls this while it builds, and the reply's surfaces
    // may already show, so their change waits for the frame to end.
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
    assert(!_disposed, 'A2UIEngine.view was called after dispose.');
    if (_disposed) return null;
    // The document asked for now is the reply's latest.
    _received.remove(messageId);
    final reply = (_replies[messageId] ??= _A2UIReply(this, messageId))..update(document);
    if (reply.processor.surfaceIds.isEmpty) return null;
    return A2UIReplyView(
      processor: reply.processor,
      catalog: reply.catalog,
      theme: _renderer.theme,
      mediaUrl: _renderer.mediaUrl,
      onOpenLink: _host.open,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _received.clear();
    _afterFrame.clear();
    for (final reply in _replies.values) {
      reply.dispose();
    }
    _replies.clear();
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

  // Runs the work that waited for the frame, in order.
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
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stream_chat_flutter_ai_a2ui',
          context: ErrorDescription("while showing a reply's A2UI"),
        ),
      );
    }
  }

  void _send(A2UIActionEvent event, _A2UIReply reply) {
    final surface = reply.processor.surface(event.surfaceId);
    final userMessage = event.userMessage;
    // The host reports an action it couldn't send to FlutterError.onError, and
    // the app's own `send` can tell the person. It isn't a problem with the
    // reply's A2UI, so it doesn't go to `onError`.
    unawaited(
      _host.send(
        AIUIAction(
          messageId: reply.messageId,
          format: AIUIFormat.a2ui,
          name: event.name,
          label: _buttonText(surface, event.sourceComponentId) ?? a2uiWords(event.name),
          payload: {
            'surfaceId': event.surfaceId,
            'sourceComponentId': event.sourceComponentId,
            'context': event.context,
            if (userMessage != null && userMessage.isNotEmpty) 'userMessage': userMessage,
            if (surface != null && surface.sendDataModel) 'dataModel': surface.read('/'),
          },
        ),
      ),
    );
  }

  // The text the button [componentId] of [surface] shows, as a person reads
  // it, or `null` when it shows none.
  static String? _buttonText(A2UISurface? surface, String componentId) {
    final text = a2uiText(surface?.buttonTextOf(componentId));
    if (text == null) return null;
    if (text.trim().isEmpty) return null;
    return text;
  }

  void _handleError(A2UIError error, _A2UIReply reply) {
    final onError = _renderer.onError;
    if (onError == null) {
      _debugReport(error, reply.messageId);
      return;
    }
    _whenNotBuilding(() {
      if (_shows(reply)) onError(error, reply.messageId);
    });
  }

  // Runs one of the host's tools for [reply], and fails with the tool's own
  // words when it can't.
  Future<Object?> _runTool(A2UIAgentFunctionCall call, _A2UIReply reply) {
    final result = Completer<Object?>();
    _whenNotBuilding(() {
      if (!_shows(reply)) return;
      final output = Future.sync(
        () => _host.runTool(call.name, arguments: call.arguments, userInitiated: call.isUserInitiated),
      );
      result.complete(
        output.catchError((Object error, StackTrace stack) {
          if (error is AIUIToolException) throw A2UIAgentFunctionException(error.message);
          Error.throwWithStackTrace(error, stack);
        }),
      );
    });
    return result.future;
  }

  // Whether [reply] is still one of this engine's, rather than removed.
  bool _shows(_A2UIReply reply) => identical(_replies[reply.messageId], reply);

  // The widget of the app's [component] that a reply's surface places, with
  // the values [scope] reads for its parameters.
  //
  // Values that don't fit the component's parameters draw nothing; once the
  // reply is written they are reported through `onError`, as is anything the
  // component throws reading or building them, so the agent can correct it.
  Widget _buildAppComponent(
    A2UIComponentScope scope,
    AIUIComponent<Object?> component,
    AIUIComponentDefinition definition,
    _A2UIReply reply,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: reply.isStreaming,
      builder: (context, isStreaming, _) {
        final arguments = {
          for (final parameter in definition.parameters)
            if (scope.value(parameter.name) case final value?) parameter.name: value,
        };
        final ui = AIUIComponentContext(
          messageId: reply.messageId,
          isStreaming: isStreaming,
          host: _host,
          emit: (event, label, payload) {
            // A widget may report an event after its reply left or the
            // engine was disposed, such as when its own request completes,
            // and the agent never hears it.
            if (!_shows(reply)) return Future<void>.value();
            return _host.send(
              AIUIAction(
                messageId: reply.messageId,
                format: AIUIFormat.a2ui,
                name: event,
                label: label,
                payload: {
                  ...payload,
                  _componentKey: definition.name,
                  _surfaceIdKey: a2uiSurfaceIdOf(scope),
                  _sourceComponentIdKey: scope.id,
                },
              ),
            );
          },
        );
        final Object? read;
        try {
          read = component.readArguments(AIUIArguments(arguments));
        } on FormatException catch (error) {
          if (!isStreaming) {
            a2uiReportOnce(
              scope,
              'arguments: ${error.message}',
              "Its values don't fit the parameters of the app's component '${definition.name}' (${error.message}).",
            );
          }
          return const SizedBox.shrink();
        } on Object catch (error, stack) {
          _reportAppComponentError(scope, component, error, stack, 'reading the arguments of');
          return const SizedBox.shrink();
        }
        return AIUIEntrance(
          child: Builder(
            builder: (context) {
              try {
                return component.build(context, read, ui);
              } on Object catch (error, stack) {
                _reportAppComponentError(scope, component, error, stack, 'building');
                return const SizedBox.shrink();
              }
            },
          ),
        );
      },
    );
  }

  // Reports [error], which the app's [component] threw while [doing] what
  // [scope] places, to [FlutterError.onError] and through `onError`.
  static void _reportAppComponentError(
    A2UIComponentScope scope,
    AIUIComponent<Object?> component,
    Object error,
    StackTrace stack,
    String doing,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stream_chat_flutter_ai_a2ui',
        context: ErrorDescription("while $doing the app's component '${component.name}'"),
      ),
    );
    a2uiReportBuildError(scope, error);
  }

  static void _debugReportLeftOut(String message) {
    if (!kDebugMode) return;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: message,
        library: 'stream_chat_flutter_ai_a2ui',
        context: ErrorDescription("while adding the app's components to A2UI replies"),
      ),
    );
  }

  static void _debugReport(Object problem, String messageId) {
    if (!kDebugMode) return;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: problem,
        library: 'stream_chat_flutter_ai_a2ui',
        context: ErrorDescription("while showing the A2UI of reply '$messageId'"),
      ),
    );
  }
}

// One reply's surfaces, and the messages of its document applied to them.
final class _A2UIReply {
  _A2UIReply(this._engine, this.messageId) {
    processor = A2UIProcessor(
      catalogs: _engine._catalogs,
      onAction: (event) => _engine._send(event, this),
      onError: (error) => _engine._handleError(error, this),
      onUnreadable: () => A2UIEngine._debugReport(_unreadable, messageId),
      onAgentFunction: (call) => _engine._runTool(call, this),
      onLateAnswer: (name) => A2UIEngine._debugReport(
        "The tool '$name' answered after it timed out at "
        '${A2UIProcessor.agentFunctionTimeout.inSeconds} s, so its answer was dropped.',
        messageId,
      ),
    );
  }

  final A2UIEngine _engine;
  final String messageId;
  late final A2UIProcessor processor;
  // Whether the agent is still writing the reply, which the app's components
  // are told, and built again when it changes.
  final isStreaming = ValueNotifier(false);
  // Whether [isStreaming] holds a value of the reply's yet.
  bool _hasStreamingFlag = false;
  // The builders of the reply's components: the renderer's, and the app's
  // drawn for this reply.
  late final A2UICatalog catalog = a2uiCatalogAdding(_engine._renderer.catalog, {
    for (final (:type, :component, :definition) in _engine._appComponents)
      type: (context, scope) => _engine._buildAppComponent(scope, component, definition, this),
  });
  List<String> _applied = const [];
  // Whether the tree of each surface was checked since its messages last
  // changed.
  bool _checked = false;
  // The document that arrived while one was being applied, such as from an
  // `onError` that the reply's problems reached, to apply once it is done.
  AIUIDocument? _waiting;
  bool _updating = false;
  bool _disposed = false;

  static const _unreadable = "A message of the reply's A2UI isn't a JSON object, so it was skipped.";

  // Applies the messages of [document] not applied yet. Messages that
  // changed, rather than grew, start the surfaces again. Once the agent has
  // finished, the tree of each surface is checked, also for a reply that
  // arrives finished.
  void update(AIUIDocument document) {
    if (_updating) {
      _waiting = document;
      return;
    }
    _updating = true;
    try {
      for (AIUIDocument? next = document; next != null && !_disposed; next = _waiting) {
        _waiting = null;
        _apply(next);
      }
    } finally {
      _updating = false;
    }
  }

  void _apply(AIUIDocument document) {
    final messages = A2UIStream.messages(document.content);
    final added = A2UIStream.added(messages, applied: _applied);
    if (added == null) processor.reset();
    if (added == null || added.isNotEmpty) _checked = false;
    _applied = messages;
    processor.apply(added ?? messages);
    // A callback the messages reached may have removed the reply.
    if (_disposed) return;
    _setStreaming(document.isStreaming);
    if (document.isStreaming || _checked) return;
    _checked = true;
    // Only reported in debug builds, so only checked in them.
    if (kDebugMode) processor.checkTopology((error) => A2UIEngine._debugReport(error, messageId));
  }

  // Tells the app's components whether the agent is still writing the
  // reply. The first value is the one they are built with. A reply applies
  // while the conversation builds, and a component may show in a route above
  // it, such as a `Modal`'s sheet, so they hear a change once the frame ends.
  void _setStreaming(bool value) {
    if (!_hasStreamingFlag) {
      _hasStreamingFlag = true;
      isStreaming.value = value;
      return;
    }
    _engine._whenNotBuilding(() {
      if (!_disposed) isStreaming.value = value;
    });
  }

  void dispose() {
    _disposed = true;
    processor.dispose();
    isStreaming.dispose();
  }
}
