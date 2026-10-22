import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

const _icons = StreamIcons();

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

/// The leading "+" button's surface: the Material its [StreamButton] paints.
Material _leadingButton(WidgetTester tester) =>
    tester.widget<Material>(find.ancestor(of: find.byIcon(_icons.plus), matching: find.byType(Material)).first);

Color? _borderColor(BoxDecoration decoration) => (decoration.border as Border?)?.top.color;

Color? _buttonBorderColor(Material material) => (material.shape as OutlinedBorder?)?.side.color;

/// The color [icon] is drawn in: its own, or the [IconTheme] a [StreamButton]
/// sets around it.
Color? _iconColor(WidgetTester tester, IconData icon) {
  final finder = find.byIcon(icon);
  return tester.widget<Icon>(finder).color ?? IconTheme.of(tester.element(finder)).color;
}

bool _hasBoxWithColor(WidgetTester tester, Finder scope, Color color) {
  final boxes = tester.widgetList<DecoratedBox>(
    find.descendant(of: scope, matching: find.byType(DecoratedBox), matchRoot: true),
  );
  return boxes.any((box) {
    final decoration = box.decoration;
    return decoration is BoxDecoration && decoration.color == color;
  });
}

bool _hasActionButtonWithFill(WidgetTester tester, Color color) {
  // The send/stop/mic circle is a StreamButton, which paints its fill on a
  // Material — so scan the action buttons' Materials for it.
  final found = tester.widgetList<Material>(
    find.descendant(of: find.byType(ComposerActionButton), matching: find.byType(Material)),
  );
  return found.any((material) => material.color == color);
}

/// Opens the real attachment sheet from the "+" button.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byIcon(_icons.plus));
  // Not `pumpAndSettle` — the sheet's photo section spins a
  // StreamLoadingSpinner while its (unmocked) permission check is in
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
      expect(_buttonBorderColor(_leadingButton(tester)), _border, reason: 'the leading "+" takes the same border');
      expect(_iconColor(tester, _icons.plus), _icon, reason: 'an enabled "+" takes iconColor');
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

      expect(_hasActionButtonWithFill(tester, _send), isTrue, reason: 'send takes sendButtonColor');

      controller.isGenerating = true;
      await tester.pumpAndSettle();

      expect(_hasActionButtonWithFill(tester, _stop), isTrue, reason: 'stop takes stopButtonColor');
      expect(
        _hasActionButtonWithFill(tester, _send),
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

      expect(_iconColor(tester, _icons.arrowUp), _actionForeground);
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

      expect(_iconColor(tester, Icons.star), own);
      expect(
        _iconColor(tester, Icons.favorite),
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

      final addIcon = _iconColor(tester, _icons.plus);
      // Not set on the theme, so it derives from the *resolved* iconColor — a
      // host setting only `iconColor` gets a matching disabled shade for free.
      expect(addIcon, _icon.withValues(alpha: 0.3));
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

      final addIcon = _iconColor(tester, _icons.plus);
      // Scaled, not replaced: a disabled shade never more opaque than the
      // enabled one.
      expect(addIcon, translucent.withValues(alpha: translucent.a * 0.3));
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

      expect(_iconColor(tester, _icons.plus), disabled);
    });

    group('hintStyle', () {
      InputDecoration hint(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).decoration!;
      final derived = StreamTheme.light().colorScheme.textSecondary.withValues(alpha: 0.6);

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
      testWidgets('draw the placeholder and its glyph from the theme', (tester) async {
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

        final broken = find.byIcon(_icons.image);
        expect(broken, findsOneWidget);
        expect(tester.widget<Icon>(broken).color, glyph, reason: 'the error glyph takes the placeholder foreground');
        expect(
          tester.widget<ColoredBox>(find.ancestor(of: broken, matching: find.byType(ColoredBox)).first).color,
          placeholder,
        );
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

        // The quieter textSecondary, as before theming.
        expect(
          tester.widget<Icon>(find.byIcon(_icons.image)).color,
          StreamTheme.light().colorScheme.textSecondary,
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

        final camera = find.byIcon(_icons.camera);
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
          StreamTheme.light().colorScheme.textPrimary,
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

        expect(tester.widget<Icon>(find.byIcon(_icons.camera)).color, _icon.withValues(alpha: 0.3));
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

      final scheme = StreamTheme.light().colorScheme;
      expect(_pill(tester).color, const Color(0x00000000), reason: 'outlined, not filled');
      expect(_borderColor(_pill(tester)), scheme.borderDefault);
      expect(_leadingButton(tester).color, const Color(0x00000000));
      expect(_iconColor(tester, _icons.plus), scheme.textPrimary);
      expect(
        _hasActionButtonWithFill(tester, scheme.accentPrimary),
        isTrue,
        reason: 'send falls back to accentPrimary',
      );
      expect(_iconColor(tester, _icons.arrowUp), scheme.textOnAccent);

      controller.isGenerating = true;
      await tester.pumpAndSettle();
      expect(_hasActionButtonWithFill(tester, scheme.accentError), isTrue, reason: 'stop falls back to accentError');
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
        StreamTheme.light().colorScheme.textPrimary,
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
      expect(text.style?.color, StreamTheme.light().colorScheme.textPrimary);
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

      final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      expect(
        boxes
            .map((b) => b.decoration)
            .whereType<BoxDecoration>()
            .any((d) => d.color == const Color(0x00000000) && d.border != null),
        isTrue,
      );
    });
  });
}
