/// The entrance animation of generated UI: when each part animates in, and
/// how.
///
/// Internal and not exported. `AIUIEntrance` and `AIUIView` are the public
/// widgets built on it.
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Staggers the parts of one reply's UI that start animating at the same time,
/// so they animate one after another rather than all at once.
@internal
class AIUICascade {
  /// The delay between one part starting to animate and the next.
  static const step = Duration(milliseconds: 100);

  /// The longest any part waits before it starts animating.
  static const longestWait = Duration(milliseconds: 400);

  Duration _next = Duration.zero;

  /// Reserves the next slot for a part that appears now, and returns how long
  /// that part waits before it starts animating.
  Duration delay() {
    final now = Duration(microseconds: clock.now().microsecondsSinceEpoch);
    final start = _min(_max(now, _next), now + longestWait);
    _next = start + step;
    return start - now;
  }

  static Duration _min(Duration a, Duration b) => a < b ? a : b;
  static Duration _max(Duration a, Duration b) => a > b ? a : b;
}

/// Tracks, for one part of a reply's UI and everything inside it, whether a
/// part appearing now should animate on its own or simply appear as part of
/// the UI around it.
@internal
class AIUIStage {
  /// The stage of a reply's whole UI.
  AIUIStage.root(this.cascade) : _parent = null;

  AIUIStage._(this._parent, this.cascade);

  final AIUIStage? _parent;

  /// The reply's [AIUICascade], shared by all its parts.
  final AIUICascade cascade;

  /// Whether parts appearing inside this one now are still part of its own
  /// entrance. True until this part has been on screen for a frame or two.
  bool carries = true;

  /// Whether a part appearing inside this one now should skip its own
  /// animation, because this part, or one around it, is still appearing.
  bool get isCarried => carries || (_parent?.isCarried ?? false);

  /// A stage for a part inside this one.
  AIUIStage child() => AIUIStage._(this, cascade);
}

/// Provides the [AIUIStage] to the parts below it.
@internal
class AIUIStageScope extends InheritedWidget {
  /// Creates an [AIUIStageScope].
  const AIUIStageScope({super.key, required this.stage, required super.child});

  /// The stage.
  final AIUIStage stage;

  /// The nearest stage above [context], or `null` outside generated UI.
  static AIUIStage? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AIUIStageScope>()?.stage;

  @override
  bool updateShouldNotify(AIUIStageScope oldWidget) => oldWidget.stage != stage;
}

/// Animates [child] in when it first appears. [child] is either a reply's
/// whole UI ([isStage]) or one part of it.
///
/// The whole UI animates only if it first appears while the agent is still
/// writing it ([isStreaming]). A part animates only if it appears after the
/// UI around it is already on screen, waiting its turn in the cascade.
/// Otherwise it appears together with the UI around it.
@internal
class AIUIEntering extends StatefulWidget {
  /// Creates an [AIUIEntering].
  const AIUIEntering({super.key, required this.isStage, this.isStreaming = false, required this.child});

  /// Whether [child] is a reply's whole UI rather than one part of it.
  final bool isStage;

  /// Whether the agent is still writing the reply's UI.
  ///
  /// Only used when [isStage] is true.
  final bool isStreaming;

  /// The widget to animate in.
  final Widget child;

  @override
  State<AIUIEntering> createState() => _AIUIEnteringState();
}

class _AIUIEnteringState extends State<AIUIEntering> with SingleTickerProviderStateMixin {
  AIUIStage? _stage;
  AnimationController? _controller;
  Animation<double> _progress = kAlwaysCompleteAnimation;
  bool _reduceMotion = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_started) return;
    _started = true;

    if (widget.isStage) {
      final stage = _stage = AIUIStage.root(AIUICascade());
      if (widget.isStreaming) _comeIn(stage.cascade.delay());
    } else if (AIUIStageScope.maybeOf(context) case final around?) {
      _stage = around.child();
      if (!around.isCarried) _comeIn(around.cascade.delay());
    }
    // Parts that appear in this part's first frame, or in the frame after it,
    // are part of its own entrance and don't animate separately. The extra
    // frame covers engines that add parts in a post-frame callback, as they're
    // told to. Parts that appear later animate on their own.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance
        ..addPostFrameCallback((_) => _stage?.carries = false)
        ..ensureVisualUpdate();
    });
  }

  void _comeIn(Duration delay) {
    final motion = _reduceMotion ? _kFadeDuration : _kSpringDuration;
    final total = delay + motion;
    final controller = _controller = AnimationController(vsync: this, duration: total)..forward();
    _progress = CurvedAnimation(
      parent: controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: _reduceMotion ? Curves.easeOut : const _SpringCurve(),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stage;
    return _AIUIEntranceEffect(
      progress: _progress,
      moves: !_reduceMotion,
      child: stage == null ? widget.child : AIUIStageScope(stage: stage, child: widget.child),
    );
  }
}

// How long a part takes to fade in when motion is reduced.
const _kFadeDuration = Duration(milliseconds: 300);

// How long a part takes to come in: long enough for its spring to settle.
const _kSpringDuration = Duration(milliseconds: 900);

// How long the spring takes to swing once, in seconds, were it not damped.
const _kSpringPeriod = 0.7;

// How damped the spring is: just under 1, so it overshoots a little before it
// settles.
const _kSpringDampingRatio = 0.88;

// A spring that comes to rest in about [_kSpringPeriod], overshooting a little.
class _SpringCurve extends Curve {
  const _SpringCurve();

  // The stiffness that swings a mass of 1 once in [_kSpringPeriod].
  static final _stiffness = math.pow(2 * math.pi / _kSpringPeriod, 2).toDouble();

  static final _simulation = SpringSimulation(
    SpringDescription.withDampingRatio(mass: 1, stiffness: _stiffness, ratio: _kSpringDampingRatio),
    0,
    1,
    0,
  );

  @override
  double transformInternal(double t) =>
      _simulation.x(t * _kSpringDuration.inMicroseconds / Duration.microsecondsPerSecond);
}

// How a part looks while animating in, as [progress] goes from 0 to 1: it
// starts invisible, a little lower, slightly smaller and blurred. When
// [moves] is false, only the fade is applied.
class _AIUIEntranceEffect extends StatelessWidget {
  const _AIUIEntranceEffect({required this.progress, required this.moves, required this.child});

  // How far down a part starts.
  static const _rise = 16.0;
  // How much smaller a part starts.
  static const _shrink = 0.03;
  // How out of focus a part starts: a Gaussian blur of standard deviation 8.
  static const _blurSigma = 8.0;

  final Animation<double> progress;
  final bool moves;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) {
        final value = progress.value;
        final away = moves ? 1 - value : 0.0;
        final blur = math.max(0, away) * _blurSigma;
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, _rise * away),
            child: Transform.scale(
              scale: 1 - _shrink * away,
              alignment: Alignment.topCenter,
              child: ImageFiltered(
                enabled: blur > 0,
                imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
