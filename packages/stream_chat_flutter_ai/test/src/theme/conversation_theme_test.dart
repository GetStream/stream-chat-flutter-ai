import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Pumps a probe under [theme] (wrapped in [scope]) and returns what
/// [ConversationTheme.of] resolves beneath it.
Future<ConversationThemeData> _resolve(
  WidgetTester tester, {
  ThemeData? theme,
  Widget Function(Widget)? scope,
}) async {
  late ConversationThemeData resolved;
  final probe = Builder(
    builder: (context) {
      resolved = ConversationTheme.of(context);
      return const SizedBox();
    },
  );
  await tester.pumpWidget(MaterialApp(theme: theme, home: scope?.call(probe) ?? probe));
  return resolved;
}

void main() {
  group('ConversationThemeData', () {
    test('describes only the fields it sets to DevTools', () {
      final description = const ConversationThemeData(
        scrollButtonIconColor: Color(0xFF111111),
      ).toDiagnosticsNode().toStringDeep();
      expect(description, contains('scrollButtonIconColor'));
      expect(description, isNot(contains('scrollButtonBorderColor')), reason: 'unset fields stay out of the tree');
    });

    group('every field', () {
      const base = ConversationThemeData(
        userMessageBackgroundColor: Color(0xFF111111),
        userMessageTextStyle: TextStyle(fontSize: 12),
        attachmentBackgroundColor: Color(0xFF333333),
        attachmentTitleStyle: TextStyle(fontSize: 14),
        attachmentDetailsStyle: TextStyle(fontSize: 15),
        scrollButtonBackgroundColor: Color(0xFF666666),
        scrollButtonIconColor: Color(0xFF777777),
        scrollButtonBorderColor: Color(0xFF888888),
      );

      /// One per field: how to set it to a second value, and how to read it.
      final fields =
          <
            ({
              String name,
              ConversationThemeData only,
              ConversationThemeData Function() copied,
              Object? Function(ConversationThemeData) read,
            })
          >[
            (
              name: 'userMessageBackgroundColor',
              only: const ConversationThemeData(userMessageBackgroundColor: Color(0xFF0000A1)),
              copied: () => base.copyWith(userMessageBackgroundColor: const Color(0xFF0000A1)),
              read: (t) => t.userMessageBackgroundColor,
            ),
            (
              name: 'userMessageTextStyle',
              only: const ConversationThemeData(userMessageTextStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(userMessageTextStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.userMessageTextStyle,
            ),
            (
              name: 'attachmentBackgroundColor',
              only: const ConversationThemeData(attachmentBackgroundColor: Color(0xFF0000A3)),
              copied: () => base.copyWith(attachmentBackgroundColor: const Color(0xFF0000A3)),
              read: (t) => t.attachmentBackgroundColor,
            ),
            (
              name: 'attachmentTitleStyle',
              only: const ConversationThemeData(attachmentTitleStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(attachmentTitleStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.attachmentTitleStyle,
            ),
            (
              name: 'attachmentDetailsStyle',
              only: const ConversationThemeData(attachmentDetailsStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(attachmentDetailsStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.attachmentDetailsStyle,
            ),
            (
              name: 'scrollButtonBackgroundColor',
              only: const ConversationThemeData(scrollButtonBackgroundColor: Color(0xFF0000A6)),
              copied: () => base.copyWith(scrollButtonBackgroundColor: const Color(0xFF0000A6)),
              read: (t) => t.scrollButtonBackgroundColor,
            ),
            (
              name: 'scrollButtonIconColor',
              only: const ConversationThemeData(scrollButtonIconColor: Color(0xFF0000A7)),
              copied: () => base.copyWith(scrollButtonIconColor: const Color(0xFF0000A7)),
              read: (t) => t.scrollButtonIconColor,
            ),
            (
              name: 'scrollButtonBorderColor',
              only: const ConversationThemeData(scrollButtonBorderColor: Color(0xFF0000A8)),
              copied: () => base.copyWith(scrollButtonBorderColor: const Color(0xFF0000A8)),
              read: (t) => t.scrollButtonBorderColor,
            ),
          ];

      test('the table covers every field the class declares', () {
        expect(fields, hasLength(8));
        expect(fields.map((f) => f.name).toSet(), hasLength(8));
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
          final early = ConversationThemeData.lerp(base, field.only, 0.25);
          final end = ConversationThemeData.lerp(base, field.only, 1);

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
      const base = ConversationThemeData(scrollButtonBorderColor: Color(0xFF555555));
      expect(base.merge(null), same(base));
    });

    test('lerp with identical themes returns the first', () {
      const theme = ConversationThemeData(scrollButtonBorderColor: Color(0xFF555555));
      expect(ConversationThemeData.lerp(theme, theme, 0.5), same(theme));
    });
  });

  group('ConversationTheme', () {
    testWidgets('resolves to an all-null theme with nothing registered', (tester) async {
      expect(await _resolve(tester), const ConversationThemeData(), reason: 'theming stays opt-in');
    });

    testWidgets('layers a scope over the AITheme rather than replacing it', (tester) async {
      final resolved = await _resolve(
        tester,
        theme: ThemeData(
          extensions: const [
            AITheme(
              conversationTheme: ConversationThemeData(
                scrollButtonIconColor: Color(0xFF111111),
                scrollButtonBorderColor: Color(0xFF222222),
              ),
            ),
          ],
        ),
        scope: (child) => ConversationTheme(
          data: const ConversationThemeData(scrollButtonBorderColor: Color(0xFF333333)),
          child: child,
        ),
      );

      expect(resolved.scrollButtonBorderColor, const Color(0xFF333333), reason: 'the scope wins');
      expect(resolved.scrollButtonIconColor, const Color(0xFF111111), reason: "the extension's other fields survive");
    });

    testWidgets('merge layers over an enclosing scope', (tester) async {
      final resolved = await _resolve(
        tester,
        scope: (child) => ConversationTheme(
          data: const ConversationThemeData(scrollButtonBorderColor: Color(0xFF555555)),
          child: ConversationTheme.merge(
            data: const ConversationThemeData(scrollButtonIconColor: Color(0xFF444444)),
            child: child,
          ),
        ),
      );

      expect(resolved.scrollButtonBorderColor, const Color(0xFF555555));
      expect(resolved.scrollButtonIconColor, const Color(0xFF444444));
    });

    testWidgets('a nested scope replaces rather than layers', (tester) async {
      final resolved = await _resolve(
        tester,
        scope: (child) => ConversationTheme(
          data: const ConversationThemeData(scrollButtonBorderColor: Color(0xFF555555)),
          child: ConversationTheme(
            data: const ConversationThemeData(scrollButtonIconColor: Color(0xFF444444)),
            child: child,
          ),
        ),
      );

      expect(resolved.scrollButtonBorderColor, isNull);
      expect(resolved.scrollButtonIconColor, const Color(0xFF444444));
    });
  });
}
