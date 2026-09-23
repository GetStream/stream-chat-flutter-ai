import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// The end of the theming chain: the theme data classes are unit-tested next
/// door, but a field that resolves correctly and is then never read by the
/// widget is exactly the bug this file exists to catch.

const _fill = Color(0xFF102030);
const _border = Color(0xFF203040);
const _send = Color(0xFF304050);
const _stop = Color(0xFF405060);
const _optionFill = Color(0xFF506070);
const _optionForeground = Color(0xFF607080);
const _actionForeground = Color(0xFF708090);
const _icon = Color(0xFF8090A0);

const _composerTheme = ComposerThemeData(
  fillColor: _fill,
  borderColor: _border,
  sendButtonColor: _send,
  stopButtonColor: _stop,
  selectedOptionColor: _optionFill,
  selectedOptionForegroundColor: _optionForeground,
  actionButtonForegroundColor: _actionForeground,
  iconColor: _icon,
);

Widget _app({required Widget child, AITheme? extension}) => MaterialApp(
  theme: ThemeData(extensions: extension == null ? const <ThemeExtension<dynamic>>[] : [extension]),
  home: Scaffold(body: child),
);

/// The input pill's own decoration: the rounded box directly around the
/// [TextField].
///
/// Targeted rather than "any box carrying this color", because the pill, the
/// leading "+" and the sheet's tiles share [ComposerThemeData.fillColor] on
/// purpose — a scan would pass on the "+" alone with the pill ignoring it.
BoxDecoration _pill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .ancestor(
          of: find.byType(TextField),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).borderRadius == BorderRadius.circular(24),
          ),
        )
        .first,
  );
  return box.decoration as BoxDecoration;
}

