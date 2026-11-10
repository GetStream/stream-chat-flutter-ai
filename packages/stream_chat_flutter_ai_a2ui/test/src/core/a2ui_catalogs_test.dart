import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

void main() {
  test("the app's catalog id is getstream.io:app-catalog by default", () {
    expect(A2UICatalogs().catalogId, 'getstream.io:app-catalog');
  });

  test("a surface in the app's catalog gets the basic components", () {
    final surface = _surfaceWithText(catalogs: A2UICatalogs(), catalogId: A2UICatalogs.defaultCatalogId);

    expect(surface.root!.isResolved, isTrue);
  });

  test('a surface in the basic catalog gets the basic components', () {
    final surface = _surfaceWithText(catalogs: A2UICatalogs(), catalogId: A2UICatalogs.basicCatalogId);

    expect(surface.root!.isResolved, isTrue);
  });

  test("a surface in an app's catalog named otherwise gets the basic components", () {
    final surface = _surfaceWithText(
      catalogs: A2UICatalogs(catalogId: 'acme'),
      catalogId: 'acme',
    );

    expect(surface.root!.isResolved, isTrue);
  });

  test("an app's catalog named like the basic catalog is the basic catalog", () {
    final surface = _surfaceWithText(
      catalogs: A2UICatalogs(catalogId: A2UICatalogs.basicCatalogId),
      catalogId: A2UICatalogs.basicCatalogId,
    );

    expect(surface.root!.isResolved, isTrue);
  });

  test("a surface in the app's catalog gets the basic functions", () {
    final processor = A2UIProcessor(catalogs: A2UICatalogs());
    addTearDown(processor.dispose);
    processor.apply([
      jsonEncode({
        'version': '1.0',
        'createSurface': {
          'surfaceId': 'plan',
          'catalogId': A2UICatalogs.defaultCatalogId,
          'dataModel': {'place': 'Ohrid'},
          'components': [
            {
              'id': 'root',
              'component': 'Text',
              'text': {
                '@call': 'formatString',
                'args': {'value': r'A weekend in ${/place}'},
              },
            },
          ],
        },
      }),
    ]);

    expect(processor.surface('plan')!.root!.property('text'), 'A weekend in Ohrid');
  });

  test('one catalogs object serves several processors', () {
    final catalogs = A2UICatalogs();
    final first = _surfaceWithText(catalogs: catalogs, catalogId: A2UICatalogs.defaultCatalogId);
    final second = _surfaceWithText(catalogs: catalogs, catalogId: A2UICatalogs.defaultCatalogId);

    expect(first.root!.isResolved && second.root!.isResolved, isTrue);
  });
}

A2UISurface _surfaceWithText({required A2UICatalogs catalogs, required String catalogId}) {
  final processor = A2UIProcessor(catalogs: catalogs);
  addTearDown(processor.dispose);
  processor.apply([
    jsonEncode({
      'version': '1.0',
      'createSurface': {
        'surfaceId': 'plan',
        'catalogId': catalogId,
        'components': [
          {'id': 'root', 'component': 'Text', 'text': 'Ohrid'},
        ],
      },
    }),
  ]);
  return processor.surface('plan')!;
}
