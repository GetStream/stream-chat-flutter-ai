import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Advances the clock far enough for the typewriter to reveal any pending text.
///
/// `Timer.periodic` runs in the widget tester's fake-async zone, so advancing
/// the clock drives the typewriter without any real waiting.
Future<void> _typeOut(WidgetTester tester) => tester.pump(const Duration(seconds: 1));

void main() {
  group('TypewriterController', () {
    test('starts fully revealed when constructed with text', () {
      final controller = TypewriterController(text: 'Hello');
      expect(controller.value.text, 'Hello');
      expect(controller.value.state, TypewriterState.idle);
      controller.dispose();
    });

    testWidgets('reveals appended text progressively', (tester) async {
      final controller = TypewriterController(text: '');
      addTearDown(controller.dispose);

      final revealed = <String>[];
      controller
        ..addListener(() => revealed.add(controller.value.text))
        ..updateText('abc');

      await _typeOut(tester);

      expect(revealed, containsAllInOrder(['a', 'ab', 'abc']));
      expect(controller.value.state, TypewriterState.idle);
    });

    testWidgets('continues from the current position when text is appended', (tester) async {
      final controller = TypewriterController(text: 'Hel');
      addTearDown(controller.dispose);

      controller.updateText('Hello');
      await _typeOut(tester);

      expect(controller.value.text, 'Hello');
    });

    testWidgets('reveals a shorter replacement instead of freezing on stale text', (tester) async {
      // Regression test: `updateText` used to only swap the target string,
      // leaving the char index pointing past the end of the new text. That made
      // `startTyping` bail out immediately, so a regenerated/edited/shorter
      // message left the *previous* text on screen indefinitely.
      final controller = TypewriterController(text: 'Hello world, this is long');
      addTearDown(controller.dispose);

      controller.updateText('Bye');
      await _typeOut(tester);

      expect(controller.value.text, 'Bye');
    });

    testWidgets('replays from the start when the new text is not a continuation', (tester) async {
      final controller = TypewriterController(text: 'Hello');
      addTearDown(controller.dispose);

      controller.updateText('Goodbye');
      // Reset to empty first, rather than jumping mid-word from 'Hello'.
      expect(controller.value.text, isEmpty);

      await _typeOut(tester);
      expect(controller.value.text, 'Goodbye');
    });

    testWidgets('pauseTyping keeps the revealed text and startTyping resumes it', (tester) async {
      final controller = TypewriterController(text: '');
      addTearDown(controller.dispose);

      controller.updateText('abcdef');
      await tester.pump(const Duration(milliseconds: 30));
      controller.pauseTyping();

      final paused = controller.value.text;
      expect(controller.value.state, TypewriterState.paused);
      expect(paused, isNotEmpty);

      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.value.text, paused, reason: 'a paused typewriter must not advance');

      controller.startTyping();
      await _typeOut(tester);
      expect(controller.value.text, 'abcdef');
    });

    testWidgets('stopTyping resets so startTyping replays from the beginning', (tester) async {
      final controller = TypewriterController(text: 'abc');
      addTearDown(controller.dispose);

      controller.stopTyping();
      expect(controller.value.text, isEmpty);
      expect(controller.value.state, TypewriterState.stopped);

      controller.startTyping();
      await _typeOut(tester);
      expect(controller.value.text, 'abc');
    });

    testWidgets('text setter reveals everything immediately', (tester) async {
      final controller = TypewriterController(text: '');
      addTearDown(controller.dispose);

      controller
        ..updateText('abcdef')
        ..text = 'xyz';

      expect(controller.value.text, 'xyz');
      expect(controller.value.state, TypewriterState.idle);

      // The in-flight typing timer must not resurrect the old target.
      await _typeOut(tester);
      expect(controller.value.text, 'xyz');
    });

    testWidgets('treats grapheme clusters as single characters', (tester) async {
      final controller = TypewriterController(text: '');
      addTearDown(controller.dispose);

      final revealed = <String>[];
      controller
        ..addListener(() => revealed.add(controller.value.text))
        ..updateText('👍🏽ok');

      await _typeOut(tester);

      // The emoji + skin-tone modifier is revealed as one unit, never split
      // into a half-rendered pair.
      expect(revealed, containsAllInOrder(['👍🏽', '👍🏽o', '👍🏽ok']));
      expect(controller.value.text, '👍🏽ok');
    });
    test('finishTyping reveals everything received so far', () {
      final controller = TypewriterController()..updateText('a partial reply');
      addTearDown(controller.dispose);

      controller.finishTyping();

      // The companion to a "stop generating" control: stopTyping empties the
      // view and pauseTyping freezes it half-written, neither of which is what
      // the user asked for.
      expect(controller.value.text, 'a partial reply');
      expect(controller.value.state, TypewriterState.idle);
    });

    test('a chunk that extends a grapheme cluster is not treated as a continuation', () {
      // '\u{1F468}' is a UTF-16 prefix of the family emoji but not a grapheme
      // one. Comparing by code unit left the index past the end of a target one
      // cluster long, so nothing was ever revealed and the view froze.
      final controller = TypewriterController();
      addTearDown(controller.dispose);

      controller
        ..updateText('\u{1F468}')
        ..finishTyping();
      expect(controller.value.text, '\u{1F468}');

      controller.updateText('\u{1F468}\u200D\u{1F469}\u200D\u{1F466}');
      expect(controller.value.state, TypewriterState.typing);
    });
  });

  group('TypewriterBuilder', () {
    testWidgets('rebuilds as the controller reveals text', (tester) async {
      final controller = TypewriterController(text: '');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: TypewriterBuilder(
            controller: controller,
            builder: (context, value, child) => Text(value.text, textDirection: TextDirection.ltr),
          ),
        ),
      );

      controller.updateText('hi');
      await _typeOut(tester);

      expect(find.text('hi'), findsOneWidget);
    });
  });
}
