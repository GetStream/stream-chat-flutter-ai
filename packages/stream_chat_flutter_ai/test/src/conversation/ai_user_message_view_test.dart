import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  group('AIUserMessageView context menu', () {
    testWidgets('copies the message', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(_wrap(const AIUserMessageView(text: 'Hello')));

      await tester.longPress(find.text('Hello'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(copied, 'Hello');
      expect(find.byType(StreamContextMenu), findsNothing);
    });

    testWidgets('offers Edit only with onEdit, and calls it', (tester) async {
      var edited = 0;
      await tester.pumpWidget(_wrap(AIUserMessageView(text: 'Hello', onEdit: () => edited++)));

      await tester.longPress(find.text('Hello'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(edited, 1);
    });

    testWidgets('takes the theme set around the message, not just the app', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Theme(
            data: ThemeData(brightness: Brightness.dark, extensions: [StreamTheme.dark()]),
            child: const AIUserMessageView(text: 'Hello'),
          ),
        ),
      );

      await tester.longPress(find.text('Hello'));
      await tester.pumpAndSettle();

      expect(Theme.of(tester.element(find.byType(StreamContextMenu))).brightness, Brightness.dark);
    });

    testWidgets('opens towards the start of a right-to-left message', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Directionality(
            textDirection: TextDirection.rtl,
            child: AIUserMessageView(text: 'Hello'),
          ),
        ),
      );
      final press = tester.getCenter(find.text('Hello'));

      await tester.longPressAt(press);
      await tester.pumpAndSettle();

      expect(Directionality.of(tester.element(find.byType(StreamContextMenu))), TextDirection.rtl);
      expect(tester.getRect(find.byType(StreamContextMenu)).right, lessThanOrEqualTo(press.dx));
    });
  });
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topRight,
      child: SizedBox(width: 360, child: child),
    ),
  ),
);
