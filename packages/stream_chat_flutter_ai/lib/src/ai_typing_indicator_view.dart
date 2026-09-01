import 'package:flutter/material.dart';

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
    this.dotCount = 3,
    this.dotSize = 8,
  });

  /// The text to display in the widget.
  ///
  /// Typically this is the state of the AI such as "AI is thinking",
  final String text;

  /// The style to use for the text.
  ///
  /// If not provided, the default text style is used.
  final TextStyle? textStyle;

  /// The color of the animated dots displayed next to the text.
  ///
  /// If not provided, the color of the [textStyle] is used if available or
  /// [Colors.black] is used.
  final Color? dotColor;

  /// The number of animated dots to display next to the text.
  ///
  /// Defaults to 3.
  final int dotCount;

  /// The size of the animated dots displayed next to the text.
  ///
  /// Defaults to 8.
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: textStyle),
        const SizedBox(width: 8),
        AnimatedDots(
          size: dotSize,
          count: dotCount,
          color: dotColor ?? textStyle?.color ?? Colors.black,
        ),
      ],
    );
  }
}

/// {@template animatedDots}
/// A widget that displays a series of animated dots.
///
/// The dots are animated to scale up and down in size and fade in and out in
/// opacity.
///
/// The widget is typically used to indicate that someone is typing.
/// {@endtemplate}
class AnimatedDots extends StatelessWidget {
  /// {@macro animatedDots}
  const AnimatedDots({
    super.key,
    this.count = 3,
    this.size = 8,
    this.spacing = 4,
    this.color = Colors.black,
  });

  /// The number of dots to display.
  ///
  /// Defaults to 3.
  final int count;

  /// The size of each dot.
  ///
  /// Defaults to 8.
  final double size;

  /// The spacing between each dot.
  ///
  /// Defaults to 4.
  final double spacing;

  /// The color of the dots.
  ///
  /// Defaults to [Colors.black].
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: spacing,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (index) => _AnimatedDot(
          key: ValueKey(index),
          index: index,
          size: size,
          color: color,
        ),
      ),
    );
  }
}

class _AnimatedDot extends StatefulWidget {
  const _AnimatedDot({
    super.key,
    required this.index,
    this.size = 8,
    this.color = Colors.black,
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
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
