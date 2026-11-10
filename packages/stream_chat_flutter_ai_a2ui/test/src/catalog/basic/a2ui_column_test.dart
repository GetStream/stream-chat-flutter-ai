import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_flex.dart';

import '../../a2ui_test_app.dart';
import 'a2ui_layout_test_support.dart';

// A column 300 wide of 24 by 24 icon images, 8 apart.
void main() {
  testWidgets('the children are one below the other, 8 apart', (tester) async {
    await _pumpColumn(tester);

    expect(imageOffset(tester, 'b', find.byType(A2UIFlex)).dy, 32);
  });

  testWidgets('a column is as wide as it is given when it stretches its children', (tester) async {
    await _pumpColumn(tester);

    expect(tester.getSize(find.byType(A2UIFlex)).width, 300);
  });

  testWidgets('a stretched child starts at the start', (tester) async {
    await _pumpColumn(tester);

    expect(imageOffset(tester, 'a', find.byType(A2UIFlex)).dx, 0);
  });

  testWidgets('a stretched child keeps its own width', (tester) async {
    await _pumpColumn(tester);

    expect(tester.getSize(imageBox('a')).width, 24);
  });

  testWidgets('align center places a child in the middle', (tester) async {
    await _pumpColumn(
      tester,
      align: 'center',
      children: [
        iconImage('a'),
        iconImage('b', variant: 'avatar'),
      ],
    );

    // The column is as wide as its widest child, the avatar.
    expect(imageOffset(tester, 'a', find.byType(A2UIFlex)).dx, (48 - 24) / 2);
  });

  testWidgets('align end places a child at the end', (tester) async {
    await _pumpColumn(
      tester,
      align: 'end',
      children: [
        iconImage('a'),
        iconImage('b', variant: 'avatar'),
      ],
    );

    // The column is as wide as the avatar.
    expect(imageOffset(tester, 'a', find.byType(A2UIFlex)).dx, 48 - 24);
  });

  testWidgets('right to left, a stretched child starts at the right', (tester) async {
    await _pumpColumn(tester, direction: TextDirection.rtl);

    expect(tester.getTopRight(imageBox('a')).dx, tester.getTopRight(find.byType(A2UIFlex)).dx);
  });

  testWidgets('a column without a height of its own is as tall as its children', (tester) async {
    await _pumpColumn(tester, justify: 'end');

    expect(tester.getSize(find.byType(A2UIFlex)).height, 24 + 8 + 24);
  });

  testWidgets('a weighted child of a column without a height keeps its own height', (tester) async {
    await _pumpColumn(
      tester,
      children: [
        {...iconImage('a'), 'weight': 1},
        iconImage('b'),
      ],
    );

    // The image above, 24 tall, and the gap.
    expect(imageOffset(tester, 'b', find.byType(A2UIFlex)).dy, 24 + 8);
  });

  testWidgets('a card in a column is as wide as the column', (tester) async {
    await _pumpColumn(
      tester,
      children: [
        {'id': 'card', 'component': 'Card', 'child': 'a'},
        iconImage('a'),
      ],
    );

    expect(tester.getSize(find.byWidgetPredicate((widget) => widget is DecoratedBox)).width, 300);
  });

  testWidgets('a row whose text wraps is as tall as the wrapped text', (tester) async {
    await _pumpColumn(
      tester,
      children: [
        {
          'id': 'row',
          'component': 'Row',
          'children': ['icon', 'long'],
        },
        iconImage('icon'),
        _text('long', _longText()),
      ],
    );

    // The row nearest the text.
    final row = find.ancestor(of: find.text(_longText()), matching: find.byType(A2UIFlex)).first;
    expect(tester.getSize(row).height, _wrappedHeight(tester, _longText()));
  });

  testWidgets('a column given the height of the row around it shows its wrapped text whole', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Row',
          'children': ['column'],
        },
        {
          'id': 'column',
          'component': 'Column',
          'children': ['row', 'after'],
          'weight': 1,
        },
        {
          'id': 'row',
          'component': 'Row',
          'children': ['first', 'second'],
        },
        _text('first', _longText()),
        _text('second', 'And a second ${_longText()}'),
        _text('after', 'After'),
      ],
      width: 300,
    );

    expect(tester.getSize(find.text(_longText())).height, _wrappedHeight(tester, _longText()));
  });
}

// Text that takes more than one line in half a column 300 wide.
String _longText() => 'A long label that wraps onto several lines in a column three hundred wide';

// A text component.
Map<String, Object?> _text(String id, String text) => {'id': id, 'component': 'Text', 'text': text};

// The height [text] needs at the width it is shown at.
double _wrappedHeight(WidgetTester tester, String text) {
  final box = tester.renderObject<RenderBox>(find.text(text));
  return box.getMinIntrinsicHeight(box.size.width);
}

// Shows a root column 300 wide of [children], two icon images by default.
Future<void> _pumpColumn(
  WidgetTester tester, {
  String? justify,
  String? align,
  List<Map<String, Object?>>? children,
  TextDirection direction = TextDirection.ltr,
}) async {
  final items = children ?? [iconImage('a'), iconImage('b')];
  await pumpSurface(
    tester,
    components: [
      {'id': 'root', 'component': 'Column', 'children': _topLevel(items), 'justify': ?justify, 'align': ?align},
      ...items,
    ],
    width: 300,
    direction: direction,
    mediaUrl: (url) => null,
  );
}

// The ids of [items] no other item holds.
List<Object?> _topLevel(List<Map<String, Object?>> items) {
  final held = {
    for (final item in items) ...[item['child'], ...?item['children'] as List<Object?>?],
  };
  return [
    for (final item in items)
      if (!held.contains(item['id'])) item['id'],
  ];
}
