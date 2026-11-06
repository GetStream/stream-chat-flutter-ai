import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view.dart';

import '../../openui_test_app.dart';

void main() {
  for (final (name, stream) in [('light', StreamTheme.light()), ('dark', StreamTheme.dark())]) {
    group('drawn with the theme ($name)', () {
      final theme = OpenUIThemeData.defaults(stream);

      Future<void> draw(WidgetTester tester, String program) async {
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(tester, runtime, stream: stream, program: 'root = Card([$program])');
      }

      testWidgets('Tag draws a neutral pill in the subtle fill and secondary color', (tester) async {
        await draw(tester, 'Tag("New")');

        final box = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).last;
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.color, theme.colors!.subtleFill);
        expect(decoration.borderRadius, BorderRadius.circular(theme.radius!.pill!));
        final text = tester.widget<Text>(find.text('New'));
        expect(text.style!.color, theme.colors!.textSecondary);
        expect(text.style!.fontWeight, FontWeight.w500);
        expect(text.maxLines, 1);
      });

      testWidgets('Tag draws a variant pill at 14% of its color, and its icon', (tester) async {
        await draw(tester, 'Tag("Ok", Icon("check"), "lg", "success")');

        final decoration = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).last.decoration as BoxDecoration;
        expect(decoration.color, theme.colors!.success!.withValues(alpha: 0.14));
        expect(tester.widget<Text>(find.text('Ok')).style!.color, theme.colors!.success);
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.icon, stream.icons.checkmark);
        expect(icon.size, 16);
        expect(icon.color, theme.colors!.success);
      });

      testWidgets('Tag pads by size', (tester) async {
        await draw(tester, 'Tag("S"), Tag("M", null, "md"), Tag("L", null, "lg")');

        EdgeInsets padding(String text) =>
            tester.widget<Padding>(find.ancestor(of: find.text(text), matching: find.byType(Padding)).first).padding
                as EdgeInsets;
        expect(padding('S'), const EdgeInsets.symmetric(horizontal: 8, vertical: 3));
        expect(padding('M'), const EdgeInsets.symmetric(horizontal: 10, vertical: 4));
        expect(padding('L'), const EdgeInsets.symmetric(horizontal: 12, vertical: 6));
      });

      testWidgets('EntityList draws its rows between lines, in the secondary and primary colors', (tester) async {
        await draw(
          tester,
          'EntityList([{left: "A", right: "1", rightVariant: "number"}, {left: "B", right: "2"}], "default", {left: "H", right: "R"}, {left: "F", right: "T"})',
        );

        expect(tester.widget<Text>(find.text('A')).style!.color, theme.colors!.textSecondary);
        expect(tester.widget<Text>(find.text('1')).style!.color, theme.colors!.textPrimary);
        expect(tester.widget<Text>(find.text('1')).style!.fontFeatures, contains(const FontFeature.tabularFigures()));
        expect(tester.widget<Text>(find.text('2')).style!.fontFeatures, isNull);
        expect(tester.widget<Text>(find.text('H')).style!.color, theme.colors!.textPrimary);
        expect(tester.widget<Text>(find.text('H')).style!.fontWeight, FontWeight.w600);
        final lines = tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .where((box) => box.color == theme.colors!.border);
        expect(lines, hasLength(2));
        final dim = tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .where(
              (box) => box.color == theme.colors!.border!.withValues(alpha: 0.6),
            );
        expect(dim, hasLength(1));
      });

      testWidgets('Text and BoldText draw in their sizes with subtext below', (tester) async {
        await draw(tester, 'Text("text", "Plain", "note", "text", "sm"), BoldText("text", "Bold", "", "text", "lg")');

        expect(_styleOf(tester, 'Plain').fontSize, theme.textStyles!.bodySmall!.fontSize);
        expect(_styleOf(tester, 'Bold').fontSize, theme.textStyles!.title!.fontSize);
        expect(_styleOf(tester, 'Bold').fontWeight, FontWeight.w600);
        expect(tester.widget<Text>(find.text('note')).style!.color, theme.colors!.textSecondary);
      });

      testWidgets('a metric subtext is green after + and red after - or the minus sign', (tester) async {
        await draw(
          tester,
          'Text("text", "a", "+3%", "metric"), Text("text", "b", "-3%", "metric"), Text("text", "c", "−3%", "metric")',
        );

        expect(tester.widget<Text>(find.text('+3%')).style!.color, theme.colors!.success);
        expect(tester.widget<Text>(find.text('-3%')).style!.color, theme.colors!.danger);
        expect(tester.widget<Text>(find.text('−3%')).style!.color, theme.colors!.danger);
      });

      testWidgets('MetricIndicatorInline draws its value in the metric style with a trend badge', (tester) async {
        await draw(tester, 'MetricIndicatorInline("USD 1,200", "vs last", {direction: "up", value: 5})');

        final value = tester.widget<Text>(find.text('USD 1,200'));
        expect(value.style!.fontSize, theme.textStyles!.metric!.fontSize);
        expect(value.style!.color, theme.colors!.textPrimary);
        expect(find.text('5%'), findsOneWidget);
        expect(tester.widget<Text>(find.text('5%')).style!.color, theme.colors!.success);
        expect(find.bySemanticsLabel('Up 5'), findsOneWidget);
      });

      testWidgets('a trend that goes down is red, and one without a direction draws no badge', (tester) async {
        await draw(
          tester,
          'MetricIndicatorInline("1", "", {direction: "down", value: -2.5}), MetricIndicatorInline("2", "", {value: 5})',
        );

        expect(tester.widget<Text>(find.text('2.5%')).style!.color, theme.colors!.danger);
        expect(find.text('5%'), findsNothing);
      });

      testWidgets('MetricIndicatorWithStrikethrough strikes its previous value out', (tester) async {
        await draw(tester, 'MetricIndicatorWithStrikethrough("USD 80", "", "USD 100")');

        final previous = tester.widget<Text>(find.text('USD 100'));
        expect(previous.style!.decoration, TextDecoration.lineThrough);
        expect(previous.style!.color, theme.colors!.textTertiary);
      });

      testWidgets('IconText draws a filled badge of its variant beside its title', (tester) async {
        await draw(tester, 'IconText(Icon("check"), "filled", "lg", "Title", "Sub", true, "horizontal")');

        final badge = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).last;
        expect((badge.decoration as BoxDecoration).color, theme.colors!.accent);
        expect(tester.getSize(find.byType(Icon)), const Size(44 * 0.45, 44 * 0.45));
        expect(tester.widget<Icon>(find.byType(Icon)).color, theme.colors!.onAccent);
        expect(tester.getTopLeft(find.text('Title')).dx, greaterThan(tester.getTopLeft(find.byType(Icon)).dx));
        expect(_styleOf(tester, 'Title').fontWeight, FontWeight.w600);
      });

      testWidgets('IconText with the vertical layout puts the title below the badge', (tester) async {
        await draw(tester, 'IconText(Icon("check"), "soft", "s", "Title", "", false, "vertical")');

        expect(tester.getTopLeft(find.text('Title')).dy, greaterThan(tester.getBottomLeft(find.byType(Icon)).dy));
      });
    });
  }

  group('ImageText', () {
    Future<Size> imageSize(WidgetTester tester, String size) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program: 'root = Card([ImageText("ftp://x", "alt", "Title", "", false, "horizontal", $size)])',
      );
      return tester.getSize(find.byType(ClipRRect).first);
    }

    testWidgets('is 40 square by default and clamps its imageSize to 8 to 200', (tester) async {
      expect(await imageSize(tester, 'null'), const Size(40, 40));
      expect(await imageSize(tester, '2'), const Size(8, 8));
      expect(await imageSize(tester, '5000'), const Size(200, 200));
      expect(await imageSize(tester, '64'), const Size(64, 64));
    });
  });

  group('ImageTextLarge', () {
    testWidgets('draws its image 140 tall across the width, above its title', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([ImageTextLarge("ftp://x", "alt", "Title", "Sub")])');

      expect(tester.getSize(find.byType(ClipRRect).first).height, 140);
      expect(
        tester.getTopLeft(find.text('Title')).dy,
        greaterThan(tester.getBottomLeft(find.byType(ClipRRect).first).dy),
      );
    });
  });

  group('review fixes', () {
    testWidgets('an entity row puts its right text at the end of the row, with a gap after the left one', (
      tester,
    ) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([EntityList([{left: "A", right: "1"}])])');

      expect(tester.getTopRight(find.text('1')).dx, closeTo(360 - 16, 0.01));
      expect(tester.getTopLeft(find.text('A')).dx, closeTo(16, 0.01));
    });

    testWidgets('an image gallery inside a composite card does not break the card', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program:
            'root = Card([CompositeCardBlock([CompositeCardItem("a", Text("text", "Head"), [ImageGallery([{src: "https://a.dev/1.png", alt: "One"}])])])])',
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Head'), findsOneWidget);
    });

    testWidgets('a placeholder is not scaled up to fill a large box', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([ImageBlock("ftp://x", "alt text")])');

      expect(tester.getSize(find.byType(Icon)).width, lessThanOrEqualTo(24));
    });

    testWidgets('a tag is as wide as its content in a column that stretches', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([Tag("New")])');

      expect(
        tester.getSize(find.ancestor(of: find.text('New'), matching: find.byType(DecoratedBox)).first).width,
        lessThan(100),
      );
    });

    testWidgets('a standalone icon is 20 and grows with the text size', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([Icon("check")])');
      expect(tester.getSize(find.byType(Icon)), const Size(20, 20));
    });

    testWidgets('cards of a context block stretch to the height of their row', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program:
            'root = Card([ContextCardBlock([ContextCardItem("a", "T", "short"), ContextCardItem("b", "T", "A body that is much much longer than the other one so that it wraps over several lines")])])',
      );

      final heights = tester
          .widgetList<ClipRRect>(find.byType(ClipRRect))
          .map((box) => tester.getSize(find.byWidget(box)).height)
          .toSet();
      expect(heights, hasLength(1));
    });

    testWidgets('a replacement for Tag or MetricIndicatorInline wins inside card blocks', (tester) async {
      final library = OpenUILibrary.chat
          .replacing('Tag', (context, scope) => const Text('mine-tag'))
          .replacing('MetricIndicatorInline', (context, scope) => const Text('mine-metric'));
      final runtime = testRuntime(library: library);
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        library: library,
        program:
            'root = Card([OverviewCardBlock([OverviewCardItem("a", Text("text", "T"), Text("text", "9"))]), ContextCardBlock([ContextCardItem("b", Tag("Hot"), "x")])])',
      );

      expect(find.text('mine-metric'), findsOneWidget);
      expect(find.text('mine-tag'), findsOneWidget);
    });

    testWidgets('a block inside an unbounded width scrolls instead of throwing', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      runtime.update(
        'root = Card([OverviewCardBlock([OverviewCardItem("a", Text("text", "T")), OverviewCardItem("b", Text("text", "U"))])])',
        isStreaming: false,
      );
      await tester.pumpWidget(
        testApp(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: UnconstrainedBox(
              child: SizedBox(
                width: 1000,
                child: OpenUIView(runtime: runtime, library: OpenUILibrary.chat),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('EntityList size', () {
    testWidgets('small has less space around its rows, and draws no header or footer', (tester) async {
      Future<double> rowHeight(String size) async {
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(
          tester,
          runtime,
          program:
              'root = Card([EntityList([{left: "A", right: "1"}], "$size", {left: "H", right: "R"}, {left: "F", right: "T"})])',
        );
        return tester.getSize(find.ancestor(of: find.text('A'), matching: find.byType(Padding)).first).height;
      }

      final normal = await rowHeight('default');
      expect(find.text('H'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
      final small = await rowHeight('small');
      expect(small, lessThan(normal));
      expect(find.text('H'), findsNothing);
      expect(find.text('F'), findsNothing);
    });
  });

  group('Icon', () {
    testWidgets('draws the design system icon its name finds, and reads as the name without numbers', (tester) async {
      final handle = tester.ensureSemantics();
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([Icon("Trash-2")])');

      expect(tester.widget<Icon>(find.byType(Icon)).icon, StreamTheme.light().icons.delete);
      expect(find.bySemanticsLabel('trash'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('finds an icon for a name with trailing parts, or a category, and draws nothing for any other', (
      tester,
    ) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([Icon("arrow-up-right-big")])');
      expect(tester.widget<Icon>(find.byType(Icon)).icon, StreamTheme.light().icons.arrowUpRight);

      runtime.update('root = Card([Icon("zzz-qqq", "mail")])', isStreaming: false);
      await tester.pump();
      expect(tester.widget<Icon>(find.byType(Icon)).icon, StreamTheme.light().icons.send);

      runtime.update('root = Card([Icon("zzz-qqq")])', isStreaming: false);
      await tester.pump();
      expect(find.byType(Icon), findsNothing);
    });
  });

  group('text size and direction', () {
    Future<void> pumpScaled(WidgetTester tester, String program, {double scale = 1, TextDirection? direction}) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      runtime.update(program, isStreaming: false);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: testApp(
            Directionality(
              textDirection: direction ?? TextDirection.ltr,
              child: OpenUIView(runtime: runtime, library: OpenUILibrary.chat),
            ),
          ),
        ),
      );
    }

    testWidgets('a tag and a badge grow with the text size, with no fixed height', (tester) async {
      const program = 'root = Card([Tag("New"), IconText(Icon("check"), "soft", "s", "T")])';
      await pumpScaled(tester, program);
      final tag = tester.getSize(find.ancestor(of: find.text('New'), matching: find.byType(DecoratedBox)).first).height;
      final badge = tester.getSize(find.byType(Icon)).height;
      await pumpScaled(tester, program, scale: 2);

      expect(
        tester.getSize(find.ancestor(of: find.text('New'), matching: find.byType(DecoratedBox)).first).height,
        greaterThan(tag * 1.5),
      );
      expect(tester.getSize(find.byType(Icon)).height, closeTo(badge * 2, 0.01));
    });

    testWidgets('a long entity list label wraps instead of overflowing at a large text size', (tester) async {
      await pumpScaled(
        tester,
        'root = Card([EntityList([{left: "A fairly long label that has to wrap", right: "A fairly long value"}])])',
        scale: 2,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the sources strip starts at the right in a right-to-left direction', (tester) async {
      const program = 'root = Card([TextContent("x")], [{url: "https://a.dev", title: "Alpha", sourceName: "a"}])';
      await pumpScaled(tester, program);
      final left = tester.getTopLeft(find.text('Alpha')).dx;
      await pumpScaled(tester, program, direction: TextDirection.rtl);

      expect(tester.getTopRight(find.text('Alpha')).dx, greaterThan(left));
      expect(tester.getTopRight(find.text('Sources')).dx, greaterThan(300));
    });
  });

  group('TagBlock', () {
    testWidgets('wraps neutral pills of its size with a gap of 6', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program: 'root = Card([TagBlock(["one", "two", "three", "four", "five", "six", "seven", "eight"], "lg")])',
      );

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, 6);
      expect(wrap.runSpacing, 6);
      final tops = {
        for (final text in ['one', 'eight']) tester.getTopLeft(find.text(text)).dy,
      };
      expect(tops, hasLength(2));
      expect(
        tester.widget<Text>(find.text('one')).style!.fontSize,
        OpenUIThemeData.defaults(StreamTheme.light()).textStyles!.bodySmall!.fontSize,
      );
    });
  });

  group('card blocks', () {
    const snippet =
        'SnippetCardItem("a", IconText(Icon("check"), "soft", "s", "One", "", false, "horizontal"), Text("text", "9"))';

    testWidgets('draw their items as sunken cards of rounded corners', (tester) async {
      final theme = OpenUIThemeData.defaults(StreamTheme.light());
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([SnippetCardBlock([$snippet, $snippet])])');

      final cards = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where(
            (box) => (box.decoration as BoxDecoration).color == theme.colors!.sunkenSurface,
          );
      expect(cards.length, greaterThanOrEqualTo(2));
      expect((cards.first.decoration as BoxDecoration).borderRadius, BorderRadius.circular(theme.radius!.medium!));
      expect(find.text('One'), findsNWidgets(2));
    });

    testWidgets('a snippet block is a grid even with the carousel layout, and its rhs is drawn extra small', (
      tester,
    ) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([SnippetCardBlock([$snippet, $snippet], "carousel")])');

      expect(find.byType(SingleChildScrollView), findsNothing);
      final theme = OpenUIThemeData.defaults(StreamTheme.light());
      expect(_styleOf(tester, '9').fontSize, theme.textStyles!.caption!.fontSize);
    });

    testWidgets('lay out in columns by width, up to three, and stretch to the row height', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      final items = List.generate(
        4,
        (index) => 'OverviewCardItem("o$index", Text("text", "Top $index"), MetricIndicatorInline("$index"))',
      ).join(', ');
      await pumpOpenUI(tester, runtime, program: 'root = Card([OverviewCardBlock([$items])])');

      // 360 wide less the card's padding: 328; (328 + 12) / (140 + 12) = 2 columns.
      expect(tester.getTopLeft(find.text('Top 0')).dy, tester.getTopLeft(find.text('Top 1')).dy);
      expect(tester.getTopLeft(find.text('Top 2')).dy, greaterThan(tester.getTopLeft(find.text('Top 0')).dy));
    });

    testWidgets('a carousel scrolls its items sideways, each as wide as the block says', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      final items = List.generate(4, (index) => 'OverviewCardItem("o$index", Text("text", "Top $index"))').join(', ');
      await pumpOpenUI(tester, runtime, program: 'root = Card([OverviewCardBlock([$items], "carousel")])');

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final card = find.ancestor(of: find.text('Top 0'), matching: find.byType(SizedBox)).first;
      expect(tester.getSize(card).width, 180);
    });

    testWidgets('the gap clamps to 0 to 48, and a number that is not finite or a name gives the default', (
      tester,
    ) async {
      Future<double> gapOf(String gap) async {
        final runtime = testRuntime();
        addTearDown(runtime.dispose);
        await pumpOpenUI(
          tester,
          runtime,
          program:
              'root = Card([OverviewCardBlock([OverviewCardItem("a", Text("text", "A")), OverviewCardItem("b", Text("text", "B"))], "carousel", true, null, $gap)])',
        );
        final first = tester.getTopRight(find.ancestor(of: find.text('A'), matching: find.byType(SizedBox)).first).dx;
        final second = tester.getTopLeft(find.ancestor(of: find.text('B'), matching: find.byType(SizedBox)).first).dx;
        return second - first;
      }

      expect(await gapOf('200'), 48);
      expect(await gapOf('-5'), 0);
      expect(await gapOf('20'), 20);
      expect(await gapOf('"xl"'), OpenUIThemeData.defaults(StreamTheme.light()).spacing!.xl);
      expect(await gapOf('{}'), OpenUIThemeData.defaults(StreamTheme.light()).spacing!.m);
    });

    testWidgets('a block without items draws nothing', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Card([ContextCardBlock([])])');

      expect(find.byType(LayoutBuilder), findsNothing);
    });

    testWidgets('ContextCardBlock draws a Tag title as a tag, other titles as text, and its body', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program:
            'root = Card([ContextCardBlock([ContextCardItem("a", Tag("Hot", null, "sm", "danger"), "Body A"), ContextCardItem("b", "Plain title", "Body B")])])',
      );

      final theme = OpenUIThemeData.defaults(StreamTheme.light());
      expect(find.text('Hot'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Plain title')).style!.color, theme.colors!.textSecondary);
      expect(_styleOf(tester, 'Body A').fontWeight, FontWeight.w600);
      expect(
        tester.getSize(find.ancestor(of: find.text('Plain title'), matching: find.byType(ClipRRect)).first).height,
        greaterThanOrEqualTo(100),
      );
    });

    testWidgets('ContextCardBlock with an image draws its text in white over it, at least 150 tall', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program:
            'root = Card([ContextCardBlock([ContextCardItem("a", "Title", "Body", null, "ftp://x/i.png", "pic")])])',
      );

      expect(tester.widget<Text>(find.text('Title')).style!.color, Colors.white.withValues(alpha: 0.9));
      expect(_styleOf(tester, 'Body').color, Colors.white);
      expect(
        tester.getSize(find.ancestor(of: find.text('Title'), matching: find.byType(ClipRRect)).first).height,
        greaterThanOrEqualTo(150),
      );
      expect(find.text('pic'), findsOneWidget);
    });

    testWidgets('VisualCardBlock draws its body over the foot of its image and its tag at the top', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program:
            'root = Card([VisualCardBlock([VisualCardItem(BoldText("text", "Big", "small"), "a", "ftp://x/i.png", Tag("New"), "pic")])])',
      );

      final card = find.ancestor(of: find.text('Big'), matching: find.byType(ClipRRect)).first;
      expect(tester.getSize(card).height, greaterThanOrEqualTo(190));
      expect(tester.getTopLeft(find.text('New')).dy, lessThan(tester.getTopLeft(find.text('Big')).dy));
      expect(tester.getBottomLeft(find.text('small')).dy, lessThanOrEqualTo(tester.getBottomLeft(card).dy));
      expect(tester.widget<Text>(find.text('Big')).style!.color, Colors.white);
    });

    testWidgets('CompositeCardBlock draws its header, body and footer, with an empty footer button', (tester) async {
      final runtime = testRuntime();
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program:
            'root = Card([CompositeCardBlock([CompositeCardItem("a", Text("text", "Head"), [Text("text", "Line", "", "text", "lg")], {price: Text("text", "USD 9"), button: Button("Buy")})])])',
      );

      final theme = OpenUIThemeData.defaults(StreamTheme.light());
      expect(find.text('Head'), findsOneWidget);
      // A body Text is drawn extra small.
      expect(_styleOf(tester, 'Line').fontSize, theme.textStyles!.caption!.fontSize);
      expect(find.text('USD 9'), findsOneWidget);
      expect(find.text('Buy'), findsNothing);
      expect(tester.getTopLeft(find.text('USD 9')).dy, greaterThan(tester.getTopLeft(find.text('Line')).dy));
    });
  });
}

TextStyle _styleOf(WidgetTester tester, String text) {
  final paragraph = tester.widget<RichText>(
    find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText().contains(text)).first,
  );
  TextStyle? found;
  paragraph.text.visitChildren((span) {
    if (span is TextSpan && span.text != null && span.text!.contains(text)) {
      found = span.style;
      return false;
    }
    return true;
  });
  return paragraph.text.style!.merge(found);
}
