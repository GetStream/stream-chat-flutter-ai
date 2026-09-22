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

/// The fill of the first [DecoratedBox] whose decoration is a [BoxDecoration]
/// carrying [color], searched under [scope].
bool _hasBoxWithColor(WidgetTester tester, Finder scope, Color color) {
  final boxes = tester.widgetList<DecoratedBox>(
    find.descendant(of: scope, matching: find.byType(DecoratedBox), matchRoot: true),
  );
  return boxes.any((box) {
    final decoration = box.decoration;
    return decoration is BoxDecoration && decoration.color == color;
  });
}

bool _hasContainerWithColor(WidgetTester tester, Color color) {
  final containers = tester.widgetList<Container>(find.byType(Container));
  return containers.any((c) {
    final decoration = c.decoration;
    return decoration is BoxDecoration && decoration.color == color;
  });
}

bool _hasAnimatedContainerWithColor(WidgetTester tester, Color color) {
  // The send/stop/mic circle is an AnimatedContainer, whose *rendered*
  // decoration lives on the state rather than the widget, so read it back
  // through the element tree instead of the widget's own `decoration`.
  final found = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
  return found.any((box) {
    final decoration = box.decoration;
    return decoration is BoxDecoration && decoration.color == color && decoration.shape == BoxShape.circle;
  });
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

      expect(_hasBoxWithColor(tester, find.byType(ChatComposer), _fill), isTrue, reason: 'the input pill takes fill');
      expect(_hasContainerWithColor(tester, _fill), isTrue, reason: 'the leading "+" button takes the same fill');
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

      expect(_hasBoxWithColor(tester, find.byType(ChatComposer), _fill), isTrue);
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

      expect(_hasAnimatedContainerWithColor(tester, _send), isTrue, reason: 'send takes sendButtonColor');

      controller.isGenerating = true;
      await tester.pumpAndSettle();

      expect(_hasAnimatedContainerWithColor(tester, _stop), isTrue, reason: 'stop takes stopButtonColor');
      expect(
        _hasAnimatedContainerWithColor(tester, _send),
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

    testWidgets('leaves the appearance alone when nothing is registered', (tester) async {
      final controller = ChatComposerController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          child: ChatComposer(controller: controller, onSendPressed: (_, _, _) {}),
        ),
      );

      final scheme = ThemeData().colorScheme;
      expect(
        _hasBoxWithColor(tester, find.byType(ChatComposer), scheme.surfaceContainerHigh),
        isTrue,
        reason: 'the untouched default is still ColorScheme.surfaceContainerHigh',
      );
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
      expect(text.style?.color, isNotNull, reason: 'a partial override keeps the derived color');
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
