import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:stream_chat_flutter_ai/src/components/stream_ai_component_builders.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_assistant_message_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_offers.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_status.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_thinking_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_user_message_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/conversation_state.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_document.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_host.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/message/ai_reply_actions_view.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approver.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/conversation_theme.dart';
import 'package:stream_core_flutter/core.dart';

/// The messages of an AI conversation, oldest first.
///
/// The conversation starts at the top of the list and grows down. When the
/// person sends a message the list scrolls it to the top, and the reply types
/// out below it without moving anything on screen. A conversation that loads,
/// or replaces the one shown, opens at its end, and a button brings the end
/// back into view whenever it is out of it.
///
/// Each message the person sends starts a turn: that message and the replies
/// after it. The latest turn, with the bottom [padding] under it, is at least as
/// tall as the list, so its message can always reach the top.
///
/// ```dart
/// AIConversationView(
///   messages: messages,
///   pendingMessage: sending,
///   isThinking: isWaitingForReply,
///   approver: approver,
///   loadOlderMessages: hasMore ? loadOlder : null,
///   footer: error == null ? null : RetryButton(error: error, onPressed: retry),
///   emptyContent: const Text('How can I help?'),
/// )
/// ```
///
/// Or give it an [AIConversation], which holds the conversation and acts on
/// what the person does, with [AIConversationView.conversation]: it follows
/// the conversation as it changes.
///
/// The rows can be replaced through the `userMessage` and `assistantMessage`
/// builders of [streamAIComponentBuilders], and under each finished reply its
/// `replyActions` builder shows the person's actions, nothing until you set
/// it. A row is only built again when what its message says changes, or the
/// builders do, so a reply streaming in does not rebuild the rest of the
/// conversation. A builder that shows state of your own, such as a reply's
/// rating, should therefore read it through a [Listenable] (a
/// [ListenableBuilder] or [ValueListenableBuilder] in what it returns), and
/// the builders, [onAttachmentTap] and [approver] should be created once
/// rather than in `build`, since new ones rebuild every row.
///
/// When given a [ui] host, replies that carry generated UI show that UI
/// instead of their text, below their steps.
///
/// Place the composer below the list rather than over it, so the list knows how
/// much of it is visible.
class AIConversationView extends StatefulWidget {
  /// Creates an [AIConversationView].
  const AIConversationView({
    super.key,
    required this.messages,
    this.pendingMessage,
    this.isThinking = false,
    this.approver,
    this.ui,
    this.loadOlderMessages,
    this.onAttachmentTap,
    this.footer,
    this.emptyContent,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  }) : _conversation = null;

  /// Creates an [AIConversationView] that shows `conversation`, and follows it
  /// as it changes.
  ///
  /// The list shows the conversation's messages, the message on its way and
  /// the agent thinking while its status is
  /// [AIConversationStatus.submitted], asks the conversation's approver tool
  /// calls' questions, and loads older messages while the conversation has
  /// any. The person's latest message offers to edit it, and each finished
  /// reply to rate it, the latest also to regenerate it, as the
  /// conversation's [AIConversation.actions] allow. Under each finished reply
  /// an [AIReplyActionsView] offers them, unless the `replyActions` builder
  /// of [streamAIComponentBuilders] is set, which finds them in
  /// [AIReplyActionsProps.actions].
  ///
  /// The package shows no error of its own: put the conversation's
  /// [AIConversation.error] and a way to retry in the [footer], which shows
  /// under the empty content too, such as when a first message failed. Read
  /// the conversation through a [ListenableBuilder] there, so the footer
  /// follows it:
  ///
  /// ```dart
  /// AIConversationView.conversation(
  ///   conversation: conversation,
  ///   footer: ListenableBuilder(
  ///     listenable: conversation,
  ///     builder: (context, _) {
  ///       if (conversation.status != AIConversationStatus.error) {
  ///         return const SizedBox.shrink();
  ///       }
  ///       return TextButton(
  ///         onPressed: conversation.retry,
  ///         child: const Text('Try again'),
  ///       );
  ///     },
  ///   ),
  /// )
  /// ```
  const AIConversationView.conversation({
    super.key,
    required AIConversation this._conversation,
    this.ui,
    this.onAttachmentTap,
    this.footer,
    this.emptyContent,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  }) : messages = const [],
       pendingMessage = null,
       isThinking = false,
       approver = null,
       loadOlderMessages = null;

