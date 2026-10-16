import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_message_part.dart';

/// Builds the widget for one [AIMessagePart], or returns `null` to fall back to
/// [AIMessagePartsView]'s default for it.
typedef AIMessagePartWidgetBuilder = Widget? Function(BuildContext context, AIMessagePart part);

/// {@template aiMessagePartsView}
/// The steps an AI agent took while replying, in order. Show it before the
/// reply's text.
///
/// ```dart
/// AIMessagePartsView(parts: AIMessagePart.parseAll(attachments))
/// ```
///
/// Each part gets this package's default view for its kind, and
/// [AIUnsupportedPartView] — a neutral "a step this app version can't show" —
/// for anything without one. To show some parts your own way, such as a kind
/// of your own, pass a [partBuilder] and return `null` for the parts you leave
/// to the default:
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
/// Children are keyed by [AIMessagePart.id], so a step keeps its state as the
/// list grows while a reply streams in. Two parts sharing an id are told apart
/// by how many came before them.
/// {@endtemplate}
class AIMessagePartsView extends StatelessWidget {
  /// {@macro aiMessagePartsView}
  const AIMessagePartsView({
    super.key,
    required this.parts,
    this.partBuilder,
    this.spacing = 8,
  });

  /// The steps to show, in order.
  final List<AIMessagePart> parts;

  /// Builds a part your own way; returning `null` falls back to the default
  /// for that part.
  final AIMessagePartWidgetBuilder? partBuilder;

  /// The vertical gap between two parts.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) return const SizedBox.shrink();

    final occurrences = <String, int>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: spacing,
      children: [
        for (final part in parts)
          KeyedSubtree(
            key: switch (occurrences.update(part.id, (count) => count + 1, ifAbsent: () => 0)) {
              0 => ValueKey<Object>(part.id),
              final occurrence => ValueKey<Object>((part.id, occurrence)),
            },
            child: partBuilder?.call(context, part) ?? _defaultPartView(part),
          ),
      ],
    );
  }

  /// The one place a kind's default view is chosen. Every kind shows the
  /// placeholder until this package has a view of its own for it.
  static Widget _defaultPartView(AIMessagePart part) => const AIUnsupportedPartView();
}

/// A neutral placeholder for an agent step this app version can't show: a kind
/// it doesn't know, or a format newer than it reads. It says that something
/// happened without guessing what.
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
