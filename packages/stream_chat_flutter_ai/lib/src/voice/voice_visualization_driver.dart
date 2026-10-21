/// The motion behind the voice visualizations, ported from iOS StreamChatAI.
///
/// Internal. The web reference eases each value by a fixed fraction per frame,
/// which settles twice as fast at 120 Hz as at 60 Hz; here each fraction is
/// converted to time, so the motion is the reference's at 60 Hz on any display.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:stream_chat_flutter_ai/src/voice/ai_voice_agent_state.dart';

/// The most colors a visualization takes.
@internal
const kVoiceMaxColors = 5;

/// What selects each state's motion: `load`, `flow` and `react` each pick a
/// motion pattern, so easing between states crossfades the patterns.
@internal
@immutable
class VoiceMotion {
  /// Creates a [VoiceMotion].
  const VoiceMotion({
    required this.speed,
    required this.bright,
    required this.sat,
    required this.load,
    required this.flow,
    required this.react,
  });

  /// The motion of [state].
  factory VoiceMotion.of(AIVoiceAgentState state) => switch (state) {
    AIVoiceAgentState.idle => const VoiceMotion(speed: 0.4, bright: 1, sat: 1, load: 0, flow: 0, react: 0.12),
    AIVoiceAgentState.connecting => const VoiceMotion(speed: 1, bright: 1, sat: 1, load: 1, flow: 0, react: 0),
    AIVoiceAgentState.listening => const VoiceMotion(speed: 0.9, bright: 1, sat: 1, load: 0, flow: 0, react: 0.45),
    AIVoiceAgentState.thinking => const VoiceMotion(speed: 1.25, bright: 1, sat: 1, load: 0, flow: 1, react: 0),
    AIVoiceAgentState.speaking => const VoiceMotion(speed: 1.25, bright: 1, sat: 1, load: 0, flow: 0, react: 1),
  };

  /// How fast time passes.
  final double speed;

  /// How bright it is.
  final double bright;

  /// How saturated it is.
  final double sat;

  /// The connecting pattern's weight.
  final double load;

  /// The thinking pattern's weight.
  final double flow;

  /// The listening and speaking pattern's weight.
  final double react;
}

/// How closely the motion follows a live audio level: the share of the way it
/// moves each frame at 60 Hz, toward a louder or a quieter level.
@internal
enum VoiceLevelResponse {
  /// Follows the level closely, both ways.
  steady(0.35, 0.35),

  /// Follows the level like a VU meter: about 0.1 s up to a louder reading and
  /// about 0.3 s down from it, so per-syllable jumps swell with the phrase.
  smooth(0.16, 0.05);

  const VoiceLevelResponse(this.rise, this.fall);

  /// Toward a louder level.
  final double rise;

  /// Toward a quieter level.
  final double fall;
}

/// What drives the motion.
@internal
@immutable
class VoiceInput {
  /// Creates a [VoiceInput].
  const VoiceInput({
    required this.state,
    required this.colors,
    required this.expressivity,
    required this.audioLevel,
    required this.reduceMotion,
  });

  /// What the agent is doing.
  final AIVoiceAgentState state;

  /// One to five colors as HSV, hue a fraction of a turn.
  final List<(double, double, double)> colors;

  /// From 0 to 2.
  final double expressivity;

  /// From 0 to 1, or `null` when no live audio drives the motion.
  final double? audioLevel;

  /// Whether the motion barely moves.
  final bool reduceMotion;
}

/// [color] as HSV, hue a fraction of a turn, keeping its full saturation and
/// value so muted and pastel colors render true.
@internal
(double, double, double) voiceHsv(Color color) {
  final hsv = HSVColor.fromColor(color);
  return (hsv.hue / 360 % 1, hsv.saturation, hsv.value);
}

/// Eases the motion toward its [input] frame by frame, and hands the shader its
/// uniforms.
@internal
class VoiceVisualizationDriver {
  /// Starts settled on [input], so the first frame shows it rather than easing
  /// into it.
  VoiceVisualizationDriver(this._input, {this.levelResponse = VoiceLevelResponse.steady}) {
    final motion = VoiceMotion.of(_input.state);
    final scales = _scales(_input.expressivity);
    _speed = motion.speed * scales.speed;
    _bright = motion.bright;
    _sat = motion.sat;
    _load = motion.load * scales.amplitude;
    _flow = motion.flow * scales.amplitude;
    _react = motion.react * scales.amplitude;
    _expressivity = _input.expressivity;
    _colors = _slots(_input.colors);
    _count = _input.colors.length.toDouble();
  }

  /// How closely the motion follows a live audio level.
  final VoiceLevelResponse levelResponse;

  VoiceInput _input;

  /// What drives the motion.
  VoiceInput get input => _input;

  set input(VoiceInput value) {
    _input = value;
    if (value.reduceMotion) _isHovering = false;
  }

  late double _speed;
  late double _bright;
  late double _sat;
  late double _load;
  late double _flow;
  late double _react;
  late double _expressivity;
  late List<(double, double, double)> _colors;
  late double _count;
  double _time = 0;
  double _flowSpin = 0;
  double _orbSpin = 0;
  Offset _tapPoint = Offset.zero;
  double _tapAge = 100;
  Offset _hoverPoint = Offset.zero;
  bool _isHovering = false;
  double _hoverAmount = 0;
  double _micLevel = 0;
  double _voiceAmount = 0;
  double _bounceAge = double.infinity;

  /// The motion's own clock.
  double get time => _time;

  /// Ripples from [point], centred and normalized to the shorter side with y
  /// up, and bounces.
  void tap(Offset point) {
    if (_input.reduceMotion) return;
    _tapPoint = point;
    _tapAge = 0;
    _bounceAge = 0;
  }

