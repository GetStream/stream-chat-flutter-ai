import 'dart:async';

import 'package:collection/collection.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/composer/chat_composer.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_controller.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_option.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_agent_activity.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_agent_error.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_actions.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_request.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_status.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_transport.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message.dart';
import 'package:stream_chat_flutter_ai/src/conversation/conversation_exchange.dart';
import 'package:stream_chat_flutter_ai/src/conversation/pending_attachments.dart';
import 'package:stream_chat_flutter_ai/src/message/ai_reply_actions_view.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approver.dart';

/// The state behind an AI conversation, and what the person does in it.
///
/// It holds the conversation's [messages], where the latest exchange with the
/// agent is ([status]) and why it failed ([error]), and it sends what the
/// person asks through its [AIConversationTransport]. Give it to
/// [AIConversationView.conversation] and [ChatComposer.conversation], which
/// show it and act on it: sending, stopping, regenerating and rating replies,
/// and editing the person's latest message.
///
/// ```dart
/// late final conversation = AIConversation(
///   transport: AgentTransport(channel),
/// );
///
/// @override
/// Widget build(BuildContext context) {
///   return Column(
///     children: [
///       Expanded(
///         child: AIConversationView.conversation(
///           conversation: conversation,
///           footer: ListenableBuilder(
///             listenable: conversation,
///             builder: (context, _) {
///               if (conversation.status != AIConversationStatus.error) {
///                 return const SizedBox.shrink();
///               }
///               return TextButton(
///                 onPressed: conversation.retry,
///                 child: const Text('Try again'),
///               );
///             },
///           ),
///         ),
///       ),
///       ChatComposer.conversation(conversation: conversation),
///     ],
///   );
/// }
///
/// @override
/// void dispose() {
///   conversation.dispose();
///   super.dispose();
/// }
/// ```
///
/// Where `AgentTransport` follows a channel's messages and sends to it:
///
/// ```dart
/// class AgentTransport with AIConversationTransport<AgentMessage> {
///   AgentTransport(this.channel);
///
///   final AgentChannel channel;
///
///   @override
///   void connect(AIConversationFeed<AgentMessage> feed) {
///     channel.messages.listen(feed.updateMessages);
///   }
///
///   @override
///   Future<void> send(AIConversationRequest<AgentMessage> request) {
///     return channel.sendMessage(
///       request.text,
///       id: request.messageId,
///       files: request.attachments,
///     );
///   }
///
///   @override
///   Future<void> stop() => channel.stopGenerating();
/// }
/// ```
///
/// What the person sends shows straight away, as the [pendingMessage], and
/// the agent thinks until its reply starts. While a reply is written again,
/// or a message the person edited is answered again, the messages it replaces
/// are left out of [messages] until the new reply starts.
///
/// It notifies its listeners each time what it holds changes. Whoever creates
/// it calls [dispose] once it is no longer shown.
class AIConversation<M extends AIMessage> extends ChangeNotifier {
  /// Creates an [AIConversation] that reaches the agent through [transport].
  ///
  /// The conversation keeps [transport], and connects to it straight away.
  ///
  /// The [composer] holds what the person writes, such as one with the app's
  /// chat options. Without one the conversation creates its own, and disposes
  /// it with itself.
  ///
  /// The `replyTimeout` is how long the conversation waits, once the agent
  /// has the request, for the agent to start its reply or say what it is
  /// doing, before it shows an [AIAgentError]. It is five minutes by default.
  /// While the agent says it is working, such as thinking, it waits as long as
  /// that takes. With a `null` `replyTimeout`, it always waits as long as it
  /// takes.
  AIConversation({
    required AIConversationTransport<M> transport,
    ChatComposerController? composer,
    this.approver,
    this.actions = AIConversationActions.all,
    this._replyTimeout = const Duration(seconds: 300),
  }) : _transport = transport,
       composer = composer ?? ChatComposerController(),
       _ownsComposer = composer == null {
    transport.connect(AIConversationFeed._(this));
  }

