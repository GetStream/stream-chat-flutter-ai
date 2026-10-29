import 'dart:ui' show Tristate;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: child)),
);

/// The tooltips of the buttons, in order.
List<String> _labels(WidgetTester tester) =>
    tester.widgetList<IconButton>(find.byType(IconButton)).map((b) => b.tooltip!).toList();

IconData _iconOf(WidgetTester tester, String tooltip) =>
    tester.widget<Icon>(find.descendant(of: find.byTooltip(tooltip), matching: find.byType(Icon))).icon!;

void main() {
  group('AIReplyActionsView', () {
    testWidgets('offers only copying when the app handles nothing else', (tester) async {
      await tester.pumpWidget(_wrap(const AIReplyActionsView(text: 'Hi')));
      expect(_labels(tester), ['Copy']);
    });

    testWidgets('offers each action the app handles, in order', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIReplyActionsView(
            text: 'Hi',
            actions: AIReplyActions(onShare: (_, _) {}, onRegenerate: () {}, onRate: (_) {}),
          ),
        ),
      );
      expect(_labels(tester), ['Copy', 'Share', 'Regenerate', 'Good response', 'Bad response']);
    });

    for (final material3 in [true, false]) {
      testWidgets('gives every button a 48 dp tap target (Material ${material3 ? 3 : 2})', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(
            AIReplyActionsView(
              text: 'Hi',
              actions: AIReplyActions(onShare: (_, _) {}, onRegenerate: () {}, onRate: (_) {}),
            ),
            theme: ThemeData(useMaterial3: material3),
          ),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        semantics.dispose();
      });
    }

    for (final (material3, tapTarget) in [
      (true, MaterialTapTargetSize.padded),
      (false, MaterialTapTargetSize.padded),
      (true, MaterialTapTargetSize.shrinkWrap),
      (false, MaterialTapTargetSize.shrinkWrap),
    ]) {
      testWidgets(
        'puts its buttons 48 dp apart (Material ${material3 ? 3 : 2}, ${tapTarget.name} targets)',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              AIReplyActionsView(
                text: 'Hi',
                actions: AIReplyActions(onShare: (_, _) {}, onRegenerate: () {}, onRate: (_) {}),
              ),
              theme: ThemeData(useMaterial3: material3, materialTapTargetSize: tapTarget),
            ),
          );
          final centers = [
            for (final label in ['Copy', 'Share', 'Regenerate', 'Good response', 'Bad response'])
              tester.getCenter(find.byTooltip(label)).dx,
          ];
          for (var i = 1; i < centers.length; i++) {
            expect(centers[i] - centers[i - 1], 48);
          }
          if (tapTarget == MaterialTapTargetSize.shrinkWrap) {
            expect(tester.getSize(find.byTooltip('Copy')), const Size.square(40));
          }
        },
      );
    }

    testWidgets('copies the text and confirms it for a moment', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(_wrap(const AIReplyActionsView(text: 'The answer')));
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(copied, ['The answer']);
      expect(_labels(tester), ['Copied!']);
      expect(_iconOf(tester, 'Copied!'), Icons.check);
      expect(tester.takeAnnouncements().map((a) => a.message), ['Copied!']);

      await tester.pump(const Duration(milliseconds: 1499));
      expect(_labels(tester), ['Copied!']);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_labels(tester), ['Copy']);
    });

    testWidgets('confirms nothing when the clipboard refuses the text', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') throw PlatformException(code: 'denied');
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(_wrap(const AIReplyActionsView(text: 'The answer')));
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(_labels(tester), ['Copy']);
      expect(tester.takeAnnouncements(), isEmpty);
    });

    testWidgets('shares the text from where the button is', (tester) async {
      String? shared;
      Rect? origin;
      await tester.pumpWidget(
        _wrap(
          AIReplyActionsView(
            text: 'The answer',
            actions: AIReplyActions(
              onShare: (text, rect) {
                shared = text;
                origin = rect;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Share'));

      expect(shared, 'The answer');
      expect(origin, tester.getRect(find.widgetWithIcon(IconButton, Icons.ios_share)));
    });

    testWidgets('regenerates', (tester) async {
      var regenerated = 0;
      await tester.pumpWidget(
        _wrap(
          AIReplyActionsView(
            text: 'Hi',
            actions: AIReplyActions(onRegenerate: () => regenerated++),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Regenerate'));
      expect(regenerated, 1);
    });

    group('rating', () {
      Future<List<AIMessageRating?>> tapRating(WidgetTester tester, AIMessageRating? rating, String tooltip) async {
        final rated = <AIMessageRating?>[];
        await tester.pumpWidget(
          _wrap(
            AIReplyActionsView(
              text: 'Hi',
              actions: AIReplyActions(rating: rating, onRate: rated.add),
            ),
          ),
        );
        await tester.tap(find.byTooltip(tooltip));
        return rated;
      }

      testWidgets('rates an unrated reply', (tester) async {
        expect(await tapRating(tester, null, 'Good response'), [AIMessageRating.positive]);
        expect(await tapRating(tester, null, 'Bad response'), [AIMessageRating.negative]);
      });

      testWidgets('switches to the other rating', (tester) async {
        expect(await tapRating(tester, AIMessageRating.positive, 'Bad response'), [AIMessageRating.negative]);
      });

      testWidgets('takes the rating back when its button is tapped again', (tester) async {
        expect(await tapRating(tester, AIMessageRating.positive, 'Good response'), [null]);
      });

      for (final material3 in [true, false]) {
        testWidgets('fills the rating given and marks it selected (Material ${material3 ? 3 : 2})', (tester) async {
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            _wrap(
              AIReplyActionsView(
                text: 'Hi',
                actions: AIReplyActions(rating: AIMessageRating.positive, onRate: (_) {}),
              ),
              theme: ThemeData(useMaterial3: material3),
            ),
          );

          expect(_iconOf(tester, 'Good response'), Icons.thumb_up);
          expect(_iconOf(tester, 'Bad response'), Icons.thumb_down_outlined);
          expect(tester.getSemantics(find.byTooltip('Good response')).flagsCollection.isSelected, Tristate.isTrue);
          expect(tester.getSemantics(find.byTooltip('Bad response')).flagsCollection.isSelected, Tristate.isFalse);
          // Material 2 can't pad a button out to its tap target, so there the
          // button fills it.
          expect(tester.getSize(find.byTooltip('Good response')), Size.square(material3 ? 40 : 48));
          expect(tester.getSize(find.widgetWithIcon(IconButton, Icons.thumb_up)), const Size.square(48));
          semantics.dispose();
        });
      }
    });

    testWidgets('a confirmation still showing is dropped with the view', (tester) async {
      await tester.pumpWidget(_wrap(const AIReplyActionsView(text: 'Hi')));
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('takes its icon color and size from the theme', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIReplyActionsView(
            text: 'Hi',
            actions: AIReplyActions(rating: AIMessageRating.negative, onRate: (_) {}),
          ),
          theme: ThemeData(
            extensions: const [
              AITheme(
                replyActionsTheme: ReplyActionsThemeData(
                  iconColor: Color(0xFF112233),
                  selectedIconColor: Color(0xFF445566),
                  iconSize: 22,
                ),
              ),
            ],
          ),
        ),
      );
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.map((i) => i.color), [const Color(0xFF112233), const Color(0xFF112233), const Color(0xFF445566)]);
      expect(icons.map((i) => i.size), everyElement(22));
    });

    testWidgets('translates its tooltips', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AITranslationsScope(
            translations: const _DutchTranslations(),
            child: AIReplyActionsView(
              text: 'Hi',
              actions: AIReplyActions(onRegenerate: () {}),
            ),
          ),
        ),
      );
      expect(_labels(tester), ['Kopiëren', 'Opnieuw']);
    });

    group('goldens', () {
      Widget rows(ThemeData theme) => Theme(
        data: theme,
        child: ColoredBox(
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                const AIReplyActionsView(text: 'Hi'),
                AIReplyActionsView(
                  text: 'Hi',
                  actions: AIReplyActions(onShare: (_, _) {}, onRegenerate: () {}, onRate: (_) {}),
                ),
                AIReplyActionsView(
                  text: 'Hi',
                  actions: AIReplyActions(rating: AIMessageRating.positive, onShare: (_, _) {}, onRate: (_) {}),
                ),
              ],
            ),
          ),
        ),
      );

      goldenTest('light', fileName: 'ai_reply_actions_view_light', builder: () => rows(ThemeData()));

      goldenTest(
        'dark',
        fileName: 'ai_reply_actions_view_dark',
        builder: () => rows(ThemeData(brightness: Brightness.dark)),
      );
    });
  });
}

class _DutchTranslations extends DefaultAITranslations {
  const _DutchTranslations();

  @override
  String get copyReply => 'Kopiëren';

  @override
  String get regenerateReply => 'Opnieuw';
}
