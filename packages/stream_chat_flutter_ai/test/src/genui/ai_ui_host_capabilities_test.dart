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

  test("AIUIHost.capabilities gives each renderer the app's tool definitions, sorted by name", () {
    final renderer = _ToolsRenderer();

    testHost(
      renderers: [renderer],
      tools: const [_Tool('send_email'), _Tool('list_events', isReadOnly: true)],
    ).capabilities;

    expect(renderer.tools, [
      const AIToolDefinition(name: 'list_events', description: 'list_events', isReadOnly: true),
      const AIToolDefinition(name: 'send_email', description: 'send_email'),
    ]);
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
  Map<String, Object?> capabilities(List<AIUIComponent<Object?>> components, List<AIToolDefinition> tools) => added;

  @override
  AIUIEngine createEngine(AIUIHosting host) => TestEngine(host);
}

class _PlaceCard extends PlaceCardComponent {
  const _PlaceCard(this.definition);

  @override
  final AIUIComponentDefinition definition;
}

// A renderer that keeps the tools it was last given.
class _ToolsRenderer extends AIUIRenderer {
  List<AIToolDefinition> tools = const [];

  @override
  AIUIFormat get format => AIUIFormat.openUI;

  @override
  Map<String, Object?> capabilities(List<AIUIComponent<Object?>> components, List<AIToolDefinition> tools) {
    this.tools = tools;
    return const {};
  }

  @override
  AIUIEngine createEngine(AIUIHosting host) => TestEngine(host);
}

// A tool called [name], described by its name.
class _Tool extends AIResultClientTool {
  const _Tool(this.name, {this.isReadOnly = false});

  final String name;
  final bool isReadOnly;

  @override
  AIToolDefinition get definition => AIToolDefinition(name: name, description: name, isReadOnly: isReadOnly);

  @override
  Future<AIClientToolResult> run(AIToolCallPart call) async => AIClientToolResult.completed(null);
}
