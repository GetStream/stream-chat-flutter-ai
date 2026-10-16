import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/resolved_typing_indicator_theme.dart';
// Imported for the doc links below too.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/typing_indicator_theme.dart';

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
/// derived from the ambient [ThemeData] (`bodyMedium` in `onSurfaceVariant`,
/// with dots in the caption's color).
///
/// **Accessibility.** The indicator is a polite live region labelled with
/// [text], and the dots are hidden from assistive technology. Keep the widget
/// mounted and change [text] as the state moves on ("Thinking" → "Checking
/// sources"), and a screen reader announces each new state. With reduced
/// motion on ([MediaQueryData.disableAnimations]) the dots are drawn static.
///
/// see also:
/// - [AnimatedDots] which is used to display the animated dots.
/// {@endtemplate}
class AITypingIndicatorView extends StatelessWidget {
  /// {@macro aiTypingIndicatorView}
  const AITypingIndicatorView({
    super.key,
    required this.text,
    this.textStyle,
    this.dotColor,
    this.dotCount,
    this.dotSize,
    this.dotSpacing,
  }) : assert(dotCount == null || dotCount >= 0, 'dotCount must not be negative');

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

  /// The number of animated dots to display next to the text.
  ///
  /// See [TypingIndicatorThemeData.dotCount]; defaults to 3.
  final int? dotCount;

  /// The size of the animated dots displayed next to the text.
  ///
  /// See [TypingIndicatorThemeData.dotSize]; defaults to 8.
  final double? dotSize;

  /// The gap between two dots.
  ///
  /// See [TypingIndicatorThemeData.dotSpacing]; defaults to 4.
  final double? dotSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = ResolvedTypingIndicatorTheme.resolve(
      context,
      TypingIndicatorThemeData(
        textStyle: textStyle,
        dotColor: dotColor,
        dotSize: dotSize,
        dotCount: dotCount,
        dotSpacing: dotSpacing,
      ),
    );

    // One live-region node carrying [text] as its label, with the caption and
    // the dots beneath it excluded: the label is the whole message, and a
    // change to it on a node that stays put is what makes a screen reader
    // re-announce. `container` keeps the node from merging into an ancestor,
    // which would lose the live-region flag.
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: theme.textStyle),
            const SizedBox(width: 8),
            AnimatedDots(
              size: theme.dotSize,
              count: theme.dotCount,
              spacing: theme.dotSpacing,
              color: theme.dotColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// {@template animatedDots}
/// A widget that displays a series of animated dots.
///
/// The dots are animated to scale up and down in size and fade in and out in
/// opacity.
///
/// The widget is typically used to indicate that someone is typing. Unset
/// parameters come from [TypingIndicatorTheme] / [AITheme.typingIndicatorTheme]
/// like [AITypingIndicatorView]'s do.
///
/// The dots are decorative and excluded from semantics. When the platform asks
/// for reduced motion ([MediaQueryData.disableAnimations]) they are drawn
/// static, at full size and opacity, with no animation running at all.
/// {@endtemplate}
class AnimatedDots extends StatelessWidget {
  /// {@macro animatedDots}
  const AnimatedDots({
    super.key,
    this.count,
    this.size,
    this.spacing,
    this.color,
  }) : assert(count == null || count >= 0, 'count must not be negative');

  /// The number of dots to display.
  ///
  /// See [TypingIndicatorThemeData.dotCount]; defaults to 3.
  final int? count;

  /// The size of each dot.
  ///
  /// See [TypingIndicatorThemeData.dotSize]; defaults to 8.
  final double? size;

  /// The spacing between each dot.
  ///
  /// See [TypingIndicatorThemeData.dotSpacing]; defaults to 4.
  final double? spacing;

  /// The color of the dots.
  ///
  /// See [TypingIndicatorThemeData.dotColor]; defaults to the themed text
  /// color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = ResolvedTypingIndicatorTheme.resolve(
      context,
      TypingIndicatorThemeData(dotColor: color, dotSize: size, dotCount: count, dotSpacing: spacing),
    );
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return ExcludeSemantics(
      child: Row(
        spacing: theme.dotSpacing,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          theme.dotCount,
          (index) => reduceMotion
              ? _Dot(size: theme.dotSize, color: theme.dotColor)
              : _AnimatedDot(
                  key: ValueKey(index),
                  index: index,
                  size: theme.dotSize,
                  color: theme.dotColor,
                ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _AnimatedDot extends StatefulWidget {
  const _AnimatedDot({
    super.key,
    required this.index,
    required this.size,
    required this.color,
  });

  final int index;
  final double size;
  final Color color;

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot> with SingleTickerProviderStateMixin<_AnimatedDot> {
  late final AnimationController _repeatingController;

  // Built once, rather than per build: a `CurvedAnimation` registers a listener
  // on its parent and needs disposing, so allocating a fresh one (plus two
  // tweens) on every frame of the animation both churns and leaks.
  late final CurvedAnimation _curve;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _repeatingController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 800),
        )..addStatusListener(
          (status) {
            if (status == AnimationStatus.completed) {
              if (mounted) _repeatingController.reverse();
            } else if (status == AnimationStatus.dismissed) {
              if (mounted) _repeatingController.forward();
            }
          },
        );

    _curve = CurvedAnimation(parent: _repeatingController, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 0.5, end: 1).animate(_curve);
    _opacity = Tween<double>(begin: 0.3, end: 1).animate(_curve);

    Future.delayed(
      Duration(milliseconds: 200 * widget.index),
      () {
        if (mounted) _repeatingController.forward();
      },
    );
  }

  @override
  void dispose() {
    _curve.dispose();
    _repeatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _opacity,
        child: _Dot(size: widget.size, color: widget.color),
      ),
    );
  }
}
