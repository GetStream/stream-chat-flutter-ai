import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Pumps a probe under [theme] (wrapped in [scope]) and returns what [CodeBlockTheme.of] resolves
/// beneath it.
Future<CodeBlockThemeData> _resolve(WidgetTester tester, {ThemeData? theme, Widget Function(Widget)? scope}) async {
  late CodeBlockThemeData resolved;
  final probe = Builder(
    builder: (context) {
      resolved = CodeBlockTheme.of(context);
      return const SizedBox();
    },
  );
  await tester.pumpWidget(MaterialApp(theme: theme, home: scope?.call(probe) ?? probe));
  return resolved;
}

void main() {
  group('CodeBlockThemeData', () {
    test('describes only the fields it sets to DevTools', () {
      final description = const CodeBlockThemeData(
        backgroundColor: Color(0xFF123456),
      ).toDiagnosticsNode().toStringDeep();
      expect(description, contains('backgroundColor'));
      expect(description, isNot(contains('copyIconColor')), reason: 'unset fields stay out of the tree');
    });

    group('every field', () {
      const base = CodeBlockThemeData(
        backgroundColor: Color(0xFF111111),
        headerBackgroundColor: Color(0xFF222222),
        languageLabelStyle: TextStyle(fontSize: 11),
        copyIconColor: Color(0xFF333333),
        copiedIconColor: Color(0xFF444444),
        codeTextStyle: TextStyle(fontSize: 12),
      );

      /// One per field: how to set it to a second value, and how to read it.
      final fields =
          <
            ({
              String name,
              CodeBlockThemeData only,
              CodeBlockThemeData Function() copied,
              Object? Function(CodeBlockThemeData) read,
            })
          >[
            (
              name: 'backgroundColor',
              only: const CodeBlockThemeData(backgroundColor: Color(0xFF0000A1)),
              copied: () => base.copyWith(backgroundColor: const Color(0xFF0000A1)),
              read: (t) => t.backgroundColor,
            ),
            (
              name: 'headerBackgroundColor',
              only: const CodeBlockThemeData(headerBackgroundColor: Color(0xFF0000A2)),
              copied: () => base.copyWith(headerBackgroundColor: const Color(0xFF0000A2)),
              read: (t) => t.headerBackgroundColor,
            ),
            (
              name: 'languageLabelStyle',
              only: const CodeBlockThemeData(languageLabelStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(languageLabelStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.languageLabelStyle,
            ),
            (
              name: 'copyIconColor',
              only: const CodeBlockThemeData(copyIconColor: Color(0xFF0000A3)),
              copied: () => base.copyWith(copyIconColor: const Color(0xFF0000A3)),
              read: (t) => t.copyIconColor,
            ),
            (
              name: 'copiedIconColor',
              only: const CodeBlockThemeData(copiedIconColor: Color(0xFF0000A4)),
              copied: () => base.copyWith(copiedIconColor: const Color(0xFF0000A4)),
              read: (t) => t.copiedIconColor,
            ),
            (
              name: 'codeTextStyle',
              only: const CodeBlockThemeData(codeTextStyle: TextStyle(fontSize: 98)),
              copied: () => base.copyWith(codeTextStyle: const TextStyle(fontSize: 98)),
              read: (t) => t.codeTextStyle,
            ),
          ];

      test('the table covers every field the class declares', () {
        // Guards the loop itself: add a field without a row here and this fails
        // rather than silently leaving the new field untested.
        expect(fields, hasLength(6));
        expect(fields.map((f) => f.name).toSet(), hasLength(6));
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
          final early = CodeBlockThemeData.lerp(base, field.only, 0.25);
          final end = CodeBlockThemeData.lerp(base, field.only, 1);

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
      const base = CodeBlockThemeData(backgroundColor: Color(0xFF111111));
      expect(base.merge(null), same(base));
    });

    test('lerp swaps an unset field instead of fading it through transparency', () {
      const set = CodeBlockThemeData(backgroundColor: Color(0xFF123456));
      const unset = CodeBlockThemeData();

      expect(CodeBlockThemeData.lerp(set, unset, 0.25).backgroundColor, const Color(0xFF123456));
      expect(CodeBlockThemeData.lerp(set, unset, 0.75).backgroundColor, isNull);
    });

    test('lerp interpolates a field both sides set', () {
      const a = CodeBlockThemeData(backgroundColor: Color(0xFF000000));
      const b = CodeBlockThemeData(backgroundColor: Color(0xFFFFFFFF));

      expect(CodeBlockThemeData.lerp(a, b, 0.5).backgroundColor, Color.lerp(Colors.black, Colors.white, 0.5));
    });

    test('lerp with identical themes returns the first', () {
      const theme = CodeBlockThemeData(backgroundColor: Color(0xFF111111));
      expect(CodeBlockThemeData.lerp(theme, theme, 0.5), same(theme));
    });
  });

  group('CodeBlockTheme', () {
    testWidgets('resolves to an all-null theme with nothing registered', (tester) async {
      expect(await _resolve(tester), const CodeBlockThemeData(), reason: 'theming stays opt-in');
    });

    testWidgets('layers a scope over the AITheme rather than replacing it', (tester) async {
      final resolved = await _resolve(
        tester,
        theme: ThemeData(
          extensions: const [
            AITheme(
              codeBlockTheme: CodeBlockThemeData(
                backgroundColor: Color(0xFF111111),
                copyIconColor: Color(0xFF222222),
              ),
            ),
          ],
        ),
        scope: (child) => CodeBlockTheme(
          data: const CodeBlockThemeData(copyIconColor: Color(0xFF333333)),
          child: child,
        ),
      );

      expect(resolved.copyIconColor, const Color(0xFF333333), reason: 'the scope wins');
      expect(resolved.backgroundColor, const Color(0xFF111111), reason: "the extension's other fields survive");
    });

    testWidgets('merge layers over an enclosing scope', (tester) async {
      final resolved = await _resolve(
        tester,
        scope: (child) => CodeBlockTheme(
          data: const CodeBlockThemeData(backgroundColor: Color(0xFF111111)),
          child: CodeBlockTheme.merge(
            data: const CodeBlockThemeData(copyIconColor: Color(0xFF222222)),
            child: child,
          ),
        ),
      );

      expect(resolved.backgroundColor, const Color(0xFF111111));
      expect(resolved.copyIconColor, const Color(0xFF222222));
    });

    testWidgets('merge with no enclosing scope applies its data as is', (tester) async {
      final resolved = await _resolve(
        tester,
        scope: (child) => CodeBlockTheme.merge(
          data: const CodeBlockThemeData(copyIconColor: Color(0xFF222222)),
          child: child,
        ),
      );

      expect(resolved, const CodeBlockThemeData(copyIconColor: Color(0xFF222222)));
    });

    testWidgets('merge puts its key on the returned widget', (tester) async {
      const key = Key('scope');
      await tester.pumpWidget(
        CodeBlockTheme.merge(key: key, data: const CodeBlockThemeData(), child: const SizedBox()),
      );
      expect(find.byKey(key), findsOneWidget);
    });

    testWidgets('wrap carries the scope across a captured theme', (tester) async {
      // What a route or overlay does with InheritedTheme.capture.
      late CodeBlockThemeData resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: CodeBlockTheme(
            data: const CodeBlockThemeData(backgroundColor: Color(0xFF123456)),
            child: Builder(
              builder: (context) {
                final captured = InheritedTheme.capture(from: context, to: null);
                return MediaQuery(
                  data: MediaQuery.of(context),
                  child: captured.wrap(
                    Builder(
                      builder: (inner) {
                        resolved = CodeBlockTheme.of(inner);
                        return const SizedBox();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(resolved.backgroundColor, const Color(0xFF123456));
    });

    testWidgets('a nested scope replaces rather than layers', (tester) async {
      final resolved = await _resolve(
        tester,
        scope: (child) => CodeBlockTheme(
          data: const CodeBlockThemeData(backgroundColor: Color(0xFF111111)),
          child: CodeBlockTheme(
            data: const CodeBlockThemeData(copyIconColor: Color(0xFF222222)),
            child: child,
          ),
        ),
      );

      expect(resolved.backgroundColor, isNull);
      expect(resolved.copyIconColor, const Color(0xFF222222));
    });
  });
}
