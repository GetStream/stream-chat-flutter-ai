import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_fill.dart';

import '../../a2ui_test_app.dart';
import 'a2ui_layout_test_support.dart';

void main() {
  testWidgets("a card's child is 12 from its edges", (tester) async {
    await _pumpCard(tester);

    expect(imageOffset(tester, 'a', _card()), const Offset(12, 12));
  });

  testWidgets('a card is as wide as it is given', (tester) async {
    await _pumpCard(tester);

    expect(tester.getSize(_card()).width, 300);
  });

  testWidgets('a card shows the surface color', (tester) async {
    await _pumpCard(tester);

    expect((tester.widget<DecoratedBox>(_card()).decoration as BoxDecoration).color, lightTheme().surface);
  });

  testWidgets("a card's corners have the corner radius", (tester) async {
    await _pumpCard(tester);

    expect(
      (tester.widget<DecoratedBox>(_card()).decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(lightTheme().cornerRadius),
    );
  });

  testWidgets('a card whose child has not arrived shows its empty box', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {'id': 'root', 'component': 'Card', 'child': 'later'},
      ],
      width: 300,
    );

    // The card's padding above and below nothing.
    expect(tester.getSize(_card()), const Size(300, 12 + 12));
  });

  testWidgets('a short text in a card keeps its own width', (tester) async {
    await _pumpTextCard(tester);

    final text = tester.renderObject<RenderBox>(find.text('Short'));
    expect(text.size.width, text.getMaxIntrinsicWidth(double.infinity));
  });

  testWidgets('a card with a short text is as wide as it is given', (tester) async {
    await _pumpTextCard(tester);

    expect(tester.getSize(_card()).width, 300);
  });
}

// The box a card draws.
Finder _card() => find.descendant(of: find.byType(A2UIFill), matching: find.byType(DecoratedBox));

// Shows a root card 300 wide around an icon image `a`.
Future<void> _pumpCard(WidgetTester tester) async {
  await pumpSurface(
    tester,
    components: [
      {'id': 'root', 'component': 'Card', 'child': 'a'},
      iconImage('a'),
    ],
    width: 300,
    mediaUrl: (url) => null,
  );
}

// Shows a root card 300 wide around the text `Short`.
Future<void> _pumpTextCard(WidgetTester tester) async {
  await pumpSurface(
    tester,
    components: [
      {'id': 'root', 'component': 'Card', 'child': 'text'},
      {'id': 'text', 'component': 'Text', 'text': 'Short'},
    ],
    width: 300,
  );
}
