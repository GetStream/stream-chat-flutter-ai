import 'package:alchemist/alchemist.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/voice/voice_visualization_driver.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

VoiceInput _input({
  AIVoiceAgentState state = AIVoiceAgentState.idle,
  List<(double, double, double)> colors = const [(0.6, 0.8, 0.9)],
  double expressivity = 1,
  double? audioLevel,
  bool reduceMotion = false,
}) => VoiceInput(
  state: state,
  colors: colors,
  expressivity: expressivity,
  audioLevel: audioLevel,
  reduceMotion: reduceMotion,
);

/// Runs [driver] for [seconds] in 60 Hz frames.
void _run(VoiceVisualizationDriver driver, double seconds) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    driver.advance(1 / 60);
  }
}

/// The driver behind the voice view [view].
VoiceVisualizationDriver _driverOf(WidgetTester tester, Finder view) {
  final paint = tester.widget<CustomPaint>(find.descendant(of: view, matching: find.byType(CustomPaint)));
  // The painter is private; its driver is what the gestures move.
  return (paint.painter! as dynamic).driver as VoiceVisualizationDriver;
}

Widget _centered(Widget view) => MaterialApp(
  home: Center(child: SizedBox.square(dimension: 200, child: view)),
);

void main() {
  group('VoiceVisualizationDriver', () {
    test('converts a per-frame fraction into one per second of time', () {
      expect(VoiceVisualizationDriver.ease(0.5, 1 / 60), closeTo(0.5, 1e-9));
      expect(VoiceVisualizationDriver.ease(0.5, 2 / 60), closeTo(0.75, 1e-9), reason: 'two 60 Hz frames');
      expect(VoiceVisualizationDriver.ease(0.5, 0), 0);
    });

    test('eases hue the short way round the wheel', () {
      final (h, _, _) = VoiceVisualizationDriver.easeHsv((0.95, 1, 1), (0.05, 1, 1), 0.5);
      expect(h, closeTo(0, 1e-9));
    });

    test('bounces a tap down to 93%, up to 103%, then settles', () {
      expect(VoiceVisualizationDriver.bounceScale(0), 1);
      final scales = [for (var t = 0.0; t < 0.34; t += 0.005) VoiceVisualizationDriver.bounceScale(t)];
      expect(scales.reduce((a, b) => a < b ? a : b), closeTo(0.93, 0.005));
      expect(scales.reduce((a, b) => a > b ? a : b), closeTo(1.03, 0.005));
      expect(VoiceVisualizationDriver.bounceScale(1), 1);
    });

    test('moves its clock with the state, and barely with reduced motion', () {
      final calm = VoiceVisualizationDriver(_input());
      final speaking = VoiceVisualizationDriver(_input(state: AIVoiceAgentState.speaking));
      final reduced = VoiceVisualizationDriver(_input(state: AIVoiceAgentState.speaking, reduceMotion: true));
      _run(calm, 1);
      _run(speaking, 1);
      _run(reduced, 1);
      expect(speaking.time, greaterThan(calm.time));
      expect(reduced.time, lessThan(speaking.time * 0.1));
    });

    test('bounces on a tap, but not with reduced motion', () {
      final driver = VoiceVisualizationDriver(_input())
        ..tap(Offset.zero)
        ..advance(0.1);
      expect(driver.scale, lessThan(1));
      final reduced = VoiceVisualizationDriver(_input(reduceMotion: true))
        ..tap(Offset.zero)
        ..advance(0.1);
      expect(reduced.scale, 1);
    });

    test('clamps a long frame so the motion does not leap', () {
      final driver = VoiceVisualizationDriver(_input())..advance(10);
      final once = driver.time;
      final other = VoiceVisualizationDriver(_input())..advance(0.05);
      expect(once, other.time);
    });
  });

  group('voice inputs', () {
    test('clamps expressivity, and reads one that is not finite as 1', () {
      expect(voiceExpressivity(3), 2);
      expect(voiceExpressivity(-1), 0);
      expect(voiceExpressivity(0.5), 0.5);
      expect(voiceExpressivity(double.nan), 1);
      expect(voiceExpressivity(double.infinity), 1);
    });

    test('clamps the audio level, and drops one that is not finite', () {
      expect(voiceAudioLevel(2), 1);
      expect(voiceAudioLevel(-1), 0);
      expect(voiceAudioLevel(0.4), 0.4);
      expect(voiceAudioLevel(null), isNull);
      expect(voiceAudioLevel(double.nan), isNull);
      expect(voiceAudioLevel(double.negativeInfinity), isNull);
    });
  });

  group('voiceShaderAssetKey', () {
    const packaged = 'packages/stream_chat_flutter_ai/shaders/voice_glow.frag';
    const local = 'shaders/voice_glow.frag';

    test("reads an app's packaged shader, even beside one of its own", () {
      expect(voiceShaderAssetKey('voice_glow', [packaged]), packaged);
      expect(voiceShaderAssetKey('voice_glow', [packaged, local]), packaged);
    });

    test("reads the package's own tests' shader", () {
      expect(voiceShaderAssetKey('voice_glow', [local]), local);
    });

    test('names the packaged shader when none is listed', () {
      expect(voiceShaderAssetKey('voice_glow', const []), packaged);
    });
  });

  group('voiceHsv', () {
    test('reads hue as a fraction of a turn', () {
      final (h, s, v) = voiceHsv(const Color(0xFF0000FF));
      expect(h, closeTo(2 / 3, 1e-6));
      expect(s, 1);
      expect(v, 1);
    });
  });

  group('voice views', () {
    for (final (name, build) in [
      ('AIVoiceGlowView', (AIVoiceAgentState state) => AIVoiceGlowView(state: state)),
      ('AIVoiceWaveView', (AIVoiceAgentState state) => AIVoiceWaveView(state: state)),
    ]) {
      testWidgets('$name reads out the agent and what it is doing', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            home: Center(child: SizedBox.square(dimension: 200, child: build(AIVoiceAgentState.listening))),
          ),
        );
        await tester.pump();
        expect(find.bySemanticsLabel('Voice agent'), findsOneWidget);
        expect(tester.getSemantics(find.bySemanticsLabel('Voice agent')).value, 'Listening');
        semantics.dispose();
      });

      testWidgets('$name draws with its shader', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(child: SizedBox.square(dimension: 200, child: build(AIVoiceAgentState.speaking))),
          ),
        );
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('voice view layout and gestures', () {
    testWidgets('a NaN audio level animates on its own rather than at full volume', (tester) async {
      await tester.pumpWidget(
        _centered(
          const AIVoiceGlowView(state: AIVoiceAgentState.speaking, expressivity: double.nan, audioLevel: double.nan),
        ),
      );
      final input = _driverOf(tester, find.byType(AIVoiceGlowView)).input;
      expect(input.audioLevel, isNull);
      expect(input.expressivity, 1);
    });

    testWidgets('bounces when a tap is released, not when it goes down', (tester) async {
      await tester.pumpWidget(_centered(const AIVoiceGlowView(state: AIVoiceAgentState.idle)));
      final driver = _driverOf(tester, find.byType(AIVoiceGlowView));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(AIVoiceGlowView)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(driver.scale, 1);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 84));
      expect(driver.scale, lessThan(1));
    });

    testWidgets('a scroll that starts on it does not bounce it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ListView(
            children: const [
              SizedBox.square(dimension: 200, child: AIVoiceGlowView(state: AIVoiceAgentState.idle)),
              SizedBox(height: 2000),
            ],
          ),
        ),
      );
      final driver = _driverOf(tester, find.byType(AIVoiceGlowView));
      await tester.drag(find.byType(AIVoiceGlowView), const Offset(0, -150));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 84));
      expect(driver.scale, 1);
      expect(tester.getTopLeft(find.byType(AIVoiceGlowView)).dy, lessThan(0), reason: 'the list scrolled');
    });

    testWidgets('a secondary click does not bounce it', (tester) async {
      await tester.pumpWidget(_centered(const AIVoiceGlowView(state: AIVoiceAgentState.idle)));
      final driver = _driverOf(tester, find.byType(AIVoiceGlowView));
      await tester.tap(find.byType(AIVoiceGlowView), buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 84));
      expect(driver.scale, 1);
    });

    testWidgets('a hovering mouse ripples it only over the shape', (tester) async {
      await tester.pumpWidget(_centered(const AIVoiceWaveView(state: AIVoiceAgentState.idle)));
      final view = find.byType(AIVoiceWaveView);
      final driver = _driverOf(tester, view);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getTopLeft(view) + const Offset(10, 10));
      await tester.pump();
      expect(driver.isHovering, isFalse, reason: 'a corner, away from the line');
      await gesture.moveTo(tester.getCenter(view));
      await tester.pump();
      expect(driver.isHovering, isTrue);
      await gesture.moveTo(tester.getCenter(view) + const Offset(0, 80));
      await tester.pump();
      expect(driver.isHovering, isFalse, reason: 'off the line again');
    });

    testWidgets('paints on a layer of its own', (tester) async {
      await tester.pumpWidget(_centered(const AIVoiceGlowView(state: AIVoiceAgentState.idle)));
      expect(
        find.descendant(of: find.byType(AIVoiceGlowView), matching: find.byType(RepaintBoundary)),
        findsOneWidget,
      );
    });

    testWidgets('a tap still reaches a parent', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: GestureDetector(
              onTap: () => taps++,
              child: const SizedBox.square(dimension: 200, child: AIVoiceGlowView(state: AIVoiceAgentState.idle)),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AIVoiceGlowView));
      expect(taps, 1);
    });

    testWidgets('takes a square of the bounded side in a column', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 180,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [AIVoiceWaveView(state: AIVoiceAgentState.idle)],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AIVoiceWaveView)), const Size(180, 180));
    });
  });

  group('goldens', () {
    Widget gallery(ThemeData theme) => Theme(
      data: theme,
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final glow in [true, false])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final state in AIVoiceAgentState.values)
                      SizedBox.square(
                        dimension: 120,
                        child: glow
                            ? AIVoiceGlowView(
                                state: state,
                                colors: const [Color(0xFF005FFF), Color(0xFF8E44FF), Color(0xFF00C2A8)],
                              )
                            : AIVoiceWaveView(
                                state: state,
                                colors: const [Color(0xFF005FFF), Color(0xFF8E44FF), Color(0xFF00C2A8)],
                              ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );

    Future<void> loadShaders(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 16));
    }

    goldenTest(
      'light',
      fileName: 'ai_voice_views_light',
      pumpBeforeTest: loadShaders,
      builder: () => gallery(ThemeData()),
    );

    goldenTest(
      'dark',
      fileName: 'ai_voice_views_dark',
      pumpBeforeTest: loadShaders,
      builder: () => gallery(ThemeData(brightness: Brightness.dark)),
    );
  });
}
