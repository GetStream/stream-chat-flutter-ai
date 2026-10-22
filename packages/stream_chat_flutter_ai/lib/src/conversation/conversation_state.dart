/// The bookkeeping behind `AIConversationView`: turns, messages on their way,
/// the thinking timer and whether a reply is still typing out.
///
/// Internal. None of it is exported.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';

/// A row of the conversation: a message, or one the person sent that is on its
/// way.
@internal
@immutable
class ConversationEntry {
  /// A message, under [id] (its own, or that of the pending message it took
  /// over).
  const ConversationEntry.message(this.id, AIMessage this.message, {this.sentAttachments = const []})
    : pending = null,
      isLatestReply = false;

  /// A message on its way.
  ConversationEntry.pending(AIPendingMessage this.pending)
    : id = pending.id,
      message = null,
      sentAttachments = const [],
      isLatestReply = false;

  const ConversationEntry._(this.id, this.message, this.pending, this.sentAttachments, this.isLatestReply);

  /// The row's id, which stays the same when a pending message's copy arrives.
  final String id;

  /// The message, or `null` for one on its way.
  final AIMessage? message;

  /// The message on its way, until its copy arrives.
  final AIPendingMessage? pending;

  /// What the person sent with a message on its way, which its copy shows
  /// rather than load again.
  final List<AIMessageAttachment> sentAttachments;

  /// Whether it is a reply that ends the conversation.
  final bool isLatestReply;

  /// Whether the person sent it.
  bool get isFromUser => message == null || message!.role == AIMessageRole.user;

  /// What it carries: what was sent with it, or else its own.
  List<AIMessageAttachment> get attachments {
    if (sentAttachments.isNotEmpty) return sentAttachments;
    return message?.attachments ?? pending?.attachments ?? const [];
  }

  /// This entry as the latest reply.
  ConversationEntry asLatestReply() => ConversationEntry._(id, message, pending, sentAttachments, true);
}

/// Whether [message] is a reply that has nothing to show yet.
@internal
bool showsNothing(AIMessage message) =>
    message.role != AIMessageRole.user && message.text.isEmpty && message.parts.isEmpty && message.attachments.isEmpty;

/// A message the person sent and the replies after it. Messages before their
/// first one, such as a greeting, make a turn of their own.
@internal
@immutable
class ConversationTurn {
  /// Creates a [ConversationTurn].
  const ConversationTurn(this.entries);

  /// The turn's rows, its first one the person's message.
  final List<ConversationEntry> entries;

  /// The turn's id: its first row's.
  String get id => entries.first.id;

  /// Groups [entries] into turns.
  static List<ConversationTurn> of(List<ConversationEntry> entries) {
    final turns = <List<ConversationEntry>>[];
    for (final entry in entries) {
      if (turns.isEmpty || entry.isFromUser) {
        turns.add([entry]);
      } else {
        turns.last.add(entry);
      }
    }
    return [for (final turn in turns) ConversationTurn(turn)];
  }
}

/// Matches the messages the person sent while they were on their way to the
/// copies that arrive, so each copy takes over its row.
@internal
class PendingMessageTracker {
  // The person's messages each pending message's copy cannot be: those there
  // were when it was first seen, and those that arrived since without being its
  // copy, such as older ones.
  final _seen = <String, Set<String>>{};
  // The pending message each copy took over, by the copy's id.
  final _copies = <String, AIPendingMessage>{};
  // The pending message of the last update, whose copy can arrive in the
  // update that stops passing it.
  AIPendingMessage? _lastPending;

  /// The rows of a conversation: its messages, apart from replies with nothing
  /// to show yet, and a message on its way until its copy arrives.
  List<ConversationEntry> entries(List<AIMessage> messages, AIPendingMessage? pending) {
    var showsPending = pending != null;
    // A copy that arrives in the update that stops passing its pending message
    // still takes over its row. Only then: a message sent later is not the copy
    // of one that failed.
    if (pending ?? _lastPending case final awaited?) {
      final sent = [
        for (final m in messages)
          if (m.role == AIMessageRole.user) m,
      ];
      final ids = {for (final m in sent) m.id};
      final known = _seen[awaited.id] ?? ids;
      final matched = _copies.entries.where((e) => e.value.id == awaited.id && ids.contains(e.key)).firstOrNull?.key;
      if (matched ?? _copyOf(awaited, sent, known) case final copy?) {
        _copies.putIfAbsent(copy, () => awaited);
        showsPending = false;
      } else {
        _seen[awaited.id] = {...known, ...ids};
      }
    }
    _lastPending = pending;

    final entries = <ConversationEntry>[
      for (final message in messages)
        if (!showsNothing(message))
          switch (_copies[message.id]) {
            final taken? => ConversationEntry.message(taken.id, message, sentAttachments: taken.attachments),
            null => ConversationEntry.message(message.id, message),
          },
      if (showsPending) ConversationEntry.pending(pending!),
    ];
    if (entries.isNotEmpty && !entries.last.isFromUser) entries.last = entries.last.asLatestReply();
    return entries;
  }

