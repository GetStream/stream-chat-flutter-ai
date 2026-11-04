import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_fill.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_flex.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_view.dart';

import '../../a2ui_test_app.dart';
import 'a2ui_layout_test_support.dart';

void main() {
  testWidgets('a vertical list places its children one below the other, 8 apart', (tester) async {
    await _pumpList(tester);

    expect(imageOffset(tester, 'i1', find.byType(A2UIFlex)).dy, 32);
  });

  testWidgets('a vertical list does not scroll', (tester) async {
    await _pumpList(tester);

    expect(find.descendant(of: find.byType(A2UIFlex), matching: find.byType(Scrollable)), findsNothing);
  });

  testWidgets('a list is vertical without a direction', (tester) async {
    await _pumpList(tester);

    expect(imageOffset(tester, 'i1', find.byType(A2UIFlex)).dx, 0);
  });

  testWidgets('a horizontal list places its children side by side, 8 apart', (tester) async {
    await _pumpList(tester, direction: 'horizontal');

    expect(imageOffset(tester, 'i1', find.byType(A2UIFlex)).dx, 32);
  });

  testWidgets('a horizontal list scrolls', (tester) async {
    await _pumpList(tester, direction: 'horizontal');

    expect(
      tester
          .widget<SingleChildScrollView>(
            find.descendant(of: find.byType(A2UISurfaceView), matching: find.byType(SingleChildScrollView)),
          )
          .scrollDirection,
      Axis.horizontal,
    );
  });

  testWidgets('a horizontal list wider than the surface keeps its children their width', (tester) async {
    await _pumpList(tester, direction: 'horizontal', variants: List.filled(20, 'icon'));

    expect(tester.getSize(imageBox('i19')).width, 24);
  });

  testWidgets('a horizontal list of cards keeps each card its own width', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'List',
          'direction': 'horizontal',
          'children': ['card'],
        },
        {'id': 'card', 'component': 'Card', 'child': 'i0'},
        iconImage('i0'),
      ],
      mediaUrl: (url) => null,
    );

    // The card's padding on both sides, and the image.
    final card = find.descendant(of: find.byType(A2UIFill), matching: find.byType(DecoratedBox));
    expect(tester.getSize(card).width, 12 + 24 + 12);
  });

  testWidgets('align center places a child of a vertical list in the middle', (tester) async {
    await _pumpList(tester, align: 'center', variants: const ['icon', 'avatar']);

    // The list is as wide as its widest child, the avatar.
    expect(imageOffset(tester, 'i0', find.byType(A2UIFlex)).dx, (48 - 24) / 2);
  });

  testWidgets('a template gives a child for each item, in order', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'List',
          'children': {'componentId': 'item', 'path': '/places'},
        },
        {
          'id': 'item',
          'component': 'Text',
          'text': {'@path': 'name'},
        },
      ],
      data: {
        'places': [
          {'name': 'Plaošnik'},
          {'name': 'Kaneo'},
        ],
      },
    );

    expect(tester.getTopLeft(find.text('Kaneo')).dy, greaterThan(tester.getTopLeft(find.text('Plaošnik')).dy));
  });
}

// A list 300 wide of icon images i0, i1, …, of [variants], 24 by 24 for an
// icon and 48 by 48 for an avatar.
Future<void> _pumpList(
  WidgetTester tester, {
  String? direction,
  String? align,
  List<String> variants = const ['icon', 'icon'],
}) async {
  final images = [
    for (var index = 0; index < variants.length; index += 1) iconImage('i$index', variant: variants[index]),
  ];
  await pumpSurface(
    tester,
    components: [
      {
        'id': 'root',
        'component': 'List',
        'children': [for (final image in images) image['id']],
        'direction': ?direction,
        'align': ?align,
      },
      ...images,
    ],
    width: 300,
    mediaUrl: (url) => null,
  );
}
