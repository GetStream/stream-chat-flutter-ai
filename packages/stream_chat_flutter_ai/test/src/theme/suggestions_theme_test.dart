import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  group('SuggestionsThemeData', () {
    test('describes only the fields it sets to DevTools', () {
      final description = const SuggestionsThemeData(
        backgroundColor: Color(0xFF123456),
      ).toDiagnosticsNode().toStringDeep();
      expect(description, contains('backgroundColor'));
      expect(description, isNot(contains('borderColor')), reason: 'unset fields stay out of the tree');
    });

    group('every field', () {
      const base = SuggestionsThemeData(
        backgroundColor: Color(0xFF111111),
        borderColor: Color(0xFF222222),
        textStyle: TextStyle(fontSize: 11),
      );

      /// One per field: how to set it to a second value, and how to read it.
      final fields =
          <
            ({
              String name,
              SuggestionsThemeData only,
              SuggestionsThemeData Function() copied,
              Object? Function(SuggestionsThemeData) read,
            })
          >[
            (
              name: 'backgroundColor',
              only: const SuggestionsThemeData(backgroundColor: Color(0xFF0000A1)),
              copied: () => base.copyWith(backgroundColor: const Color(0xFF0000A1)),
              read: (t) => t.backgroundColor,
            ),
            (
              name: 'borderColor',
              only: const SuggestionsThemeData(borderColor: Color(0xFF0000A2)),
              copied: () => base.copyWith(borderColor: const Color(0xFF0000A2)),
              read: (t) => t.borderColor,
            ),
            (
              name: 'textStyle',
              only: const SuggestionsThemeData(textStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(textStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.textStyle,
            ),
          ];

      test('the table covers every field the class declares', () {
        // Guards the loop itself: add a field without a row here and this fails
        // rather than silently leaving the new field untested.
        expect(fields, hasLength(3));
        expect(fields.map((f) => f.name).toSet(), hasLength(3));
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
          final early = SuggestionsThemeData.lerp(base, field.only, 0.25);
          final end = SuggestionsThemeData.lerp(base, field.only, 1);

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
      const base = SuggestionsThemeData(backgroundColor: Color(0xFF111111));
      expect(base.merge(null), same(base));
    });

    test('lerp swaps an unset field instead of fading it through transparency', () {
      const set = SuggestionsThemeData(backgroundColor: Color(0xFF123456));
      const unset = SuggestionsThemeData();

      expect(SuggestionsThemeData.lerp(set, unset, 0.25).backgroundColor, const Color(0xFF123456));
      expect(SuggestionsThemeData.lerp(set, unset, 0.75).backgroundColor, isNull);
    });

    test('lerp with identical themes returns the first', () {
      const theme = SuggestionsThemeData(backgroundColor: Color(0xFF111111));
      expect(SuggestionsThemeData.lerp(theme, theme, 0.5), same(theme));
    });
  });

  group('SuggestionsTheme', () {
    testWidgets('resolves to an all-null theme with nothing registered', (tester) async {
      late SuggestionsThemeData resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = SuggestionsTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, const SuggestionsThemeData(), reason: 'theming stays opt-in');
    });

    testWidgets('layers a scope over the AITheme rather than replacing it', (tester) async {
      late SuggestionsThemeData resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [
              AITheme(
                suggestionsTheme: SuggestionsThemeData(
                  backgroundColor: Color(0xFF111111),
                  borderColor: Color(0xFF222222),
                ),
              ),
            ],
          ),
          home: SuggestionsTheme(
            data: const SuggestionsThemeData(borderColor: Color(0xFF333333)),
            child: Builder(
              builder: (context) {
                resolved = SuggestionsTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolved.borderColor, const Color(0xFF333333), reason: 'the scope wins');
      expect(resolved.backgroundColor, const Color(0xFF111111), reason: "the extension's other fields survive");
    });

    testWidgets('merge layers over an enclosing scope', (tester) async {
      late SuggestionsThemeData layered;
      await tester.pumpWidget(
        MaterialApp(
          home: SuggestionsTheme(
            data: const SuggestionsThemeData(backgroundColor: Color(0xFF111111)),
            child: SuggestionsTheme.merge(
              data: const SuggestionsThemeData(borderColor: Color(0xFF222222)),
              child: Builder(
                builder: (context) {
                  layered = SuggestionsTheme.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      expect(layered.backgroundColor, const Color(0xFF111111));
      expect(layered.borderColor, const Color(0xFF222222));
    });
  });
}
