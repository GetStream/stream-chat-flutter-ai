import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'genui_fixtures.dart';
import 'genui_test_doubles.dart';

void main() {
  test("AIUIHost.capabilities lists each format, with what its renderer adds, and the app's components", () {
    final host = testHost(
      renderers: [TestRenderer(), _CatalogRenderer()],
      components: [_PlaceCard(AIUIComponentDefinition.fromJson(genuiFixture('definition_place_card.json')))],
    );

    final capabilities = overTheWire(host.capabilities);

    expect(capabilities, genuiFixture('capabilities_place_card.json'));
  });

  test("AIUIHost.capabilities names each renderer's format over a format of its own", () {
    final host = testHost(
      renderers: [
        _CatalogRenderer.withCapabilities({'format': 'other'}),
      ],
    );

    final renderers = host.capabilities['renderers']! as List<Object?>;

    expect((renderers.single! as Map<String, Object?>)['format'], AIUIFormat.a2ui);
  });

  test('AIUIHost.capabilities shares nothing with what a renderer adds', () {
    final added = <String, Object?>{
      'catalog': <String, Object?>{'id': 'trips'},
    };
    final host = testHost(renderers: [_CatalogRenderer.withCapabilities(added)]);

    final renderers = host.capabilities['renderers']! as List<Object?>;
    ((renderers.single! as Map<String, Object?>)['catalog']! as Map<String, Object?>)['id'] = 'changed';

    expect(added, {
      'catalog': {'id': 'trips'},
    });
  });
}

class _CatalogRenderer extends AIUIRenderer {
  _CatalogRenderer()
    : added = const {
        'catalog': {'id': 'trips', 'version': '1.0'},
      };

  _CatalogRenderer.withCapabilities(this.added);

  final Map<String, Object?> added;

  @override
  AIUIFormat get format => AIUIFormat.a2ui;

  @override
  Map<String, Object?> capabilities(List<AIUIComponent<Object?>> components) => added;

  @override
  AIUIEngine makeEngine(AIUIHosting host) => TestEngine(host);
}

class _PlaceCard extends PlaceCardComponent {
  const _PlaceCard(this.definition);

  @override
  final AIUIComponentDefinition definition;
}
