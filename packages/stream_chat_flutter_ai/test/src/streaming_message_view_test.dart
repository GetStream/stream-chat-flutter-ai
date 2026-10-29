import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/code_block_view.dart';
import 'package:stream_chat_flutter_ai/src/streaming_message_view.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/code_block_theme.dart';
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

        Widget build(String text) => MaterialApp(
          home: Scaffold(
            body: StreamingMessageView(text: text, typingSpeed: typingSpeed, expectMoreText: true),
          ),
        );

        await tester.pumpWidget(build(testText));
        await tester.pump(typingSpeed * testText.length);
        expect(find.text(testText), findsOneWidget);

        const updatedText = 'Hello, world! How are you?';
        await tester.pumpWidget(build(updatedText));
        await tester.pump(typingSpeed * 4);
        expect(find.text('Hello, world! How'), findsOneWidget);

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

    testWidgets('types the first text of a generating reply from its first character', (tester) async {
      // A view created by the first chunk of a reply used to show that chunk
      // at once and type only what followed it.
      const typingSpeed = Duration(milliseconds: 10);
      final states = <TypewriterState>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingMessageView(
              text: 'Hello, world!',
              typingSpeed: typingSpeed,
              expectMoreText: true,
              onTypewriterStateChanged: states.add,
            ),
          ),
        ),
      );

      expect(find.text('Hello, world!'), findsNothing);
      await tester.pump(typingSpeed * 5);
      expect(find.text('Hello'), findsOneWidget);
      expect(states.toSet(), {TypewriterState.typing});

      await tester.pump(typingSpeed * 10);
      expect(find.text('Hello, world!'), findsOneWidget);
      expect(states.last, TypewriterState.idle);
    });

    testWidgets('types 5 ms per character by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StreamingMessageView(text: 'abcdefghij', expectMoreText: true)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 25));
      expect(find.text('abcde'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 25));
      expect(find.text('abcdefghij'), findsOneWidget);
    });

    group('expectMoreText', () {
      const typingSpeed = Duration(milliseconds: 10);

      Widget build(String text, {required bool expectMoreText, List<TypewriterState>? states}) => MaterialApp(
        home: Scaffold(
          body: StreamingMessageView(
            text: text,
            typingSpeed: typingSpeed,
            expectMoreText: expectMoreText,
            onTypewriterStateChanged: states?.add,
          ),
        ),
      );

      testWidgets('shows a change at once when not generating', (tester) async {
        final states = <TypewriterState>[];
        await tester.pumpWidget(build('Hello', expectMoreText: false, states: states));
        await tester.pumpWidget(build('Hello, world!', expectMoreText: false, states: states));

        expect(find.text('Hello, world!'), findsOneWidget);
        await tester.pump();
        expect(states, isNot(contains(TypewriterState.typing)));
      });

      testWidgets('types the text that arrives with the end of generation', (tester) async {
        await tester.pumpWidget(build('', expectMoreText: true));
        await tester.pumpWidget(build('Hello, world!', expectMoreText: false));

        await tester.pump(typingSpeed * 5);
        expect(find.text('Hello'), findsOneWidget);

        await tester.pump(typingSpeed * 10);
        expect(find.text('Hello, world!'), findsOneWidget);
      });

      testWidgets('keeps typing what is left after generation ends', (tester) async {
        await tester.pumpWidget(build('Hello, world!', expectMoreText: true));
        await tester.pump(typingSpeed * 5);
        await tester.pumpWidget(build('Hello, world!', expectMoreText: false));

        expect(find.text('Hello'), findsOneWidget);
        await tester.pump(typingSpeed * 10);
        expect(find.text('Hello, world!'), findsOneWidget);
      });

      testWidgets('shows a change after generation ended at once', (tester) async {
        await tester.pumpWidget(build('Hello', expectMoreText: true));
        await tester.pumpWidget(build('Hello', expectMoreText: false));
        await tester.pump(typingSpeed * 10);

        await tester.pumpWidget(build('Hello, edited.', expectMoreText: false));
        expect(find.text('Hello, edited.'), findsOneWidget);
      });
    });

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

    group('onFinished', () {
      const typingSpeed = Duration(milliseconds: 10);

      Widget build(String text, {required bool expectMoreText, required VoidCallback onFinished}) => MaterialApp(
        home: Scaffold(
          body: StreamingMessageView(
            text: text,
            typingSpeed: typingSpeed,
            expectMoreText: expectMoreText,
            onFinished: onFinished,
          ),
        ),
      );

      testWidgets('waits for the typewriter after generation ends', (WidgetTester tester) async {
        var finished = 0;
        void onFinished() => finished++;
        const reply = 'Hello, world! How are you today?';

        await tester.pumpWidget(build('', expectMoreText: true, onFinished: onFinished));
        await tester.pumpWidget(build('Hello', expectMoreText: true, onFinished: onFinished));

        // Caught up mid-stream: the typewriter is idle, but more text may come.
        await tester.pump(typingSpeed * 10);
        expect(finished, 0);

        // The backend finishes well before the typewriter does.
        await tester.pumpWidget(build(reply, expectMoreText: false, onFinished: onFinished));
        await tester.pump(typingSpeed * 5);
        expect(find.text(reply), findsNothing);
        expect(finished, 0);

        await tester.pump(typingSpeed * reply.length);
        await tester.pump();
        expect(find.text(reply), findsOneWidget);
        expect(finished, 1);

        // Rebuilding a finished reply doesn't report it again.
        await tester.pumpWidget(build(reply, expectMoreText: false, onFinished: onFinished));
        await tester.pump();
        expect(finished, 1);
      });

      testWidgets('fires when generation ends after the typewriter has caught up', (WidgetTester tester) async {
        var finished = 0;
        var lastState = TypewriterState.typing;
        void onFinished() => finished++;
        const reply = 'The whole reply.';

        Widget buildTracked(String text, {required bool expectMoreText}) => MaterialApp(
          home: Scaffold(
            body: StreamingMessageView(
              text: text,
              typingSpeed: typingSpeed,
              expectMoreText: expectMoreText,
              onFinished: onFinished,
              onTypewriterStateChanged: (state) => lastState = state,
            ),
          ),
        );

        await tester.pumpWidget(buildTracked('', expectMoreText: true));
        await tester.pumpWidget(buildTracked(reply, expectMoreText: true));
        expect(lastState, TypewriterState.typing);
        await tester.pump(typingSpeed * (reply.length + 5));
        await tester.pump();

        // Every character is on screen and the typewriter has gone idle, but
        // the backend hasn't said it's done yet.
        expect(find.text(reply), findsOneWidget);
        expect(lastState, TypewriterState.idle);
        expect(finished, 0);

        // The done signal arrives with no new text, so the typewriter emits no
        // further state change.
        await tester.pumpWidget(buildTracked(reply, expectMoreText: false));
        await tester.pump();
        expect(lastState, TypewriterState.idle);
        expect(finished, 1);
      });

      testWidgets('does not report an empty placeholder', (WidgetTester tester) async {
        var finished = 0;
        void onFinished() => finished++;
        const reply = 'The real reply.';

        // An AI placeholder is created empty, before the backend marks it as
        // generating, so it briefly looks like a complete message.
        await tester.pumpWidget(build('', expectMoreText: false, onFinished: onFinished));
        await tester.pump();
        expect(finished, 0);

        await tester.pumpWidget(build('The', expectMoreText: true, onFinished: onFinished));
        await tester.pumpWidget(build(reply, expectMoreText: false, onFinished: onFinished));
        await tester.pump(typingSpeed * (reply.length + 5));
        await tester.pump();
        expect(finished, 1);
      });

      testWidgets('does not report a reply that finished before the callback was passed', (
        WidgetTester tester,
      ) async {
        var finished = 0;
        void onFinished() => finished++;

        Widget buildOptional(String text, {required bool expectMoreText, VoidCallback? onFinished}) => MaterialApp(
          home: Scaffold(
            body: StreamingMessageView(
              text: text,
              typingSpeed: typingSpeed,
              expectMoreText: expectMoreText,
              onFinished: onFinished,
            ),
          ),
        );

        await tester.pumpWidget(buildOptional('An earlier reply.', expectMoreText: false));
        await tester.pump();

        // The callback arrives later, e.g. once this becomes the latest reply.
        await tester.pumpWidget(buildOptional('An earlier reply.', expectMoreText: false, onFinished: onFinished));
        await tester.pump();
        expect(finished, 0);

        // A new reply into the same view is still reported.
        await tester.pumpWidget(buildOptional('An earlier reply.', expectMoreText: true, onFinished: onFinished));
        await tester.pumpWidget(
          buildOptional('An earlier reply. And more.', expectMoreText: false, onFinished: onFinished),
        );
        await tester.pump(typingSpeed * 20);
        await tester.pump();
        expect(finished, 1);
      });

      testWidgets('reports a complete message after its first frame', (WidgetTester tester) async {
        var finished = 0;

        // `pumpWidget` runs the first frame, post-frame callbacks included.
        await tester.pumpWidget(build('A reply from history.', expectMoreText: false, onFinished: () => finished++));
        expect(finished, 1);

        await tester.pump(const Duration(seconds: 1));
        expect(finished, 1);
      });

      testWidgets('reports again after the reply is regenerated', (WidgetTester tester) async {
        var finished = 0;
        void onFinished() => finished++;

        await tester.pumpWidget(build('First reply.', expectMoreText: false, onFinished: onFinished));
        await tester.pump();
        expect(finished, 1);

        await tester.pumpWidget(build('First reply.', expectMoreText: true, onFinished: onFinished));
        await tester.pumpWidget(build('First reply. Second.', expectMoreText: false, onFinished: onFinished));
        await tester.pump(typingSpeed * 20);
        await tester.pump();
        expect(finished, 2);
      });
    });

    testWidgets(
      'renders a code block while its fence is still streaming',
      (WidgetTester tester) async {
        // Regression test: the markdown used to be pre-split on a regex that
        // required the *closing* fence, so a code block still being typed out
        // showed its raw ``` markers and unstyled source for the whole time it
        // was arriving, then snapped into a CodeBlockView once complete.
        const typingSpeed = Duration(milliseconds: 10);
        const full =
            'Here you go:\n\n'
            '```dart\n'
            'void main() {\n'
            '  for (var i = 0; i < 10; i++) {\n'
            '    print(i);\n'
            '  }\n'
            '}\n'
            '```';

        Widget build(String text) => MaterialApp(
          home: Scaffold(
            body: StreamingMessageView(text: text, typingSpeed: typingSpeed, expectMoreText: true),
          ),
        );

        await tester.pumpWidget(build('Here you go:'));
        await tester.pump(typingSpeed * 12);
        await tester.pumpWidget(build(full));

        // Enough ticks to clear the opening fence and reveal part of the body,
        // but well short of the closing fence.
        await tester.pump(typingSpeed * 30);

        expect(find.byType(CodeBlockView), findsOneWidget);
        expect(find.textContaining('```'), findsNothing);
        // The language is known from the opening fence alone.
        expect(find.text('dart'), findsOneWidget);

        // Still mid-stream: the tail of the body has not arrived yet.
        expect(find.textContaining('print(i)'), findsNothing);
      },
    );

    testWidgets(
      'forwards codeHighlighter to the fences it renders',
      (WidgetTester tester) async {
        // Without the forwarding, `codeHighlighter` is unreachable for the main
        // use case: fences are built by `AIMarkdownBody`'s private fence
        // builder, so a host never constructs the `CodeBlockView` itself.
        const typingSpeed = Duration(milliseconds: 10);
        const text = '```dart\nvar x = 1;\n```';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StreamingMessageView(
                text: text,
                typingSpeed: typingSpeed,
                codeHighlighter: _plainSpan,
                codeBlockTheme: CodeBlockThemeData(backgroundColor: Color(0xFF102030)),
              ),
            ),
          ),
        );
        await tester.pump(typingSpeed * text.length);

        final fence = tester.widget<CodeBlockView>(find.byType(CodeBlockView));
        expect(fence.highlighter, same(_plainSpan));
        expect(fence.theme?.backgroundColor, const Color(0xFF102030));
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

    group('reduced motion', () {
      void reduceMotion(WidgetTester tester) {
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
          disableAnimations: true,
        );
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      }

      Widget view(String text, List<TypewriterState> states) => MaterialApp(
        home: Scaffold(
          body: StreamingMessageView(
            text: text,
            typingSpeed: const Duration(milliseconds: 20),
            expectMoreText: true,
            onTypewriterStateChanged: states.add,
          ),
        ),
      );

      testWidgets('shows each new text in full at once and reports idle', (tester) async {
        reduceMotion(tester);
        final states = <TypewriterState>[];

        await tester.pumpWidget(view('Hello', states));
        await tester.pumpWidget(view('Hello, world!', states));

        // One frame, not 13 × 20ms of typing.
        expect(find.text('Hello, world!'), findsOneWidget);
        expect(states, isNot(contains(TypewriterState.typing)));
        expect(states.last, TypewriterState.idle);

        // A replacement, not a continuation, is shown in full just the same.
        await tester.pumpWidget(view('Bye.', states));
        expect(find.text('Bye.'), findsOneWidget);
        expect(states, isNot(contains(TypewriterState.typing)));

        // Nothing left running: no typewriter timer.
        await tester.pumpAndSettle();
      });

      testWidgets("shows a generating reply's first text at once", (tester) async {
        reduceMotion(tester);
        final states = <TypewriterState>[];

        await tester.pumpWidget(view('Hello, world!', states));

        expect(find.text('Hello, world!'), findsOneWidget);
        await tester.pump();
        expect(states, [TypewriterState.idle]);
        await tester.pumpAndSettle();
      });

      testWidgets('switching it back off types the next update normally', (tester) async {
        reduceMotion(tester);
        final states = <TypewriterState>[];
        await tester.pumpWidget(view('Hello', states));

        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        await tester.pump();
        await tester.pumpWidget(view('Hello, world!', states));
        await tester.pump(const Duration(milliseconds: 60));

        expect(find.text('Hello, world!'), findsNothing, reason: 'typing again');
        expect(states.last, TypewriterState.typing);
        await tester.pumpAndSettle();
        expect(find.text('Hello, world!'), findsOneWidget);
      });

      testWidgets('switching it on mid-reveal shows the rest at once', (tester) async {
        final states = <TypewriterState>[];

        await tester.pumpWidget(view('', states));
        await tester.pumpWidget(view('Hello, world!', states));
        await tester.pump(const Duration(milliseconds: 60));
        expect(find.text('Hello, world!'), findsNothing, reason: 'still typing');
        expect(states.last, TypewriterState.typing);

        reduceMotion(tester);
        await tester.pump();

        expect(find.text('Hello, world!'), findsOneWidget);
        expect(states.last, TypewriterState.idle);
      });
    });

    group('a host calling setState from onTypewriterStateChanged', () {
      /// Pumps a host that stores every reported state with `setState`, the
      /// way a host flips its "generating" flag.
      Future<_HostState> pumpHost(WidgetTester tester, String text) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: _Host(text: text)),
          ),
        );
        return tester.state<_HostState>(find.byType(_Host));
      }

      void reduceMotion(WidgetTester tester) {
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
          disableAnimations: true,
        );
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      }

      testWidgets('does not throw on an update in normal mode', (tester) async {
        await pumpHost(tester, '');
        final host = await pumpHost(tester, 'Bye.');
        await tester.pump();

        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(host.states.last, TypewriterState.idle);
        expect(host.states, contains(TypewriterState.typing));
      });

      testWidgets('does not throw on an update under reduced motion', (tester) async {
        reduceMotion(tester);
        await pumpHost(tester, 'Hello');
        final host = await pumpHost(tester, 'Hello, world!');
        expect(tester.takeException(), isNull);

        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(host.states.last, TypewriterState.idle, reason: 'reported after the frame');
        expect(find.text('Hello, world!'), findsOneWidget);
      });

      testWidgets('does not throw when reduced motion switches on mid-reveal', (tester) async {
        await pumpHost(tester, '');
        final host = await pumpHost(tester, 'Hello, world!');
        await tester.pump(const Duration(milliseconds: 30));
        expect(host.states.last, TypewriterState.typing);

        reduceMotion(tester);
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(host.states.last, TypewriterState.idle);
        expect(find.text('Hello, world!'), findsOneWidget);
      });
    });
  });
}

/// A minimal [CodeHighlighter]: one span, text intact.
TextSpan _plainSpan(CodeHighlightRequest request) => TextSpan(text: request.code, style: request.baseStyle);

class _Host extends StatefulWidget {
  const _Host({required this.text});

  final String text;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final states = <TypewriterState>[];

  @override
  Widget build(BuildContext context) => StreamingMessageView(
    text: widget.text,
    expectMoreText: true,
    onTypewriterStateChanged: (state) => setState(() => states.add(state)),
  );
}
