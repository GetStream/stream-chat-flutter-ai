import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_flex.dart';

import '../../a2ui_test_app.dart';
import 'a2ui_layout_test_support.dart';

// A row 300 wide of 24 wide icon images, 8 apart.
void main() {
  for (final (justify, lefts) in [
    ('start', [0.0, 32.0]),
    ('center', [122.0, 154.0]),
    ('end', [244.0, 276.0]),
    ('spaceBetween', [0.0, 276.0]),
    ('spaceAround', [61.0, 215.0]),
    ('spaceEvenly', [81.33333333333333, 194.66666666666666]),
  ]) {
    testWidgets('justify $justify places the children at $lefts', (tester) async {
      await _pumpRow(tester, justify: justify);

      expect(_lefts(tester), _near(lefts));
    });
  }

  testWidgets('without a justify, the children start at the start', (tester) async {
    await _pumpRow(tester);

    expect(_lefts(tester), _near([0, 32]));
  });

  testWidgets('justify stretch gives each child an equal share of the width', (tester) async {
    await _pumpRow(tester, justify: 'stretch', children: [_text('a', 'A'), _text('b', 'B')]);

    expect(tester.getTopLeft(find.text('B')).dx, 154);
  });

  testWidgets('a weighted child takes the free space', (tester) async {
    await _pumpRow(tester, children: [iconImage('a'), _text('b', 'B', weight: 1), iconImage('c')]);

    // The last image ends at the row's end.
    expect(tester.getTopLeft(imageBox('c')).dx, 300 - 24);
  });

  testWidgets('weighted children share the free space by weight', (tester) async {
    await _pumpRow(tester, children: [_text('a', 'A', weight: 1), _text('b', 'B', weight: 3)]);

    // A quarter of what is left after the gap goes to the first.
    expect(tester.getTopLeft(find.text('B')).dx, (300 - 8) / 4 + 8);
  });

  testWidgets('a row is as wide as it is given', (tester) async {
    await _pumpRow(tester);

    expect(tester.getSize(find.byType(A2UIFlex)).width, 300);
  });

  testWidgets('children that do not fit shrink to fit', (tester) async {
    await _pumpRow(tester, children: [_text('a', 'A long first label that does not fit'), _text('b', 'B')]);

    expect(tester.getBottomRight(find.text('B')).dx, lessThanOrEqualTo(300));
  });

  for (final (align, top) in [('start', 0.0), ('center', 12.0), ('end', 24.0), ('stretch', 0.0)]) {
    testWidgets('align $align places a short child $top from the top', (tester) async {
      await _pumpRow(
        tester,
        align: align,
        children: [
          iconImage('a'),
          iconImage('b', variant: 'avatar'),
        ],
      );

      expect(tester.getTopLeft(imageBox('a')).dy, top);
    });
  }

  testWidgets('a short child keeps its height when the row stretches its children', (tester) async {
    await _pumpRow(
      tester,
      align: 'stretch',
      children: [
        iconImage('a'),
        iconImage('b', variant: 'avatar'),
      ],
    );

    expect(tester.getSize(imageBox('a')).height, 24);
  });

  testWidgets('a vertical divider in a stretched row is as tall as the row', (tester) async {
    await _pumpRow(
      tester,
      children: [
        iconImage('a', variant: 'avatar'),
        {'id': 'line', 'component': 'Divider', 'axis': 'vertical'},
      ],
    );

    expect(tester.getSize(find.byWidgetPredicate((widget) => widget is SizedBox && widget.width == 1)).height, 48);
  });

  testWidgets('a vertical divider in a centered row is as tall as the row', (tester) async {
    await _pumpRow(
      tester,
      align: 'center',
      children: [
        iconImage('a', variant: 'avatar'),
        {'id': 'line', 'component': 'Divider', 'axis': 'vertical', 'weight': 1},
      ],
    );

    expect(tester.getSize(find.byWidgetPredicate((widget) => widget is SizedBox && widget.width == 1)).height, 48);
  });

  testWidgets('a vertical divider in a row aligned to the start is as tall as the row', (tester) async {
    await _pumpRow(
      tester,
      align: 'start',
      children: [
        iconImage('a', variant: 'avatar'),
        {'id': 'line', 'component': 'Divider', 'axis': 'vertical'},
      ],
    );

    expect(tester.getSize(find.byWidgetPredicate((widget) => widget is SizedBox && widget.width == 1)).height, 48);
  });

  testWidgets('a vertical divider whose axis is bound in a centered row is as tall as the row', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Row',
          'children': ['a', 'line'],
          'align': 'center',
        },
        iconImage('a', variant: 'avatar'),
        {
          'id': 'line',
          'component': 'Divider',
          'axis': {'@path': '/axis'},
        },
      ],
      data: {'axis': 'vertical'},
      width: 300,
      mediaUrl: (url) => null,
    );

    expect(tester.getSize(find.byWidgetPredicate((widget) => widget is SizedBox && widget.width == 1)).height, 48);
  });

  testWidgets('an icon image next to long text keeps its width', (tester) async {
    await _pumpRow(tester, children: [iconImage('a'), _text('b', _longText())]);

    expect(tester.getSize(imageBox('a')).width, 24);
  });

  testWidgets('an icon next to long text keeps its width', (tester) async {
    await _pumpRow(
      tester,
      children: [
        {'id': 'a', 'component': 'Icon', 'name': 'star'},
        _text('b', _longText()),
      ],
    );

    expect(tester.getSize(find.byType(Icon)).width, 24);
  });

  testWidgets('long text next to an icon image takes the rest of the width', (tester) async {
    await _pumpRow(tester, children: [iconImage('a'), _text('b', _longText())]);

    // The row less the image and the gap.
    expect(tester.getSize(find.text(_longText())).width, 300 - 24 - 8);
  });

  testWidgets('long text next to an icon image wraps', (tester) async {
    await _pumpRow(tester, children: [iconImage('a'), _text('b', _longText())]);

    expect(tester.getSize(find.text(_longText())).height, greaterThan(_lineHeight(tester, _longText())));
  });

  testWidgets('long text in a column next to an icon image wraps within the row', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Row',
          'children': ['a', 'column'],
        },
        iconImage('a'),
        {
          'id': 'column',
          'component': 'Column',
          'children': ['b', 'c'],
        },
        _text('b', _longText()),
        _text('c', 'Short'),
      ],
      width: 300,
      mediaUrl: (url) => null,
    );

    // The row less the image and the gap.
    expect(tester.getRect(find.text(_longText())).right, 300);
    expect(tester.getSize(find.text(_longText())).width, 300 - 24 - 8);
  });

  testWidgets("a row's least height at its width is the height of its wrapped text", (tester) async {
    await _pumpRow(tester, children: [iconImage('a'), _text('b', _longText())]);

    expect(tester.renderObject<RenderBox>(find.byType(A2UIFlex)).getMinIntrinsicHeight(300), _wrappedHeight(tester));
  });

  testWidgets('children with huge weights lay out without an error', (tester) async {
    await _pumpRow(tester, children: [_text('a', 'A', weight: 1e308), _text('b', 'B', weight: 1e308)]);

    expect(tester.takeException(), isNull);
  });

  testWidgets('children with equal huge weights share the width equally', (tester) async {
    await _pumpRow(tester, children: [_text('a', 'A', weight: 1e308), _text('b', 'B', weight: 1e308)]);

    // Half of what is left after the gap goes to the first.
    expect(tester.getTopLeft(find.text('B')).dx, (300 - 8) / 2 + 8);
  });

  testWidgets('a child with a huge weight takes the free space', (tester) async {
    await _pumpRow(tester, children: [_text('a', 'A', weight: 1e308), iconImage('b')]);

    // The image after it ends at the row's end.
    expect(tester.getTopLeft(imageBox('b')).dx, 300 - 24);
  });

  testWidgets('right to left, the first child is at the right', (tester) async {
    await _pumpRow(tester, direction: TextDirection.rtl);

    expect(tester.getTopRight(imageBox('a')).dx, tester.getTopRight(find.byType(A2UIFlex)).dx);
  });

  testWidgets("right to left, a weighted child narrower than its share is at the share's right", (tester) async {
    await _pumpRow(
      tester,
      direction: TextDirection.rtl,
      children: [_text('a', 'A', weight: 1), _text('b', 'B', weight: 1)],
    );

    expect(tester.getTopRight(find.text('A')).dx, tester.getTopRight(find.byType(A2UIFlex)).dx);
  });
}