  /// What the person is writing.
  ///
  /// [ChatComposer.conversation] shows it, and editing a message fills it.
  final ChatComposerController composer;

  /// Who answers tool calls' questions and sign-ins on this device, which the
  /// conversation asks them.
  final AIToolApprover? approver;

  /// What the conversation's views offer the person to do with its messages.
  final AIConversationActions actions;

  final AIConversationTransport<M> _transport;
  final bool _ownsComposer;
  final Duration? _replyTimeout;
  late final _attachments = PendingAttachments(onLoaded: _attachmentLoaded);

  /// The conversation as it shows, oldest message first.
  List<M> get messages => _messages;
  List<M> _messages = const [];

  /// The message the person sent last that is not in the conversation yet.
  ///
  /// It stays until its reply starts, and after it was stopped or failed,
  /// while [retry] can send it again.
  AIPendingMessage? get pendingMessage => _pendingMessage;
  AIPendingMessage? _pendingMessage;

  /// Where the latest exchange with the agent is.
  AIConversationStatus get status => _status;
  AIConversationStatus _status = AIConversationStatus.ready;

  /// Why the latest request failed, or, as an [AIAgentError], what the agent
  /// said when it couldn't answer or that it didn't answer in time.
  ///
  /// It stays until the next request, or until a reply starts after all.
  Object? get error => _error;
  Object? _error;

  /// What the agent says it is doing besides what its reply shows, such as
  /// checking sources.
  AIAgentActivity? get activity => _activity;
  AIAgentActivity? _activity;

  /// Whether the conversation has messages before the first one, which
  /// [loadOlderMessages] loads.
  bool get hasOlderMessages => _hasOlderMessages;
  bool _hasOlderMessages = false;

  /// How the person rated replies, by the reply's id: the rating they gave on
  /// this device, or else the reply's own [AIMessage.rating].
  Map<String, AIMessageRating> get ratings => _ratings;
  Map<String, AIMessageRating> _ratings = const {};

  /// The person's message they are editing in the composer, which the next
  /// message they send replaces.
  ///
  /// The composer shows that they are editing it, with a button that cancels
  /// it.
  M? get editingMessage => composer.isEditing ? _edited : null;

  // The messages as the transport last told them, including those left out of
  // `messages`.
  List<M> _received = const [];
  // The latest request, until its reply starts or another request takes its
  // place.
  ConversationExchange<M>? _exchange;
  // Counts the requests and stops, so the outcome of one that was overtaken is
  // ignored.
  int _generation = 0;
  // Replies stopped while they were written, which are finished whatever they
  // say.
  Set<String> _stopped = {};
  // Whether what the agent says it is doing is ignored, after it was stopped,
  // until it stops saying anything.
  bool _ignoresActivity = false;
  // The latest stop, which the next request waits for: the agent would stop
  // that one too.
  Future<void>? _stopping;
  // Ends the wait for the latest request's reply when the agent says nothing
  // for too long.
  Timer? _replyTimer;
  M? _edited;
  final _ratingChanges = <String, _RatingChange>{};
  int _ratingAttempts = 0;
  bool _isLoadingOlderMessages = false;
  bool _isDisposed = false;

  /// Sends a message, or the person's edit of the message they are editing.
  ///
  /// The [text] is what the person wrote, [attachments] the files they picked
  /// on this device, and [chatOption] the option they picked in the composer.
  /// A message with no text but whitespace, and no attachments, is ignored.
  void send(String text, {List<XFile> attachments = const [], ChatOption? chatOption}) {
    if (_isDisposed) return;
    if (text.trim().isEmpty && attachments.isEmpty) return;
    final editing = editingMessage;
    _edited = null;
    composer.isEditing = false;
    _start(
      AIConversationRequest(
        kind: editing == null ? AIConversationRequestKind.message : AIConversationRequestKind.edit,
        text: text,
        attachments: List.unmodifiable(attachments),
        chatOption: chatOption,
        message: editing,
      ),
    );
  }

