import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/voice/ai_voice_agent_state.dart';
import 'package:stream_chat_flutter_ai/src/voice/voice_visualization_driver.dart';

/// A soft, airy globe of drifting color that shows what a voice agent is
/// doing.
///
/// Masses of color orbit inside the globe and the background shows through
/// between them. It shimmers while idle, breathes while listening, turns slowly
/// while thinking and swells with speech. Tapping the globe bounces it and
/// ripples its color from the touch, and a hovering pointer ripples it too.
/// With reduced motion on it barely moves.
///
/// It has no size of its own: it fills the space it is given, with the globe
/// about half as wide as the shorter side.
///
/// ```dart
/// SizedBox.square(dimension: 320, child: AIVoiceGlowView(state: AIVoiceAgentState.speaking))
/// ```
class AIVoiceGlowView extends StatelessWidget {
  /// Creates an [AIVoiceGlowView].
  const AIVoiceGlowView({super.key, required this.state, this.colors, this.expressivity = 1, this.audioLevel});

  /// What the agent is doing.
  final AIVoiceAgentState state;

  /// One to five colors to paint it with. Defaults to [ColorScheme.primary].
  final List<Color>? colors;

  /// How lively the motion is, from 0, nearly still, through 1 to 2, twice as
  /// animated. It never changes the colors.
  final double expressivity;

  /// The live level of the voice being heard, from 0 to 1, such as a call
  /// participant's audio level, fed at 15 Hz or more. `null` animates speech on
  /// its own.
  final double? audioLevel;

  @override
  Widget build(BuildContext context) => _VoiceVisualization(
    style: _VoiceStyle.glow,
    state: state,
    colors: colors,
    expressivity: expressivity,
    audioLevel: audioLevel,
  );
}

/// A single waveform line that shows what a voice agent is doing.
///
/// The line is nearly flat while idle and listening, carries a steady wave
/// while thinking, sweeps side to side while connecting, and erupts with
/// speech, flattening in its pauses. The colors flow along it. Tapping the line
/// ripples it from the touch, and a hovering pointer ripples it too. With
/// reduced motion on it barely moves.
///
/// It has no size of its own: it fills the space it is given, with the line
/// about 80% as wide as the shorter side, so give it a square.
///
/// ```dart
/// SizedBox.square(dimension: 320, child: AIVoiceWaveView(state: AIVoiceAgentState.listening))
/// ```
class AIVoiceWaveView extends StatelessWidget {
  /// Creates an [AIVoiceWaveView].
  const AIVoiceWaveView({super.key, required this.state, this.colors, this.expressivity = 1, this.audioLevel});

  /// What the agent is doing.
  final AIVoiceAgentState state;

  /// One to five colors to paint it with. Defaults to [ColorScheme.primary].
  final List<Color>? colors;

  /// How lively the motion is, from 0, nearly still, through 1 to 2, twice as
  /// animated. It never changes the colors.
  final double expressivity;

  /// The live level of the voice being heard, from 0 to 1, such as a call
  /// participant's audio level, fed at 15 Hz or more. `null` animates speech on
  /// its own.
  final double? audioLevel;

  @override
  Widget build(BuildContext context) => _VoiceVisualization(
    style: _VoiceStyle.wave,
    state: state,
    colors: colors,
    expressivity: expressivity,
    audioLevel: audioLevel,
  );
}

enum _VoiceStyle {
  // The glow follows the level closely.
  glow('voice_glow', VoiceLevelResponse.steady),
  // The wave's height tracks the level directly, so it follows it smoothly;
  // per-syllable jumps would make it jitter.
  wave('voice_wave', VoiceLevelResponse.smooth);

  const _VoiceStyle(this.shader, this.levelResponse);

  final String shader;
  final VoiceLevelResponse levelResponse;

  // Whether a point, centred and normalized to the shorter side with y up, is
  // on the shape rather than the empty space around it.
  bool contains(Offset point) => switch (this) {
    _VoiceStyle.glow => point.distance < 0.32,
    _VoiceStyle.wave => point.dx.abs() < 0.5 && point.dy.abs() < 0.14,
  };

  // Only programs that loaded: a load is not shared, since one started in a
  // zone that goes away, such as a test's, may never finish.
  static final _programs = <_VoiceStyle, ui.FragmentProgram>{};

