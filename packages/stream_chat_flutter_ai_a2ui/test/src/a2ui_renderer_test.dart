import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

void main() {
  test('A2UIRenderer reads the ways agents write A2UI 1.0, and no version', () {
    const renderer = A2UIRenderer();

    for (final version in [null, '1', '1.0', '1.0.0', 'v1', 'v1.0']) {
      expect(renderer.supports(version), isTrue, reason: '$version');
    }
  });

  test('A2UIRenderer reads no other version', () {
    const renderer = A2UIRenderer();

    for (final version in ['V1', '0.9', 'v0.9', '1.1', '2.0', '']) {
      expect(renderer.supports(version), isFalse, reason: version);
    }
  });

  test('A2UIRenderer shows the A2UI format', () {
    expect(const A2UIRenderer().format, AIUIFormat.a2ui);
  });

  test('A2UIRenderer tells the backend its fence and the app catalog id, and nothing else', () {
    final capabilities = const A2UIRenderer().capabilities(const [], const []);

    expect(capabilities, {'fence': 'ui:a2ui@1.0', 'catalog_id': 'getstream.io:app-catalog'});
  });

  test('A2UIRenderer tells the backend the catalog id it was given', () {
    final capabilities = const A2UIRenderer(catalogId: 'acme:catalog').capabilities(const [], const []);

    expect(capabilities['catalog_id'], 'acme:catalog');
  });

  test("the host's capabilities hold the renderer's, with its format", () {
    final host = AIUIHost(renderers: [const A2UIRenderer()], send: (_) async {});
    addTearDown(host.dispose);

    expect(host.capabilities['renderers'], [
      {'fence': 'ui:a2ui@1.0', 'catalog_id': 'getstream.io:app-catalog', 'format': 'a2ui'},
    ]);
  });

  test('A2UIRenderer.version is 1.0', () {
    expect(A2UIRenderer.version, '1.0');
  });

  test('A2UIRenderer.fence labels a block of A2UI 1.0', () {
    expect(A2UIRenderer.fence, 'ui:a2ui@1.0');
  });

  test("A2UIRenderer.defaultCatalogId is Stream's app catalog id", () {
    expect(A2UIRenderer.defaultCatalogId, 'getstream.io:app-catalog');
  });

  test('A2UIRenderer.basicCatalogId is the id of the A2UI 1.0 basic catalog', () {
    expect(A2UIRenderer.basicCatalogId, 'https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json');
  });

  test('A2UIRenderer.webUrl keeps http and https links in any capitalization', () {
    for (final url in ['http://a.test/x.png', 'https://a.test/x.png', 'HTTPS://a.test/x.png']) {
      expect(A2UIRenderer.webUrl(Uri.parse(url)), Uri.parse(url), reason: url);
    }
  });

  test('A2UIRenderer.webUrl refuses any other link', () {
    for (final url in ['file:///x.png', 'data:image/png;base64,AA==', 'mailto:a@b.test', 'ftp://a.test/x']) {
      expect(A2UIRenderer.webUrl(Uri.parse(url)), isNull, reason: url);
    }
  });

  test('A2UIRenderer loads media through webUrl unless it is given another function', () {
    expect(const A2UIRenderer().mediaUrl, A2UIRenderer.webUrl);
  });
}