  /// Stops the reply the agent is writing.
  ///
  /// What it wrote so far stays. When the reply hasn't started yet, the
  /// person's message stays, and a reply that still arrives is finished
  /// whatever it says. Does nothing while the agent isn't answering.
  void stop() {
    if (_isDisposed || !_status.isAnswering) return;
    _generation += 1;
    final id = _generation;
    _activity = null;
    _ignoresActivity = true;
    final exchange = _exchange;
    if (exchange != null && exchange.state == ExchangeState.waiting) exchange.state = ExchangeState.stopped;
    final writing = _writingReply;
    if (writing != null) _stopped.add(writing);
    _refresh();
    _stopping = () async {
      // The transport runs once `stop` has returned, so a failure it raises at
      // once is handled like one it raises later.
      await null;
      try {
        await _transport.stop();
      } on Object catch (error, stack) {
        if (!_isDisposed) _stopFailed(id, writing, error, stack);
      }
    }();
  }

  /// Asks the agent for a new reply in place of [reply], and of those after
  /// it.
  ///
  /// Does nothing for one of the person's messages, or one not in the
  /// conversation.
  void regenerate(M reply) {
    if (_isDisposed) return;
    final index = _indexOf(reply);
    if (index == null || _received[index].role == AIMessageRole.user) return;
    _start(_regenerateRequest(index));
  }

  /// Puts [message], one of the person's, in the composer to edit.
  ///
  /// The composer takes focus, each time it is called. The next message they
  /// send replaces it. Does nothing for a reply.
  void edit(M message) {
    if (_isDisposed || message.role != AIMessageRole.user) return;
    _edited = message;
    final text = message.text;
    composer.textEditingController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    composer.isEditing = true;
    composer.requestFocus();
  }

  /// Stops editing a message, and empties the composer.
  ///
  /// Does nothing while the person isn't editing one.
  void cancelEditing() {
    if (_isDisposed || editingMessage == null) return;
    _edited = null;
    composer.cancelEditing();
  }

  /// Tries again after [error].
  ///
  /// It sends the request that failed again, with the same message id, or
  /// asks the agent again for the reply it couldn't write. Does nothing
  /// without a request that failed.
  void retry() {
    if (_isDisposed) return;
    final exchange = _exchange;
    if (exchange == null || !exchange.hasFailed) return;
    _start(exchange.retryRequest(_received));
  }

  /// Forgets [error], and the request that failed.
  void clearError() {
    if (_isDisposed) return;
    _error = null;
    if (_exchange?.hasFailed ?? false) _exchange = null;
    _refresh();
  }

  /// Rates [reply], or takes the rating back with a `null` [rating].
  ///
  /// Ratings reach the transport in the order the person gives them, and the
  /// reply's rating goes back to the one the transport has if it can't take
  /// the new one.
  void rate(M reply, AIMessageRating? rating) {
    if (_isDisposed) return;
    final current = _ratings[reply.id];
    if (current == rating) return;
    _ratingAttempts += 1;
    final attempt = _ratingAttempts;
    final change = _ratingChanges[reply.id] ??= _RatingChange(shown: current, sent: current);
    final earlier = change.sending;
    change
      ..shown = rating
      ..attempt = attempt
      ..sending = () async {
        await earlier;
        if (_isDisposed) return;
        await _sendRating(rating, reply, attempt);
      }();
    _refresh();
  }

  /// Loads the messages before the first one, while there are any.
  ///
  /// One load runs at a time: a call while one runs does nothing. A load that
  /// fails is reported, and the next call tries again.
  Future<void> loadOlderMessages() async {
    if (!_hasOlderMessages || _isLoadingOlderMessages) return;
    _isLoadingOlderMessages = true;
    try {
      await _transport.loadOlderMessages();
    } on Object catch (error, stack) {
      _report(error, stack, 'while loading older messages');
    } finally {
      _isLoadingOlderMessages = false;
    }
  }

