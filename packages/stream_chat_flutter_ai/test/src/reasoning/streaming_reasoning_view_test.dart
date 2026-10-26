import 'package:alchemist/alchemist.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 360, child: child),
    ),
  ),
);

/// Turns on the platform's reduced-motion setting for the rest of the test.
void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

final _view = find.byType(StreamingReasoningView);

Finder _inView(Finder finder) => find.descendant(of: _view, matching: finder);

/// The header's chevron — a spot on the header to tap.
final _chevron = _inView(find.byIcon(Icons.chevron_right));

/// The reasoning's scroll position. Only valid while the panel is mounted.
ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(_inView(find.byType(Scrollable))).position;

/// The paragraph widgets the panel has built, by their text.
Map<String, Text> _builtParagraphs(WidgetTester tester) => {
  for (final text in tester.widgetList<Text>(
    find.descendant(of: _inView(find.byType(Scrollable)), matching: find.byType(Text)),
  ))
    text.textSpan!.toPlainText(): text,
};

/// The 2pt rule beside the view.
Color? _ruleColor(WidgetTester tester) {
  final rule = tester
      .widgetList<DecoratedBox>(_inView(find.byType(DecoratedBox)))
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .singleWhere((decoration) => decoration.borderRadius == BorderRadius.circular(1));
  return rule.color;
}

const _maxHeight120 = ReasoningThemeData(maxExpandedHeight: 120);

String _paragraphs(int count, {String prefix = 'Paragraph'}) =>
    [for (var i = 0; i < count; i++) '$prefix $i: weighing the options carefully before answering.'].join('\n\n');

