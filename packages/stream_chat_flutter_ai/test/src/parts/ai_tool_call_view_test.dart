import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';
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

AIToolCallPart _call({
  String name = 'get_weather',
  String? displayTitle,
  AIToolCallStatus status = AIToolCallStatus.running,
  String? summary,
  int? durationMs,
  AIToolApproval? approval,
}) => AIToolCallPart(
  id: 'call_1',
  name: name,
  displayTitle: displayTitle,
  status: status,
  summary: summary,
  durationMs: durationMs,
  approval: approval,
);

const _declined = AIToolApproval(decision: AIToolApprovalDecision.declined);

final _view = find.byType(AIToolCallView);

Finder _inView(Finder finder) => find.descendant(of: _view, matching: finder);

/// The status icon's glyph, or `null` when it shows something else (the
/// spinner).
IconData? _icon(WidgetTester tester) {
  final icons = tester.widgetList<Icon>(_inView(find.byType(Icon)));
  return icons.isEmpty ? null : icons.single.icon;
}

Color? _iconColor(WidgetTester tester) => tester.widget<Icon>(_inView(find.byType(Icon))).color;

/// The texts in the row, in order.
List<String> _texts(WidgetTester tester) =>
    tester.widgetList<Text>(_inView(find.byType(Text))).map((t) => t.data!).toList();