/// The leading "+" button's circle.
BoxDecoration _leadingButton(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.byIcon(Icons.add), matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

Color? _borderColor(BoxDecoration decoration) => (decoration.border as Border?)?.top.color;

bool _hasBoxWithColor(WidgetTester tester, Finder scope, Color color) {
  final boxes = tester.widgetList<DecoratedBox>(
    find.descendant(of: scope, matching: find.byType(DecoratedBox), matchRoot: true),
  );
  return boxes.any((box) {
    final decoration = box.decoration;
    return decoration is BoxDecoration && decoration.color == color;
  });
}

bool _hasCircleWithColor(WidgetTester tester, Color color) {
  // The send/stop/mic circle is an AnimatedContainer, which renders through a
  // DecoratedBox carrying its current (settled) decoration — so scan those for
  // a circle, rather than reading the widget's own target `decoration`.
  final found = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
  return found.any((box) {
    final decoration = box.decoration;
    return decoration is BoxDecoration && decoration.color == color && decoration.shape == BoxShape.circle;
  });
}

/// Opens the real attachment sheet from the "+" button.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add));
  // Not `pumpAndSettle` — the sheet's photo section spins a
  // CircularProgressIndicator while its (unmocked) permission check is in
  // flight, which never settles. See chat_composer_test.dart.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Lets a thumbnail's failing `readAsBytes` land, so it shows its error glyph.
Future<void> _failThumbnail(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
}

void main() {
  group('ChatComposer honours ComposerThemeData', () {
    testWidgets('through the AITheme extension', (tester) async {
      final controller = ChatComposerController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          extension: const AITheme(composerTheme: _composerTheme),
          child: ChatComposer(controller: controller, onSendPressed: (_, _, _) {}),
        ),
      );

      expect(_pill(tester).color, _fill, reason: 'the input pill takes fillColor');
      expect(_borderColor(_pill(tester)), _border, reason: 'the input pill takes borderColor');
      expect(_leadingButton(tester).color, _fill, reason: 'the leading "+" takes the same fill');
      expect(_borderColor(_leadingButton(tester)), _border, reason: 'the leading "+" takes the same border');
      expect(tester.widget<Icon>(find.byIcon(Icons.add)).color, _icon, reason: 'an enabled "+" takes iconColor');
    });

    testWidgets('through a ComposerTheme scope', (tester) async {
      final controller = ChatComposerController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          child: ComposerTheme(
            data: _composerTheme,
            child: ChatComposer(controller: controller, onSendPressed: (_, _, _) {}),
          ),
        ),
      );

      expect(_pill(tester).color, _fill);
    });

    testWidgets('sends in sendButtonColor and stops in stopButtonColor', (tester) async {
      final controller = ChatComposerController(initialText: 'hi');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          extension: const AITheme(composerTheme: _composerTheme),
          child: ChatComposer(
            controller: controller,
            onSendPressed: (_, _, _) {},
            onStopPressed: () {},
          ),
        ),
      );

      expect(_hasCircleWithColor(tester, _send), isTrue, reason: 'send takes sendButtonColor');

      controller.isGenerating = true;
      await tester.pumpAndSettle();

      expect(_hasCircleWithColor(tester, _stop), isTrue, reason: 'stop takes stopButtonColor');
      expect(
        _hasCircleWithColor(tester, _send),
        isFalse,
        reason: 'the send fill is gone once generating',
      );
    });

    testWidgets('paints the action icon in actionButtonForegroundColor', (tester) async {
      final controller = ChatComposerController(initialText: 'hi');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          extension: const AITheme(composerTheme: _composerTheme),
          child: ChatComposer(controller: controller, onSendPressed: (_, _, _) {}),
        ),
      );

      final sendIcon = tester.widget<Icon>(find.byIcon(Icons.arrow_upward_rounded));
      expect(sendIcon.color, _actionForeground);
    });

    testWidgets("a ComposerActionButton's own foregroundColor wins over the theme", (tester) async {
      const own = Color(0xFF0F0F0F);

      await tester.pumpWidget(
        _app(
          extension: const AITheme(composerTheme: _composerTheme),
          child: Column(
            children: [
              ComposerActionButton(
                icon: Icons.star,
                onPressed: () {},
                tooltip: 'own',
                color: _send,
                foregroundColor: own,
              ),
              ComposerActionButton(icon: Icons.favorite, onPressed: () {}, tooltip: 'themed', color: _send),
            ],
          ),
        ),
      );

      expect(tester.widget<Icon>(find.byIcon(Icons.star)).color, own);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.favorite)).color,
        _actionForeground,
        reason: 'unset, it follows the theme',
      );
    });

    testWidgets('paints the selected-option chip in its own colors', (tester) async {
      final controller = ChatComposerController()
        ..selectChatOption(const ChatOption(id: 'a', text: 'Summarize', icon: Icons.summarize));
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          extension: const AITheme(composerTheme: _composerTheme),
          child: ChatComposer(controller: controller, onSendPressed: (_, _, _) {}),
        ),
      );

      expect(_hasBoxWithColor(tester, find.byType(ChatComposer), _optionFill), isTrue, reason: 'the chip fill');

      final optionIcon = tester.widget<Icon>(find.byIcon(Icons.summarize));
      expect(optionIcon.color, _optionForeground);

      final label = tester.widget<Text>(find.text('Summarize'));
      expect(label.style?.color, _optionForeground);
    });

    testWidgets('dims the leading button to disabledIconColor while generating', (tester) async {
      final controller = ChatComposerController()..isGenerating = true;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          extension: const AITheme(composerTheme: _composerTheme),
          child: ChatComposer(
            controller: controller,
            onSendPressed: (_, _, _) {},
            onStopPressed: () {},
          ),
        ),
      );

      final addIcon = tester.widget<Icon>(find.byIcon(Icons.add));
      // Not set on the theme, so it derives from the *resolved* iconColor — a
      // host setting only `iconColor` gets a matching disabled shade for free.
      expect(addIcon.color, _icon.withValues(alpha: 0.3));
    });

    testWidgets('dims to a disabledIconColor that scales a translucent iconColor', (tester) async {
      const translucent = Color(0x80112233);
      final controller = ChatComposerController()..isGenerating = true;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          extension: const AITheme(composerTheme: ComposerThemeData(iconColor: translucent)),
          child: ChatComposer(controller: controller, onSendPressed: (_, _, _) {}, onStopPressed: () {}),
        ),
      );

      final addIcon = tester.widget<Icon>(find.byIcon(Icons.add));
      // Scaled, not replaced: a disabled shade never more opaque than the
      // enabled one.
      expect(addIcon.color, translucent.withValues(alpha: translucent.a * 0.3));
    });

    testWidgets('honours an explicit disabledIconColor', (tester) async {
      const disabled = Color(0xFF0A0B0C);
      final controller = ChatComposerController()..isGenerating = true;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          extension: const AITheme(
            composerTheme: ComposerThemeData(iconColor: _icon, disabledIconColor: disabled),
          ),
          child: ChatComposer(controller: controller, onSendPressed: (_, _, _) {}, onStopPressed: () {}),
        ),
      );

      expect(tester.widget<Icon>(find.byIcon(Icons.add)).color, disabled);
    });

    group('hintStyle', () {
      InputDecoration hint(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).decoration!;
      final derived = ThemeData().colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

      Future<void> pump(WidgetTester tester, TextStyle style) async {
        final controller = ChatComposerController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(
            extension: AITheme(composerTheme: ComposerThemeData(hintStyle: style)),
            child: ChatComposer(controller: controller, onSendPressed: (_, _, _) {}),
          ),
        );
      }

      testWidgets('merges over the derived color', (tester) async {
        await pump(tester, const TextStyle(fontSize: 30));

        expect(hint(tester).hintStyle?.fontSize, 30);
        expect(hint(tester).hintStyle?.color, derived, reason: 'a size-only override keeps the default color');
      });

      testWidgets('keeps a color through an inherit: false style', (tester) async {
        // TextStyle.merge hands an `inherit: false` style back unmerged, which
        // would leave the hint with no color at all.
        await pump(tester, const TextStyle(inherit: false, fontSize: 30));

        expect(hint(tester).hintStyle?.fontSize, 30);
        expect(hint(tester).hintStyle?.color, derived);
      });

      testWidgets('takes an explicit color', (tester) async {
        await pump(tester, const TextStyle(color: _icon));
        expect(hint(tester).hintStyle?.color, _icon);
      });
    });

    group('attachment thumbnails', () {
      testWidgets('draw the placeholder, badge and glyphs from the theme', (tester) async {
        const placeholder = Color(0xFF0C0D0E);
        const glyph = Color(0xFF0E0D0C);
        final controller = ChatComposerController()..addAttachments([XFile('does-not-exist.png')]);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _app(
            extension: const AITheme(
              composerTheme: ComposerThemeData(
                iconColor: _icon,
                borderColor: _border,
                attachmentPlaceholderColor: placeholder,
                attachmentPlaceholderForegroundColor: glyph,
              ),
            ),
            child: ChatComposer(controller: controller, onSendPressed: (_, _, _) {}),
          ),
        );
        await _failThumbnail(tester);
        // The unreadable file is reported, not swallowed; that report is not
        // what this test is about.
        expect(tester.takeException(), isA<Exception>());

        final broken = find.byIcon(Icons.broken_image_outlined);
        expect(broken, findsOneWidget);
        expect(tester.widget<Icon>(broken).color, glyph, reason: 'the error glyph takes the placeholder foreground');
        expect(
          tester.widget<ColoredBox>(find.ancestor(of: broken, matching: find.byType(ColoredBox)).first).color,
          placeholder,
        );
        expect(tester.widget<Icon>(find.byIcon(Icons.close)).color, glyph, reason: 'so does the remove "×"');
      });

      testWidgets('keep their scheme defaults under a host iconColor', (tester) async {
        final controller = ChatComposerController()..addAttachments([XFile('does-not-exist.png')]);
        addTearDown(controller.dispose);

        // A dark pill with white icons. The glyphs sit on the placeholder, not
        // the pill, so white would vanish on its default `surface`.
        await tester.pumpWidget(
          _app(
            extension: const AITheme(
              composerTheme: ComposerThemeData(fillColor: Color(0xFF0A1A3A), iconColor: Colors.white),
            ),
            child: ChatComposer(controller: controller, onSendPressed: (_, _, _) {}),
          ),
        );
        await _failThumbnail(tester);
        expect(tester.takeException(), isA<Exception>());

        final scheme = ThemeData().colorScheme;
        expect(tester.widget<Icon>(find.byIcon(Icons.close)).color, scheme.onSurface);
        // The quieter onSurfaceVariant, as before theming.
        expect(
          tester.widget<Icon>(find.byIcon(Icons.broken_image_outlined)).color,
          scheme.onSurfaceVariant,
        );
      });
    });

    group('attachment sheet', () {
      testWidgets('takes the theme across the route it is pushed on', (tester) async {
        const option = ChatOption(id: 'a', text: 'Deep research', icon: Icons.science);
        final controller = ChatComposerController(chatOptions: [option]);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _app(
            // A scope, not the extension: this is what has to cross the
            // Navigator to reach the sheet.
            child: ComposerTheme(
              data: _composerTheme,
              child: ChatComposer(controller: controller, onSendPressed: (_, _, _) {}),
            ),
          ),
        );
        await _openSheet(tester);

        final sheet = find.byType(ComposerAttachmentSheet);
        expect(sheet, findsOneWidget);

        final camera = find.byIcon(Icons.camera_alt_outlined);
        expect(tester.widget<Icon>(camera).color, _icon, reason: 'the camera tile takes iconColor');
        final cameraTile = tester.widget<Container>(find.ancestor(of: camera, matching: find.byType(Container)).first);
        expect((cameraTile.decoration! as BoxDecoration).color, _fill, reason: 'the camera tile takes fillColor');

        expect(
          tester.widget<Divider>(find.descendant(of: sheet, matching: find.byType(Divider))).color,
          _border,
          reason: 'the divider takes borderColor',
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.science)).color,
          ThemeData().colorScheme.onSurface,
          reason: 'option icons sit on the unthemed sheet background, so they follow the scheme, not iconColor',
        );
      });

      testWidgets('dims the camera tile once the composer is full', (tester) async {
        final controller = ChatComposerController(maxAttachments: 1)..addAttachments([XFile('a.png')]);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _app(
            child: ComposerTheme(
              data: _composerTheme,
              child: ChatComposer(controller: controller, onSendPressed: (_, _, _) {}),
            ),
          ),
        );
        await _openSheet(tester);

        expect(tester.widget<Icon>(find.byIcon(Icons.camera_alt_outlined)).color, _icon.withValues(alpha: 0.3));
      });
    });

    testWidgets('leaves the appearance alone when nothing is registered', (tester) async {
      final controller = ChatComposerController(initialText: 'hi');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          child: ChatComposer(controller: controller, onSendPressed: (_, _, _) {}, onStopPressed: () {}),
        ),
      );

      final scheme = ThemeData().colorScheme;
      expect(_pill(tester).color, scheme.surfaceContainerHigh);
      expect(_borderColor(_pill(tester)), scheme.outlineVariant);
      expect(_leadingButton(tester).color, scheme.surfaceContainerHigh);
      expect(tester.widget<Icon>(find.byIcon(Icons.add)).color, scheme.onSurface);
      expect(_hasCircleWithColor(tester, scheme.primary), isTrue, reason: 'send falls back to primary');
      expect(tester.widget<Icon>(find.byIcon(Icons.arrow_upward_rounded)).color, Colors.white);

      controller.isGenerating = true;
      await tester.pumpAndSettle();
      expect(_hasCircleWithColor(tester, scheme.error), isTrue, reason: 'stop falls back to error');
    });
  });

  group('AISuggestionsView honours SuggestionsThemeData', () {
    testWidgets('takes the background and border from the extension', (tester) async {
      await tester.pumpWidget(
        _app(
          extension: const AITheme(
            suggestionsTheme: SuggestionsThemeData(backgroundColor: _fill, borderColor: _border),
          ),
          child: AISuggestionsView(suggestions: const ['Tell me a joke'], onSuggestionSelected: (_) {}),
        ),
      );

      final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      final chip = boxes.map((b) => b.decoration).whereType<BoxDecoration>().firstWhere((d) => d.color == _fill);

      expect(chip.color, _fill);
      expect((chip.border as Border?)?.top.color, _border);
    });

    testWidgets('merges textStyle onto the ambient DefaultTextStyle', (tester) async {
      await tester.pumpWidget(
        _app(
          extension: const AITheme(
            suggestionsTheme: SuggestionsThemeData(textStyle: TextStyle(fontWeight: FontWeight.bold)),
          ),
          child: AISuggestionsView(suggestions: const ['Tell me a joke'], onSuggestionSelected: (_) {}),
        ),
      );

      final text = tester.widget<Text>(find.text('Tell me a joke'));
      expect(text.style?.fontWeight, FontWeight.bold, reason: 'the theme weight applies');
      expect(
        text.style?.color,
        ThemeData().colorScheme.onSurface,
        reason: 'a partial override keeps the derived color',
      );
    });

    testWidgets('keeps the derived color through an inherit: false textStyle', (tester) async {
      await tester.pumpWidget(
        _app(
          extension: const AITheme(
            suggestionsTheme: SuggestionsThemeData(textStyle: TextStyle(inherit: false, fontWeight: FontWeight.bold)),
          ),
          child: AISuggestionsView(suggestions: const ['Tell me a joke'], onSuggestionSelected: (_) {}),
        ),
      );

      final text = tester.widget<Text>(find.text('Tell me a joke'));
      expect(text.style?.fontWeight, FontWeight.bold);
      expect(text.style?.color, ThemeData().colorScheme.onSurface);
    });

    testWidgets('resizes the chips to a larger textStyle rather than overflowing', (tester) async {
      Future<double> chipWidth(TextStyle? style) async {
        await tester.pumpWidget(
          _app(
            extension: AITheme(suggestionsTheme: SuggestionsThemeData(textStyle: style)),
            child: AISuggestionsView(suggestions: const ['Hi'], onSuggestionSelected: (_) {}),
          ),
        );
        // MaterialApp animates between themes; let it land on the new one.
        await tester.pumpAndSettle();
        return tester.getSize(find.ancestor(of: find.text('Hi'), matching: find.byType(InkWell)).first).width;
      }

      final normal = await chipWidth(null);
      final large = await chipWidth(const TextStyle(fontSize: 30));

      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(large, greaterThan(normal));
    });

    testWidgets('leaves the appearance alone when nothing is registered', (tester) async {
      await tester.pumpWidget(
        _app(
          child: AISuggestionsView(suggestions: const ['Tell me a joke'], onSuggestionSelected: (_) {}),
        ),
      );

      final scheme = ThemeData().colorScheme;
      final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      expect(
        boxes.map((b) => b.decoration).whereType<BoxDecoration>().any((d) => d.color == scheme.surfaceContainerHigh),
        isTrue,
      );
    });
  });
}
