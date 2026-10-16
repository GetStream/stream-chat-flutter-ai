import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/components/ai_component_factory.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_message_part.dart';
// Here for the [AIReasoningPart.preview] doc link only.
import 'package:stream_chat_flutter_ai/src/parts/ai_reasoning_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval_view.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approver.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_view.dart';
import 'package:stream_chat_flutter_ai/src/reasoning/streaming_reasoning_view.dart';

/// Builds the widget for one [AIMessagePart], or returns `null` to fall back to
/// [AIMessagePartsView]'s default for it, or [AIMessagePartsView.hidden] to
/// show nothing for it.
typedef AIMessagePartWidgetBuilder = Widget? Function(BuildContext context, AIMessagePart part);

/// Builds the widget for one tool call, or returns `null` to fall back to the
/// [AIComponentFactory]'s row for it, or [AIMessagePartsView.hidden] to show
/// nothing for it.
typedef AIToolCallWidgetBuilder = Widget? Function(BuildContext context, AIToolCallPart call);

/// {@template aiMessagePartsView}
/// The steps an AI agent took while replying, in order. Show it before the
/// reply's text.
///
/// ```dart
/// AIMessagePartsView(parts: AIMessagePart.parseAll(attachments))
/// ```
///
/// A part this package can't read — a kind it doesn't know, or a format
/// version it doesn't read ([AIMessagePart.isSupported] is `false`) — shows
/// [AIUnsupportedPartView], a neutral "a step this app version can't show". A
/// part it can read shows its kind's default view: a [StreamingReasoningView]
/// for a round of reasoning, an [AIToolCallView] for a tool call.
///
/// To show some parts your own way, such as a kind of your own, pass a
/// [partBuilder] and return `null` for the parts you leave to the default:
///
/// ```dart
/// AIMessagePartsView(
///   parts: parts,
///   partBuilder: (context, part) => switch (part.kind.value) {
///     'ai_citation' => CitationView(part: part),
///     _ => null,
///   },
/// )
/// ```
///
/// To show only some tools your own way, such as a weather card for one tool,
/// pass a [toolCallBuilder] instead, and return `null` for the calls left to
/// the default row:
///
/// ```dart
/// AIMessagePartsView(
///   parts: parts,
///   toolCallBuilder: (context, call) => call.name == 'get_weather' ? WeatherCard(call: call) : null,
/// )
/// ```
///
/// A [partBuilder] is asked first; [toolCallBuilder] only sees the tool calls
/// it returned `null` for. To replace a kind's view everywhere instead, use an
/// [AIComponentFactory]; these builders are asked before it.
///
/// To hide a part, return [AIMessagePartsView.hidden] from either builder: it
/// is left out entirely, taking up no [spacing], where an empty widget would
/// still be spaced like a step.
///
/// ```dart
/// toolCallBuilder: (context, call) => call.name == 'log_event' ? AIMessagePartsView.hidden : null,
/// ```
///
/// Pass an [approver] to ask the person on this device about the tool calls
/// waiting for their approval: such a call's row gets an [AIToolApprovalView]
/// under it, which goes away once the call stops waiting. A call a builder
/// shows its own way gets no question; put an [AIToolApprovalView] in your
/// own widget then.
///
/// Children are keyed by [AIMessagePart.id], so a step keeps its state as the
/// list grows while a reply streams in. A part whose id an earlier part already
/// used is keyed by the id and how many parts with that id came before it.
/// {@endtemplate}
class AIMessagePartsView extends StatelessWidget {
  /// {@macro aiMessagePartsView}
  const AIMessagePartsView({
    super.key,
    required this.parts,
    this.partBuilder,
    this.toolCallBuilder,
    this.approver,
    this.spacing = 8,
  });

  /// The steps to show, in order.
  final List<AIMessagePart> parts;

  /// Builds a part your own way; returning `null` falls back to the default
  /// for that part.
  final AIMessagePartWidgetBuilder? partBuilder;

  /// Builds a tool call your own way; returning `null` falls back to an
  /// [AIToolCallView] for that call. Only asked for the tool calls
  /// [partBuilder] left to the default.
  final AIToolCallWidgetBuilder? toolCallBuilder;