  /// The program, at once once it has loaded.
  ui.FragmentProgram? get loaded => _programs[this];

  Future<ui.FragmentProgram> load() async => _programs[this] ??= await _load();

  // An app reads a package's assets under `packages/`; the package's own tests
  // read them without it.
  Future<ui.FragmentProgram> _load() async {
    try {
      return await ui.FragmentProgram.fromAsset('packages/stream_chat_flutter_ai/shaders/$shader.frag');
    } on Exception {
      return ui.FragmentProgram.fromAsset('shaders/$shader.frag');
    }
  }
}

class _VoiceVisualization extends StatefulWidget {
  const _VoiceVisualization({
    required this.style,
    required this.state,
    required this.colors,
    required this.expressivity,
    required this.audioLevel,
  });

  final _VoiceStyle style;
  final AIVoiceAgentState state;
  final List<Color>? colors;
  final double expressivity;
  final double? audioLevel;

  @override
  State<_VoiceVisualization> createState() => _VoiceVisualizationState();
}

class _VoiceVisualizationState extends State<_VoiceVisualization> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _frame = ValueNotifier<int>(0);
  VoiceVisualizationDriver? _driver;
  ui.FragmentShader? _shader;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.style.loaded case final program?) {
      _shader = program.fragmentShader();
    } else {
      unawaited(
        widget.style.load().then((program) {
          if (mounted) setState(() => _shader = program.fragmentShader());
        }),
      );
    }
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    _driver?.advance((elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond);
    _last = elapsed;
    _frame.value++;
  }

  VoiceInput _input(BuildContext context) {
    final colors = widget.colors;
    final palette = colors == null || colors.isEmpty ? [Theme.of(context).colorScheme.primary] : colors;
    return VoiceInput(
      state: widget.state,
      colors: [for (final color in palette.take(kVoiceMaxColors)) voiceHsv(color)],
      expressivity: widget.expressivity.clamp(0, 2).toDouble(),
      audioLevel: widget.audioLevel?.clamp(0, 1).toDouble(),
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    );
  }

  // [local] centred and normalized to the shorter side, with y up.
  Offset _normalized(Offset local, Size size) {
    final m = size.shortestSide;
    return Offset((local.dx - size.width / 2) / m, (size.height / 2 - local.dy) / m);
  }

  String _stateLabel(AITranslations translations) => switch (widget.state) {
    AIVoiceAgentState.idle => translations.voiceIdle,
    AIVoiceAgentState.connecting => translations.voiceConnecting,
    AIVoiceAgentState.listening => translations.voiceListening,
    AIVoiceAgentState.thinking => translations.voiceThinking,
    AIVoiceAgentState.speaking => translations.voiceSpeaking,
  };

  @override
  Widget build(BuildContext context) {
    final input = _input(context);
    final driver = (_driver ??= VoiceVisualizationDriver(input, levelResponse: widget.style.levelResponse))
      ..input = input;
    final translations = AITranslations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;

    return Semantics(
      label: translations.voiceAgent,
      value: _stateLabel(translations),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return MouseRegion(
            onHover: (event) => driver.hover(_normalized(event.localPosition, size)),
            onExit: (_) => driver.hover(null),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) {
                final point = _normalized(details.localPosition, size);
                if (widget.style.contains(point)) {
                  driver.tap(point);
                }
              },
              child: CustomPaint(
                size: size,
                painter: _VoicePainter(
                  shader: _shader,
                  driver: driver,
                  dark: dark,
                  pixelRatio: pixelRatio,
                  repaint: _frame,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VoicePainter extends CustomPainter {
  _VoicePainter({
    required this.shader,
    required this.driver,
    required this.dark,
    required this.pixelRatio,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final ui.FragmentShader? shader;
  final VoiceVisualizationDriver driver;
  final bool dark;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = this.shader;
    if (shader == null || size.isEmpty) return;
    driver.apply(shader, size, dark: dark, pixelRatio: pixelRatio);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_VoicePainter oldDelegate) =>
      oldDelegate.shader != shader || oldDelegate.dark != dark || oldDelegate.pixelRatio != pixelRatio;
}