  // The copy of a message that was on its way: the person's message with its
  // id, when the app knew it. Otherwise their first after those known, which
  // older messages loading above cannot be. With none of theirs known, such as
  // when older messages arrive with it, it is their latest, when that is the
  // only new one or says the same.
  String? _copyOf(AIPendingMessage pending, List<AIMessage> sent, Set<String> known) {
    final ids = [for (final m in sent) m.id];
    if (ids.contains(pending.id)) return pending.id;
    final lastKnown = ids.lastIndexWhere(known.contains);
    if (lastKnown >= 0) return lastKnown + 1 < ids.length ? ids[lastKnown + 1] : null;
    final fresh = [
      for (final m in sent)
        if (!known.contains(m.id)) m,
    ];
    if (fresh.isEmpty) return null;
    final latest = fresh.last;
    return fresh.length == 1 || latest.text == pending.text ? latest.id : null;
  }

  /// Whether the latest message is surely waiting for a reply that shows
  /// nothing yet: it is on its way, it is the copy of the one on its way, or its
  /// reply is being written but shows nothing. Call it after [entries], which
  /// matches the copies.
  bool isAwaitingReply(List<AIMessage> messages, AIPendingMessage? pending) {
    final last = messages.lastOrNull;
    if (last != null && last.role != AIMessageRole.user && last.isGenerating && showsNothing(last)) return true;
    if (pending == null) return false;
    final copy = _copies.entries.where((e) => e.value.id == pending.id).firstOrNull?.key;
    if (copy == null) return true;
    return last?.id == copy;
  }
}

/// Times the thinking of each turn the conversation sees start, so the
/// thinking shown before anything of a reply arrives and the reasoning step
/// that takes its place read as one: "Thinking… 8s", then "Thought for 8s".
@internal
class ThinkingClock {
  /// Creates a [ThinkingClock] reading the time from [now].
  ThinkingClock({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final _turns = <String, _TimedTurn>{};

  /// A turn's thinking starts the first time it is the latest turn and
  /// thinking, and ends when it stops. Thinking that resumes before the first
  /// step shows carries on. A turn whose replies were taken away, such as to
  /// ask for a new one, starts thinking afresh.
  void update({required String? latest, required bool isThinking, bool hasReplies = false}) {
    if (latest == null) return;
    final timed = _turns[latest];
    if (timed == null || (isThinking && timed.hadReplies && !hasReplies)) {
      if (isThinking) _turns[latest] = _TimedTurn(_now());
      return;
    }
    if (hasReplies) timed.hadReplies = true;
    if (isThinking) {
      if (timed.firstStep == null) timed.end = null;
    } else {
      timed.end ??= _now();
    }
  }

  /// When [turn] started thinking, or `null` when it was never seen thinking.
  DateTime? start(String turn) => _turns[turn]?.start;

  /// Whether [step] takes over from [turn]'s thinking: the first reasoning step
  /// to show in a turn that was seen thinking.
  bool isFirstStep(String step, String turn) {
    final timed = _turns[turn];
    if (timed == null) return false;
    timed.firstStep ??= step;
    return timed.firstStep == step;
  }

  /// How long [turn] has thought, for its first step while it streams: from
  /// when the turn started thinking until now.
  Duration? elapsed(String turn) {
    final timed = _turns[turn];
    if (timed == null) return null;
    timed.firstStepStreamed = true;
    return _now().difference(timed.start);
  }

  /// How long [turn]'s first step thought, once done: until now for a step seen
  /// streaming, and until the turn stopped thinking for one that arrived done.
  /// The step's [own] time counts when it is longer.
  Duration? durationOfFirstStep(String turn, Duration? own) {
    final timed = _turns[turn];
    if (timed == null) return own;
    if (timed.firstStepDuration case final measured?) return measured;
    final done = timed.firstStepStreamed ? _now() : (timed.end ?? _now());
    final measured = done.difference(timed.start);
    return timed.firstStepDuration = own != null && own > measured ? own : measured;
  }
}

class _TimedTurn {
  _TimedTurn(this.start);

  final DateTime start;
  DateTime? end;
  String? firstStep;
  bool firstStepStreamed = false;
  Duration? firstStepDuration;
  bool hadReplies = false;
}

/// The turn a widget is in, whose clock times its thinking.
@internal
class ThinkingTurnScope extends InheritedWidget {
  /// Creates a [ThinkingTurnScope].
  const ThinkingTurnScope({super.key, required this.clock, required this.turn, required super.child});

  /// The conversation's clock.
  final ThinkingClock clock;

  /// The turn's id.
  final String turn;

  /// The scope above [context], or `null` outside a conversation.
  static ThinkingTurnScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThinkingTurnScope>();

  @override
  bool updateShouldNotify(ThinkingTurnScope oldWidget) => oldWidget.clock != clock || oldWidget.turn != turn;
}

/// Where a reply's view says whether its answer is still typing out, which its
/// actions wait for. `null` while nothing in the reply says, such as an app's
/// own view.
@internal
class AnswerWritingScope extends InheritedWidget {
  /// Creates an [AnswerWritingScope].
  const AnswerWritingScope({super.key, required this.writing, required super.child});

  /// Whether the answer is still typing out.
  final ValueNotifier<bool?> writing;

  /// The scope above [context], without depending on it.
  static ValueNotifier<bool?>? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AnswerWritingScope>()?.writing;

  @override
  bool updateShouldNotify(AnswerWritingScope oldWidget) => oldWidget.writing != writing;
}