// Text that takes more than one line in a row 300 wide.
String _longText() => 'A long label that wraps onto several lines in a row three hundred wide';

// The height the long text needs at the width it is shown at.
double _wrappedHeight(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(find.text(_longText()));
  return box.getMinIntrinsicHeight(box.size.width);
}

// The height of one line of [text], as it shows with no width limit.
double _lineHeight(WidgetTester tester, String text) =>
    tester.renderObject<RenderBox>(find.text(text)).getMinIntrinsicHeight(double.infinity);

// A text component, with [weight] when given.
Map<String, Object?> _text(String id, String text, {num? weight}) => {
  'id': id,
  'component': 'Text',
  'text': text,
  'weight': ?weight,
};

// Shows a root row 300 wide of [children], two icon images by default.
Future<void> _pumpRow(
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
      {
        'id': 'root',
        'component': 'Row',
        'children': [for (final item in items) item['id']],
        'justify': ?justify,
        'align': ?align,
      },
      ...items,
    ],
    width: 300,
    direction: direction,
    mediaUrl: (url) => null,
  );
}

// The left edges of images `a` and `b`.
List<double> _lefts(WidgetTester tester) => [
  tester.getTopLeft(imageBox('a')).dx,
  tester.getTopLeft(imageBox('b')).dx,
];

// Matches lengths within 0.01 of [expected].
Matcher _near(List<double> expected) => pairwiseCompare<double, double>(
  expected,
  (expected, actual) => (expected - actual).abs() < 0.01,
  'near',
);
