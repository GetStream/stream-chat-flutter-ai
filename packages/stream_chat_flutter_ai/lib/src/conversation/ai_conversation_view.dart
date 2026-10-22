import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:stream_chat_flutter_ai/src/components/ai_component_factory.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_assistant_message_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_thinking_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_user_message_view.dart';
import 'package:stream_chat_flutter_ai/src/conversation/conversation_state.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approver.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/conversation_theme.dart';
import 'package:stream_core_flutter/chat.dart';

/// The messages of an AI conversation, oldest first.
///
/// The conversation starts at the top of the list and grows down. When the
/// person sends a message the list scrolls it to the top, and the reply types
/// out below it without moving anything on screen. A conversation that loads,
/// or replaces the one shown, opens at its end, and a button brings the end
/// back into view whenever it is out of it.
///
/// Each message the person sends starts a turn: that message and the replies
/// after it. The latest turn is at least as tall as the list, so its message
/// can always reach the top.
///
/// ```dart
/// AIConversationView(
///   messages: messages,
///   pendingMessage: sending,
///   isThinking: isWaitingForReply,
///   approver: approver,
///   loadOlderMessages: hasMore ? loadOlder : null,
///   emptyContent: const Text('How can I help?'),
/// )
/// ```
///
/// The rows can be replaced through the `userMessage` builder of [streamAIComponentBuilders] and
/// the `assistantMessage` builder of [streamAIComponentBuilders], and under each finished reply
/// the `replyActions` builder of [streamAIComponentBuilders] shows the person's actions, nothing until
/// you set it. A row is only built again when what it shows changes, so a
/// reply streaming in does not rebuild the rest of the conversation.
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
    this.loadOlderMessages,
    this.onAttachmentTap,
    this.footer,
    this.emptyContent,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

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

  /// Loads the messages before the first one, which the list asks for as the
  /// person scrolls to its start. It shows a spinner meanwhile, and what is on
  /// screen stays in place as they arrive. Pass `null` once there are none
  /// left.
  final Future<void> Function()? loadOlderMessages;

  /// Opens one of a message's attachments, such as by launching its URL.
  final ValueChanged<AIMessageAttachment>? onAttachmentTap;

  /// A widget under the latest turn's messages, such as what the agent is
  /// doing, or an error with a way to retry.
  final Widget? footer;

  /// What the list shows while there are no messages, centered in it.
  final Widget? emptyContent;

  /// The space around the turns.
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

  List<ConversationEntry> _entries = const [];
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateEndInView);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateEndInView() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final inView = position.maxScrollExtent - position.pixels <= 32;
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

  // Brings [turn] to the top, which a turn the person just started can reach,
  // being at least as tall as the list.
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
    _entries = _tracker.entries(widget.messages, widget.pendingMessage);
    _thinking = widget.isThinking || _tracker.isAwaitingReply(widget.messages, widget.pendingMessage);
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
    final loadOlder = widget.loadOlderMessages;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        if (turns.isEmpty) {
          return SizedBox(
            width: double.infinity,
            height: height,
            child: Center(child: widget.emptyContent ?? const SizedBox.shrink()),
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
          minHeight: height,
          footer: widget.footer,
          approver: widget.approver,
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
                              color: theme.scrollButtonIconColor,
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
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(
                child: IgnorePointer(
                  ignoring: _endInView,
                  child: AnimatedOpacity(
                    opacity: _endInView ? 0 : 1,
                    duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
                    child: _ScrollToLatestButton(onPressed: _scrollToLatest),
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
  final ValueChanged<AIMessageAttachment>? onAttachmentTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    return ThinkingTurnScope(
      clock: clock,
      turn: turn.id,
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
                _EntryView(key: ValueKey(entry.id), entry: entry, approver: approver, onAttachmentTap: onAttachmentTap),
              if (isLatest && isThinking) const Align(alignment: Alignment.centerLeft, child: AIThinkingView()),
              if (isLatest && footer != null) footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// What a row shows, which decides whether it is built again.
@immutable
class _Shown {
  _Shown(ConversationEntry entry, this.approver, this.onAttachmentTap)
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
      isLatestReply = entry.isLatestReply;

  final bool isPending;
  final AIMessageRole role;
  final String text;
  final bool isGenerating;
  final List<Object?> parts;
  final List<String?> reasoning;
  final List<AIMessageAttachment> attachments;
  final AIToolApprover? approver;
  final ValueChanged<AIMessageAttachment>? onAttachmentTap;
  final bool isLatestReply;

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
      other.onAttachmentTap == onAttachmentTap &&
      other.isLatestReply == isLatestReply;

  @override
  int get hashCode => Object.hash(isPending, role, text, isGenerating, parts.length, attachments.length, isLatestReply);
}

class _EntryView extends StatefulWidget {
  const _EntryView({super.key, required this.entry, required this.approver, required this.onAttachmentTap});

  final ConversationEntry entry;
  final AIToolApprover? approver;
  final ValueChanged<AIMessageAttachment>? onAttachmentTap;

  @override
  State<_EntryView> createState() => _EntryViewState();
}

class _EntryViewState extends State<_EntryView> {
  // Whether the reply's answer is still typing out, which its actions wait for
  // so they do not move down with it. `null` when its view does not say.
  final _writing = ValueNotifier<bool?>(null);
  _Shown? _shown;
  Widget? _built;

  @override
  void initState() {
    super.initState();
    _writing.addListener(_onWritingChanged);
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
    final shown = _Shown(widget.entry, widget.approver, widget.onAttachmentTap);
    if (shown != _shown) {
      _shown = shown;
      _built = null;
    }
    return _built ??= AnswerWritingScope(writing: _writing, child: _content(context));
  }

  Widget _content(BuildContext context) {
    final entry = widget.entry;
    final message = entry.message;
    if (entry.isFromUser) {
      final props = AIUserMessageProps(
        message: message,
        text: message?.text ?? entry.pending?.text ?? '',
        attachments: entry.attachments,
        onAttachmentTap: widget.onAttachmentTap,
      );
      return context.aiComponentBuilder<AIUserMessageProps>()?.call(context, props) ??
          AIUserMessageView(text: props.text, attachments: props.attachments, onAttachmentTap: props.onAttachmentTap);
    }

    final reply = message!;
    final assistant = AIAssistantMessageProps(
      message: reply,
      approver: widget.approver,
      onAttachmentTap: widget.onAttachmentTap,
    );
    final showsActions = !reply.isGenerating && reply.text.isNotEmpty && _writing.value != true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        context.aiComponentBuilder<AIAssistantMessageProps>()?.call(context, assistant) ??
            AIAssistantMessageView(
              text: reply.text,
              isGenerating: reply.isGenerating,
              parts: reply.parts,
              attachments: reply.attachments,
              approver: widget.approver,
              reasoningText: reply.reasoningText,
              onAttachmentTap: widget.onAttachmentTap,
            ),
        AnimatedSwitcher(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
          child: showsActions
              ? context.aiComponentBuilder<AIReplyActionsProps>()?.call(
                      context,
                      AIReplyActionsProps(message: reply, isLatestReply: entry.isLatestReply),
                    ) ??
                    const SizedBox.shrink()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// A spinner at the start of the list that loads older messages once it has
/// stayed in view a moment, rather than for the frame a list opening at its end
/// can show its start, and again whenever the first turn changes while it is in
/// view.
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
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.removeListener(_schedule);
    _position = Scrollable.maybeOf(context)?.position?..addListener(_schedule);
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
    _position?.removeListener(_schedule);
    super.dispose();
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
    if (!mounted || _loading || !_inView) return;
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
    // Still in view, such as after a short page: load the next one.
    if (mounted) _schedule();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: StreamLoadingSpinner(size: .md, color: widget.color),
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
