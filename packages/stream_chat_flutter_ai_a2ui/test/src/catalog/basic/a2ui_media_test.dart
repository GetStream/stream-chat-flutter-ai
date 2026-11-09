import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_media.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

import '../../a2ui_test_app.dart';

// The pieces the media components are drawn with.
void main() {
  testWidgets('the progress line fills the share that has played with the accent', (tester) async {
    await _pumpProgress(tester, played: 0.25, loaded: 0.5);

    expect(tester.getSize(_bar(lightTheme().accent)).width, 100.0);
  });

  testWidgets('the progress line fills the share that has loaded', (tester) async {
    await _pumpProgress(tester, played: 0.25, loaded: 0.5);

    expect(tester.getSize(_bar(lightTheme().secondaryText.withValues(alpha: 0.4))).width, 200.0);
  });

  testWidgets('the progress line stays empty for a share that is not a number', (tester) async {
    await _pumpProgress(tester, played: double.nan, loaded: 0.5);

    expect(tester.getSize(_bar(lightTheme().accent)).width, 0.0);
  });

  testWidgets('taps pass through the progress line', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: A2UISurfaceScope(
          catalog: A2UICatalog.basic,
          theme: lightTheme(),
          mediaUrl: a2uiWebMediaUrl,
          child: Stack(
            children: [
              Positioned.fill(child: GestureDetector(onTap: () => taps += 1)),
              const Positioned.fill(child: A2UIMediaProgress(played: 0.5, loaded: 1)),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(A2UIMediaProgress));

    expect(taps, 1);
  });

  testWidgets('assistive technologies skip the progress line', (tester) async {
    final handle = tester.ensureSemantics();

    await _pumpProgress(tester, played: 0.25, loaded: 0.5);

    expect(
      find.descendant(of: find.byType(A2UIMediaProgress), matching: find.byType(ExcludeSemantics)),
      findsOneWidget,
    );
    handle.dispose();
  });
}

// Shows a progress line 400 wide under the light theme.
Future<void> _pumpProgress(WidgetTester tester, {required double played, required double loaded}) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: A2UISurfaceScope(
        catalog: A2UICatalog.basic,
        theme: lightTheme(),
        mediaUrl: a2uiWebMediaUrl,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 40,
            child: A2UIMediaProgress(played: played, loaded: loaded),
          ),
        ),
      ),
    ),
  );
}

// The part of the progress line drawn in [color].
Finder _bar(Color color) => find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == color);