  /// Ripples under a hovering pointer at [point], or stops with `null`.
  void hover(Offset? point) {
    if (point == null || _input.reduceMotion) {
      _isHovering = false;
      return;
    }
    _hoverPoint = point;
    _isHovering = true;
  }

  /// Moves the motion on by [seconds].
  void advance(double seconds) {
    // Clamped so a frame after a stall cannot leap the motion.
    final dt = seconds.clamp(0, 0.05).toDouble();
    final motion = VoiceMotion.of(_input.state);
    final scales = _scales(_input.expressivity);
    final drivers = ease(0.08, dt);
    _speed += (motion.speed * scales.speed - _speed) * drivers;
    _bright += (motion.bright - _bright) * drivers;
    _sat += (motion.sat - _sat) * drivers;
    _load += (motion.load * scales.amplitude - _load) * drivers;
    _flow += (motion.flow * scales.amplitude - _flow) * drivers;
    _react += (motion.react * scales.amplitude - _react) * drivers;
    _expressivity += (_input.expressivity - _expressivity) * drivers;

    // Integrated rather than computed as time times a weight, so a change of
    // state eases the turns instead of jumping their angles.
    final step = dt * (_input.reduceMotion ? 0.07 : 1) * _speed;
    _time += step;
    _flowSpin += step * _flow;
    _orbSpin += step * (1 + 0.5 * _flow + 0.1 * _react);

    _tapAge += dt;
    _bounceAge += dt;

    final gentle = ease(0.12, dt);
    _hoverAmount += ((_isHovering ? 1 : 0) - _hoverAmount) * gentle;
    _voiceAmount += ((_input.audioLevel == null ? 0 : 1) - _voiceAmount) * ease(0.1, dt);
    final level = _input.audioLevel ?? 0;
    final response = level > _micLevel ? levelResponse.rise : levelResponse.fall;
    _micLevel += (level - _micLevel) * ease(response, dt);

    final targets = _slots(_input.colors);
    for (var i = 0; i < _colors.length; i++) {
      _colors[i] = easeHsv(_colors[i], targets[i], gentle);
    }
    _count += (_input.colors.length - _count) * gentle;
  }

  /// Sets the shader's uniforms for a [size] in logical pixels.
  void apply(FragmentShader shader, Size size, {required bool dark, required double pixelRatio}) {
    var i = 0;
    void put(double value) => shader.setFloat(i++, value);
    put(size.width);
    put(size.height);
    for (final (h, s, v) in _colors) {
      put(h);
      put(s);
      put(v);
    }
    put(_tapPoint.dx);
    put(_tapPoint.dy);
    put(_hoverPoint.dx);
    put(_hoverPoint.dy);
    put(_time);
    put(_count);
    put(_bright);
    put(_sat);
    put(_load);
    put(_flow);
    put(_flowSpin);
    put(_orbSpin);
    // Live audio lifts the motion to its level, whatever the state.
    put(_react + (math.max(_react, _micLevel) - _react) * _voiceAmount);
    put(_expressivity);
    put(dark ? 1 : 0);
    put(_tapAge);
    put(_hoverAmount);
    put(_micLevel);
    put(_voiceAmount);
    put(bounceScale(_bounceAge));
    put(pixelRatio);
  }

  // Expressivity scales amplitude and speed, each with a floor so the motion
  // still breathes at 0.
  static ({double amplitude, double speed}) _scales(double expressivity) =>
      (amplitude: 0.15 + 0.85 * expressivity, speed: 0.6 + 0.4 * expressivity);

  /// The share of the way to its target a value moves in [dt], for a value that
  /// moves [perFrame] of the way each frame at 60 Hz.
  static double ease(double perFrame, double dt) => 1 - math.pow(1 - perFrame, dt * 60).toDouble();

  /// Eases an HSV color, its hue taking the shorter way round the wheel.
  static (double, double, double) easeHsv((double, double, double) color, (double, double, double) target, double t) {
    final (h, s, v) = color;
    final (th, ts, tv) = target;
    final hueStep = (((th - h + 1.5) % 1) - 0.5) * t;
    return ((h + hueStep + 1) % 1, s + (ts - s) * t, v + (tv - v) * t);
  }

  // The five color slots the shaders read; past the palette they repeat its
  // first color.
  static List<(double, double, double)> _slots(List<(double, double, double)> colors) {
    final first = colors.isEmpty ? (0.0, 0.0, 0.0) : colors.first;
    return [
      for (var i = 0; i < kVoiceMaxColors; i++)
        if (i < colors.length) colors[i] else first,
    ];
  }

  /// How long a tap's bounce lasts, in seconds.
  static const bounceDuration = 0.34;

  /// The bounce of a tap [age] seconds ago: a dip to 93% and an overshoot to
  /// 103% before settling. Authored keyframes rather than a spring, timed along
  /// CSS `ease-out` like the web reference.
  static double bounceScale(double age) {
    if (age >= bounceDuration) return 1;
    final progress = Curves.easeOut.transform(math.max(age, 0) / bounceDuration);
    const keyframes = [(0.0, 1.0), (0.3, 0.93), (0.62, 1.03), (1.0, 1.0)];
    for (var k = 1; k < keyframes.length; k++) {
      final (endOffset, endScale) = keyframes[k];
      if (progress <= endOffset) {
        final (startOffset, startScale) = keyframes[k - 1];
        return startScale + (endScale - startScale) * (progress - startOffset) / (endOffset - startOffset);
      }
    }
    return 1;
  }
}
