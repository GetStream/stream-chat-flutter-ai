import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Pumps a probe under [theme] (wrapped in [scope]) and returns what [TypingIndicatorTheme.of] resolves
/// beneath it.
Future<TypingIndicatorThemeData> _resolve(
  WidgetTester tester, {
  ThemeData? theme,
  Widget Function(Widget)? scope,
}) async {
  late TypingIndicatorThemeData resolved;
  final probe = Builder(
    builder: (context) {
      resolved = TypingIndicatorTheme.of(context);
      return const SizedBox();
    },
  );
  await tester.pumpWidget(MaterialApp(theme: theme, home: scope?.call(probe) ?? probe));
  return resolved;
}

void main() {
  group('TypingIndicatorThemeData', () {
    test('describes only the fields it sets to DevTools', () {
      final description = const TypingIndicatorThemeData(dotSpacing: 4).toDiagnosticsNode().toStringDeep();
      expect(description, contains('dotSpacing'));
      expect(description, isNot(contains('dotColor')), reason: 'unset fields stay out of the tree');
    });

    group('every field', () {
      const base = TypingIndicatorThemeData(
        textStyle: TextStyle(fontSize: 11),
        dotColor: Color(0xFF111111),
        dotSize: 6,
        dotSpacing: 2,
      );

      /// One per field: how to set it to a second value, and how to read it.
      final fields =
          <
            ({
              String name,
              TypingIndicatorThemeData only,
              TypingIndicatorThemeData Function() copied,
              Object? Function(TypingIndicatorThemeData) read,
            })
          >[
            (
              name: 'textStyle',
              only: const TypingIndicatorThemeData(textStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(textStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.textStyle,
            ),
            (
              name: 'dotColor',
              only: const TypingIndicatorThemeData(dotColor: Color(0xFF0000A1)),
              copied: () => base.copyWith(dotColor: const Color(0xFF0000A1)),
              read: (t) => t.dotColor,
            ),
            (
              name: 'dotSize',
              only: const TypingIndicatorThemeData(dotSize: 20),
              copied: () => base.copyWith(dotSize: 20),
              read: (t) => t.dotSize,
            ),
            (
              name: 'dotSpacing',
              only: const TypingIndicatorThemeData(dotSpacing: 10),
              copied: () => base.copyWith(dotSpacing: 10),
              read: (t) => t.dotSpacing,
            ),
          ];

      test('the table covers every field the class declares', () {
        // Guards the loop itself: add a field without a row here and this fails
        // rather than silently leaving the new field untested.
        expect(fields, hasLength(4));
        expect(fields.map((f) => f.name).toSet(), hasLength(4));
      });

      for (final field in fields) {
        test('${field.name} survives copyWith, merge, == and hashCode', () {
          final copied = field.copied();
          final merged = base.merge(field.only);

          expect(field.read(copied), field.read(field.only), reason: 'copyWith set ${field.name}');
          expect(field.read(merged), field.read(field.only), reason: 'merge took ${field.name}');

          for (final other in fields.where((f) => f.name != field.name)) {
            expect(other.read(copied), other.read(base), reason: 'copyWith(${field.name}) disturbed ${other.name}');
            expect(other.read(merged), other.read(base), reason: 'merge(${field.name}) disturbed ${other.name}');
          }

          expect(copied, merged, reason: 'copyWith and merge disagree on ${field.name}');
          expect(copied, isNot(base), reason: '== ignores ${field.name}');
          expect(copied.hashCode, isNot(base.hashCode), reason: 'hashCode ignores ${field.name}');
        });

        test('${field.name} survives lerp', () {
          // Only this field is set on both sides, so it alone interpolates;
          // every other field swaps from base's value to null at the midpoint.
          final early = TypingIndicatorThemeData.lerp(base, field.only, 0.25);
          final end = TypingIndicatorThemeData.lerp(base, field.only, 1);

          expect(field.read(early), isNotNull, reason: 'lerp dropped ${field.name}');
          expect(field.read(early), isNot(field.read(base)), reason: 'lerp did not move ${field.name}');
          expect(field.read(end), field.read(field.only), reason: 'lerp did not reach ${field.name}');
          for (final other in fields.where((f) => f.name != field.name)) {
            expect(other.read(early), other.read(base), reason: 'lerp(${field.name}) disturbed ${other.name}');
            expect(other.read(end), isNull, reason: 'lerp(${field.name}) disturbed ${other.name}');
          }
        });
      }
    });

    test('merge with null returns this', () {
      const base = TypingIndicatorThemeData(dotSize: 6);
      expect(base.merge(null), same(base));
    });

    test('lerp swaps an unset field instead of growing it from zero', () {
      const set = TypingIndicatorThemeData(dotSize: 12, dotSpacing: 5);
      const unset = TypingIndicatorThemeData();

      expect(TypingIndicatorThemeData.lerp(set, unset, 0.25).dotSize, 12);
      expect(TypingIndicatorThemeData.lerp(set, unset, 0.25).dotSpacing, 5);
      expect(TypingIndicatorThemeData.lerp(set, unset, 0.75).dotSize, isNull);
      expect(TypingIndicatorThemeData.lerp(set, unset, 0.75).dotSpacing, isNull);
    });

    test('lerp with identical themes returns the first', () {
      const theme = TypingIndicatorThemeData(dotSize: 6);
      expect(TypingIndicatorThemeData.lerp(theme, theme, 0.5), same(theme));
    });
  });

  group('TypingIndicatorTheme', () {
    testWidgets('resolves to an all-null theme with nothing registered', (tester) async {
      expect(await _resolve(tester), const TypingIndicatorThemeData(), reason: 'theming stays opt-in');
    });

    testWidgets('layers a scope over the AITheme rather than replacing it', (tester) async {
      final resolved = await _resolve(
        tester,
        theme: ThemeData(
          extensions: const [
            AITheme(typingIndicatorTheme: TypingIndicatorThemeData(dotSize: 6, dotColor: Color(0xFF222222))),
          ],
        ),
        scope: (child) => TypingIndicatorTheme(
          data: const TypingIndicatorThemeData(dotColor: Color(0xFF333333)),
          child: child,
        ),
      );

      expect(resolved.dotColor, const Color(0xFF333333), reason: 'the scope wins');
      expect(resolved.dotSize, 6, reason: "the extension's other fields survive");
    });

    testWidgets('merge layers over an enclosing scope', (tester) async {
      final resolved = await _resolve(
        tester,
        scope: (child) => TypingIndicatorTheme(
          data: const TypingIndicatorThemeData(dotSize: 6),
          child: TypingIndicatorTheme.merge(
            data: const TypingIndicatorThemeData(dotSpacing: 5),
            child: child,
          ),
        ),
      );

      expect(resolved.dotSize, 6);
      expect(resolved.dotSpacing, 5);
    });

    testWidgets('a nested scope replaces rather than layers', (tester) async {
      final resolved = await _resolve(
        tester,
        scope: (child) => TypingIndicatorTheme(
          data: const TypingIndicatorThemeData(dotSize: 6),
          child: TypingIndicatorTheme(
            data: const TypingIndicatorThemeData(dotSpacing: 5),
            child: child,
          ),
        ),
      );

      expect(resolved.dotSize, isNull);
      expect(resolved.dotSpacing, 5);
    });
  });
}