  /// Stops the conversation: the feed goes nowhere, and what is under way
  /// changes nothing. Disposes the [composer] the conversation created.
  ///
  /// From then on, sending, stopping, regenerating, editing, retrying and
  /// rating do nothing.
  @override
  void dispose() {
    _isDisposed = true;
    _replyTimer?.cancel();
    if (_ownsComposer) composer.dispose();
    super.dispose();
  }

  void _receiveMessages(List<M> messages) {
    _received = List.unmodifiable(messages);
    final exchange = _exchange;
    final reply = exchange?.reply(_received);
    if (exchange != null && reply != null) _receiveReply(reply, exchange);
    _refresh();
  }

  void _receiveHasOlderMessages(bool value) {
    if (_hasOlderMessages == value) return;
    _hasOlderMessages = value;
    notifyListeners();
  }

  void _receiveActivity(AIAgentActivity? activity) {
    if (activity == null) {
      _ignoresActivity = false;
      _activity = null;
      // The agent stopped saying it is working without starting its reply.
      final exchange = _exchange;
      if (exchange != null && exchange.state == ExchangeState.waiting) _waitForReply(exchange.id);
      _refresh();
      return;
    }
    if (_ignoresActivity) return;
    _activity = activity;
    if (activity.state == AIAgentActivityState.error) {
      _agentCouldNotAnswer(AIAgentError(message: activity.text));
    } else {
      // The agent is working on it, however long it thinks.
      _replyTimer?.cancel();
    }
    _refresh();
  }

  void _start(AIConversationRequest<M> request) {
    _generation += 1;
    final id = _generation;
    _error = null;
    _activity = null;
    _ignoresActivity = false;
    _stopped = {};
    _exchange = ConversationExchange(id: id, request: request, conversation: _received, attachmentOf: _attachments.of);
    _refresh();
    unawaited(_send(id, request, _stopping));
  }

  Future<void> _send(int id, AIConversationRequest<M> request, Future<void>? previousStop) async {
    // The agent would stop a request that reaches it before the stop made
    // before it.
    await previousStop;
    try {
      await _transport.send(request);
    } on Object catch (error) {
      if (!_isDisposed) _requestFailed(id, error);
      return;
    }
    if (!_isDisposed) _requestSent(id);
  }

  // The reply to the latest request arrived: once it shows something, or as
  // soon as it arrives after the person stopped the request.
  void _receiveReply(M reply, ConversationExchange<M> exchange) {
    if (exchange.state == ExchangeState.stopped) {
      if (reply.isGenerating) _stopped.add(reply.id);
      _exchange = null;
      return;
    }
    if (!exchange.hasReplyStarted(_received)) return;
    _exchange = null;
    if (exchange.hasFailed) {
      // The agent answered after all.
      _error = null;
      _stopped.remove(reply.id);
    }
  }

  void _requestSent(int id) {
    final exchange = _exchange;
    // The agent may already say it is working on it.
    if (exchange == null || exchange.id != id || exchange.state != ExchangeState.waiting || _activity != null) return;
    _waitForReply(id);
  }

  void _requestFailed(int id, Object error) {
    final exchange = _exchange;
    // Its reply started, so the agent had it, another request took its place,
    // or it already failed.
    if (exchange == null || exchange.id != id || exchange.hasFailed) return;
    if (error is AIConversationCancelledException) {
      _exchange = null;
    } else {
      exchange.state = ExchangeState.failed;
      _error = error;
    }
    _refresh();
  }

  // The agent goes on answering, and the composer offers to stop it again.
  void _stopFailed(int id, String? writing, Object error, StackTrace stack) {
    if (id != _generation || error is AIConversationCancelledException) return;
    _report(error, stack, 'while stopping the agent');
    if (writing != null) _stopped.remove(writing);
    final exchange = _exchange;
    if (exchange != null && exchange.state == ExchangeState.stopped) {
      exchange.state = ExchangeState.waiting;
      _waitForReply(exchange.id);
    }
    _ignoresActivity = false;
    _refresh();
  }

