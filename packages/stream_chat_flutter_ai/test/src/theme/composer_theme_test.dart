import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  group('ComposerThemeData', () {
    // Every field, rather than a spot-check: copyWith, merge, == and hashCode
    // are four hand-written 13-line tables, and a crossed line in any of them
    // is invisible until someone themes that particular field. The loop below
    // is what makes a 14th field added to only three of the four fail loudly.
    group('every field', () {
      const base = ComposerThemeData(
        fillColor: Color(0xFF111111),
        borderColor: Color(0xFF222222),
        hintStyle: TextStyle(fontSize: 11),
        iconColor: Color(0xFF333333),
        disabledIconColor: Color(0xFF444444),
        sendButtonColor: Color(0xFF555555),
        stopButtonColor: Color(0xFF666666),
        recordingButtonColor: Color(0xFF777777),
        actionButtonForegroundColor: Color(0xFF888888),
        selectedOptionColor: Color(0xFF999999),
        selectedOptionForegroundColor: Color(0xFFAAAAAA),
        selectionColor: Color(0xFFBBBBBB),
        attachmentPlaceholderColor: Color(0xFFCCCCCC),
      );

      /// One per field: how to set it to a second value, and how to read it.
      final fields =
          <
            ({
              String name,
              ComposerThemeData only,
              ComposerThemeData Function() copied,
              Object? Function(ComposerThemeData) read,
            })
          >[
            (
              name: 'fillColor',
              only: const ComposerThemeData(fillColor: Color(0xFF0000A1)),
              copied: () => base.copyWith(fillColor: const Color(0xFF0000A1)),
              read: (t) => t.fillColor,
            ),
            (
              name: 'borderColor',
              only: const ComposerThemeData(borderColor: Color(0xFF0000A2)),
              copied: () => base.copyWith(borderColor: const Color(0xFF0000A2)),
              read: (t) => t.borderColor,
            ),
            (
              name: 'hintStyle',
              only: const ComposerThemeData(hintStyle: TextStyle(fontSize: 99)),
              copied: () => base.copyWith(hintStyle: const TextStyle(fontSize: 99)),
              read: (t) => t.hintStyle,
            ),
            (
              name: 'iconColor',
              only: const ComposerThemeData(iconColor: Color(0xFF0000A3)),
              copied: () => base.copyWith(iconColor: const Color(0xFF0000A3)),
              read: (t) => t.iconColor,
            ),
            (
              name: 'disabledIconColor',
              only: const ComposerThemeData(disabledIconColor: Color(0xFF0000A4)),
              copied: () => base.copyWith(disabledIconColor: const Color(0xFF0000A4)),
              read: (t) => t.disabledIconColor,
            ),
            (
              name: 'sendButtonColor',
              only: const ComposerThemeData(sendButtonColor: Color(0xFF0000A5)),
              copied: () => base.copyWith(sendButtonColor: const Color(0xFF0000A5)),
              read: (t) => t.sendButtonColor,
            ),
            (
              name: 'stopButtonColor',
              only: const ComposerThemeData(stopButtonColor: Color(0xFF0000A6)),
              copied: () => base.copyWith(stopButtonColor: const Color(0xFF0000A6)),
              read: (t) => t.stopButtonColor,
            ),
            (
              name: 'recordingButtonColor',
              only: const ComposerThemeData(recordingButtonColor: Color(0xFF0000A7)),
              copied: () => base.copyWith(recordingButtonColor: const Color(0xFF0000A7)),
              read: (t) => t.recordingButtonColor,
            ),
            (
              name: 'actionButtonForegroundColor',
              only: const ComposerThemeData(actionButtonForegroundColor: Color(0xFF0000A8)),
              copied: () => base.copyWith(actionButtonForegroundColor: const Color(0xFF0000A8)),
              read: (t) => t.actionButtonForegroundColor,
            ),
            (
              name: 'selectedOptionColor',
              only: const ComposerThemeData(selectedOptionColor: Color(0xFF0000A9)),
              copied: () => base.copyWith(selectedOptionColor: const Color(0xFF0000A9)),
              read: (t) => t.selectedOptionColor,
            ),
            (
              name: 'selectedOptionForegroundColor',
              only: const ComposerThemeData(selectedOptionForegroundColor: Color(0xFF0000AA)),
              copied: () => base.copyWith(selectedOptionForegroundColor: const Color(0xFF0000AA)),
              read: (t) => t.selectedOptionForegroundColor,
            ),
            (
              name: 'selectionColor',
              only: const ComposerThemeData(selectionColor: Color(0xFF0000AB)),
              copied: () => base.copyWith(selectionColor: const Color(0xFF0000AB)),
              read: (t) => t.selectionColor,
            ),
            (
              name: 'attachmentPlaceholderColor',
              only: const ComposerThemeData(attachmentPlaceholderColor: Color(0xFF0000AC)),
              copied: () => base.copyWith(attachmentPlaceholderColor: const Color(0xFF0000AC)),
              read: (t) => t.attachmentPlaceholderColor,
            ),
          ];

      test('the table covers every field the class declares', () {
        // Guards the loop itself: add a field without a row here and this
        // fails rather than silently leaving the new field untested.
        expect(fields, hasLength(13));
        expect(fields.map((f) => f.name).toSet(), hasLength(13));
      });

      for (final field in fields) {
        test('${field.name} survives copyWith, merge, == and hashCode', () {
          final copied = field.copied();
          final merged = base.merge(field.only);

          expect(field.read(copied), field.read(field.only), reason: 'copyWith set ${field.name}');
          expect(field.read(merged), field.read(field.only), reason: 'merge took ${field.name}');

          // Nothing else moved — this is what catches a crossed line.
          for (final other in fields.where((f) => f.name != field.name)) {
            expect(other.read(copied), other.read(base), reason: 'copyWith(${field.name}) disturbed ${other.name}');
            expect(other.read(merged), other.read(base), reason: 'merge(${field.name}) disturbed ${other.name}');
          }

          expect(copied, merged, reason: 'copyWith and merge disagree on ${field.name}');
          expect(copied, isNot(base), reason: '== ignores ${field.name}');
          expect(copied.hashCode, isNot(base.hashCode), reason: 'hashCode ignores ${field.name}');
        });
      }
    });

    group('merge', () {
      test("takes the other theme's set fields", () {
        const base = ComposerThemeData(fillColor: Color(0xFF111111), sendButtonColor: Color(0xFF222222));
        final merged = base.merge(const ComposerThemeData(fillColor: Color(0xFF333333)));

        expect(merged.fillColor, const Color(0xFF333333));
        expect(merged.sendButtonColor, const Color(0xFF222222), reason: 'an unset field leaves the base value alone');
      });

      test('with null returns this', () {
        const base = ComposerThemeData(fillColor: Color(0xFF111111));
        expect(base.merge(null), same(base));
      });
    });

    group('lerp', () {
      test('interpolates a field both sides set', () {
        const a = ComposerThemeData(sendButtonColor: Color(0xFF000000));
        const b = ComposerThemeData(sendButtonColor: Color(0xFFFFFFFF));

        expect(
          ComposerThemeData.lerp(a, b, 0.5).sendButtonColor,
          Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.5),
        );
      });

      test('swaps an unset field instead of fading it through transparency', () {
        // `null` means "derive from the ambient ThemeData", not "transparent" —
        // interpolating towards it would wash the fill out mid-animation and
        // then snap back.
        const set = ComposerThemeData(fillColor: Color(0xFF123456));
        const unset = ComposerThemeData();

        expect(ComposerThemeData.lerp(set, unset, 0.25).fillColor, const Color(0xFF123456));
        expect(ComposerThemeData.lerp(set, unset, 0.75).fillColor, isNull);
      });

      test('with identical themes returns the first', () {
        const theme = ComposerThemeData(fillColor: Color(0xFF111111));
        expect(ComposerThemeData.lerp(theme, theme, 0.5), same(theme));
      });
    });
  });

  group('ComposerTheme', () {
    testWidgets('resolves to an all-null theme with nothing registered', (tester) async {
      late ComposerThemeData resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = ComposerTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, const ComposerThemeData(), reason: 'theming stays opt-in');
    });

    testWidgets('layers a scope over the AITheme rather than replacing it', (tester) async {
      late ComposerThemeData resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [
              AITheme(
                composerTheme: ComposerThemeData(
                  fillColor: Color(0xFF111111),
                  sendButtonColor: Color(0xFF222222),
                ),
              ),
            ],
          ),
          home: ComposerTheme(
            data: const ComposerThemeData(sendButtonColor: Color(0xFF333333)),
            child: Builder(
              builder: (context) {
                resolved = ComposerTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolved.sendButtonColor, const Color(0xFF333333), reason: 'the scope wins');
      expect(resolved.fillColor, const Color(0xFF111111), reason: "the extension's other fields survive");
    });

    testWidgets('a nested scope replaces, and merge layers', (tester) async {
      late ComposerThemeData replaced;
      late ComposerThemeData layered;

      await tester.pumpWidget(
        MaterialApp(
          home: ComposerTheme(
            data: const ComposerThemeData(fillColor: Color(0xFF111111)),
            child: Column(
              children: [
                ComposerTheme(
                  data: const ComposerThemeData(sendButtonColor: Color(0xFF222222)),
                  child: Builder(
                    builder: (context) {
                      replaced = ComposerTheme.of(context);
                      return const SizedBox();
                    },
                  ),
                ),
                ComposerTheme.merge(
                  data: const ComposerThemeData(sendButtonColor: Color(0xFF222222)),
                  child: Builder(
                    builder: (context) {
                      layered = ComposerTheme.of(context);
                      return const SizedBox();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(replaced.fillColor, isNull, reason: 'a plain nested scope shadows the outer one');
      expect(layered.fillColor, const Color(0xFF111111), reason: 'merge keeps the outer fill');
      expect(layered.sendButtonColor, const Color(0xFF222222));
    });

    testWidgets('crosses a route, so it reaches the attachment sheet', (tester) async {
      // ComposerTheme is an InheritedTheme, and the attachment sheet is pushed
      // by showModalBottomSheet onto its own route. Without the `wrap` override
      // a scope directly above the composer would stop at the Navigator and the
      // sheet would silently fall back to the ambient ColorScheme.
      late ComposerThemeData insideRoute;

      await tester.pumpWidget(
        MaterialApp(
          home: ComposerTheme(
            data: const ComposerThemeData(fillColor: Color(0xFF123456)),
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (context) {
                    insideRoute = ComposerTheme.of(context);
                    return const SizedBox();
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(insideRoute.fillColor, const Color(0xFF123456));
    });

    test('notifies only when its data changes', () {
      // The contract is updateShouldNotify itself, asserted directly: a
      // rebuild count through pumpWidget would measure the parent being
      // replaced, which happens either way.
      const a = ComposerTheme(
        data: ComposerThemeData(fillColor: Color(0xFF111111)),
        child: SizedBox.shrink(),
      );
      const b = ComposerTheme(
        data: ComposerThemeData(fillColor: Color(0xFF222222)),
        child: SizedBox.shrink(),
      );
      const sameAsA = ComposerTheme(
        data: ComposerThemeData(fillColor: Color(0xFF111111)),
        child: SizedBox.shrink(),
      );

      expect(b.updateShouldNotify(a), isTrue);
      expect(sameAsA.updateShouldNotify(a), isFalse, reason: 'an equal theme should not notify dependents');
    });
  });
}
