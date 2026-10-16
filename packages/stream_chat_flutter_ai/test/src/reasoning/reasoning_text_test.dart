import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/reasoning/reasoning_text.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  group('splitReasoningParagraphs', () {
    test('splits at blank lines, trims and drops empty paragraphs', () {
      expect(splitReasoningParagraphs('One\n\nTwo\n  \nThree\r\n\r\n\n\n  Four  \n'), ['One', 'Two', 'Three', 'Four']);
      expect(splitReasoningParagraphs('Line one\nline two'), ['Line one\nline two'], reason: 'a single newline stays');
      expect(splitReasoningParagraphs('  \n\n '), isEmpty);
    });
  });

  group('ReasoningParagraphs', () {
    test('matches a full split however the text grows', () {
      const full = 'Alpha one.\n\nBeta two\nstill beta.\n \nGamma.\n\n\nDelta';
      for (final step in [1, 2, 3, 7]) {
        final paragraphs = ReasoningParagraphs();
        for (var end = 0; end <= full.length; end += step) {
          final text = full.substring(0, end);
          expect(paragraphs.update(text), splitReasoningParagraphs(text), reason: 'step $step at $end');
        }
        expect(paragraphs.update(full), splitReasoningParagraphs(full));
      }
    });

    test('starts over for text that does not carry on', () {
      final paragraphs = ReasoningParagraphs()..update('One\n\nTwo');
      expect(paragraphs.update('Other\n\nText'), ['Other', 'Text']);
    });
  });

  group('reasoningInlineSpans', () {
    const code = TextStyle(fontFamily: 'monospace');
    const link = TextStyle(decoration: TextDecoration.underline);

    test('keeps plain text as written, without escaping it', () {
      final spans = reasoningInlineSpans('a < b & c', codeStyle: code, linkStyle: link);
      expect(TextSpan(children: spans).toPlainText(), 'a < b & c');
    });

    test('leaves a link without a recognizer when none is given', () {
      final spans = reasoningInlineSpans('[x](https://x.y)', codeStyle: code, linkStyle: link);
      final span = spans.single as TextSpan;
      expect(span.style, link);
      expect(span.recognizer, isNull);
    });
  });

  group('ReasoningTextReveal', () {
    test('reveals a sixth of the backlog per tick, at least one character', () {
      final reveal = ReasoningTextReveal('');
      addTearDown(reveal.dispose);

      reveal.update('x' * 60, animated: true);
      expect(reveal.shown, '', reason: 'nothing until the first tick');
      expect(reveal.isRevealing, isTrue);

      reveal.tick();
      expect(reveal.shown.length, 10);
      reveal.tick();
      expect(reveal.shown.length, 18);

      while (reveal.isRevealing) {
        reveal.tick();
      }
      expect(reveal.shown, 'x' * 60);
    });

    test('hurry reveals half the backlog per tick', () {
      final reveal = ReasoningTextReveal('');
      addTearDown(reveal.dispose);
      reveal
        ..update('x' * 60, animated: true)
        ..hurry()
        ..tick();
      expect(reveal.shown.length, 30);
    });

    test('shows at once when not animated, or when the text does not carry on', () {
      final reveal = ReasoningTextReveal('abc');
      addTearDown(reveal.dispose);

      reveal.update('abcdef', animated: false);
      expect(reveal.shown, 'abcdef');
      expect(reveal.isRevealing, isFalse);

      reveal.update('xyz', animated: true);
      expect(reveal.shown, 'xyz');
      expect(reveal.isRevealing, isFalse);
    });

    test('never splits a surrogate pair', () {
      final reveal = ReasoningTextReveal('');
      addTearDown(reveal.dispose);
      reveal
        ..update('a😀', animated: true)
        ..tick();
      expect(reveal.shown, 'a');
      reveal.tick();
      expect(reveal.shown, 'a😀');
    });
  });

  group('DefaultAITranslations.reasoningDuration', () {
    const translations = DefaultAITranslations();

    test('formats seconds, then minutes and seconds', () {
      expect(translations.reasoningDuration(const Duration(seconds: 7)), '7s');
      expect(translations.reasoningDuration(const Duration(milliseconds: 12900)), '12s');
      expect(translations.reasoningDuration(const Duration(seconds: 60)), '1m');
      expect(translations.reasoningDuration(const Duration(seconds: 125)), '2m 5s');
    });
  });
}
