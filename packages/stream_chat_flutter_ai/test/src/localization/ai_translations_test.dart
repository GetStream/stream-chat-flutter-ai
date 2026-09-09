import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  group('AITranslations.of', () {
    testWidgets('falls back to the English defaults with no scope in the tree', (tester) async {
      late AITranslations resolved;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              resolved = AITranslations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, isA<DefaultAITranslations>());
      expect(resolved.send, 'Send');
      expect(resolved.composerHint, 'Ask anything…');
      expect(resolved.clearOption('Weather'), 'Clear Weather');
    });

    testWidgets('finds an enclosing scope', (tester) async {
      late AITranslations resolved;

      await tester.pumpWidget(
        _wrap(
          AITranslationsScope(
            translations: const _TestTranslations(),
            child: Builder(
              builder: (context) {
                resolved = AITranslations.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(resolved, isA<_TestTranslations>());
      expect(resolved.send, 'VERSTUUR');
    });

    testWidgets('resolves to the nearest of two nested scopes', (tester) async {
      late AITranslations resolved;

      await tester.pumpWidget(
        _wrap(
          AITranslationsScope(
            translations: const DefaultAITranslations(),
            child: AITranslationsScope(
              translations: const _TestTranslations(),
              child: Builder(
                builder: (context) {
                  resolved = AITranslations.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(resolved.send, 'VERSTUUR');
    });
  });

  group('AITranslationsScope', () {
    test('updateShouldNotify tracks the instance', () {
      const child = SizedBox.shrink();
      const a = AITranslationsScope(translations: DefaultAITranslations(), child: child);
      const b = AITranslationsScope(translations: DefaultAITranslations(), child: child);
      const c = AITranslationsScope(translations: _TestTranslations(), child: child);

      // `const` instances of the same class are canonicalized to one object,
      // which is what keeps a scope rebuilt every typewriter tick from
      // notifying its dependents every tick. Documented on AITranslations.
      expect(a.updateShouldNotify(b), isFalse);
      expect(a.updateShouldNotify(c), isTrue);
    });

    testWidgets('a dependent rebuilds when the translations change, and not when they do not', (tester) async {
      var builds = 0;
      final strings = ValueNotifier<AITranslations>(const DefaultAITranslations());
      addTearDown(strings.dispose);

      await tester.pumpWidget(
        _wrap(
          ValueListenableBuilder<AITranslations>(
            valueListenable: strings,
            builder: (context, value, _) => AITranslationsScope(
              translations: value,
              child: Builder(
                builder: (context) {
                  builds++;
                  return Text(AITranslations.of(context).send);
                },
              ),
            ),
          ),
        ),
      );

      expect(builds, 1);
      expect(find.text('Send'), findsOneWidget);

      // Same const instance: the scope widget is replaced, the dependent is not
      // rebuilt.
      strings.value = const DefaultAITranslations();
      await tester.pump();
      expect(builds, 1);

      strings.value = const _TestTranslations();
      await tester.pump();
      expect(builds, 2);
      expect(find.text('VERSTUUR'), findsOneWidget);
    });
  });

  group('DefaultAITranslations', () {
    test('a subclass overriding one string keeps the rest', () {
      const translations = _TestTranslations();

      expect(translations.send, 'VERSTUUR');
      expect(translations.stopGenerating, 'Stop generating');
      expect(translations.copyCode, 'Copy code');
    });
  });
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Overrides exactly one string, to prove the rest still come from the default.
class _TestTranslations extends DefaultAITranslations {
  const _TestTranslations();

  @override
  String get send => 'VERSTUUR';
}
