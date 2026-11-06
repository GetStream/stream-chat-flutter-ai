import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_stage.dart';

void main() {
  test("AIUICascade doesn't keep a part that comes in alone waiting", () {
    final cascade = AIUICascade();
    _at(Duration.zero, cascade.delay);

    expect(_at(const Duration(seconds: 1), cascade.delay), Duration.zero);
  });

  test('AIUICascade has parts that come in at once follow one another', () {
    final cascade = AIUICascade();

    final delays = [for (var i = 0; i < 3; i++) _at(Duration.zero, cascade.delay)];

    expect(delays, [Duration.zero, AIUICascade.step, AIUICascade.step * 2]);
  });

  test('AIUICascade has a part wait only for the parts still to come in', () {
    final cascade = AIUICascade();
    _at(Duration.zero, cascade.delay);
    _at(Duration.zero, cascade.delay);

    expect(_at(AIUICascade.step, cascade.delay), AIUICascade.step);
  });

  test('AIUICascade keeps no part waiting long', () {
    final cascade = AIUICascade();
    // Twice as many parts as fit in the longest wait, one step apart.
    final parts = 2 * (AIUICascade.longestWait.inMicroseconds ~/ AIUICascade.step.inMicroseconds);

    final delays = [for (var i = 0; i < parts; i++) _at(Duration.zero, cascade.delay)];

    expect(delays.reduce((a, b) => a > b ? a : b), AIUICascade.longestWait);
  });
}

// What [delay] says at [elapsed] past a fixed moment.
Duration _at(Duration elapsed, Duration Function() delay) =>
    withClock(Clock.fixed(DateTime.utc(2026, 11, 14).add(elapsed)), delay);