  /// Who answers tool calls' questions on this device. With one, a tool call
  /// awaiting this person's approval shows an [AIToolApprovalView] under its
  /// row; without one, no questions are asked.
  final AIToolApprover? approver;

  /// The vertical gap between two parts, and between a tool call's row and its
  /// question.
  final double spacing;

  /// Returned from [partBuilder], [toolCallBuilder] or an
  /// [AIComponentFactory] part slot, hides that part: it is left out of the
  /// list, with no [spacing] around it. Compared by identity, so return this
  /// very instance.
  static const Widget hidden = _HiddenPart();

  @override
  Widget build(BuildContext context) {
    final occurrences = <String, int>{};
    final children = <Widget>[];
    for (final part in parts) {
      // Counted for every part, shown or not, so a part's key doesn't change
      // when an earlier one starts or stops showing.
      final occurrence = occurrences.update(part.id, (count) => count + 1, ifAbsent: () => 0);
      final child = partBuilder?.call(context, part) ?? _defaultPartView(context, part);
      if (child == null || identical(child, hidden)) continue;
      children.add(
        KeyedSubtree(
          key: occurrence == 0 ? ValueKey<Object>(part.id) : ValueKey<Object>((part.id, occurrence)),
          child: child,
        ),
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: spacing,
      children: children,
    );
  }

  /// A part's default view from the [AIComponentFactory], or `null` to show
  /// nothing. Tool calls ask [toolCallBuilder] first, then the factory; the
  /// [approver]'s question goes under the factory's row. Reasoning shows its
  /// [AIReasoningPart.preview]; full text goes through a [partBuilder].
  Widget? _defaultPartView(BuildContext context, AIMessagePart part) {
    final factory = AIComponents.of(context);
    if (!part.isSupported) return factory.buildUnsupportedPart(context, AIUnsupportedPartProps(part: part));
    if (part.reasoning case final reasoning?) {
      return factory.buildReasoning(context, AIReasoningProps(reasoning: reasoning));
    }
    if (part.toolCall case final call?) {
      return toolCallBuilder?.call(context, call) ?? _toolCallView(context, factory, call);
    }
    return null;
  }

  Widget _toolCallView(BuildContext context, AIComponentFactory factory, AIToolCallPart call) {
    final row = factory.buildToolCall(context, AIToolCallProps(call: call));
    final showRow = !identical(row, hidden);
    final approver = this.approver;
    final asks = approver != null && approver.identity.canApprove(call);
    // A hidden row still asks its question; with nothing to ask it takes no
    // spacing either.
    if (!showRow && !asks) return hidden;
    // The same column with or without an approver, a question or the row, so
    // each keeps its state as the others come and go. The question view stays
    // in while the call no longer waits — it is empty then — so its approver
    // can forget the answer.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showRow) row,
        if (approver != null)
          Padding(
            padding: EdgeInsets.only(top: showRow && asks ? spacing : 0),
            child: AIToolApprovalView(call: call, approver: approver),
          ),
      ],
    );
  }
}

/// [AIMessagePartsView.hidden]. Never built: the view leaves it out.
class _HiddenPart extends StatelessWidget {
  const _HiddenPart();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A neutral placeholder for an agent step this app version can't show: a kind
/// it doesn't know, a format newer than it reads, or a payload it couldn't
/// decode. It says that something happened without guessing what.
///
/// The text is [AITranslations.unsupportedMessagePart].
class AIUnsupportedPartView extends StatelessWidget {
  /// Creates an [AIUnsupportedPartView].
  const AIUnsupportedPartView({super.key, this.textStyle, this.iconColor});

  /// The style of the text, merged over `bodySmall` in `onSurfaceVariant`.
  final TextStyle? textStyle;

  /// The color of the sparkles icon; defaults to the text's color.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant).merge(textStyle);
    final iconSize = (style.fontSize ?? 12) * 1.25;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome_outlined, size: iconSize, color: iconColor ?? style.color),
        const SizedBox(width: 6),
        Flexible(child: Text(AITranslations.of(context).unsupportedMessagePart, style: style)),
      ],
    );
  }
}