  // The conversation the list follows, which makes it read that rather than
  // its own parameters.
  final AIConversation? _conversation;

  // What the list reads, which the constructor decides.
  _ConversationSource get _source {
    final conversation = _conversation;
    if (conversation == null) return _PlainSource(this);
    return _DrivenSource(conversation);
  }

  /// The conversation, oldest message first. A reply that shows nothing yet is
  /// left out; meanwhile the list shows the agent thinking.
  final List<AIMessage> messages;

  /// A message the person sent that is not in [messages] yet. Keep passing it
  /// until its reply starts: the list stops showing it once its copy arrives.
  final AIPendingMessage? pendingMessage;

  /// Whether the agent is answering the latest message and its reply shows
  /// nothing yet. Meanwhile the latest turn ends with an [AIThinkingView], and
  /// the reply's first reasoning step takes over its count.
  ///
  /// The list also knows the agent is thinking while [pendingMessage] waits, and
  /// while the latest reply is being written but shows nothing.
  final bool isThinking;

  /// Who answers tool calls' questions on this device.
  final AIToolApprover? approver;

  /// Shows the generated UI of the agent's replies, with the host's renderers
  /// and the app's components.
  ///
  /// A reply whose UI isn't in a format any renderer reads shows its text
  /// instead. While a reply has nothing but such UI, the thinking indicator
  /// stays.
  ///
  /// Keep the same host for as long as the conversation is shown. A new host
  /// starts every reply's UI over, losing state such as form values.
  final AIUIHost? ui;

  /// Loads the messages before the first one, which the list asks for as the
  /// person scrolls to its start. It shows a spinner meanwhile, and what is on
  /// screen stays in place as they arrive. Pass `null` once there are none
  /// left.
  final Future<void> Function()? loadOlderMessages;

  /// Opens one of a message's attachments, in place of the default.
  ///
  /// Without it, a file attachment with a URL opens when tapped, as the
  /// attachment view documents, and an image does nothing. When set, it gets
  /// every attachment's tap.
  final ValueChanged<AIMessageAttachment>? onAttachmentTap;

  /// A widget under the latest turn's messages, or under the [emptyContent]
  /// while there are none, such as what the agent is doing, or an error with a
  /// way to retry.
  ///
  /// When a reply fails, end the thinking too: stop passing [isThinking], and
  /// don't leave a reply that shows nothing marked as still generating.
  /// Otherwise the latest turn keeps counting "Thinking…", and the person
  /// can't tell a failure from a slow model.
  final Widget? footer;

  /// What the list shows while there are no messages, centered in it.
  final Widget? emptyContent;

  /// The space around the turns.
  ///
  /// An app that floats its composer over the list gives it a bottom padding
  /// the size of the composer, which keeps the latest message and the
  /// scroll-to-latest button above it. A list showing its end keeps showing it
  /// when the padding changes, such as when the composer grows.
  ///
  /// With `extendBody`, a [Scaffold] lays its body under the
  /// `bottomNavigationBar` and passes the bar's height down as
  /// `MediaQuery.paddingOf(context).bottom`:
  ///
  /// ```dart
  /// Scaffold(
  ///   extendBody: true,
  ///   bottomNavigationBar: Padding(
  ///     // The bar doesn't move with the keyboard on its own.
  ///     padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
  ///     child: SafeArea(top: false, child: ChatComposer(onSendPressed: send)),
  ///   ),
  ///   body: Builder(
  ///     builder: (context) => AIConversationView(
  ///       messages: messages,
  ///       padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.paddingOf(context).bottom),
  ///     ),
  ///   ),
  /// )
  /// ```
  final EdgeInsets padding;

  @override
  State<AIConversationView> createState() => _AIConversationViewState();
}

class _AIConversationViewState extends State<AIConversationView> {
  final _controller = ScrollController();
  final _tracker = PendingMessageTracker();
  final _clock = ThinkingClock();
  final _centerKey = UniqueKey();
  final _turnKeys = <String, GlobalKey>{};