  // The agent couldn't answer the latest request, or the latest message: what
  // it was writing is finished, and `retry` asks it again.
  void _agentCouldNotAnswer(AIAgentError error) {
    final writing = _writingReply;
    if (writing != null) _stopped.add(writing);
    if (_exchange == null) {
      final request = _answerAgainRequest;
      if (request != null) {
        _generation += 1;
        _exchange = ConversationExchange(
          id: _generation,
          request: request,
          conversation: _received,
          attachmentOf: _attachments.of,
        );
      }
    }
    _exchange?.state = ExchangeState.unanswered;
    _error = error;
  }

  void _waitForReply(int id) {
    _replyTimer?.cancel();
    final timeout = _replyTimeout;
    if (timeout == null) return;
    _replyTimer = Timer(timeout, () => _replyTimedOut(id));
  }

  void _replyTimedOut(int id) {
    final exchange = _exchange;
    if (exchange == null || exchange.id != id || exchange.state != ExchangeState.waiting) return;
    _agentCouldNotAnswer(const AIAgentError());
    _refresh();
  }

  // Sends the latest rating of a reply. Those it replaced while one was on its
  // way aren't.
  Future<void> _sendRating(AIMessageRating? rating, M reply, int attempt) async {
    if (_ratingChanges[reply.id]?.attempt != attempt) return;
    try {
      await _transport.rate(reply, rating);
      _ratingChanges[reply.id]?.sent = rating;
    } on Object catch (error, stack) {
      _report(error, stack, 'while sending the rating of a reply');
      final change = _ratingChanges[reply.id];
      if (_isDisposed || change == null || change.attempt != attempt) return;
      change.shown = change.sent;
      _refresh();
    }
  }

  // Asks for a new reply in place of the one at `index`, to the person's
  // message before it.
  AIConversationRequest<M> _regenerateRequest(int index) {
    final prompt = _received.take(index).lastWhereOrNull((m) => m.role == AIMessageRole.user);
    return AIConversationRequest(
      kind: AIConversationRequestKind.regenerate,
      text: prompt?.text ?? '',
      message: _received[index],
    );
  }

  // Asks again for the latest message's reply: the reply written again, or one
  // to the person's message, which has none.
  AIConversationRequest<M>? get _answerAgainRequest {
    if (_received.isEmpty) return null;
    final last = _received.length - 1;
    if (_received[last].role != AIMessageRole.user) return _regenerateRequest(last);
    return AIConversationRequest(kind: AIConversationRequestKind.regenerate, text: _received[last].text);
  }

  // The id of the latest reply, while the agent writes it.
  String? get _writingReply {
    final last = _received.lastOrNull;
    if (last == null || last.role == AIMessageRole.user || !last.isGenerating) return null;
    return last.id;
  }

  int? _indexOf(M message) {
    final index = _received.indexWhere((m) => m.id == message.id);
    return index < 0 ? null : index;
  }

  void _attachmentLoaded() {
    if (!_isDisposed) _refresh();
  }

  // Works out what the conversation shows and where it is, after anything
  // changes.
  void _refresh() {
    final exchange = _exchange;
    final replaced = exchange?.state == ExchangeState.waiting ? exchange!.replaced : null;
    if (replaced == null && _stopped.isEmpty) {
      _messages = _received;
    } else {
      _messages = List.unmodifiable(_received.where((message) => _isShown(message, replaced)));
    }
    final pending = exchange?.shownPending;
    if (_pendingMessage != pending) _pendingMessage = pending;
    final ratings = _currentRatings();
    if (!mapEquals(_ratings, ratings)) _ratings = ratings;
    final status = _currentStatus();
    if (_status != status) _status = status;
    if (composer.isGenerating != status.isAnswering) composer.isGenerating = status.isAnswering;
    notifyListeners();
  }

  // Whether the conversation shows `message`: not one the request on its way
  // replaces, and not a reply stopped before it showed anything, which has
  // nothing to show and would make the conversation think it is still on its
  // way.
  bool _isShown(M message, Map<String, M>? replaced) {
    if (replaced != null && replaced.containsKey(message.id)) return false;
    if (!_stopped.contains(message.id)) return true;
    return !hasEmptyContent(message);
  }

