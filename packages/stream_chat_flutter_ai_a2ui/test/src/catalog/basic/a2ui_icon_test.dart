import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_icon.dart';

import '../../a2ui_test_app.dart';

void main() {
  test("the icons are the basic catalog's 59 names", () {
    expect(a2uiIcons.keys.toSet(), _catalogIconNames());
  });

  test('no catalog name shows the help icon of an unknown name, except help itself', () {
    final helpless = [
      for (final MapEntry(:key, :value) in a2uiIcons.entries)
        if (value == Icons.help_rounded && key != 'help') key,
    ];

    expect(helpless, isEmpty);
  });

  test('each catalog name has its own icon', () {
    expect(a2uiIcons.values.toSet(), hasLength(a2uiIcons.length));
  });

  testWidgets('an icon shows the icon of its name', (tester) async {
    await _pumpIcon(tester, 'star');

    expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.star_rounded);
  });

  testWidgets('a name the catalog does not have shows the help icon', (tester) async {
    await _pumpIcon(tester, 'unicorn');

    expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.help_rounded);
  });

  testWidgets('an icon is 24 wide', (tester) async {
    await _pumpIcon(tester, 'star');

    expect(tester.getSize(find.byType(Icon)), const Size.square(24));
  });

  testWidgets('an icon is in the text color', (tester) async {
    await _pumpIcon(tester, 'star');

    expect(_iconColor(tester), lightTheme().text);
  });

  testWidgets("an icon's name is its label", (tester) async {
    await _pumpIcon(tester, 'star');

    expect(tester.widget<Icon>(find.byType(Icon)).semanticLabel, 'star');
  });

  testWidgets('an icon bound to the data model shows the icon of its value', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Icon',
          'name': {'@path': '/icon'},
        },
      ],
      data: {'icon': 'home'},
    );

    expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.home_rounded);
  });

  testWidgets('a name bound to data that is not there shows the help icon', (tester) async {
    await _pumpBoundIcon(tester, data: {});

    expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.help_rounded);
  });

  testWidgets('a name bound to data that is not text is not the label', (tester) async {
    await _pumpBoundIcon(tester, data: {'icon': 7});

    expect(tester.widget<Icon>(find.byType(Icon)).semanticLabel, isNull);
  });

  testWidgets('an SVG path is drawn as a picture', (tester) async {
    await _pumpPath(tester, 'M6 6h12v12H6z');

    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('an SVG path is 24 wide', (tester) async {
    await _pumpPath(tester, 'M6 6h12v12H6z');

    expect(tester.getSize(find.byType(SvgPicture)), const Size.square(24));
  });

  testWidgets('an SVG path is in the text color', (tester) async {
    await _pumpPath(tester, 'M6 6h12v12H6z');

    expect(
      tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter,
      ColorFilter.mode(lightTheme().text, BlendMode.srcIn),
    );
  });

  test('a quote in a path stays inside the path', () {
    expect(a2uiSvgOf('M6 6h12" fill="red'), contains('d="M6 6h12&quot; fill=&quot;red"'));
  });

  test('angle brackets in a path add no element to the picture', () {
    expect(a2uiSvgOf('M6 6"/><circle r="9'), isNot(contains('<circle')));
  });

  test('an ampersand in a path stays a character', () {
    expect(a2uiSvgOf('M6&6'), contains('M6&amp;6'));
  });

  testWidgets('a path that cannot be drawn shows the help icon', (tester) async {
    await _pumpPath(tester, '<not a path>');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.help_rounded), findsOneWidget);
  });
}

Future<void> _pumpIcon(WidgetTester tester, String name) async {
  await pumpSurface(
    tester,
    components: [
      {'id': 'root', 'component': 'Icon', 'name': name},
    ],
  );
}

// Shows an icon whose name is bound to `/icon` in [data].
Future<void> _pumpBoundIcon(WidgetTester tester, {required Map<String, Object?> data}) async {
  await pumpSurface(
    tester,
    components: [
      {
        'id': 'root',
        'component': 'Icon',
        'name': {'@path': '/icon'},
      },
    ],
    data: data,
  );
}

Future<void> _pumpPath(WidgetTester tester, String path) async {
  await pumpSurface(
    tester,
    components: [
      {
        'id': 'root',
        'component': 'Icon',
        'name': {'svgPath': path},
      },
    ],
  );
}

Color? _iconColor(WidgetTester tester) {
  final element = tester.element(find.byType(Icon));
  return (element.widget as Icon).color ?? IconTheme.of(element).color;
}

// The icon names the basic catalog lists, as vendored with the conformance
// suites in the workspace's `stream_chat_flutter_ai_a2ui_conformance` package.
Set<String> _catalogIconNames() {
  final catalog = jsonDecode(
    File('../stream_chat_flutter_ai_a2ui_conformance/test/upstream/catalogs/basic/v1/catalog.json').readAsStringSync(),
  );
  final name = (catalog as Map<String, Object?>)['components']! as Map<String, Object?>;
  final icon = (name['Icon']! as Map<String, Object?>)['properties']! as Map<String, Object?>;
  final oneOf = (icon['name']! as Map<String, Object?>)['oneOf']! as List<Object?>;
  final names = (oneOf.first! as Map<String, Object?>)['enum']! as List<Object?>;
  return names.cast<String>().toSet();
}