  // The turn the list grows down from. Turns before it, which older messages
  // add, grow up from it instead, so what is on screen stays in place.
  String? _anchor;
  String? _lastTurn;
  bool _endInView = true;

  late _ConversationSource _source;
  List<ConversationEntry> _entries = const [];
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateEndInView);
    _source = widget._source;
    _source.listenable?.addListener(_onSourceChanged);
  }

  @override
  void dispose() {
    _source.listenable?.removeListener(_onSourceChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSourceChanged() => setState(() {
    // What the list follows changed; `build` reads it.
  });

  @override
  void didUpdateWidget(AIConversationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final followed = _source.listenable;
    _source = widget._source;
    if (_source.listenable != followed) {
      followed?.removeListener(_onSourceChanged);
      _source.listenable?.addListener(_onSourceChanged);
    }
    final old = oldWidget.padding;
    final padding = widget.padding;
    if (old.top == padding.top && old.bottom == padding.bottom) return;
    // A list at its end, such as one whose composer just grew, keeps showing
    // it. One the person scrolled up, or with room under a turn just sent, stays.
    if (_lastTurn == null || !_controller.hasClients) return;
    final position = _controller.position;
    if (position.maxScrollExtent - position.pixels <= 1) _jumpToEnd();
  }

  void _updateEndInView() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final inView = position.maxScrollExtent - position.pixels <= 24;
    if (inView != _endInView) setState(() => _endInView = inView);
  }

  // Shows the end of the conversation. Turns not laid out yet have estimated
  // heights, which can leave it short of the end, so it goes again until the
  // end stays put.
  void _jumpToEnd([int attempts = 3]) {
    final generation = _scrollGeneration;
    _afterFrame(() {
      if (!_controller.hasClients || generation != _scrollGeneration) return;
      final position = _controller.position;
      final end = position.maxScrollExtent;
      if (position.pixels != end) position.jumpTo(end);
      if (attempts > 1) _jumpToEnd(attempts - 1);
    });
  }

  // Scrolls the list does itself, which the person scrolling calls off.
  int _scrollGeneration = 0;

  bool _onScrollStart(ScrollStartNotification notification) {
    if (notification.dragDetails != null) _scrollGeneration++;
    return false;
  }

  // Runs [callback] after the next frame, and makes sure there is one: a
  // post-frame callback alone waits for whatever frame comes next, such as one
  // of the person's own scroll.
  void _afterFrame(VoidCallback callback) {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) callback();
      })
      ..ensureVisualUpdate();
  }

  // Brings [turn] to the top, which a turn the person just started can reach:
  // with the bottom padding under it, it is at least as tall as the list.
  void _scrollToTop(String turn, {required bool animate, int attempts = 3}) {
    final generation = _scrollGeneration;
    _afterFrame(() {
      // Gone, such as a message that failed to send and is no longer passed.
      if (!_controller.hasClients || generation != _scrollGeneration || !_turnKeys.containsKey(turn)) return;
      final context = _turnKeys[turn]?.currentContext;
      if (context == null) {
        // Not built: it is far below what is in view. Get close first.
        if (attempts <= 1) return;
        _controller.position.jumpTo(_controller.position.maxScrollExtent);
        _scrollToTop(turn, animate: false, attempts: attempts - 1);
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          context,
          duration: animate && !_reduceMotion ? const Duration(milliseconds: 300) : Duration.zero,
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  Future<void> _scrollToLatest() async {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (_reduceMotion) {
      position.jumpTo(position.maxScrollExtent);
    } else {
      await position.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    _jumpToEnd(2);
  }

  // Works out the rows once per build, since matching messages on their way
  // remembers what it has seen.
  List<ConversationTurn> _turns() {
    final ui = widget.ui;
    final messages = _source.messages;
    // The rows build only the replies on screen, so the engines take every
    // reply's UI first.
    ui?.receive(messages);
    // The same answer as the rows': whether the engine built a widget.
    final canShowUI = ui == null
        ? showsNoUI
        : (AIUIDocument document, String messageId) =>
              AIUIView(host: ui, document: document, messageId: messageId).canShow;
    _entries = _tracker.entries(messages, _source.pendingMessage, canShowUI: canShowUI);
    _thinking = _source.isThinking(tracker: _tracker, entries: _entries, ui: ui, canShowUI: canShowUI);
    final turns = ConversationTurn.of(_entries);
    _clock.update(
      latest: turns.lastOrNull?.id,
      isThinking: _thinking,
      hasReplies: (turns.lastOrNull?.entries.length ?? 0) > 1,
    );

    final ids = {for (final turn in turns) turn.id};
    _turnKeys.removeWhere((id, _) => !ids.contains(id));
    final last = turns.lastOrNull?.id;
    if (_anchor == null || !ids.contains(_anchor)) {
      final replaced = _lastTurn == null || !ids.contains(_lastTurn);
      _anchor = turns.firstOrNull?.id;
      // The conversation loaded, or another replaced it: it opens at its end.
      // Its first turns going away, such as when they are trimmed, is not that.
      if (replaced && last != null) _jumpToEnd();
    } else if (last != _lastTurn && last != null) {
      if (_lastTurn != null && ids.contains(_lastTurn)) {
        _scrollToTop(last, animate: true);
      } else {
        _jumpToEnd();
      }
    }
    _lastTurn = last;
    return turns;
  }

  @override
  Widget build(BuildContext context) {
    final turns = _turns();
    final theme = ConversationTheme.of(context);
    final loadOlder = _source.loadOlderMessages;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        if (turns.isEmpty) {
          final footer = widget.footer;
          final empty = widget.emptyContent ?? const SizedBox.shrink();
          return SizedBox(
            width: double.infinity,
            height: height,
            child: footer == null
                ? Center(child: empty)
                // The footer can say why a first message isn't there, such as an
                // error to retry. The empty content keeps the space above it.
                : Column(
                    children: [
                      Expanded(child: Center(child: empty)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: context.streamSpacing.md),
                        child: footer,
                      ),
                    ],
                  ),
          );
        }

        final anchorIndex = turns.indexWhere((t) => t.id == _anchor);
        final older = turns.sublist(0, anchorIndex).reversed.toList();
        final newer = turns.sublist(anchorIndex);
        final padding = widget.padding;

        Widget turn(ConversationTurn turn) => _TurnView(
          key: _turnKeys.putIfAbsent(turn.id, GlobalKey.new),
          turn: turn,
          clock: _clock,
          isLatest: turn.id == turns.last.id,
          isThinking: _thinking,
          // Leave room for the bottom padding, so scrolling to the end puts the
          // latest message at the top, just like sending one does. A list
          // shorter than its bottom padding has nothing to leave.
          minHeight: max(0, height - padding.bottom),
          footer: widget.footer,
          approver: _source.approver,
          conversation: _source.conversation,
          ui: widget.ui,
          onAttachmentTap: widget.onAttachmentTap,
          padding: EdgeInsets.only(left: padding.left, right: padding.right),
        );

        return Stack(
          children: [
            NotificationListener<ScrollStartNotification>(
              onNotification: _onScrollStart,
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _updateEndInView();
                  return false;
                },
                child: CustomScrollView(
                  controller: _controller,
                  center: _centerKey,
                  slivers: [
                    SliverList.builder(
                      itemCount: older.length + (loadOlder == null ? 0 : 1),
                      itemBuilder: (context, index) => index < older.length
                          ? turn(older[index])
                          : _OlderMessagesLoader(
                              firstTurn: turns.first.id,
                              load: loadOlder!,
                              color: theme.scrollButtonIconColor ?? context.streamColorScheme.textPrimary,
                            ),
                    ),
                    // Turns from the anchor on, which the list grows down from.
                    SliverPadding(
                      key: _centerKey,
                      padding: EdgeInsets.only(top: padding.top),
                      sliver: SliverList.builder(
                        itemCount: newer.length,
                        itemBuilder: (context, index) => turn(newer[index]),
                      ),
                    ),
                    SliverPadding(padding: EdgeInsets.only(bottom: padding.bottom)),
                  ],
                ),
              ),
            ),
            Positioned(
              left: padding.left,
              right: padding.right,
              bottom: padding.bottom + 8,
              child: Center(
                child: IgnorePointer(
                  ignoring: _endInView,
                  child: AnimatedOpacity(
                    opacity: _endInView ? 0 : 1,
                    duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: AnimatedScale(
                      scale: _endInView ? 0.8 : 1,
                      duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: _ScrollToLatestButton(onPressed: _scrollToLatest),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// What the list reads and follows, which its constructor decides once: the
// parameters of `AIConversationView.new`, or an `AIConversation`.
sealed class _ConversationSource {
  const _ConversationSource();

  // The messages shown, and the one on its way.
  List<AIMessage> get messages;
  AIPendingMessage? get pendingMessage;

  // Who answers tool calls' questions.
  AIToolApprover? get approver;

  // Loads older messages, or `null` while there are none.
  Future<void> Function()? get loadOlderMessages;

  // Notifies when what the list reads changes, or `null` when it never does on
  // its own.
  Listenable? get listenable;

  // The conversation the rows act on, if there is one.
  AIConversation? get conversation;

  // Whether the agent is answering and its reply shows nothing yet, given the
  // `entries` the list shows after `tracker` followed `messages`.
  bool isThinking({
    required PendingMessageTracker tracker,
    required List<ConversationEntry> entries,
    required AIUIHost? ui,
    required CanShowUI canShowUI,
  });
}

// What the list is given, which it can only show.
final class _PlainSource extends _ConversationSource {
  const _PlainSource(this._view);

  final AIConversationView _view;

  @override
  List<AIMessage> get messages => _view.messages;

  @override
  AIPendingMessage? get pendingMessage => _view.pendingMessage;

  @override
  AIToolApprover? get approver => _view.approver;

  @override
  Future<void> Function()? get loadOlderMessages => _view.loadOlderMessages;

  @override
  Listenable? get listenable => null;

  @override
  AIConversation? get conversation => null;

  @override
  bool isThinking({
    required PendingMessageTracker tracker,
    required List<ConversationEntry> entries,
    required AIUIHost? ui,
    required CanShowUI canShowUI,
  }) {
    if (_view.isThinking) return true;
    return tracker.isAwaitingReply(messages, pendingMessage, canShowUI: canShowUI);
  }
}

// What an `AIConversation` holds, which the list follows and acts on.
final class _DrivenSource extends _ConversationSource {
  const _DrivenSource(this.conversation);

  @override
  final AIConversation conversation;

  @override
  List<AIMessage> get messages => conversation.messages;

  @override
  AIPendingMessage? get pendingMessage => conversation.pendingMessage;

  @override
  AIToolApprover? get approver => conversation.approver;

  @override
  Future<void> Function()? get loadOlderMessages {
    if (!conversation.hasOlderMessages) return null;
    return conversation.loadOlderMessages;
  }

  @override
  Listenable get listenable => conversation;

  // The conversation knows when its agent is thinking, including after a stop
  // or a failure that leaves the person's message on its way. A reply that
  // shows only its UI has started, which the conversation can't tell without
  // the host that reads it.
  @override
  bool isThinking({
    required PendingMessageTracker tracker,
    required List<ConversationEntry> entries,
    required AIUIHost? ui,
    required CanShowUI canShowUI,
  }) {
    if (conversation.status != AIConversationStatus.submitted) return false;
    if (ui == null) return true;
    return entries.lastOrNull?.isFromUser ?? true;
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({
    super.key,
    required this.turn,
    required this.clock,
    required this.isLatest,
    required this.isThinking,
    required this.minHeight,
    required this.footer,
    required this.approver,
    required this.conversation,
    required this.ui,
    required this.onAttachmentTap,
    required this.padding,
  });

  final ConversationTurn turn;
  final ThinkingClock clock;
  final bool isLatest;
  final bool isThinking;
  final double minHeight;
  final Widget? footer;
  final AIToolApprover? approver;
  final AIConversation? conversation;
  final AIUIHost? ui;
  final ValueChanged<AIMessageAttachment>? onAttachmentTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    return ThinkingTurnScope(
      clock: clock,
      turn: turn.id,
      // 8 between turns. It goes under a turn rather than above it, so the
      // first one keeps its place whether or not older messages can load.
      child: Padding(
        padding: EdgeInsets.only(bottom: isLatest ? 0 : 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: isLatest ? minHeight : 0),
          child: Padding(
            padding: padding.copyWith(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                for (final entry in turn.entries)
                  _EntryView(
                    key: ValueKey(entry.id),
                    entry: entry,
                    approver: approver,
                    conversation: conversation,
                    ui: ui,
                    onAttachmentTap: onAttachmentTap,
                  ),
                if (isLatest && isThinking) const Align(alignment: Alignment.centerLeft, child: AIThinkingView()),
                if (isLatest && footer != null) footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// What a row shows, which decides whether it is built again: including what
// its conversation offers to do with its message.
@immutable
class _Shown {
  _Shown(ConversationEntry entry, this.approver, this.conversation, this.ui, this.onAttachmentTap)
    : isPending = entry.message == null,
      role = entry.message?.role ?? AIMessageRole.user,
      text = entry.message?.text ?? entry.pending?.text ?? '',
      isGenerating = entry.message?.isGenerating ?? false,
      parts = entry.message?.parts ?? const [],
      reasoning = [
        for (final part in entry.message?.parts ?? const [])
          if (part.reasoning case final step?) entry.message!.reasoningText(step),
      ],
      attachments = entry.attachments,
      isLatestReply = entry.isLatestReply,
      uiDocument = entry.message?.uiDocument,
      rating = _rating(entry, conversation),
      offersRegenerate = _offersRegenerate(entry, conversation),
      offersEdit = _offersEdit(entry, conversation);

  static AIMessageRating? _rating(ConversationEntry entry, AIConversation? conversation) {
    final message = entry.message;
    if (conversation == null || message == null || message.role == AIMessageRole.user) return null;
    return conversation.ratings[message.id];
  }

  static bool _offersRegenerate(ConversationEntry entry, AIConversation? conversation) {
    final message = entry.message;
    if (conversation == null || message == null || message.role == AIMessageRole.user) return false;
    return conversation.offersRegenerate(isLatestReply: entry.isLatestReply);
  }

  static bool _offersEdit(ConversationEntry entry, AIConversation? conversation) {
    final message = entry.message;
    if (conversation == null || message == null) return false;
    return conversation.offersEdit(message);
  }

  final bool isPending;
  final AIMessageRole role;
  final String text;
  final bool isGenerating;
  final List<Object?> parts;
  final List<String?> reasoning;
  final List<AIMessageAttachment> attachments;
  final AIToolApprover? approver;
  final AIConversation? conversation;
  final AIUIHost? ui;
  final ValueChanged<AIMessageAttachment>? onAttachmentTap;
  final bool isLatestReply;
  final AIUIDocument? uiDocument;
  final AIMessageRating? rating;
  final bool offersRegenerate;
  final bool offersEdit;

  @override
  bool operator ==(Object other) =>
      other is _Shown &&
      other.isPending == isPending &&
      other.role == role &&
      other.text == text &&
      other.isGenerating == isGenerating &&
      listEquals(other.parts, parts) &&
      listEquals(other.reasoning, reasoning) &&
      listEquals(other.attachments, attachments) &&
      identical(other.approver, approver) &&
      identical(other.conversation, conversation) &&
      identical(other.ui, ui) &&
      other.onAttachmentTap == onAttachmentTap &&
      other.isLatestReply == isLatestReply &&
      other.uiDocument == uiDocument &&
      other.rating == rating &&
      other.offersRegenerate == offersRegenerate &&
      other.offersEdit == offersEdit;

  @override
  int get hashCode => Object.hash(isPending, role, text, isGenerating, parts.length, attachments.length, isLatestReply);
}

class _EntryView extends StatefulWidget {
  const _EntryView({
    super.key,
    required this.entry,
    required this.approver,
    required this.conversation,
    required this.ui,
    required this.onAttachmentTap,
  });

  final ConversationEntry entry;
  final AIToolApprover? approver;
  final AIConversation? conversation;
  final AIUIHost? ui;
  final ValueChanged<AIMessageAttachment>? onAttachmentTap;

  @override
  State<_EntryView> createState() => _EntryViewState();
}

class _EntryViewState extends State<_EntryView> {
  // Whether the reply's answer is still typing out, which its actions wait for
  // so they do not move down with it. `null` when its view does not say.
  final _writing = ValueNotifier<bool?>(null);
  // Whether a frame has built the row. Until one has, the view of a reply whose
  // answer can be held has not had the chance to say so, so no actions show.
  bool _framed = false;
  bool _framing = false;
  _Shown? _shown;
  Widget? _built;
  AIUIView? _generated;
  (AIUIHost, AIUIDocument, String)? _generatedFor;

  @override
  void initState() {
    super.initState();
    _writing.addListener(_onWritingChanged);
  }

  // Builds the row again once a frame has passed, for a reply whose answer can
  // be held. Other rows have nothing to wait for, so they build once.
  void _waitForFrame() {
    if (_framed || _framing) return;
    _framing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _framed = true;
        _built = null;
      });
    });
  }

  @override
  void dispose() {
    _writing.dispose();
    super.dispose();
  }

  void _onWritingChanged() => setState(() => _built = null);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _built = null;
  }

  @override
  Widget build(BuildContext context) {
    final shown = _Shown(widget.entry, widget.approver, widget.conversation, widget.ui, widget.onAttachmentTap);
    if (shown != _shown) {
      _shown = shown;
      _built = null;
    }
    return _built ??= AnswerWritingScope(writing: _writing, child: _content(context));
  }

  // The UI the agent generated for the reply, when one of the host's renderers
  // shows it. The engine is asked for it again only as the reply's document
  // changes, not each time the row builds.
  AIUIView? _generatedUI(AIMessage reply) {
    final ui = widget.ui;
    final document = reply.uiDocument;
    if (ui == null || document == null) {
      _generated = null;
      _generatedFor = null;
      return null;
    }
    final shown = (ui, document, reply.id);
    if (shown == _generatedFor) return _generated;
    _generatedFor = shown;
    final view = AIUIView(host: ui, document: document, messageId: reply.id);
    return _generated = view.canShow ? view : null;
  }

  // The actions under a finished reply: the builder's, or else, with a
  // conversation, its actions in an [AIReplyActionsView].
  Widget? _replyActions(BuildContext context, AIMessage reply, {required bool isLatestReply}) {
    final offered = widget.conversation?.replyActions(reply, isLatestReply: isLatestReply);
    final builder = context.aiComponentBuilder<AIReplyActionsProps>();
    if (builder != null) {
      return builder(context, AIReplyActionsProps(message: reply, isLatestReply: isLatestReply, actions: offered));
    }
    if (offered == null) return null;
    return AIReplyActionsView(text: reply.text, actions: offered);
  }

  Widget _content(BuildContext context) {
    final entry = widget.entry;
    final message = entry.message;
    final conversation = widget.conversation;
    if (entry.isFromUser) {
      final props = AIUserMessageProps(
        message: message,
        text: message?.text ?? entry.pending?.text ?? '',
        attachments: entry.attachments,
        onAttachmentTap: widget.onAttachmentTap,
        onEdit: message == null ? null : conversation?.editAction(message),
      );
      return context.aiComponentBuilder<AIUserMessageProps>()?.call(context, props) ??
          AIUserMessageView(
            text: props.text,
            attachments: props.attachments,
            onEdit: props.onEdit,
            onAttachmentTap: props.onAttachmentTap,
          );
    }

    final reply = message!;
    final generated = _generatedUI(reply);
    final assistant = AIAssistantMessageProps(
      message: reply,
      text: generated == null ? null : '',
      approver: widget.approver,
      onAttachmentTap: widget.onAttachmentTap,
    );
    final isWriting = _writing.value == true || (generated?.document.isStreaming ?? false);
    final hasAnswer = reply.text.isNotEmpty || reply.attachments.isNotEmpty || generated != null;
    // Only a turn the conversation saw thinking can hold its answer. A reply
    // from history shows its actions with it, so the list opens at its true end.
    final turn = ThinkingTurnScope.maybeOf(context);
    final canBeHeld = turn != null && turn.clock.start(turn.turn) != null;
    if (canBeHeld) _waitForFrame();
    final showsActions = (_framed || !canBeHeld) && !reply.isGenerating && hasAnswer && !isWriting;
    final actions = showsActions ? _replyActions(context, reply, isLatestReply: entry.isLatestReply) : null;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        context.aiComponentBuilder<AIAssistantMessageProps>()?.call(context, assistant) ??
            AIAssistantMessageView(
              text: assistant.text,
              isGenerating: reply.isGenerating,
              parts: reply.parts,
              attachments: reply.attachments,
              approver: widget.approver,
              reasoningText: reply.reasoningText,
              onAttachmentTap: widget.onAttachmentTap,
            ),
        if (generated != null) Padding(padding: const EdgeInsets.only(top: 8), child: generated),
        AnimatedSwitcher(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
          // The gap above the actions comes and goes with them, so an answer
          // without any leaves no space under it.
          child: actions == null
              ? const SizedBox.shrink()
              : Padding(padding: const EdgeInsets.only(top: 8), child: actions),
        ),
      ],
    );
  }
}

/// A spinner at the start of the list that loads older messages once it has
/// stayed in view a moment, rather than for the frame a list opening at its end
/// can show its start, and again whenever the first turn changes while it is in
/// view. A load that brings nothing, or fails, isn't retried until the first
/// turn changes or the spinner leaves and comes back into view.
class _OlderMessagesLoader extends StatefulWidget {
  const _OlderMessagesLoader({required this.firstTurn, required this.load, required this.color});

  final String firstTurn;
  final Future<void> Function() load;
  final Color? color;

  @override
  State<_OlderMessagesLoader> createState() => _OlderMessagesLoaderState();
}

class _OlderMessagesLoaderState extends State<_OlderMessagesLoader> {
  Timer? _timer;
  bool _loading = false;
  bool _wasInView = false;
  bool _checkingView = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.removeListener(_onScroll);
    _position = Scrollable.maybeOf(context)?.position?..addListener(_onScroll);
    _schedule();
  }

  @override
  void didUpdateWidget(_OlderMessagesLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.firstTurn != oldWidget.firstTurn) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  // Scrolling loads only when it brings the spinner into view, not on every
  // movement while it stays there. The position changes before the list lays
  // out, so where the spinner is gets checked after the frame.
  void _onScroll() {
    if (_checkingView) return;
    _checkingView = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkingView = false;
      if (!mounted) return;
      final inView = _inView;
      if (inView && !_wasInView) _schedule();
      _wasInView = inView;
    });
  }

  void _schedule() {
    if (_loading || (_timer?.isActive ?? false)) return;
    _timer = Timer(const Duration(milliseconds: 300), _loadIfInView);
  }

  bool get _inView {
    final box = context.findRenderObject() as RenderBox?;
    final scrollable = Scrollable.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize || scrollable == null) return false;
    final rect = box.localToGlobal(Offset.zero, ancestor: scrollable) & box.size;
    return rect.overlaps(Offset.zero & scrollable.size);
  }

  Future<void> _loadIfInView() async {
    if (!mounted || _loading) return;
    _wasInView = _inView;
    if (!_wasInView) return;
    final firstTurn = widget.firstTurn;
    _loading = true;
    try {
      await widget.load();
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stream_chat_flutter_ai',
          context: ErrorDescription('while loading older messages'),
        ),
      );
    } finally {
      _loading = false;
    }
    // The first turn changed while loading, such as a short page arriving:
    // load the next one if the spinner is still in view.
    if (mounted && widget.firstTurn != firstTurn) _schedule();
  }

  @override
  Widget build(BuildContext context) {
    // 8 under it, as between turns.
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Center(
        child: StreamLoadingSpinner(
          size: .sm,
          color: widget.color,
          backgroundColor: StreamColors.transparent,
          trackColor: StreamColors.transparent,
        ),
      ),
    );
  }
}

class _ScrollToLatestButton extends StatelessWidget {
  const _ScrollToLatestButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ConversationTheme.of(context);
    WidgetStateProperty<Color?>? all(Color? color) => color == null ? null : WidgetStatePropertyAll(color);
    return StreamButton.icon(
      onPressed: onPressed,
      style: .secondary,
      type: .outline,
      size: .medium,
      isFloating: true,
      tooltip: AITranslations.of(context).scrollToLatest,
      icon: Icon(context.streamIcons.arrowDown),
      themeStyle: StreamButtonThemeStyle(
        backgroundColor: all(theme.scrollButtonBackgroundColor),
        borderColor: all(theme.scrollButtonBorderColor),
        foregroundColor: all(theme.scrollButtonIconColor),
      ),
    );
  }
}