void main() {
  group('StreamingReasoningView', () {
    group('header', () {
      testWidgets('counts the seconds while thinking, in tabular figures', (tester) async {
        await tester.pumpWidget(_wrap(const StreamingReasoningView(text: 'Hmm', isThinking: true)));

        expect(find.text('Thinking…'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Thinking… 1s'), findsOneWidget);

        await tester.pump(const Duration(seconds: 6));
        expect(find.text('Thinking… 7s'), findsOneWidget);

        final style = tester.widget<Text>(find.text('Thinking… 7s')).style!;
        expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      });

      testWidgets('counts on from a given duration', (tester) async {
        Widget build(Duration duration) =>
            _wrap(StreamingReasoningView(text: 'Hmm', isThinking: true, duration: duration));

        await tester.pumpWidget(build(const Duration(seconds: 5)));
        expect(find.text('Thinking… 5s'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Thinking… 6s'), findsOneWidget);

        // The host moving the count on resets it, and it carries on from there.
        await tester.pumpWidget(build(const Duration(seconds: 20)));
        expect(find.text('Thinking… 20s'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Thinking… 21s'), findsOneWidget);
      });

      testWidgets('counts afresh when a finished view starts thinking again', (tester) async {
        Widget build({required bool thinking, Duration? duration}) =>
            _wrap(StreamingReasoningView(text: 'Hmm', isThinking: thinking, duration: duration));

        await tester.pumpWidget(build(thinking: false, duration: const Duration(seconds: 12)));
        expect(find.text('Thought for 12s'), findsOneWidget);

        await tester.pumpWidget(build(thinking: true));
        expect(find.text('Thinking…'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Thinking… 2s'), findsOneWidget);

        await tester.pumpWidget(build(thinking: false));
        expect(find.text('Thought for 2s'), findsOneWidget, reason: 'measured, not the stale 12s');
        await tester.pumpAndSettle();
      });

      testWidgets('reads "Thought for" the measured time when no duration is given', (tester) async {
        Widget build({required bool thinking}) => _wrap(StreamingReasoningView(text: 'Hmm', isThinking: thinking));

        await tester.pumpWidget(build(thinking: true));
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(build(thinking: false));

        expect(find.text('Thought for 3s'), findsOneWidget);
        await tester.pumpAndSettle();
      });

      testWidgets('reads "Thought for" the given duration, in minutes from a minute on', (tester) async {
        await tester.pumpWidget(
          _wrap(const StreamingReasoningView(text: 'Hmm', isThinking: false, duration: Duration(seconds: 75))),
        );
        expect(find.text('Thought for 1m 15s'), findsOneWidget);

        await tester.pumpWidget(
          _wrap(const StreamingReasoningView(text: 'Hmm', isThinking: false, duration: Duration(milliseconds: 200))),
        );
        expect(find.text('Thought for 1s'), findsOneWidget, reason: 'never "0s"');
      });

      testWidgets('reads "Thought process" when how long is unknown', (tester) async {
        await tester.pumpWidget(_wrap(const StreamingReasoningView(text: 'Hmm', isThinking: false)));
        expect(find.text('Thought process'), findsOneWidget);
      });

      testWidgets('uses the ambient translations', (tester) async {
        await tester.pumpWidget(
          _wrap(
            const AITranslationsScope(
              translations: _DutchTranslations(),
              child: StreamingReasoningView(text: 'Hmm', isThinking: false, duration: Duration(seconds: 4)),
            ),
          ),
        );
        expect(find.text('4s nagedacht'), findsOneWidget);
      });

      testWidgets('shows the summary only while the finished reasoning is folded', (tester) async {
        Widget build({required bool thinking}) => _wrap(
          StreamingReasoningView(text: 'Hmm', isThinking: thinking, summary: 'Compared both plans'),
        );
        _reduceMotion(tester);

        await tester.pumpWidget(build(thinking: true));
        expect(find.textContaining('Compared both plans'), findsNothing, reason: 'not while thinking');

        await tester.pumpWidget(build(thinking: false));
        await tester.pumpAndSettle();
        expect(find.textContaining('Compared both plans'), findsOneWidget, reason: 'folded once done');

        await tester.tap(_chevron);
        await tester.pumpAndSettle();
        expect(find.textContaining('Compared both plans'), findsNothing, reason: 'not while open');
      });

      testWidgets('ellipsizes a long title at a large text scale instead of overflowing', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(3)),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 160,
                    child: StreamingReasoningView(
                      text: 'Hmm',
                      isThinking: false,
                      duration: Duration(seconds: 754),
                      summary: 'A summary far too long for the line',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(tester.getSize(_view).width, lessThanOrEqualTo(160));
      });

      testWidgets('turns the chevron the other way in right-to-left text', (tester) async {
        await tester.pumpWidget(
          _wrap(
            const Directionality(
              textDirection: TextDirection.rtl,
              child: StreamingReasoningView(text: 'Hmm', isThinking: false),
            ),
          ),
        );
        await tester.tap(_chevron);
        await tester.pumpAndSettle();
        expect(tester.widget<RotationTransition>(_inView(find.byType(RotationTransition))).turns.value, -0.25);
      });

      testWidgets('turns the chevron a quarter while open', (tester) async {
        await tester.pumpWidget(_wrap(const StreamingReasoningView(text: 'Hmm', isThinking: false)));
        final rotation = tester.widget<RotationTransition>(_inView(find.byType(RotationTransition)));
        expect(rotation.turns.value, 0);

        await tester.tap(_chevron);
        await tester.pumpAndSettle();
        expect(rotation.turns.value, 0.25);
      });
    });

    group('opening and folding', () {
      testWidgets('opens while thinking and folds once done', (tester) async {
        Widget build({required bool thinking}) =>
            _wrap(StreamingReasoningView(text: 'Weighing the options', isThinking: thinking));

        await tester.pumpWidget(build(thinking: true));
        final folded = tester.getSize(_view).height;
        // The unfold, then the rest of the reveal.
        await tester.pump(StreamingReasoningView.foldDuration);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Weighing the options'), findsOneWidget);
        final open = tester.getSize(_view).height;
        expect(open, greaterThan(folded), reason: 'live reasoning unfolds rather than appears');

        await tester.pumpWidget(build(thinking: false));
        await tester.pump(StreamingReasoningView.foldDuration ~/ 2);
        final midway = tester.getSize(_view).height;
        expect(midway, lessThan(open), reason: 'the fold animates the height');
        expect(midway, greaterThan(folded));

        await tester.pumpAndSettle();
        expect(find.text('Weighing the options'), findsNothing, reason: 'folded away entirely');
        expect(tester.getSize(_view).height, folded);
      });

      testWidgets('stays folded while thinking without showsLiveReasoning', (tester) async {
        await tester.pumpWidget(
          _wrap(const StreamingReasoningView(text: 'Weighing', isThinking: true, showsLiveReasoning: false)),
        );
        await tester.pump(StreamingReasoningView.foldDuration);
        expect(find.text('Weighing'), findsNothing);
      });

      testWidgets('opens once done with expandedWhenDone', (tester) async {
        await tester.pumpWidget(
          _wrap(const StreamingReasoningView(text: 'Weighing', isThinking: false, expandedWhenDone: true)),
        );
        expect(find.text('Weighing'), findsOneWidget);
      });

      testWidgets('tapping the header toggles it', (tester) async {
        await tester.pumpWidget(_wrap(const StreamingReasoningView(text: 'Weighing', isThinking: false)));
        expect(find.text('Weighing'), findsNothing);

        await tester.tap(_chevron);
        await tester.pumpAndSettle();
        expect(find.text('Weighing'), findsOneWidget);

        await tester.tap(find.text('Thought process'));
        await tester.pumpAndSettle();
        expect(find.text('Weighing'), findsNothing);
      });

      testWidgets('turning reduced motion on while thinking stops the shimmer', (tester) async {
        await tester.pumpWidget(_wrap(const StreamingReasoningView(text: 'Weighing', isThinking: true)));
        await tester.pump(const Duration(milliseconds: 300));
        _reduceMotion(tester);
        await tester.pump();
        // Only the once-a-second header count is left; nothing animates frame to frame.
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('a reader who folded the live reasoning keeps it folded', (tester) async {
        Widget build({required bool thinking}) => _wrap(StreamingReasoningView(text: 'Weighing', isThinking: thinking));
        _reduceMotion(tester);

        await tester.pumpWidget(build(thinking: true));
        await tester.tap(_chevron);
        await tester.pump();
        expect(find.text('Weighing'), findsNothing);

        await tester.pumpWidget(build(thinking: false));
        await tester.pumpWidget(build(thinking: true));
        await tester.pump();
        expect(find.text('Weighing'), findsNothing, reason: 'a new round of thinking does not reopen it');
      });

      testWidgets('a reader who opened the reasoning keeps it open once done', (tester) async {
        Widget build({required bool thinking}) => _wrap(StreamingReasoningView(text: 'Weighing', isThinking: thinking));
        _reduceMotion(tester);

        await tester.pumpWidget(build(thinking: true));
        // Fold, then open again: an explicit choice to read along.
        await tester.tap(_chevron);
        await tester.pump();
        await tester.tap(_chevron);
        await tester.pump();

        await tester.pumpWidget(build(thinking: false));
        await tester.pumpAndSettle();
        expect(find.text('Weighing'), findsOneWidget, reason: 'the choice wins over folding');
      });

      testWidgets('reports changes, deferring the automatic ones past the frame', (tester) async {
        final reports = <bool>[];
        final phases = <SchedulerPhase>[];
        var hostBuilds = 0;
        Widget build({required bool thinking}) => _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              hostBuilds++;
              return StreamingReasoningView(
                text: 'Weighing',
                isThinking: thinking,
                // A host rebuilding from the callback must not throw.
                onExpandedChanged: (expanded) {
                  phases.add(SchedulerBinding.instance.schedulerPhase);
                  setState(() => reports.add(expanded));
                },
              );
            },
          ),
        );
        _reduceMotion(tester);

        await tester.pumpWidget(build(thinking: true));
        await tester.pumpWidget(build(thinking: false));
        expect(reports, [false]);
        expect(phases, [SchedulerPhase.postFrameCallbacks], reason: 'not mid-build');
        expect(tester.takeException(), isNull);

        await tester.tap(_chevron);
        expect(reports, [false, true]);
        expect(phases.last, isNot(SchedulerPhase.persistentCallbacks), reason: 'a tap reports at once');
        await tester.pump();
        expect(hostBuilds, greaterThan(2));
      });
    });

    group('footnote', () {
      Widget build({required bool thinking, bool expandedWhenDone = false}) => _wrap(
        StreamingReasoningView(
          text: 'Weighing',
          isThinking: thinking,
          footnote: 'Reasoning is kept for 30 days',
          expandedWhenDone: expandedWhenDone,
        ),
      );

      testWidgets('shows only when the reader opened the finished reasoning', (tester) async {
        _reduceMotion(tester);

        await tester.pumpWidget(build(thinking: true));
        expect(find.text('Weighing'), findsOneWidget);
        expect(find.text('Reasoning is kept for 30 days'), findsNothing, reason: 'not while thinking');

        await tester.pumpWidget(build(thinking: false));
        await tester.pump();
        expect(find.text('Reasoning is kept for 30 days'), findsNothing);

        await tester.tap(_chevron);
        await tester.pump();
        expect(find.text('Reasoning is kept for 30 days'), findsOneWidget);
      });

      testWidgets('shows with expandedWhenDone', (tester) async {
        await tester.pumpWidget(build(thinking: false, expandedWhenDone: true));
        expect(find.text('Reasoning is kept for 30 days'), findsOneWidget);
      });
    });

    group('panel', () {
      testWidgets('grows up to maxExpandedHeight, then scrolls with a fading top', (tester) async {
        _reduceMotion(tester);
        await tester.pumpWidget(_wrap(const StreamingReasoningView(text: 'Short', isThinking: true)));
        await tester.pump();

        final short = tester.getSize(_inView(find.byType(Scrollable))).height;
        expect(short, lessThan(100));
        expect(_position(tester).maxScrollExtent, 0);

        await tester.pumpWidget(
          _wrap(StreamingReasoningView(text: _paragraphs(40), isThinking: true, theme: _maxHeight120)),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(_inView(find.byType(Scrollable))).height, 120);
        expect(_position(tester).maxScrollExtent, greaterThan(0));

        final fade = tester.widget<ShaderMask>(_inView(find.byType(ShaderMask)));
        final shader = fade.shaderCallback(const Rect.fromLTWH(0, 0, 100, 100));
        expect(shader, isNotNull);
      });

      testWidgets('follows the newest text unless the reader scrolled up', (tester) async {
        _reduceMotion(tester);
        Widget build(String text) => _wrap(StreamingReasoningView(text: text, isThinking: true, theme: _maxHeight120));

        var text = _paragraphs(30);
        await tester.pumpWidget(build(text));
        await tester.pumpAndSettle();
        expect(_position(tester).pixels, _position(tester).maxScrollExtent, reason: 'live reasoning opens at its end');

        text += '\n\nAnother thought arrives.';
        await tester.pumpWidget(build(text));
        await tester.pumpAndSettle();
        expect(_position(tester).pixels, _position(tester).maxScrollExtent, reason: 'and keeps following');

        // The reader scrolls up to re-read.
        await tester.drag(_inView(find.byType(Scrollable)), const Offset(0, 200));
        await tester.pumpAndSettle();
        final reading = _position(tester).pixels;
        expect(reading, lessThan(_position(tester).maxScrollExtent - 24));

        text += '\n\nYet another thought.';
        await tester.pumpWidget(build(text));
        await tester.pumpAndSettle();
        expect(_position(tester).pixels, reading, reason: 'stays where the reader is');

        // Back to the end: following resumes.
        await tester.drag(_inView(find.byType(Scrollable)), const Offset(0, -5000));
        await tester.pumpAndSettle();
        text += '\n\nA final thought.';
        await tester.pumpWidget(build(text));
        await tester.pumpAndSettle();
        expect(_position(tester).pixels, _position(tester).maxScrollExtent);
        expect(find.text('A final thought.'), findsOneWidget);
      });

      testWidgets('reveals new text a little at a time while thinking', (tester) async {
        Widget build(String text) => _wrap(StreamingReasoningView(text: text, isThinking: true));
        await tester.pumpWidget(build('Start'));
        await tester.pump(StreamingReasoningView.foldDuration);

        final arrived = 'Start ${'and then some more words ' * 10}'.trim();
        await tester.pumpWidget(build(arrived));
        await tester.pump(const Duration(milliseconds: 40));
        final partial = _builtParagraphs(tester).keys.single;
        expect(partial.length, greaterThan('Start'.length));
        expect(partial.length, lessThan(arrived.length), reason: 'revealed over several ticks');
        expect(arrived, startsWith(partial));

        await tester.pump(const Duration(seconds: 2));
        expect(_builtParagraphs(tester).keys.single, arrived);
      });

      testWidgets('reveals the rest quickly, not at once, once thinking stops', (tester) async {
        Widget build(String text, {required bool thinking}) =>
            _wrap(StreamingReasoningView(text: text, isThinking: thinking, expandedWhenDone: true));
        await tester.pumpWidget(build('Start', thinking: true));
        await tester.pump(StreamingReasoningView.foldDuration);

        final arrived = 'Start ${'word ' * 400}'.trim();
        await tester.pumpWidget(build(arrived, thinking: true));
        await tester.pump(const Duration(milliseconds: 40));
        await tester.pumpWidget(build(arrived, thinking: false));
        await tester.pump(const Duration(milliseconds: 40));
        final catchingUp = _builtParagraphs(tester).keys.single;
        expect(catchingUp.length, lessThan(arrived.length), reason: 'still revealing after thinking ends');

        // A sixth per tick would need ~30 ticks for this backlog; half needs ~10.
        await tester.pump(const Duration(milliseconds: 400));
        expect(_builtParagraphs(tester).keys.single, arrived);
      });

      testWidgets('shows the rest at once with reduced motion', (tester) async {
        _reduceMotion(tester);
        Widget build(String text, {required bool thinking}) =>
            _wrap(StreamingReasoningView(text: text, isThinking: thinking, expandedWhenDone: true));
        await tester.pumpWidget(build('Start', thinking: true));
        final arrived = 'Start ${'word ' * 400}'.trim();
        await tester.pumpWidget(build(arrived, thinking: true));
        await tester.pumpWidget(build(arrived, thinking: false));
        expect(_builtParagraphs(tester).keys.single, arrived);
      });

      testWidgets('live reasoning that starts empty unfolds and reveals its first text', (tester) async {
        Widget build(String text) => _wrap(StreamingReasoningView(text: text, isThinking: true));
        await tester.pumpWidget(build(''));
        await tester.pump(const Duration(seconds: 1));
        final empty = tester.getSize(_view).height;

        const first = 'The first thoughts arrive, a whole sentence of them at once.';
        await tester.pumpWidget(build(first));
        await tester.pump(const Duration(milliseconds: 40));
        final early = tester.getSize(_view).height;
        expect(_builtParagraphs(tester).keys.single.length, lessThan(first.length), reason: 'revealed, not shown');

        await tester.pump(StreamingReasoningView.foldDuration);
        await tester.pump(const Duration(seconds: 2));
        final open = tester.getSize(_view).height;
        expect(early, lessThan(open), reason: 'unfolds rather than appearing at full height');
        expect(early, greaterThanOrEqualTo(empty));
        expect(_builtParagraphs(tester).keys.single, first);
      });

      testWidgets('reduced motion switched on mid-reveal shows the rest', (tester) async {
        Widget build(String text) => _wrap(StreamingReasoningView(text: text, isThinking: true));
        await tester.pumpWidget(build('Start'));
        await tester.pump(StreamingReasoningView.foldDuration);
        final arrived = 'Start ${'word ' * 200}'.trim();
        await tester.pumpWidget(build(arrived));
        await tester.pump(const Duration(milliseconds: 40));
        expect(_builtParagraphs(tester).keys.single, isNot(arrived));

        _reduceMotion(tester);
        await tester.pump();
        expect(_builtParagraphs(tester).keys.single, arrived);
      });

      testWidgets('reduced motion switched on mid-fold finishes the fold', (tester) async {
        await tester.pumpWidget(
          _wrap(const StreamingReasoningView(text: 'Weighing', isThinking: false, expandedWhenDone: true)),
        );
        await tester.tap(_chevron);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Weighing'), findsOneWidget, reason: 'still folding');

        _reduceMotion(tester);
        await tester.pump();
        expect(find.text('Weighing'), findsNothing);
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('sits inside IntrinsicWidth and IntrinsicHeight', (tester) async {
        for (final wrap in <Widget Function(Widget)>[
          (child) => IntrinsicWidth(child: child),
          (child) => IntrinsicHeight(child: child),
        ]) {
          await tester.pumpWidget(
            _wrap(
              wrap(StreamingReasoningView(text: _paragraphs(5), isThinking: false, expandedWhenDone: true)),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.textContaining('Paragraph 0'), findsOneWidget);
        }
      });

      testWidgets('a new trace is followed even after the reader scrolled up', (tester) async {
        _reduceMotion(tester);
        Widget build(String text) => _wrap(StreamingReasoningView(text: text, isThinking: true, theme: _maxHeight120));

        await tester.pumpWidget(build(_paragraphs(30)));
        await tester.pumpAndSettle();
        await tester.drag(_inView(find.byType(Scrollable)), const Offset(0, 200));
        await tester.pumpAndSettle();

        await tester.pumpWidget(build(_paragraphs(30, prefix: 'Other')));
        await tester.pumpAndSettle();
        expect(_position(tester).pixels, _position(tester).maxScrollExtent);
      });

      testWidgets('renders inline markdown and reports link taps', (tester) async {
        final taps = <String?>[];
        await tester.pumpWidget(
          _wrap(
            StreamingReasoningView(
              text: '## Plan\n**Bold**, *italic*, `code` and [docs](https://example.com).',
              isThinking: false,
              expandedWhenDone: true,
              onTapLink: (text, href, title) => taps.add(href),
            ),
          ),
        );

        final paragraph = _builtParagraphs(tester).values.single;
        expect(paragraph.textSpan!.toPlainText(), 'Plan\nBold, italic, code and docs.');

        // Every span, styled wrappers included — visitChildren only visits the
        // ones carrying text.
        final spans = <TextSpan>[];
        void collect(InlineSpan span) {
          if (span is! TextSpan) return;
          spans.add(span);
          span.children?.forEach(collect);
        }

        collect(paragraph.textSpan!);
        TextSpan styled(String text) => spans.firstWhere((s) => s.style != null && s.toPlainText() == text);

        expect(styled('Plan').style!.fontWeight, FontWeight.w600, reason: 'a heading reads as bold');
        expect(styled('Bold').style!.fontWeight, FontWeight.w600);
        expect(styled('italic').style!.fontStyle, FontStyle.italic);
        expect(styled('code').style!.fontFamily, 'monospace');
        final link = styled('docs');
        expect(link.style!.decoration, TextDecoration.underline);

        (link.recognizer! as TapGestureRecognizer).onTap!();
        expect(taps, ['https://example.com']);
      });

      testWidgets('links become tappable once onTapLink is set, and always call the latest', (tester) async {
        final taps = <String>[];
        Widget build(MarkdownTapLinkCallback? onTapLink) => _wrap(
          StreamingReasoningView(
            text: 'See [docs](https://example.com).',
            isThinking: false,
            expandedWhenDone: true,
            onTapLink: onTapLink,
          ),
        );
        TextSpan link() => (_builtParagraphs(tester).values.single.textSpan! as TextSpan).children!
            .whereType<TextSpan>()
            .singleWhere((span) => span.toPlainText() == 'docs');

        await tester.pumpWidget(build(null));
        expect(link().recognizer, isNull);

        await tester.pumpWidget(build((text, href, title) => taps.add('first $href')));
        expect(link().recognizer, isNotNull);
        final paragraph = _builtParagraphs(tester).values.single;

        // A fresh closure each build: the paragraph isn't rebuilt, yet a tap
        // reaches the newest callback.
        await tester.pumpWidget(build((text, href, title) => taps.add('second $href')));
        expect(identical(_builtParagraphs(tester).values.single, paragraph), isTrue);
        (link().recognizer! as TapGestureRecognizer).onTap!();
        expect(taps, ['second https://example.com']);
      });

      testWidgets('a long stream only rebuilds the paragraph being written', (tester) async {
        _reduceMotion(tester);
        // ~40 KB in 200 paragraphs, delivered in 1 KB chunks.
        final full = [
          for (var i = 0; i < 200; i++) 'Thought $i: ${'considering the trade-offs of each approach ' * 5}'.trim(),
        ].join('\n\n');
        expect(full.length, greaterThan(40000));

        Widget build(String text) => _wrap(StreamingReasoningView(text: text, isThinking: true));
        var delivered = 0;
        var previous = <String, Text>{};
        while (delivered < full.length) {
          delivered = (delivered + 1024).clamp(0, full.length);
          final text = full.substring(0, delivered);
          await tester.pumpWidget(build(text));
          await tester.pumpAndSettle();

          final built = _builtParagraphs(tester);
          expect(built.length, lessThan(40), reason: 'paragraphs are built lazily, not all 200 of them');

          // Every paragraph that was already finished and is still built is
          // the very same widget: it was not built again.
          final last = built.keys.last;
          for (final MapEntry(key: paragraph, value: widget) in built.entries) {
            if (paragraph == last) continue;
            if (previous[paragraph] case final before?) {
              expect(identical(before, widget), isTrue, reason: 'a finished paragraph was rebuilt');
            }
          }
          previous = built;
        }

        expect(find.textContaining('Thought 199'), findsOneWidget, reason: 'followed to the end');
      });
    });

    group('accessibility', () {
      testWidgets('the header is one button with a label and a hint', (tester) async {
        final handle = tester.ensureSemantics();
        _reduceMotion(tester);
        await tester.pumpWidget(
          _wrap(
            const StreamingReasoningView(
              text: 'Weighing the options',
              isThinking: false,
              duration: Duration(seconds: 12),
              summary: 'Compared both plans',
            ),
          ),
        );

        expect(
          tester.getSemantics(find.bySemanticsLabel('Thought for 12s. Compared both plans')),
          isSemantics(
            isButton: true,
            hasTapAction: true,
            hasExpandedState: true,
            isExpanded: false,
            hint: "Shows the model's reasoning",
          ),
        );
        expect(find.bySemanticsLabel('Weighing the options'), findsNothing, reason: 'folded content is hidden');

        await tester.tap(_chevron);
        await tester.pump();
        expect(
          tester.getSemantics(find.bySemanticsLabel('Thought for 12s')),
          isSemantics(isButton: true, isExpanded: true, hint: "Hides the model's reasoning"),
        );
        expect(find.bySemanticsLabel('Weighing the options'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('folding content leaves the semantics tree at once', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(const StreamingReasoningView(text: 'Weighing', isThinking: false, expandedWhenDone: true)),
        );
        expect(find.bySemanticsLabel('Weighing'), findsOneWidget);

        await tester.tap(_chevron);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('Weighing'), findsOneWidget, reason: 'still folding');
        expect(find.semantics.byLabel('Weighing'), findsNothing);
        await tester.pumpAndSettle();
        handle.dispose();
      });

      testWidgets('reduced motion: no shimmer, pulse or fold animation, and text appears at once', (tester) async {
        _reduceMotion(tester);
        Widget build(String text, {required bool thinking}) =>
            _wrap(StreamingReasoningView(text: text, isThinking: thinking));

        await tester.pumpWidget(build('Weighing', thinking: true));
        expect(find.text('Weighing'), findsOneWidget, reason: 'open at once');
        expect(tester.hasRunningAnimations, isFalse);
        expect(_inView(find.byType(ShaderMask)), findsOneWidget, reason: "only the panel's fade, no shimmer");
        expect(
          find.descendant(of: _view, matching: find.byType(Opacity)),
          findsNothing,
          reason: 'no pulse',
        );

        await tester.pumpWidget(build('Weighing ${'more ' * 50}'.trim(), thinking: true));
        expect(find.text('Weighing ${'more ' * 50}'.trim()), findsOneWidget, reason: 'no reveal');
        expect(tester.hasRunningAnimations, isFalse);

        await tester.pumpWidget(build('Weighing', thinking: false));
        expect(find.text('Weighing'), findsNothing, reason: 'folded at once');
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('shimmers and pulses while thinking with motion on', (tester) async {
        await tester.pumpWidget(_wrap(const StreamingReasoningView(text: 'Weighing', isThinking: true)));
        await tester.pump(StreamingReasoningView.foldDuration);
        expect(_inView(find.byType(ShaderMask)), findsNWidgets(2));
        expect(tester.hasRunningAnimations, isTrue);

        await tester.pumpWidget(_wrap(const StreamingReasoningView(text: 'Weighing', isThinking: false)));
        await tester.pumpAndSettle();
        expect(tester.hasRunningAnimations, isFalse, reason: 'everything stops once done');
      });
    });

    group('theme', () {
      testWidgets('defaults derive from the ambient theme', (tester) async {
        final theme = ThemeData();
        _reduceMotion(tester);
        await tester.pumpWidget(_wrap(const StreamingReasoningView(text: 'Weighing', isThinking: true), theme: theme));

        expect(_ruleColor(tester), theme.colorScheme.primary, reason: 'the shimmer color while thinking');
        final text = tester.widget<Text>(find.text('Weighing'));
        expect(text.style!.color, theme.colorScheme.onSurfaceVariant);

        await tester.pumpWidget(_wrap(const StreamingReasoningView(text: 'Weighing', isThinking: false), theme: theme));
        expect(_ruleColor(tester), theme.colorScheme.outlineVariant, reason: 'the rule color once done');
      });

      testWidgets('resolves widget > ReasoningTheme > AITheme > defaults', (tester) async {
        _reduceMotion(tester);
        final theme = ThemeData(
          extensions: const [
            AITheme(
              reasoningTheme: ReasoningThemeData(
                ruleColor: Color(0xFF0000A1),
                textStyle: TextStyle(fontSize: 30, color: Color(0xFF0000B1)),
                maxExpandedHeight: 80,
              ),
            ),
          ],
        );

        Future<void> pump({ReasoningThemeData? scope, ReasoningThemeData? local, double? maxHeight}) async {
          Widget child = StreamingReasoningView(
            text: _paragraphs(20),
            isThinking: false,
            expandedWhenDone: true,
            theme: maxHeight == null
                ? local
                : (local ?? const ReasoningThemeData()).copyWith(maxExpandedHeight: maxHeight),
          );
          if (scope != null) child = ReasoningTheme(data: scope, child: child);
          await tester.pumpWidget(_wrap(child, theme: theme));
        }

        await pump();
        expect(_ruleColor(tester), const Color(0xFF0000A1), reason: 'AITheme over the defaults');
        expect(tester.getSize(_inView(find.byType(Scrollable))).height, 80);
        expect(_builtParagraphs(tester).values.first.style!.fontSize, 30);

        await pump(scope: const ReasoningThemeData(ruleColor: Color(0xFF0000A2)));
        expect(_ruleColor(tester), const Color(0xFF0000A2), reason: 'the scope over AITheme');

        await pump(
          scope: const ReasoningThemeData(ruleColor: Color(0xFF0000A2)),
          local: const ReasoningThemeData(ruleColor: Color(0xFF0000A3), textStyle: TextStyle(fontSize: 12)),
          maxHeight: 60,
        );
        expect(_ruleColor(tester), const Color(0xFF0000A3), reason: 'the widget over the scope');
        expect(tester.getSize(_inView(find.byType(Scrollable))).height, 60);
        final style = _builtParagraphs(tester).values.first.style!;
        expect(style.fontSize, 12);
        expect(style.color, const Color(0xFF0000B1), reason: "the widget's style merges over the themed one");
      });

      testWidgets('a foreground paint stands in for a style color', (tester) async {
        final theme = ThemeData();
        final paint = Paint()..color = const Color(0xFF00A000);
        for (final (data, label) in [
          (ReasoningThemeData(titleStyle: TextStyle(foreground: paint)), 'titleStyle'),
          (ReasoningThemeData(textStyle: TextStyle(foreground: paint)), 'textStyle'),
          (ReasoningThemeData(footnoteStyle: TextStyle(foreground: paint)), 'footnoteStyle'),
        ]) {
          for (final isThinking in [true, false]) {
            await tester.pumpWidget(
              _wrap(
                StreamingReasoningView(
                  text: 'Weighing',
                  isThinking: isThinking,
                  summary: 'Compared both plans',
                  footnote: 'Model: test',
                  expandedWhenDone: true,
                  theme: data,
                ),
                theme: theme,
              ),
            );
            await tester.pump(StreamingReasoningView.foldDuration);
            expect(tester.takeException(), isNull, reason: '$label, isThinking: $isThinking');
          }
        }

        await tester.pumpWidget(
          _wrap(
            StreamingReasoningView(
              text: 'Weighing',
              isThinking: false,
              theme: ReasoningThemeData(titleStyle: TextStyle(foreground: paint)),
            ),
            theme: theme,
          ),
        );
        expect(
          tester.widget<Icon>(_chevron).color,
          isSameColorAs(const Color(0xFF00A000)),
          reason: "the icons take the title's paint color",
        );

        await tester.pumpWidget(
          _wrap(
            StreamingReasoningView(
              text: 'Weighing',
              isThinking: false,
              expandedWhenDone: true,
              theme: ReasoningThemeData(textStyle: TextStyle(foreground: paint)),
            ),
            theme: theme,
          ),
        );
        await tester.pump(StreamingReasoningView.foldDuration);
        final style = _builtParagraphs(tester).values.first.style!;
        expect(style.foreground, same(paint), reason: 'the paint is kept');
        expect(style.color, isNull, reason: 'no color is added beside the paint');
      });
    });

    group('part', () {
      testWidgets('reads status, duration and summary, and falls back to the preview, then the summary', (
        tester,
      ) async {
        const part = AIReasoningPart(
          id: 'r1',
          summary: 'Compared both plans',
          preview: 'The user wants…',
          durationMs: 2400,
        );
        final view = StreamingReasoningView.part(part);
        expect(view.isThinking, isFalse);
        expect(view.duration, const Duration(milliseconds: 2400));
        expect(view.summary, 'Compared both plans');
        expect(view.text, 'The user wants…');

        expect(StreamingReasoningView.part(part, text: 'Full reasoning').text, 'Full reasoning');
        expect(
          StreamingReasoningView.part(const AIReasoningPart(id: 'r', summary: 'S')).text,
          'S',
          reason: 'the summary, with no preview: the header shows it only while folded',
        );
        expect(StreamingReasoningView.part(const AIReasoningPart(id: 'r')).text, '');
      });

      testWidgets('a step with only a summary opens to it', (tester) async {
        _reduceMotion(tester);
        await tester.pumpWidget(
          _wrap(
            StreamingReasoningView.part(
              const AIReasoningPart(id: 'r', summary: 'Compared both plans', durationMs: 2400),
            ),
          ),
        );
        expect(_inView(find.byType(Scrollable)), findsNothing, reason: 'folded');

        await tester.tap(_chevron);
        await tester.pump();
        expect(_builtParagraphs(tester).keys, ['Compared both plans'], reason: 'the panel shows the summary');
        expect(
          StreamingReasoningView.part(const AIReasoningPart(id: 'r', status: AIReasoningStatus.streaming)).isThinking,
          isTrue,
        );
      });
    });

    group('goldens', () {
      Widget scenario(ThemeData theme, Widget child) => Theme(
        data: theme,
        child: Builder(
          builder: (context) => MediaQuery(
            // Deterministic: no shimmer, no reveal, no fold in flight.
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: ColoredBox(
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(width: 340, child: child),
              ),
            ),
          ),
        ),
      );

      const reasoning =
          'The user wants a **three-day** itinerary for Lisbon, so I should balance the big sights with '
          'slower afternoons.\n\n'
          'Day one could cover Alfama and the castle; `tram 28` links them. Day two, Belém.\n\n'
          'I should check opening hours before suggesting the *Jerónimos* monastery.';

      Widget scenarios(ThemeData theme) => GoldenTestGroup(
        columns: 1,
        children: [
          GoldenTestScenario(
            name: 'thinking',
            child: scenario(
              theme,
              const StreamingReasoningView(
                text: reasoning,
                isThinking: true,
                duration: Duration(seconds: 7),
                theme: _maxHeight120,
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'done, opened with footnote',
            child: scenario(
              theme,
              const StreamingReasoningView(
                text: reasoning,
                isThinking: false,
                duration: Duration(seconds: 12),
                summary: 'Planned a balanced three-day trip',
                footnote: 'Reasoning is kept for 30 days',
                expandedWhenDone: true,
                theme: _maxHeight120,
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'done, folded with summary',
            child: scenario(
              theme,
              const StreamingReasoningView(
                text: reasoning,
                isThinking: false,
                duration: Duration(seconds: 12),
                summary: 'Planned a balanced three-day trip',
              ),
            ),
          ),
        ],
      );

      goldenTest(
        'light',
        fileName: 'streaming_reasoning_view_light',
        builder: () => scenarios(ThemeData()),
      );

      goldenTest(
        'dark',
        fileName: 'streaming_reasoning_view_dark',
        builder: () => scenarios(ThemeData(brightness: Brightness.dark)),
      );
    });
  });
}

class _DutchTranslations extends DefaultAITranslations {
  const _DutchTranslations();

  @override
  String reasoningThoughtFor(Duration duration) => '${reasoningDuration(duration)} nagedacht';
}
