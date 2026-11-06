import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_flex.dart';

import '../../a2ui_test_app.dart';

// A child that fills the width it is given, such as a text field, shares the
// free space of a row with a width as if its weight were 1.
void main() {
  testWidgets('a text beside a field keeps its own width', (tester) async {
    await pumpSurface(tester, components: _row([_text('Who'), _field('name')]));

    expect(tester.getSize(find.text('Who')).width, lessThan(100));
  });

  testWidgets('a field beside a text longer than the row keeps an equal share of it', (tester) async {
    await pumpSurface(
      tester,
      components: _row([
        _text('A caption long enough to fill the whole row on its own, and then some more words'),
        _field('name'),
      ]),
    );

    expect(tester.getSize(find.byType(TextField)).width, 196);
  });

  testWidgets('two fields without weights share the row equally', (tester) async {
    await pumpSurface(tester, components: _row([_field('first'), _field('last')]));

    final widths = tester.widgetList(find.byType(TextField)).map((field) => tester.getSize(find.byWidget(field)).width);
    expect(widths, [196, 196]);
  });

  testWidgets('a field without a weight shares the row with a weighted one as if its weight were 1', (tester) async {
    await pumpSurface(tester, components: _row([_field('first'), _field('last', weight: 2)]));

    final widths = [
      for (final field in tester.widgetList(find.byType(TextField))) tester.getSize(find.byWidget(field)).width,
    ];
    expect(widths.last, closeTo(widths.first * 2, 0.01));
  });

  testWidgets('a child that fills its width takes no free space of a column with a height', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 300,
            child: A2UIFlex(
              axis: Axis.vertical,
              justify: null,
              align: null,
              children: [
                A2UIFlexChild(weight: null, fills: true, child: SizedBox(height: 20)),
                A2UIFlexChild(weight: null, child: SizedBox(key: Key('next'), height: 20)),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.byKey(const Key('next'))).dy, 28);
  });

  testWidgets('a child of a column with a height keeps its height beside one that fills its width', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 300,
            child: A2UIFlex(
              axis: Axis.vertical,
              justify: null,
              align: null,
              children: [
                A2UIFlexChild(weight: 1, child: SizedBox.shrink()),
                A2UIFlexChild(weight: null, fills: true, child: SizedBox(height: 20)),
                A2UIFlexChild(weight: null, child: SizedBox(key: Key('tall'), height: 150)),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('tall'))).height, 150);
  });

  testWidgets('a field in a column is as wide as the column', (tester) async {
    await pumpSurface(tester, components: inColumn([_field('name')]));

    expect(tester.getSize(find.byType(TextField)).width, 400);
  });
}

List<Map<String, Object?>> _row(List<Map<String, Object?>> children) {
  return [
    {
      'id': 'root',
      'component': 'Row',
      'children': [for (final child in children) child['id']],
    },
    ...children,
  ];
}

Map<String, Object?> _text(String text) => {'id': 'caption', 'component': 'Text', 'text': text};

Map<String, Object?> _field(String id, {double? weight}) {
  return {
    'id': id,
    'component': 'TextField',
    'label': id,
    'value': {'@path': '/$id'},
    'weight': ?weight,
  };
}
