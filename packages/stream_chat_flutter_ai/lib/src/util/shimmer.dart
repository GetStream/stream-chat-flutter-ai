import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A highlight sweeping across [child] while [animation] runs, from fully
/// before it to fully past it once per cycle.
///
/// Internal. The owner drives [animation] — typically a repeating
/// `AnimationController` — and stops it (or doesn't show the shimmer at all)
/// under reduced motion. [child] is painted in [base] with the band of
/// [highlight] passing over it, so a child drawn in any color works: the
/// mask's colors replace its own.
@internal
class Shimmer extends StatelessWidget {
  /// Creates a [Shimmer].
  const Shimmer({super.key, required this.animation, required this.base, required this.highlight, required this.child});

  /// How far the sweep has gone, 0 to 1.
  final Animation<double> animation;

  /// The color [child] is drawn in outside the highlight.
  final Color base;

  /// The color of the band sweeping across [child].
  final Color highlight;

  /// What the highlight sweeps across.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        // From fully left of the child to fully right of it.
        final x = -1.6 + 3.2 * animation.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(x - 0.6, 0),
            end: Alignment(x + 0.6, 0),
            colors: [base, highlight, base],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
