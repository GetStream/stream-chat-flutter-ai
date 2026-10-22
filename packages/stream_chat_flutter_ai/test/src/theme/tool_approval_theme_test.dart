import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Pumps a probe under [theme] (wrapped in [scope]) and returns what
/// [ToolApprovalTheme.of] resolves beneath it.
Future<ToolApprovalThemeData> _resolve(
  WidgetTester tester, {
  ThemeData? theme,
  Widget Function(Widget)? scope,
}) async {
  late ToolApprovalThemeData resolved;
  final probe = Builder(
    builder: (context) {
      resolved = ToolApprovalTheme.of(context);
      return const SizedBox();
    },
  );
  await tester.pumpWidget(MaterialApp(theme: theme, home: scope?.call(probe) ?? probe));
  return resolved;
}

void main() {
  group('ToolApprovalThemeData', () {
    test('describes only the fields it sets to DevTools', () {
      final description = const ToolApprovalThemeData(
        accentColor: Color(0xFF111111),
      ).toDiagnosticsNode().toStringDeep();
      expect(description, contains('accentColor'));
      expect(description, isNot(contains('borderColor')), reason: 'unset fields stay out of the tree');
    });

    group('every field', () {
      const base = ToolApprovalThemeData(
        titleStyle: TextStyle(fontSize: 11),
        messageStyle: TextStyle(fontSize: 12),
        backgroundColor: Color(0xFF111111),
        borderColor: Color(0xFF222222),
        accentColor: Color(0xFF333333),
        failureStyle: TextStyle(fontSize: 13),
      );

      /// One per field: how to set it to a second value, and how to read it.
      final fields =
          <
            ({
              String name,
              ToolApprovalThemeData only,
              ToolApprovalThemeData Function() copied,
              Object? Function(ToolApprovalThemeData) read,
            })
          >[
            (
              name: 'titleStyle',
              only: const ToolApprovalThemeData(titleStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(titleStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.titleStyle,
            ),
            (
              name: 'messageStyle',
              only: const ToolApprovalThemeData(messageStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(messageStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.messageStyle,
            ),
            (
              name: 'backgroundColor',
              only: const ToolApprovalThemeData(backgroundColor: Color(0xFF0000A1)),
              copied: () => base.copyWith(backgroundColor: const Color(0xFF0000A1)),
              read: (t) => t.backgroundColor,
            ),
            (
              name: 'borderColor',
              only: const ToolApprovalThemeData(borderColor: Color(0xFF0000A2)),
              copied: () => base.copyWith(borderColor: const Color(0xFF0000A2)),
              read: (t) => t.borderColor,
            ),
            (
              name: 'accentColor',
              only: const ToolApprovalThemeData(accentColor: Color(0xFF0000A3)),
              copied: () => base.copyWith(accentColor: const Color(0xFF0000A3)),
              read: (t) => t.accentColor,
            ),
            (
              name: 'failureStyle',
              only: const ToolApprovalThemeData(failureStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(failureStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.failureStyle,
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
          final early = ToolApprovalThemeData.lerp(base, field.only, 0.25);
          final end = ToolApprovalThemeData.lerp(base, field.only, 1);

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
      const base = ToolApprovalThemeData(backgroundColor: Color(0xFF555555));
      expect(base.merge(null), same(base));
    });

    test('lerp with identical themes returns the first', () {
      const theme = ToolApprovalThemeData(backgroundColor: Color(0xFF555555));
      expect(ToolApprovalThemeData.lerp(theme, theme, 0.5), same(theme));
    });
  });

  group('ToolApprovalTheme', () {
    testWidgets('resolves to an all-null theme with nothing registered', (tester) async {
      expect(await _resolve(tester), const ToolApprovalThemeData(), reason: 'theming stays opt-in');
    });

    testWidgets('layers a scope over the AITheme rather than replacing it', (tester) async {
      final resolved = await _resolve(
        tester,
        theme: ThemeData(
          extensions: const [
            AITheme(
              toolApprovalTheme: ToolApprovalThemeData(accentColor: Color(0xFF111111), borderColor: Color(0xFF222222)),
            ),
          ],
        ),
        scope: (child) => ToolApprovalTheme(
          data: const ToolApprovalThemeData(borderColor: Color(0xFF333333)),
          child: child,
        ),
      );

      expect(resolved.borderColor, const Color(0xFF333333), reason: 'the scope wins');
      expect(resolved.accentColor, const Color(0xFF111111), reason: "the extension's other fields survive");
    });

    testWidgets('merge layers over an enclosing scope', (tester) async {
      final resolved = await _resolve(
        tester,
        scope: (child) => ToolApprovalTheme(
          data: const ToolApprovalThemeData(backgroundColor: Color(0xFF555555)),
          child: ToolApprovalTheme.merge(
            data: const ToolApprovalThemeData(accentColor: Color(0xFF444444)),
            child: child,
          ),
        ),
      );

      expect(resolved.backgroundColor, const Color(0xFF555555));
      expect(resolved.accentColor, const Color(0xFF444444));
    });

    testWidgets('a nested scope replaces rather than layers', (tester) async {
      final resolved = await _resolve(
        tester,
        scope: (child) => ToolApprovalTheme(
          data: const ToolApprovalThemeData(backgroundColor: Color(0xFF555555)),
          child: ToolApprovalTheme(
            data: const ToolApprovalThemeData(accentColor: Color(0xFF444444)),
            child: child,
          ),
        ),
      );

      expect(resolved.backgroundColor, isNull);
      expect(resolved.accentColor, const Color(0xFF444444));
    });
  });
}
