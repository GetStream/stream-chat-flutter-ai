import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_fill.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import '../../a2ui_test_app.dart';

void main() {
  testWidgets('a divider is a line 1 high across the width it is given', (tester) async {
    await _pumpDivider(tester);

    expect(tester.getSize(_line()), const Size(300, 1));
  });

  testWidgets('a divider is horizontal without an axis', (tester) async {
    await _pumpDivider(tester, axis: null);

    expect(tester.getSize(_line()).height, 1);
  });

  testWidgets('a divider is in the border color', (tester) async {
    await _pumpDivider(tester);

    expect(tester.widget<ColoredBox>(_line()).color, lightTheme().border);
  });

  testWidgets('a vertical divider is 1 wide', (tester) async {
    await _pumpDivider(tester, axis: 'vertical');

    expect(tester.getSize(_line()).width, 1);
  });

  testWidgets('a divider follows a change to its axis', (tester) async {
    final processor = await _pumpDivider(tester);

    processor.apply([
      updateComponents([
        {'id': 'root', 'component': 'Divider', 'axis': 'vertical'},
      ]),
    ]);
    await tester.pump();

    expect(tester.getSize(_line()).width, 1);
  });
}

// The line a divider draws.
Finder _line() => find.descendant(of: find.byType(A2UIFill), matching: find.byType(ColoredBox));

// Shows a root divider along [axis] in a surface 300 wide, and returns the
// processor.
Future<A2UIProcessor> _pumpDivider(WidgetTester tester, {String? axis = 'horizontal'}) {
  return pumpSurface(
    tester,
    components: [
      {'id': 'root', 'component': 'Divider', 'axis': ?axis},
    ],
    width: 300,
  );
}