void main() {
  group('AIToolCallView', () {
    testWidgets('a call declined while its status still waits stops shimmering', (tester) async {
      const waiting = AIToolApproval(title: 'Send it?');
      await tester.pumpWidget(
        _wrap(
          AIToolCallView(
            call: _call(status: AIToolCallStatus.awaitingApproval, approval: waiting),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'the hand shimmers while it waits');

      await tester.pumpWidget(
        _wrap(
          AIToolCallView(
            call: _call(status: AIToolCallStatus.awaitingApproval, approval: _declined),
          ),
        ),
      );
      await tester.pump();
      expect(_icon(tester), Icons.close_rounded);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    group('title', () {
      testWidgets('is the display title', (tester) async {
        _reduceMotion(tester);
        await tester.pumpWidget(_wrap(AIToolCallView(call: _call(displayTitle: 'Checking the weather'))));
        expect(_texts(tester), ['Checking the weather']);
      });

      testWidgets('falls back to the tool name with spaces for underscores', (tester) async {
        _reduceMotion(tester);
        await tester.pumpWidget(_wrap(AIToolCallView(call: _call())));
        expect(_texts(tester), ['get weather']);

        await tester.pumpWidget(_wrap(AIToolCallView(call: _call(displayTitle: '  '))));
        expect(_texts(tester), ['get weather'], reason: 'a blank title counts as none');
      });

      testWidgets('falls back to a translated "Tool" when there is neither', (tester) async {
        _reduceMotion(tester);
        await tester.pumpWidget(_wrap(AIToolCallView(call: _call(name: ''))));
        expect(_texts(tester), ['Tool']);

        await tester.pumpWidget(
          _wrap(
            AITranslationsScope(
              translations: const _DutchTranslations(),
              child: AIToolCallView(call: _call(name: '')),
            ),
          ),
        );
        expect(_texts(tester), ['Hulpmiddel']);
      });
    });

    group('detail', () {
      final cases = {
        AIToolCallStatus.running: null,
        AIToolCallStatus.completed: null,
        AIToolCallStatus.awaitingApproval: 'Waiting for approval',
        AIToolCallStatus.awaitingClient: 'Waiting for the device',
        AIToolCallStatus.failed: "Didn't complete",
        AIToolCallStatus.cancelled: 'Cancelled',
        const AIToolCallStatus('queued'): null,
      };
      for (final MapEntry(key: status, value: detail) in cases.entries) {
        testWidgets('${status.value}: ${detail ?? 'no detail line'}', (tester) async {
          _reduceMotion(tester);
          await tester.pumpWidget(_wrap(AIToolCallView(call: _call(status: status))));
          expect(_texts(tester), ['get weather', ?detail]);
        });
      }

      testWidgets('a declined call reads "Declined", whatever its status', (tester) async {
        _reduceMotion(tester);
        for (final status in [AIToolCallStatus.cancelled, AIToolCallStatus.awaitingApproval]) {
          await tester.pumpWidget(
            _wrap(
              AIToolCallView(
                call: _call(status: status, approval: _declined),
              ),
            ),
          );
          expect(_texts(tester), ['get weather', 'Declined']);
        }
      });

      testWidgets('the summary wins over the status text', (tester) async {
        _reduceMotion(tester);
        for (final status in [AIToolCallStatus.running, AIToolCallStatus.failed, AIToolCallStatus.awaitingApproval]) {
          await tester.pumpWidget(
            _wrap(
              AIToolCallView(
                call: _call(status: status, summary: 'Sunny, 21°C'),
              ),
            ),
          );
          expect(_texts(tester), ['get weather', 'Sunny, 21°C'], reason: status.value);
        }
        await tester.pumpWidget(
          _wrap(
            AIToolCallView(
              call: _call(status: AIToolCallStatus.failed, summary: ''),
            ),
          ),
        );
        expect(_texts(tester), ['get weather', "Didn't complete"], reason: 'an empty summary counts as none');
      });

      testWidgets('is translated', (tester) async {
        _reduceMotion(tester);
        await tester.pumpWidget(
          _wrap(
            AITranslationsScope(
              translations: const _DutchTranslations(),
              child: AIToolCallView(call: _call(status: AIToolCallStatus.failed)),
            ),
          ),
        );
        expect(_texts(tester), ['get weather', 'Niet gelukt']);
      });
    });

    group('duration', () {
      testWidgets('shows only once the call has finished', (tester) async {
        _reduceMotion(tester);
        for (final status in [AIToolCallStatus.running, AIToolCallStatus.awaitingClient]) {
          await tester.pumpWidget(_wrap(AIToolCallView(call: _call(status: status, durationMs: 400))));
          expect(find.text('0.4s'), findsNothing, reason: status.value);
        }
        for (final status in [AIToolCallStatus.completed, AIToolCallStatus.failed, AIToolCallStatus.cancelled]) {
          await tester.pumpWidget(_wrap(AIToolCallView(call: _call(status: status, durationMs: 400))));
          expect(find.text('0.4s'), findsOneWidget, reason: status.value);
        }
      });

      testWidgets('a declined call shows none', (tester) async {
        _reduceMotion(tester);
        await tester.pumpWidget(
          _wrap(
            AIToolCallView(
              call: _call(status: AIToolCallStatus.cancelled, approval: _declined, durationMs: 400),
            ),
          ),
        );
        expect(find.text('0.4s'), findsNothing);
      });

      testWidgets('shows nothing when the agent sent none', (tester) async {
        await tester.pumpWidget(_wrap(AIToolCallView(call: _call(status: AIToolCallStatus.completed))));
        expect(_texts(tester), ['get weather']);
      });

      testWidgets('sits at the end of the title row, in tabular figures', (tester) async {
        await tester.pumpWidget(
          _wrap(AIToolCallView(call: _call(status: AIToolCallStatus.completed, durationMs: 65000))),
        );
        expect(tester.getTopRight(find.text('1m 5s')).dx, 360);
        expect(tester.widget<Text>(find.text('1m 5s')).style!.fontFeatures, const [FontFeature.tabularFigures()]);
      });

      testWidgets('sits at the start edge in right-to-left text', (tester) async {
        _reduceMotion(tester);
        await tester.pumpWidget(
          _wrap(
            Directionality(
              textDirection: TextDirection.rtl,
              child: AIToolCallView(call: _call(status: AIToolCallStatus.completed, durationMs: 65000)),
            ),
          ),
        );
        expect(tester.getTopLeft(find.text('1m 5s')).dx, 0);
        expect(tester.getTopRight(_inView(find.byType(Icon))).dx, 360, reason: 'the icon leads on the right');
      });

      testWidgets('adds tabular figures to the themed font features rather than replacing them', (tester) async {
        await tester.pumpWidget(
          _wrap(
            AIToolCallView(
              call: _call(status: AIToolCallStatus.completed, durationMs: 400),
              theme: const ToolCallThemeData(detailStyle: TextStyle(fontFeatures: [FontFeature.slashedZero()])),
            ),
          ),
        );
        expect(tester.widget<Text>(find.text('0.4s')).style!.fontFeatures, const [
          FontFeature.slashedZero(),
          FontFeature.tabularFigures(),
        ]);
      });
    });

    group('icon', () {
      testWidgets('per status', (tester) async {
        _reduceMotion(tester);
        final theme = ThemeData();
        final colors = theme.colorScheme;
        final cases = <({AIToolCallPart call, IconData icon, Color color})>[
          (
            call: _call(status: AIToolCallStatus.awaitingApproval),
            icon: Icons.back_hand_outlined,
            color: colors.primary,
          ),
          (
            call: _call(status: AIToolCallStatus.awaitingClient),
            icon: Icons.smartphone_outlined,
            color: colors.primary,
          ),
          (call: _call(status: AIToolCallStatus.failed), icon: Icons.priority_high_rounded, color: colors.error),
          (call: _call(status: AIToolCallStatus.cancelled), icon: Icons.close_rounded, color: colors.onSurfaceVariant),
          (
            call: _call(status: AIToolCallStatus.cancelled, approval: _declined),
            icon: Icons.close_rounded,
            color: colors.onSurfaceVariant,
          ),
        ];
        for (final (:call, :icon, :color) in cases) {
          await tester.pumpWidget(_wrap(AIToolCallView(call: call), theme: theme));
          expect(_icon(tester), icon, reason: call.status.value);
          expect(_iconColor(tester), color, reason: call.status.value);
        }

        await tester.pumpWidget(
          _wrap(
            AIToolCallView(call: _call(status: AIToolCallStatus.completed)),
            theme: theme,
          ),
        );
        expect(_icon(tester), Icons.check_rounded);
        final success = _iconColor(tester)!;
        expect(success.g, greaterThan(success.r), reason: 'a green');
      });

      testWidgets('an unknown status spins, and debug builds report it once per change', (tester) async {
        final reports = <String>[];
        debugPartIssueReporter = reports.add;
        addTearDown(() => debugPartIssueReporter = null);

        await tester.pumpWidget(_wrap(AIToolCallView(call: _call(status: const AIToolCallStatus('queued')))));
        expect(_inView(find.byType(CircularProgressIndicator)), findsOneWidget);
        expect(reports, hasLength(1));
        expect(reports.single, contains('"queued"'));

        await tester.pumpWidget(_wrap(AIToolCallView(call: _call(status: const AIToolCallStatus('queued')))));
        expect(reports, hasLength(1), reason: 'a rebuild with the same status stays quiet');

        await tester.pumpWidget(_wrap(AIToolCallView(call: _call())));
        await tester.pumpWidget(_wrap(AIToolCallView(call: _call(status: const AIToolCallStatus('paused')))));
        expect(reports, hasLength(2));
        expect(reports.last, contains('"paused"'));
      });

      testWidgets('a running call, or one in a status this package does not know, spins', (tester) async {
        for (final status in [AIToolCallStatus.running, const AIToolCallStatus('queued')]) {
          await tester.pumpWidget(_wrap(AIToolCallView(call: _call(status: status))));
          expect(_inView(find.byType(CircularProgressIndicator)), findsOneWidget, reason: status.value);
          expect(_icon(tester), isNull);
          expect(tester.hasRunningAnimations, isTrue);
        }
      });

      testWidgets('shimmers while the call waits, and stops once it does not', (tester) async {
        for (final status in [AIToolCallStatus.awaitingApproval, AIToolCallStatus.awaitingClient]) {
          await tester.pumpWidget(_wrap(AIToolCallView(call: _call(status: status))));
          expect(_inView(find.byType(ShaderMask)), findsOneWidget, reason: status.value);
          expect(tester.hasRunningAnimations, isTrue);
        }

        await tester.pumpWidget(_wrap(AIToolCallView(call: _call(status: AIToolCallStatus.completed))));
        expect(_inView(find.byType(ShaderMask)), findsNothing);
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('reduced motion: no spinner and no shimmer', (tester) async {
        _reduceMotion(tester);
        await tester.pumpWidget(_wrap(AIToolCallView(call: _call())));
        expect(_inView(find.byType(CircularProgressIndicator)), findsNothing);
        expect(_icon(tester), Icons.more_horiz_rounded);
        expect(tester.hasRunningAnimations, isFalse);

        for (final status in [AIToolCallStatus.awaitingApproval, AIToolCallStatus.awaitingClient]) {
          await tester.pumpWidget(_wrap(AIToolCallView(call: _call(status: status))));
          expect(_inView(find.byType(ShaderMask)), findsNothing, reason: status.value);
          expect(tester.hasRunningAnimations, isFalse, reason: status.value);
        }
      });

      testWidgets('starts and stops shimmering as the same call changes status', (tester) async {
        Future<void> pump(AIToolCallStatus status) =>
            tester.pumpWidget(_wrap(AIToolCallView(call: _call(status: status))));

        await pump(AIToolCallStatus.running);
        expect(_inView(find.byType(ShaderMask)), findsNothing);

        await pump(AIToolCallStatus.awaitingApproval);
        expect(_inView(find.byType(ShaderMask)), findsOneWidget);
        expect(tester.hasRunningAnimations, isTrue);

        await pump(AIToolCallStatus.completed);
        expect(_inView(find.byType(ShaderMask)), findsNothing);
        expect(tester.hasRunningAnimations, isFalse);

        await pump(AIToolCallStatus.awaitingClient);
        expect(_inView(find.byType(ShaderMask)), findsOneWidget);
        expect(tester.hasRunningAnimations, isTrue, reason: 'the stopped shimmer starts again');
      });

      testWidgets('the shimmer sweeps an accent band over the neutral icon', (tester) async {
        const data = ToolCallThemeData(accentColor: Color(0xFF0000D1), iconColor: Color(0xFF0000D2));
        await tester.pumpWidget(
          _wrap(
            AIToolCallView(
              call: _call(status: AIToolCallStatus.awaitingApproval),
              theme: data,
            ),
          ),
        );
        expect(_iconColor(tester), const Color(0xFF0000D2));
      });

      testWidgets('swaps spinner and still icon both ways as reduced motion toggles', (tester) async {
        await tester.pumpWidget(_wrap(AIToolCallView(call: _call())));
        expect(_inView(find.byType(CircularProgressIndicator)), findsOneWidget);

        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
          disableAnimations: true,
        );
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await tester.pump();
        expect(_inView(find.byType(CircularProgressIndicator)), findsNothing);
        expect(_icon(tester), Icons.more_horiz_rounded);
        expect(tester.hasRunningAnimations, isFalse);

        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        await tester.pump();
        expect(_inView(find.byType(CircularProgressIndicator)), findsOneWidget);
        expect(tester.hasRunningAnimations, isTrue);
      });

      testWidgets('shimmers again when reduced motion turns off', (tester) async {
        _reduceMotion(tester);
        await tester.pumpWidget(_wrap(AIToolCallView(call: _call(status: AIToolCallStatus.awaitingApproval))));
        expect(_inView(find.byType(ShaderMask)), findsNothing);

        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        await tester.pump();
        expect(_inView(find.byType(ShaderMask)), findsOneWidget);
        expect(tester.hasRunningAnimations, isTrue);
      });

      testWidgets('stops shimmering when reduced motion turns on', (tester) async {
        await tester.pumpWidget(_wrap(AIToolCallView(call: _call(status: AIToolCallStatus.awaitingApproval))));
        expect(tester.hasRunningAnimations, isTrue);

        _reduceMotion(tester);
        await tester.pump();
        expect(_inView(find.byType(ShaderMask)), findsNothing);
        expect(tester.hasRunningAnimations, isFalse);
      });
    });

    group('accessibility', () {
      testWidgets('the row is one live-region node reading title, status, summary and duration', (tester) async {
        final handle = tester.ensureSemantics();
        _reduceMotion(tester);
        await tester.pumpWidget(
          _wrap(
            AIToolCallView(
              call: _call(
                displayTitle: 'Checking the weather',
                status: AIToolCallStatus.completed,
                summary: 'Sunny, 21°C',
                durationMs: 800,
              ),
            ),
          ),
        );

        expect(
          tester.getSemantics(find.bySemanticsLabel('Checking the weather, Completed, Sunny, 21°C, 0.8s')),
          isSemantics(isLiveRegion: true),
        );
        expect(find.bySemanticsLabel('Sunny, 21°C'), findsNothing, reason: 'the texts are merged into the row');
        handle.dispose();
      });

      testWidgets('one node updates its label in place as the call finishes', (tester) async {
        final handle = tester.ensureSemantics();
        _reduceMotion(tester);
        await tester.pumpWidget(_wrap(AIToolCallView(call: _call())));
        final node = tester.getSemantics(find.bySemanticsLabel('get weather, Running'));

        await tester.pumpWidget(
          _wrap(
            AIToolCallView(
              call: _call(status: AIToolCallStatus.completed, summary: 'Sunny', durationMs: 800),
            ),
          ),
        );
        final updated = tester.getSemantics(find.bySemanticsLabel('get weather, Completed, Sunny, 0.8s'));
        expect(updated.id, node.id, reason: 'the same live region, so the change is announced');
        expect(updated, isSemantics(isLiveRegion: true));
        handle.dispose();
      });

      testWidgets('reads the status even without a detail line', (tester) async {
        final handle = tester.ensureSemantics();
        _reduceMotion(tester);
        final labels = {
          _call(): 'get weather, Running',
          _call(status: AIToolCallStatus.failed): "get weather, Didn't complete",
          _call(status: AIToolCallStatus.cancelled, approval: _declined, durationMs: 1200): 'get weather, Declined',
          _call(status: const AIToolCallStatus('queued')): 'get weather, Running',
        };
        for (final MapEntry(key: call, value: label) in labels.entries) {
          await tester.pumpWidget(_wrap(AIToolCallView(call: call)));
          expect(find.bySemanticsLabel(label), findsOneWidget);
        }
        handle.dispose();
      });
    });

    group('theme', () {
      Color? spinnerColor(WidgetTester tester) =>
          tester.widget<CircularProgressIndicator>(_inView(find.byType(CircularProgressIndicator))).color;

      testWidgets('defaults derive from the ambient theme', (tester) async {
        final theme = ThemeData();
        await tester.pumpWidget(
          _wrap(
            AIToolCallView(
              call: _call(status: AIToolCallStatus.failed, summary: 'Timed out'),
            ),
            theme: theme,
          ),
        );

        final textTheme = Theme.of(tester.element(_view)).textTheme;
        final title = tester.widget<Text>(find.text('get weather')).style!;
        expect(title.color, theme.colorScheme.onSurface);
        expect(title.fontSize, textTheme.bodyMedium!.fontSize);
        final detail = tester.widget<Text>(find.text('Timed out')).style!;
        expect(detail.color, theme.colorScheme.onSurfaceVariant);
        expect(detail.fontSize, textTheme.bodySmall!.fontSize);
        expect(tester.widget<Icon>(_inView(find.byType(Icon))).size, 14);

        await tester.pumpWidget(_wrap(AIToolCallView(call: _call()), theme: theme));
        expect(spinnerColor(tester), theme.colorScheme.primary);
      });

      testWidgets('the default success green differs between light and dark', (tester) async {
        _reduceMotion(tester);
        final completed = AIToolCallView(call: _call(status: AIToolCallStatus.completed));
        await tester.pumpWidget(_wrap(completed, theme: ThemeData()));
        final light = _iconColor(tester);
        await tester.pumpWidget(_wrap(completed, theme: ThemeData(brightness: Brightness.dark)));
        await tester.pumpAndSettle();
        expect(_iconColor(tester), isNot(light));
      });

      testWidgets('resolves widget > ToolCallTheme > AITheme > defaults', (tester) async {
        _reduceMotion(tester);
        final theme = ThemeData(
          extensions: const [
            AITheme(
              toolCallTheme: ToolCallThemeData(
                failureColor: Color(0xFF0000A1),
                titleStyle: TextStyle(fontSize: 30, color: Color(0xFF0000B1)),
                iconSize: 20,
              ),
            ),
          ],
        );

        Future<void> pump({ToolCallThemeData? scope, ToolCallThemeData? local}) async {
          Widget child = AIToolCallView(
            call: _call(status: AIToolCallStatus.failed),
            theme: local,
          );
          if (scope != null) child = ToolCallTheme(data: scope, child: child);
          await tester.pumpWidget(_wrap(child, theme: theme));
        }

        await pump();
        expect(_iconColor(tester), const Color(0xFF0000A1), reason: 'AITheme over the defaults');
        expect(tester.widget<Icon>(_inView(find.byType(Icon))).size, 20);
        expect(tester.widget<Text>(find.text('get weather')).style!.fontSize, 30);

        await pump(scope: const ToolCallThemeData(failureColor: Color(0xFF0000A2)));
        expect(_iconColor(tester), const Color(0xFF0000A2), reason: 'the scope over AITheme');

        await pump(
          scope: const ToolCallThemeData(failureColor: Color(0xFF0000A2)),
          local: const ToolCallThemeData(failureColor: Color(0xFF0000A3), titleStyle: TextStyle(fontSize: 12)),
        );
        expect(_iconColor(tester), const Color(0xFF0000A3), reason: 'the widget over the scope');
        final style = tester.widget<Text>(find.text('get weather')).style!;
        expect(style.fontSize, 12);
        expect(style.color, const Color(0xFF0000B1), reason: "the widget's style merges over the themed one");
      });

      testWidgets('an inherit: false style still gets a color', (tester) async {
        final theme = ThemeData();
        await tester.pumpWidget(
          _wrap(
            AIToolCallView(
              call: _call(status: AIToolCallStatus.failed),
              theme: const ToolCallThemeData(
                titleStyle: TextStyle(inherit: false, fontSize: 15, textBaseline: TextBaseline.alphabetic),
                detailStyle: TextStyle(inherit: false, fontSize: 11, textBaseline: TextBaseline.alphabetic),
              ),
            ),
            theme: theme,
          ),
        );
        expect(tester.widget<Text>(find.text('get weather')).style!.color, theme.colorScheme.onSurface);
        expect(tester.widget<Text>(find.text("Didn't complete")).style!.color, theme.colorScheme.onSurfaceVariant);
      });

      test('a negative icon size is rejected', () {
        // The resolved theme also clamps it to zero, for release builds, where
        // the assert is gone.
        expect(() => ToolCallThemeData(iconSize: -1), throwsAssertionError);
      });

      testWidgets('accent, success and detail colors reach their icons', (tester) async {
        _reduceMotion(tester);
        const data = ToolCallThemeData(
          accentColor: Color(0xFF0000C1),
          successColor: Color(0xFF0000C2),
          detailStyle: TextStyle(color: Color(0xFF0000C3)),
        );
        final cases = {
          AIToolCallStatus.running: const Color(0xFF0000C1),
          AIToolCallStatus.awaitingApproval: const Color(0xFF0000C1),
          AIToolCallStatus.completed: const Color(0xFF0000C2),
          AIToolCallStatus.cancelled: const Color(0xFF0000C3),
        };
        // iconColor, when set, wins over the detail color for the neutral icon.
        await tester.pumpWidget(
          _wrap(
            AIToolCallView(
              call: _call(status: AIToolCallStatus.cancelled),
              theme: data.copyWith(iconColor: const Color(0xFF0000C4)),
            ),
          ),
        );
        expect(_iconColor(tester), const Color(0xFF0000C4));
        for (final MapEntry(key: status, value: color) in cases.entries) {
          await tester.pumpWidget(
            _wrap(
              AIToolCallView(
                call: _call(status: status),
                theme: data,
              ),
            ),
          );
          expect(_iconColor(tester), color, reason: status.value);
        }
      });
    });

    group('goldens', () {
      final calls = [
        _call(displayTitle: 'Searching the web'),
        _call(
          name: 'get_location',
          displayTitle: 'Sharing your location',
          status: AIToolCallStatus.awaitingApproval,
        ),
        _call(name: 'read_contacts', status: AIToolCallStatus.awaitingClient),
        _call(
          displayTitle: 'Checking the weather',
          status: AIToolCallStatus.completed,
          summary: 'Sunny, 21°C',
          durationMs: 420,
        ),
        _call(name: 'book_table', status: AIToolCallStatus.failed, durationMs: 65000),
        _call(name: 'send_email', status: AIToolCallStatus.cancelled, durationMs: 1200),
        _call(name: 'delete_files', status: AIToolCallStatus.cancelled, approval: _declined),
      ];

      Widget rows(ThemeData theme) => Theme(
        data: theme,
        child: Builder(
          builder: (context) => MediaQuery(
            // Deterministic: no spinner, no shimmer.
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: ColoredBox(
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 10,
                    children: [for (final call in calls) AIToolCallView(call: call)],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      goldenTest('light', fileName: 'ai_tool_call_view_light', builder: () => rows(ThemeData()));

      goldenTest(
        'dark',
        fileName: 'ai_tool_call_view_dark',
        builder: () => rows(ThemeData(brightness: Brightness.dark)),
      );
    });
  });
}

class _DutchTranslations extends DefaultAITranslations {
  const _DutchTranslations();

  @override
  String get toolCallFallbackTitle => 'Hulpmiddel';

  @override
  String get toolCallFailed => 'Niet gelukt';
}
