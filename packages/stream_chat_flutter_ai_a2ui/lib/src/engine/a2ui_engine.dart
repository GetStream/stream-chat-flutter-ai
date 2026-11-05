import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_renderer.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/engine/a2ui_action_label.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/engine/a2ui_stream.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_reply_view.dart';

/// The A2UI replies of one conversation, each with surfaces of its own, which
/// follow the reply's messages as the agent writes them.
///
/// A reply's surfaces are made the first time its widget is asked for with
/// [view], and are kept until the reply is [remove]d or the engine is
/// disposed, while the reply streams and after it finishes.
///
/// Internal to the package.
@internal
final class A2UIEngine extends AIUIEngine {
  /// Creates the engine of [_renderer] for one conversation's [_host].
  A2UIEngine(this._renderer, this._host)
    : _catalogs = A2UICatalogs(
        catalogId: _renderer.catalogId,
        locale: WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
      );

  final A2UIRenderer _renderer;
  final AIUIHosting _host;
  final A2UICatalogs _catalogs;
  final Map<String, _A2UIReply> _replies = {};
  // The latest document of each reply that [receive] got during a frame, to
  // apply once it ends.
  final Map<String, AIUIDocument> _received = {};
  // What waits for the frame being built to end, in the order it came.
  final List<VoidCallback> _afterFrame = [];
  bool _disposed = false;

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
      catalog: _renderer.catalog,
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
    // The host reports an action it couldn't send.
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
    );
  }

  final A2UIEngine _engine;
  final String messageId;
  late final A2UIProcessor processor;
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
    if (_disposed || document.isStreaming || _checked) return;
    _checked = true;
    processor.checkTopology((error) => A2UIEngine._debugReport(error, messageId));
  }

  void dispose() {
    _disposed = true;
    processor.dispose();
  }
}
