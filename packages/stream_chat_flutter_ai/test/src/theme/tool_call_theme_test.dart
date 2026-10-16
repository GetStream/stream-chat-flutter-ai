import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Pumps a probe under [theme] (wrapped in [scope]) and returns what
/// [ToolCallTheme.of] resolves beneath it.
Future<ToolCallThemeData> _resolve(
  WidgetTester tester, {
  ThemeData? theme,
  Widget Function(Widget)? scope,
}) async {
  late ToolCallThemeData resolved;
  final probe = Builder(
    builder: (context) {
      resolved = ToolCallTheme.of(context);
      return const SizedBox();
    },
  );
  await tester.pumpWidget(MaterialApp(theme: theme, home: scope?.call(probe) ?? probe));
  return resolved;
}

void main() {
  group('ToolCallThemeData', () {
    test('describes only the fields it sets to DevTools', () {
      final description = const ToolCallThemeData(iconSize: 20).toDiagnosticsNode().toStringDeep();
      expect(description, contains('iconSize'));
      expect(description, isNot(contains('failureColor')), reason: 'unset fields stay out of the tree');
    });

    group('every field', () {
      const base = ToolCallThemeData(
        titleStyle: TextStyle(fontSize: 11),
        detailStyle: TextStyle(fontSize: 12),
        accentColor: Color(0xFF111111),
        successColor: Color(0xFF222222),
        failureColor: Color(0xFF333333),
        iconSize: 10,
      );

      /// One per field: how to set it to a second value, and how to read it.
      final fields =
          <
            ({
              String name,
              ToolCallThemeData only,
              ToolCallThemeData Function() copied,
              Object? Function(ToolCallThemeData) read,
            })
          >[
            (
              name: 'titleStyle',
              only: const ToolCallThemeData(titleStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(titleStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.titleStyle,
            ),
            (
              name: 'detailStyle',
              only: const ToolCallThemeData(detailStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(detailStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.detailStyle,
            ),
            (
              name: 'accentColor',
              only: const ToolCallThemeData(accentColor: Color(0xFF0000A1)),
              copied: () => base.copyWith(accentColor: const Color(0xFF0000A1)),
              read: (t) => t.accentColor,
            ),
            (
              name: 'successColor',
              only: const ToolCallThemeData(successColor: Color(0xFF0000A2)),
              copied: () => base.copyWith(successColor: const Color(0xFF0000A2)),
              read: (t) => t.successColor,
            ),
            (
              name: 'failureColor',
              only: const ToolCallThemeData(failureColor: Color(0xFF0000A3)),
              copied: () => base.copyWith(failureColor: const Color(0xFF0000A3)),
              read: (t) => t.failureColor,
            ),
            (
              name: 'iconSize',
              only: const ToolCallThemeData(iconSize: 40),
              copied: () => base.copyWith(iconSize: 40),
              read: (t) => t.iconSize,
            ),
          ];

      test('the table covers every field the class declares', () {
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
          final early = ToolCallThemeData.lerp(base, field.only, 0.25);
          final end = ToolCallThemeData.lerp(base, field.only, 1);

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
      const base = ToolCallThemeData(iconSize: 20);
      expect(base.merge(null), same(base));
    });

    test('lerp with identical themes returns the first', () {
      const theme = ToolCallThemeData(iconSize: 20);
      expect(ToolCallThemeData.lerp(theme, theme, 0.5), same(theme));
    });
  });

  group('ToolCallTheme', () {
    testWidgets('resolves to an all-null theme with nothing registered', (tester) async {
      expect(await _resolve(tester), const ToolCallThemeData(), reason: 'theming stays opt-in');
    });

    testWidgets('layers a scope over the AITheme rather than replacing it', (tester) async {
      final resolved = await _resolve(
        tester,
        theme: ThemeData(
          extensions: const [
            AITheme(toolCallTheme: ToolCallThemeData(iconSize: 20, failureColor: Color(0xFF222222))),
          ],
        ),
        scope: (child) => ToolCallTheme(
          data: const ToolCallThemeData(failureColor: Color(0xFF333333)),
          child: child,
        ),
      );

      expect(resolved.failureColor, const Color(0xFF333333), reason: 'the scope wins');
      expect(resolved.iconSize, 20, reason: "the extension's other fields survive");
    });

    testWidgets('merge layers over an enclosing scope', (tester) async {
      final resolved = await _resolve(
        tester,
        scope: (child) => ToolCallTheme(
          data: const ToolCallThemeData(iconSize: 20),
          child: ToolCallTheme.merge(
            data: const ToolCallThemeData(accentColor: Color(0xFF444444)),
            child: child,
          ),
        ),
      );

      expect(resolved.iconSize, 20);
      expect(resolved.accentColor, const Color(0xFF444444));
    });

    testWidgets('a nested scope replaces rather than layers', (tester) async {
      final resolved = await _resolve(
        tester,
        scope: (child) => ToolCallTheme(
          data: const ToolCallThemeData(iconSize: 20),
          child: ToolCallTheme(
            data: const ToolCallThemeData(accentColor: Color(0xFF444444)),
            child: child,
          ),
        ),
      );

      expect(resolved.iconSize, isNull);
      expect(resolved.accentColor, const Color(0xFF444444));
    });
  });
}