  Map<String, AIMessageRating> _currentRatings() {
    final ratings = <String, AIMessageRating>{};
    for (final message in _received) {
      if (message.role == AIMessageRole.user) continue;
      _put(ratings, message.id, message.rating);
    }
    for (final MapEntry(key: id, value: change) in _ratingChanges.entries) {
      _put(ratings, id, change.shown);
    }
    return Map.unmodifiable(ratings);
  }

  static void _put(Map<String, AIMessageRating> ratings, String id, AIMessageRating? rating) {
    if (rating == null) {
      ratings.remove(id);
    } else {
      ratings[id] = rating;
    }
  }

  AIConversationStatus _currentStatus() {
    if (_exchange?.state == ExchangeState.waiting) return AIConversationStatus.submitted;
    final last = _messages.lastOrNull;
    if (last != null && _isBeingWritten(last)) {
      return hasEmptyContent(last) ? AIConversationStatus.submitted : AIConversationStatus.streaming;
    }
    if (_isWorkingOnLatestMessage(last)) return AIConversationStatus.submitted;
    return _error == null ? AIConversationStatus.ready : AIConversationStatus.error;
  }

  // Whether the agent is writing `message`: a reply that is still generating,
  // and wasn't stopped.
  bool _isBeingWritten(M message) {
    if (message.role == AIMessageRole.user) return false;
    if (!message.isGenerating) return false;
    return !_stopped.contains(message.id);
  }

  // Whether the agent says it is working on the person's latest message, whose
  // reply isn't here yet.
  bool _isWorkingOnLatestMessage(M? last) {
    final activity = _activity;
    if (activity == null) return false;
    if (activity.state == AIAgentActivityState.error) return false;
    return last == null || last.role == AIMessageRole.user;
  }

  static void _report(Object error, StackTrace stack, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stream_chat_flutter_ai',
        context: ErrorDescription(context),
      ),
    );
  }
}

// A rating the person gave a reply on this device, shown in place of the
// reply's own.
class _RatingChange {
  _RatingChange({required this.shown, required this.sent});

  AIMessageRating? shown;
  // What the transport has, which the rating goes back to when it can't take
  // a new one.
  AIMessageRating? sent;
  // Tells the latest rating of the reply apart from those before it.
  int attempt = 0;
  // Sends the latest rating, after those before it.
  Future<void>? sending;
}

/// Where an [AIConversationTransport] tells its [AIConversation] what the
/// conversation holds.
///
/// The transport gets it in [AIConversationTransport.connect]. Keep it for as
/// long as the transport follows what the conversation holds: once the
/// conversation is disposed or no longer used, its updates go nowhere.
final class AIConversationFeed<M extends AIMessage> {
  AIConversationFeed._(AIConversation<M> conversation) : _conversation = WeakReference(conversation);

  final WeakReference<AIConversation<M>> _conversation;

  AIConversation<M>? get _target {
    final conversation = _conversation.target;
    if (conversation == null || conversation._isDisposed) return null;
    return conversation;
  }

  /// Whether the conversation it updates is still there.
  ///
  /// Stop following what it holds once it isn't.
  bool get isConnected => _target != null;

  /// Tells the conversation its [messages], oldest first, each time they
  /// change.
  void updateMessages(List<M> messages) => _target?._receiveMessages(messages);

  /// Tells the conversation whether there are messages before the first one,
  /// which [AIConversationTransport.loadOlderMessages] loads.
  // ignore: avoid_positional_boolean_parameters
  void updateHasOlderMessages(bool hasOlderMessages) => _target?._receiveHasOlderMessages(hasOlderMessages);

  /// Tells the conversation what the agent says it is doing, or, with a
  /// `null` [activity], that it stopped saying.
  void updateActivity(AIAgentActivity? activity) => _target?._receiveActivity(activity);
}
