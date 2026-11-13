import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
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

      expect(launcher.launched, ['https://x.io/docs']);
      expect(launcher.modes, [PreferredLaunchMode.externalApplication]);
    });

    testWidgets('opens any other link in the answer with the platform default', (tester) async {
      final launcher = _useLauncher();
      await tester.pumpWidget(_view('Write to [us](mailto:hi@x.io).', isGenerating: false));

      await tester.tapOnText(find.textRange.ofSubstring('us'));
      await tester.pump();

      expect(launcher.launched, ['mailto:hi@x.io']);
      expect(launcher.modes, [PreferredLaunchMode.platformDefault]);
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

      // The reasoning's own tests tap its links through their recognizer too.
      final paragraph = tester.widget<RichText>(find.text('Checked the docs.', findRichText: true));
      (_linkIn(paragraph.text)!.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();

      expect(launcher.launched, ['https://x.io/docs']);
    });
  });
}

_FakeUrlLauncher _useLauncher({bool throws = false}) {
  final launcher = _FakeUrlLauncher(throws: throws);
  final previous = UrlLauncherPlatform.instance;
  UrlLauncherPlatform.instance = launcher;
  addTearDown(() => UrlLauncherPlatform.instance = previous);
  return launcher;
}

final class _FakeUrlLauncher extends Fake with MockPlatformInterfaceMixin implements UrlLauncherPlatform {
  _FakeUrlLauncher({required this.throws});

  final bool throws;
  final launched = <String>[];
  final modes = <PreferredLaunchMode>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    modes.add(options.mode);
    if (throws) throw PlatformException(code: 'x');
    return true;
  }
}

// The span of the link in [span]. Not `visitChildren`, which skips spans
// without text of their own, as a link's is in its children.
TextSpan? _linkIn(InlineSpan span) {
  if (span is! TextSpan) return null;
  if (span.recognizer != null) return span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (_linkIn(child) case final link?) return link;
  }
  return null;
}
