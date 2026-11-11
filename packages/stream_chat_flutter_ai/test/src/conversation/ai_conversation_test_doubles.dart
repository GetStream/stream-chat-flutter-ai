import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// A message of the conversations under test.
class ChatMessage with AIMessage {
  ChatMessage(
    this.id,
    this.role,
    this.text, {
    this.isGenerating = false,
    this.parts = const [],
    this.attachments = const [],
    this.rating,
    this.uiDocument,
  });

  /// One of the person's messages.
  ChatMessage.user(this.id, [this.text = 'Plan a weekend in Lisbon'])
    : role = AIMessageRole.user,
      isGenerating = false,
      parts = const [],
      attachments = const [],
      rating = null,
      uiDocument = null;

  /// One of the agent's replies.
  ChatMessage.reply(
    this.id, {
    this.text = "Here's a plan",
    bool generating = false,
    this.parts = const [],
    this.rating,
    this.uiDocument,
  }) : role = AIMessageRole.assistant,
       isGenerating = generating,
       attachments = const [];

  @override
  final String id;

  @override
  final AIMessageRole role;

  @override
  final String text;

  @override
  final bool isGenerating;

  @override
  final List<AIMessagePart> parts;

  @override
  final List<AIMessageAttachment> attachments;

  @override
  final AIMessageRating? rating;

  @override
  final AIUIDocument? uiDocument;
}

/// What a [ConversationTransport] fails with.
class TransportError implements Exception {
  const TransportError();

  @override
  bool operator ==(Object other) => other is TransportError;

  @override
  int get hashCode => 0;
}

/// Records what the conversation asks of it, and lets a test say what the
/// conversation holds and when each request finishes.
class ConversationTransport with AIConversationTransport<ChatMessage> {
  ConversationTransport({List<ChatMessage> messages = const []}) : initialMessages = messages;

  AIConversationFeed<ChatMessage>? feed;
  final requests = <AIConversationRequest<ChatMessage>>[];
  int stops = 0;
  int loads = 0;
  int disconnects = 0;
  final ratings = <(String, AIMessageRating?)>[];

  List<ChatMessage> initialMessages;
  Object? sendError;
  Object? stopError;
  Object? loadError;
  bool Function(AIMessageRating? rating) failsRating = (_) => false;

  // Hold each send, stop, load and rating until the test finishes it.
  bool holdsSends = false;
  bool holdsStops = false;
  bool holdsLoads = false;
  bool holdsRatings = false;
  final _heldSends = <Completer<void>>[];
  final _heldStops = <Completer<void>>[];
  final _heldLoads = <Completer<void>>[];
  final _heldRatings = <Completer<void>>[];

  AIConversationRequest<ChatMessage>? get lastRequest => requests.lastOrNull;

  @override
  void connect(AIConversationFeed<ChatMessage> feed) {
    this.feed = feed;
    feed.updateMessages(initialMessages);
  }

  @override
  void disconnect() => disconnects += 1;

  @override
  Future<void> send(AIConversationRequest<ChatMessage> request) async {
    requests.add(request);
    if (holdsSends) await _hold(_heldSends);
    if (sendError case final error?) return Future.error(error);
  }

  @override
  Future<void> stop() async {
    stops += 1;
    if (holdsStops) await _hold(_heldStops);
    if (stopError case final error?) return Future.error(error);
  }

  @override
  Future<void> loadOlderMessages() async {
    loads += 1;
    if (holdsLoads) await _hold(_heldLoads);
    if (loadError case final error?) return Future.error(error);
  }

  @override
  Future<void> rate(ChatMessage reply, AIMessageRating? rating) async {
    ratings.add((reply.id, rating));
    if (holdsRatings) await _hold(_heldRatings);
    if (failsRating(rating)) throw const TransportError();
  }

  static Future<void> _hold(List<Completer<void>> held) {
    final completer = Completer<void>();
    held.add(completer);
    return completer.future;
  }

  void finishSend(int index, {Object? error}) => _finish(_heldSends[index], error);

  void finishStop(int index) => _heldStops[index].complete();

  void finishRating(int index, {Object? error}) => _finish(_heldRatings[index], error);

  void finishLoads() {
    for (final load in _heldLoads) {
      load.complete();
    }
    _heldLoads.clear();
  }

  static void _finish(Completer<void> held, Object? error) {
    if (error == null) {
      held.complete();
    } else {
      held.completeError(error);
    }
  }

  void update(List<ChatMessage> messages) => feed?.updateMessages(messages);

  void updateActivity(AIAgentActivity? activity) => feed?.updateActivity(activity);
}

/// A transport that only holds the conversation, which relies on what the
/// transport does by default.
class MinimalTransport with AIConversationTransport<ChatMessage> {
  AIConversationFeed<ChatMessage>? feed;

  @override
  void connect(AIConversationFeed<ChatMessage> feed) => this.feed = feed;

  @override
  Future<void> send(AIConversationRequest<ChatMessage> request) async {}

  @override
  Future<void> stop() async {}
}

/// A conversation over [transport], disposed once the test ends.
AIConversation<ChatMessage> conversationOver(
  AIConversationTransport<ChatMessage> transport, {
  ChatComposerController? composer,
  AIToolApprover? approver,
  AIConversationActions actions = AIConversationActions.all,
  Duration? replyTimeout = const Duration(seconds: 300),
}) {
  final conversation = AIConversation(
    transport: transport,
    composer: composer,
    approver: approver,
    actions: actions,
    replyTimeout: replyTimeout,
  );
  addTearDown(conversation.dispose);
  return conversation;
}

/// Lets what the conversation started run, outside a widget test.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// The errors the package reports while the test runs, kept off the console.
List<FlutterErrorDetails> captureErrors() {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) =>
      details.library == 'stream_chat_flutter_ai' ? errors.add(details) : previous?.call(details);
  addTearDown(() => FlutterError.onError = previous);
  return errors;
}

extension ChatMessageIds on List<ChatMessage> {
  List<String> get ids => [for (final message in this) message.id];
}
