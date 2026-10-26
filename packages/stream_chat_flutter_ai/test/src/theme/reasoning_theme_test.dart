import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Pumps a probe under [theme] (wrapped in [scope]) and returns what
/// [ReasoningTheme.of] resolves beneath it.
Future<ReasoningThemeData> _resolve(
  WidgetTester tester, {
  ThemeData? theme,
  Widget Function(Widget)? scope,
}) async {
  late ReasoningThemeData resolved;
  final probe = Builder(
    builder: (context) {
      resolved = ReasoningTheme.of(context);
      return const SizedBox();
    },
  );
  await tester.pumpWidget(MaterialApp(theme: theme, home: scope?.call(probe) ?? probe));
  return resolved;
}

void main() {
  group('ReasoningThemeData', () {
    test('describes only the fields it sets to DevTools', () {
      final description = const ReasoningThemeData(maxExpandedHeight: 100).toDiagnosticsNode().toStringDeep();
      expect(description, contains('maxExpandedHeight'));
      expect(description, isNot(contains('ruleColor')), reason: 'unset fields stay out of the tree');
    });

    group('every field', () {
      const base = ReasoningThemeData(
        titleStyle: TextStyle(fontSize: 11),
        textStyle: TextStyle(fontSize: 12),
        footnoteStyle: TextStyle(fontSize: 10),
        shimmerColor: Color(0xFF111111),
        ruleColor: Color(0xFF222222),
        iconColor: Color(0xFF333333),
        maxExpandedHeight: 100,
      );

      /// One per field: how to set it to a second value, and how to read it.
      final fields =
          <
            ({
              String name,
              ReasoningThemeData only,
              ReasoningThemeData Function() copied,
              Object? Function(ReasoningThemeData) read,
            })
          >[
            (
              name: 'titleStyle',
              only: const ReasoningThemeData(titleStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(titleStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.titleStyle,
            ),
            (
              name: 'textStyle',
              only: const ReasoningThemeData(textStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(textStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.textStyle,
            ),
            (
              name: 'footnoteStyle',
              only: const ReasoningThemeData(footnoteStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(footnoteStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.footnoteStyle,
            ),
            (
              name: 'shimmerColor',
              only: const ReasoningThemeData(shimmerColor: Color(0xFF0000A1)),
              copied: () => base.copyWith(shimmerColor: const Color(0xFF0000A1)),
              read: (t) => t.shimmerColor,
            ),
            (
              name: 'ruleColor',
              only: const ReasoningThemeData(ruleColor: Color(0xFF0000A2)),
              copied: () => base.copyWith(ruleColor: const Color(0xFF0000A2)),
              read: (t) => t.ruleColor,
            ),
            (
              name: 'iconColor',
              only: const ReasoningThemeData(iconColor: Color(0xFF0000A3)),
              copied: () => base.copyWith(iconColor: const Color(0xFF0000A3)),
              read: (t) => t.iconColor,
            ),
            (
              name: 'maxExpandedHeight',
              only: const ReasoningThemeData(maxExpandedHeight: 400),
              copied: () => base.copyWith(maxExpandedHeight: 400),
              read: (t) => t.maxExpandedHeight,
            ),
          ];

      test('the table covers every field the class declares', () {
        expect(fields, hasLength(7));
        expect(fields.map((f) => f.name).toSet(), hasLength(7));
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
          final early = ReasoningThemeData.lerp(base, field.only, 0.25);
          final end = ReasoningThemeData.lerp(base, field.only, 1);

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
      const base = ReasoningThemeData(maxExpandedHeight: 100);
      expect(base.merge(null), same(base));
    });

    test('lerp with identical themes returns the first', () {
      const theme = ReasoningThemeData(maxExpandedHeight: 100);
      expect(ReasoningThemeData.lerp(theme, theme, 0.5), same(theme));
    });
  });

  group('ReasoningTheme', () {
    testWidgets('resolves to an all-null theme with nothing registered', (tester) async {
      expect(await _resolve(tester), const ReasoningThemeData(), reason: 'theming stays opt-in');
    });

    testWidgets('layers a scope over the AITheme rather than replacing it', (tester) async {
      final resolved = await _resolve(
        tester,
        theme: ThemeData(
          extensions: const [
            AITheme(reasoningTheme: ReasoningThemeData(maxExpandedHeight: 100, ruleColor: Color(0xFF222222))),
          ],
        ),
        scope: (child) => ReasoningTheme(
          data: const ReasoningThemeData(ruleColor: Color(0xFF333333)),
          child: child,
        ),
      );

      expect(resolved.ruleColor, const Color(0xFF333333), reason: 'the scope wins');
      expect(resolved.maxExpandedHeight, 100, reason: "the extension's other fields survive");
    });

    testWidgets('merge layers over an enclosing scope', (tester) async {
      final resolved = await _resolve(
        tester,
        scope: (child) => ReasoningTheme(
          data: const ReasoningThemeData(maxExpandedHeight: 100),
          child: ReasoningTheme.merge(
            data: const ReasoningThemeData(iconColor: Color(0xFF444444)),
            child: child,
          ),
        ),
      );

      expect(resolved.maxExpandedHeight, 100);
      expect(resolved.iconColor, const Color(0xFF444444));
    });

    testWidgets('a nested scope replaces rather than layers', (tester) async {
      final resolved = await _resolve(
        tester,
        scope: (child) => ReasoningTheme(
          data: const ReasoningThemeData(maxExpandedHeight: 100),
          child: ReasoningTheme(
            data: const ReasoningThemeData(iconColor: Color(0xFF444444)),
            child: child,
          ),
        ),
      );

      expect(resolved.maxExpandedHeight, isNull);
      expect(resolved.iconColor, const Color(0xFF444444));
    });
  });
}
