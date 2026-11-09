import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_fill.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_flex.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import '../../a2ui_test_app.dart';
import 'a2ui_layout_test_support.dart';

// A row or a column 300 wide, changed after it first shows, and the sizes the
// dry layouts of a row, a column and a divider give.
void main() {
  testWidgets("a weighted child's share follows a change to its weight", (tester) async {
    final processor = await _pumpRow(tester, children: [_text('a', 'A', weight: 1), _text('b', 'B', weight: 1)]);

    processor.apply([
      updateComponents([_text('a', 'A', weight: 3)]),
    ]);
    await tester.pump();

    // Three quarters of what is left after the gap go to the first.
    expect(tester.getTopLeft(find.text('B')).dx, (300 - 8) * 3 / 4 + 8);
  });

  testWidgets("a row's children follow a change to its justify", (tester) async {
    final processor = await _pumpRow(tester, children: [iconImage('a'), iconImage('b')]);

    processor.apply([
      updateComponents([
        _row(['a', 'b'], justify: 'end'),
      ]),
    ]);
    await tester.pump();

    // The last image ends at the row's end.
    expect(tester.getTopLeft(imageBox('b')).dx, 300 - 24);
  });

  testWidgets("a row's children follow a change to the text direction", (tester) async {
    final processor = await _pumpRow(tester, children: [iconImage('a'), iconImage('b')]);

    await tester.pumpWidget(
      surfaceApp(processor.surface('s')!, direction: TextDirection.rtl, width: 300, mediaUrl: (url) => null),
    );

    expect(tester.getTopRight(imageBox('a')).dx, tester.getTopRight(find.byType(A2UIFlex)).dx);
  });

  testWidgets("a row's dry layout is the size it lays out at", (tester) async {
    await _pumpRow(tester, children: [iconImage('a'), _text('b', _longText())]);

    final row = tester.renderObject<RenderBox>(find.byType(A2UIFlex));
    expect(row.getDryLayout(row.constraints), row.size);
  });

  testWidgets("a column's dry layout is the size it lays out at", (tester) async {
    await pumpSurface(
      tester,
      components: inColumn([iconImage('a'), _text('b', _longText())]),
      width: 300,
      mediaUrl: (url) => null,
    );

    final column = tester.renderObject<RenderBox>(find.byType(A2UIFlex));
    expect(column.getDryLayout(column.constraints), column.size);
  });

  testWidgets("a divider's dry layout is the size it lays out at", (tester) async {
    await pumpSurface(
      tester,
      components: inColumn([
        {'id': 'line', 'component': 'Divider'},
      ]),
      width: 300,
    );

    final line = tester.renderObject<RenderBox>(find.byType(A2UIFill));
    expect(line.getDryLayout(line.constraints), line.size);
  });
}

// Text that takes more than one line in a row 300 wide.
String _longText() => 'A long label that wraps onto several lines in a row three hundred wide';

// A text component, with [weight] when given.
Map<String, Object?> _text(String id, String text, {num? weight}) => {
  'id': id,
  'component': 'Text',
  'text': text,
  'weight': ?weight,
};

// The root row of the children with [ids].
Map<String, Object?> _row(List<String> ids, {String? justify}) => {
  'id': 'root',
  'component': 'Row',
  'children': ids,
  'justify': ?justify,
};

// Shows a root row 300 wide of [children], and returns the processor.
Future<A2UIProcessor> _pumpRow(WidgetTester tester, {required List<Map<String, Object?>> children}) {
  return pumpSurface(
    tester,
    components: [
      _row([for (final child in children) child['id']! as String]),
      ...children,
    ],
    width: 300,
    mediaUrl: (url) => null,
  );
}
