import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/resolved_typing_indicator_theme.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/typing_indicator_theme.dart';
import 'package:stream_core_flutter/chat.dart';

/// {@template aiTypingIndicatorView}
/// A widget that displays a typing indicator for the AI.
///
/// Use it to surface whatever state the AI is in — "Thinking", "Checking
/// sources", "Generating" — as a caption next to a row of animated dots. The
/// state itself is just a string supplied by the host; this package has no
/// opinion on the set of states.
///
/// ```dart
/// AITypingIndicatorView(
///  text: 'AI is thinking',
/// );
/// ```
///
/// Styling resolves per field: the constructor's parameters, then the nearest
/// [TypingIndicatorTheme], then [AITheme.typingIndicatorTheme], then defaults
/// derived from the Stream theme (`bodyDefault` in `textSecondary`, with dots
/// in the caption's color). The one exception is [textStyle], which
/// is merged over the themed style rather than replacing it, so passing only a
/// font size keeps the themed color.
///
/// **Accessibility.** The indicator is a polite live region labelled with
/// [text], and the dots are hidden from assistive technology. Keep the widget
/// mounted and change [text] as the state moves on ("Thinking" → "Checking
/// sources"), and a screen reader announces each new state. With reduced
/// motion on ([MediaQueryData.disableAnimations]) the dots are drawn static.
///
/// The dots are a [StreamTypingIndicatorDots].
/// {@endtemplate}
class AITypingIndicatorView extends StatelessWidget {
  /// {@macro aiTypingIndicatorView}
  const AITypingIndicatorView({
    super.key,
    required this.text,
    this.textStyle,
    this.dotColor,
    this.dotSize,
    this.dotSpacing,
  }) : assert(dotSize == null || dotSize >= 0, 'dotSize must not be negative'),
       assert(dotSpacing == null || dotSpacing >= 0, 'dotSpacing must not be negative');

  /// The text to display in the widget.
  ///
  /// Typically this is the state of the AI such as "AI is thinking". It is
  /// also the label a screen reader announces.
  final String text;

  /// The style to use for the text, merged over the themed one.
  ///
  /// See [TypingIndicatorThemeData.textStyle].
  final TextStyle? textStyle;

  /// The color of the animated dots displayed next to the text.
  ///
  /// See [TypingIndicatorThemeData.dotColor]; defaults to the resolved text
  /// color.
  final Color? dotColor;

  /// The size of the animated dots displayed next to the text.
  ///
  /// See [TypingIndicatorThemeData.dotSize].
  final double? dotSize;

  /// The gap between two dots.
  ///
  /// See [TypingIndicatorThemeData.dotSpacing].
  final double? dotSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = ResolvedTypingIndicatorTheme.resolve(
      context,
      override: TypingIndicatorThemeData(
        textStyle: textStyle,
        dotColor: dotColor,
        dotSize: dotSize,
        dotSpacing: dotSpacing,
      ),
    );

    // One live-region node carrying [text] as its label, with the caption and
    // the dots beneath it excluded: the label is the whole message, and a
    // change to it on a node that stays put is what makes a screen reader
    // re-announce. `container` gives it a node of its own rather than letting
    // it fold into a sibling's or parent's; a `MergeSemantics` ancestor still
    // merges it, as it would any node.
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: theme.textStyle),
            SizedBox(width: context.streamSpacing.xs),
            StreamTypingIndicatorDots(color: theme.dotColor, dotSize: theme.dotSize, spacing: theme.dotSpacing),
          ],
        ),
      ),
    );
  }
}
