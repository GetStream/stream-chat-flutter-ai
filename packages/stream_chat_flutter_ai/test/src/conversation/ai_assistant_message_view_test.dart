import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

Widget _view(String text, {required bool isGenerating}) => MaterialApp(
  home: Scaffold(
    body: AIAssistantMessageView(text: text, isGenerating: isGenerating),
  ),
);

/// Advances the clock far enough for the typewriter to reveal the answer.
///
/// Not `pumpAndSettle`, which stops at the first frame with nothing scheduled
/// and so doesn't wait for the typewriter's timer.
Future<void> _typeOut(WidgetTester tester) => tester.pump(const Duration(seconds: 1));

class _Reply with AIMessage {
  _Reply(this.text, {required this.isGenerating});

  @override
  String get id => 'r1';
  @override
  AIMessageRole get role => AIMessageRole.assistant;
  @override
  final String text;
  @override
  final bool isGenerating;
  @override
  List<AIMessagePart> get parts => [AIMessagePart(id: 'step', kind: AIMessagePartKind.reasoning)];
  @override
  List<AIMessageAttachment> get attachments => const [];
}

void main() {
  group('AIAssistantMessageView', () {
    testWidgets('shows a reply from history at once', (tester) async {
      await tester.pumpWidget(_view('An earlier answer.', isGenerating: false));

      expect(find.text('An earlier answer.'), findsOneWidget);
    });

    testWidgets('types a generating answer from its first character', (tester) async {
      await tester.pumpWidget(_view('', isGenerating: true));
      await tester.pumpWidget(_view('Hello, world!', isGenerating: true));

      expect(find.text('Hello, world!'), findsNothing);
      await _typeOut(tester);
      expect(find.text('Hello, world!'), findsOneWidget);
    });

    testWidgets('types an answer that arrives whole with the end of generation', (tester) async {
      // The answer is kept writing for a moment after `isGenerating` turns
      // false, so one that arrives complete in its last update still types.
      const answer = 'The whole answer, in one update.';
      await tester.pumpWidget(_view('', isGenerating: true));
      await tester.pumpWidget(_view(answer, isGenerating: false));

      await tester.pump(const Duration(milliseconds: 25));
      expect(find.text(answer), findsNothing);
      expect(find.text('The w'), findsOneWidget);

      await _typeOut(tester);
      expect(find.text(answer), findsOneWidget);
    });

    testWidgets('types the last chunk that arrives with the end of generation', (tester) async {
      const answer = 'Hello, world! And the rest of it.';
      await tester.pumpWidget(_view('Hello, world!', isGenerating: true));
      await _typeOut(tester);

      await tester.pumpWidget(_view(answer, isGenerating: false));
      await tester.pump(const Duration(milliseconds: 25));
      expect(find.text(answer), findsNothing);

      await _typeOut(tester);
      expect(find.text(answer), findsOneWidget);
    });

    testWidgets('shows a change at once once the answer is done', (tester) async {
      await tester.pumpWidget(_view('Hello', isGenerating: true));
      await tester.pumpWidget(_view('Hello', isGenerating: false));
      await _typeOut(tester);

      await tester.pumpWidget(_view('Hello, edited.', isGenerating: false));
      expect(find.text('Hello, edited.'), findsOneWidget);
    });

    testWidgets('in a conversation, types an answer that arrives whole after a step', (tester) async {
      // A reply showing only a step is on screen before its answer, so the
      // answer arriving with the end of generation still types out.
      const answer = 'The whole answer, in one update.';
      Widget conversation(_Reply reply) => MaterialApp(
        home: Scaffold(body: AIConversationView(messages: [reply])),
      );

      await tester.pumpWidget(conversation(_Reply('', isGenerating: true)));
      await tester.pumpWidget(conversation(_Reply(answer, isGenerating: false)));

      await tester.pump(const Duration(milliseconds: 25));
      expect(find.textContaining(answer, findRichText: true), findsNothing);

      await _typeOut(tester);
      expect(find.textContaining(answer, findRichText: true), findsOneWidget);
    });

    testWidgets('in a conversation, keeps the reply actions after an edit once done', (tester) async {
      Widget conversation(_Reply reply) => StreamComponentFactory(
        builders: StreamComponentBuilders(
          extensions: streamAIComponentBuilders(replyActions: (context, props) => const Text('actions')),
        ),
        child: MaterialApp(
          home: Scaffold(body: AIConversationView(messages: [reply])),
        ),
      );

      await tester.pumpWidget(conversation(_Reply('Hello', isGenerating: true)));
      await tester.pumpWidget(conversation(_Reply('Hello', isGenerating: false)));
      await _typeOut(tester);
      await tester.pump();
      expect(find.text('actions'), findsOneWidget);

      await tester.pumpWidget(conversation(_Reply('Hello, edited.', isGenerating: false)));
      await _typeOut(tester);
      await tester.pump();
      expect(find.text('actions'), findsOneWidget);
    });

    testWidgets('shows a generating answer at once with reduced motion', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(_view('', isGenerating: true));
      await tester.pumpWidget(_view('Hello, world!', isGenerating: false));

      expect(find.text('Hello, world!'), findsOneWidget);
      await _typeOut(tester);
    });

    testWidgets('opens a web link in the answer in the browser', (tester) async {
      final launcher = _useLauncher();
      await tester.pumpWidget(_view('See [the docs](https://x.io/docs).', isGenerating: false));

      await tester.tapOnText(find.textRange.ofSubstring('the docs'));
      await tester.pump();

      expect(launcher.launched, [('https://x.io/docs', PreferredLaunchMode.externalApplication)]);
    });

    testWidgets('opens any other link in the answer with the platform default', (tester) async {
      final launcher = _useLauncher();
      await tester.pumpWidget(_view('Write to [us](mailto:hi@x.io).', isGenerating: false));

      await tester.tapOnText(find.textRange.ofSubstring('us'));
      await tester.pump();

      expect(launcher.launched, [('mailto:hi@x.io', PreferredLaunchMode.platformDefault)]);
    });

    testWidgets('opens nothing for a link without a scheme', (tester) async {
      final launcher = _useLauncher();
      await tester.pumpWidget(_view('See [the docs](docs/setup.md).', isGenerating: false));

      await tester.tapOnText(find.textRange.ofSubstring('the docs'));
      await tester.pump();

      expect(launcher.launched, isEmpty);
    });

    testWidgets('reports a link that fails to open', (tester) async {
      _useLauncher(throws: true);
      await tester.pumpWidget(_view('See [the docs](https://x.io/docs).', isGenerating: false));

      await tester.tapOnText(find.textRange.ofSubstring('the docs'));
      await tester.pump();

      expect(tester.takeException(), isA<PlatformException>());
    });

    testWidgets('reports a link that no app can open', (tester) async {
      _useLauncher(opens: false);
      final issues = <String>[];
      debugPartIssueReporter = issues.add;
      addTearDown(() => debugPartIssueReporter = null);
      await tester.pumpWidget(_view('Call [us](tel:+15550100).', isGenerating: false));

      await tester.tapOnText(find.textRange.ofSubstring('us'));
      await tester.pump();

      expect(issues, ['stream_chat_flutter_ai: No app could open the link to tel:+15550100.']);
    });

    testWidgets('hands a tapped link to onTapLink instead of opening it', (tester) async {
      final launcher = _useLauncher();
      final taps = <(String, String?)>[];
      const step = AIReasoningPart(id: 'step', preview: 'Read [the guide](https://x.io/guide).', durationMs: 2000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AIAssistantMessageView(
              text: 'See [the docs](https://x.io/docs).',
              parts: [AIMessagePart.fromReasoning(step)],
              onTapLink: (text, href, title) => taps.add((text, href)),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Thought for 2s'));
      await tester.pumpAndSettle();

      await tester.tapOnText(find.textRange.ofSubstring('the docs'));
      await tester.tapOnText(find.textRange.ofSubstring('the guide'));
      await tester.pump();

      expect(taps, [('the docs', 'https://x.io/docs'), ('the guide', 'https://x.io/guide')]);
      expect(launcher.launched, isEmpty);
    });

    testWidgets('gives a custom reasoning builder the link opener', (tester) async {
      final launcher = _useLauncher();
      const step = AIReasoningPart(id: 'step', preview: 'Read [the guide](https://x.io/guide).');
      await tester.pumpWidget(
        StreamComponentFactory(
          builders: StreamComponentBuilders(
            extensions: streamAIComponentBuilders(
              reasoning: (context, props) => GestureDetector(
                onTap: () => props.onTapLink?.call('the guide', 'https://x.io/guide', ''),
                child: const Text('Custom reasoning'),
              ),
            ),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: AIAssistantMessageView(text: 'Done.', parts: [AIMessagePart.fromReasoning(step)]),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Custom reasoning'));
      await tester.pump();

      expect(launcher.launched, [('https://x.io/guide', PreferredLaunchMode.externalApplication)]);
    });

    testWidgets('opens a link in the reasoning', (tester) async {
      final launcher = _useLauncher();
      const step = AIReasoningPart(id: 'step', preview: 'Checked [the docs](https://x.io/docs).', durationMs: 2000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AIAssistantMessageView(text: 'Done.', parts: [AIMessagePart.fromReasoning(step)]),
          ),
        ),
      );
      await tester.tap(find.text('Thought for 2s'));
      await tester.pumpAndSettle();

      await tester.tapOnText(find.textRange.ofSubstring('the docs'));
      await tester.pump();

      expect(launcher.launched, [('https://x.io/docs', PreferredLaunchMode.externalApplication)]);
    });

    testWidgets('opens a link in reasoning that is still being written', (tester) async {
      final launcher = _useLauncher();
      const step = AIReasoningPart(
        id: 'step',
        status: AIReasoningStatus.streaming,
        preview: 'Checking [the docs](https://x.io/docs).',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: AIAssistantMessageView(text: '', isGenerating: true, parts: [AIMessagePart.fromReasoning(step)]),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tapOnText(find.textRange.ofSubstring('the docs'));
      await tester.pump();

      expect(launcher.launched, [('https://x.io/docs', PreferredLaunchMode.externalApplication)]);
    });
  });
}

_FakeUrlLauncher _useLauncher({bool throws = false, bool opens = true}) {
  final launcher = _FakeUrlLauncher(throws: throws, opens: opens);
  final previous = UrlLauncherPlatform.instance;
  UrlLauncherPlatform.instance = launcher;
  addTearDown(() => UrlLauncherPlatform.instance = previous);
  return launcher;
}

final class _FakeUrlLauncher extends Fake with MockPlatformInterfaceMixin implements UrlLauncherPlatform {
  _FakeUrlLauncher({required this.throws, required this.opens});

  final bool throws;
  final bool opens;
  final launched = <(String, PreferredLaunchMode)>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add((url, options.mode));
    if (throws) throw PlatformException(code: 'x');
    return opens;
  }
}
