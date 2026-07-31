import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/streaming_message_view.dart';
import 'package:stream_chat_flutter_ai/src/typewriter_builder.dart';

void main() {
  group('StreamingMessageView Tests', () {
    testWidgets(
      'displays initial text',
      (WidgetTester tester) async {
        const testText = 'Hello, world!';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StreamingMessageView(text: testText),
            ),
          ),
        );

        expect(find.text(testText), findsOneWidget);
      },
    );

    testWidgets(
      'updates text progressively like a typewriter',
      (WidgetTester tester) async {
        const testText = 'Hello, world!';
        const typingSpeed = Duration(milliseconds: 20);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StreamingMessageView(
                text: testText,
                typingSpeed: typingSpeed,
              ),
            ),
          ),
        );

        expect(find.text(testText), findsOneWidget);

        const updatedText = 'Hello, world! How are you?';
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StreamingMessageView(
                text: updatedText,
                typingSpeed: typingSpeed,
              ),
            ),
          ),
        );

        await tester.pump(typingSpeed * updatedText.length);

        expect(find.text(updatedText), findsOneWidget);
      },
    );

    testWidgets(
      'replaces the text when the new message is shorter',
      (WidgetTester tester) async {
        // Regression test: a replaced message (regenerate, edit, or an error
        // swapped in for a partial reply) that is shorter than what is already
        // on screen used to leave the previous text displayed indefinitely.
        Widget build(String text) => MaterialApp(
          home: Scaffold(body: StreamingMessageView(text: text)),
        );

        await tester.pumpWidget(build('Hello, world! This is a long reply.'));
        await tester.pumpWidget(build('Bye.'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.textContaining('Hello, world!'), findsNothing);
        expect(find.text('Bye.'), findsOneWidget);
      },
    );

    testWidgets(
      'reports the initial typewriter state to onTypewriterStateChanged',
      (WidgetTester tester) async {
        // Regression test: a view built with its complete text is already fully
        // revealed, so the controller never transitioned and this callback never
        // fired — leaving hosts that flip a "generating" flag off on `idle`
        // stuck in the generating state forever.
        final states = <TypewriterState>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamingMessageView(
                text: 'A complete reply.',
                onTypewriterStateChanged: states.add,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(states, contains(TypewriterState.idle));
      },
    );

    testWidgets(
      'handles links correctly',
      (WidgetTester tester) async {
        const testText = '[Click me](https://example.com)';
        const typingSpeed = Duration(milliseconds: 20);
        String? tappedLink;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamingMessageView(
                text: testText,
                typingSpeed: typingSpeed,
                onTapLink: (String link, String? href, String title) {
                  tappedLink = href;
                },
              ),
            ),
          ),
        );

        await tester.pump(typingSpeed * testText.length);

        final linkFinder = find.text('Click me');
        expect(linkFinder, findsOneWidget);
        await tester.tap(linkFinder);

        expect(tappedLink, equals('https://example.com'));
      },
    );
  });
}
