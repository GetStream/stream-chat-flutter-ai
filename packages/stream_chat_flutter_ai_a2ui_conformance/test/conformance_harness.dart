part of 'a2ui_conformance.dart';

// A processor under test, with everything it reported, dispatched and sent.
final class _Harness {
  _Harness(List<A2UIDebugCatalog> catalogs, {A2UIDebugChecks? checks}) {
    processor = debugProcessor(
      catalogs: debugCatalogs(catalogs),
      onAction: actions.add,
      onError: errors.add,
      checks: checks,
      onOutbound: sent.add,
    );
    addTearDown(processor.dispose);
  }

  late final A2UIProcessor processor;
  final List<A2UIError> errors = [];
  final List<A2UIActionEvent> actions = [];
  final List<Map<String, Object?>> sent = [];

  void process(List<Object?> messages) {
    for (final message in messages) {
      processor.apply([jsonEncode(message)]);
    }
  }

  // Resolves every surface's tree, so problems its components hold are found,
  // and waits for them to be reported.
  Future<void> resolveSurfaces() async {
    for (final surfaceId in processor.surfaceIds) {
      final surface = processor.surface(surfaceId);
      if (surface != null) await _resolveComponents(surface);
    }
    await pumpEventQueue();
  }
}

List<A2UIDebugCatalog> _catalogPaths(Map<String, Object?> testCase) => [
  for (final path in (testCase['catalogPaths'] as List<Object?>?) ?? const [])
    if (path == 'catalogs/basic/v1/catalog.json')
      const A2UIDebugCatalog.basic(A2UICatalogs.basicCatalogId)
    else if (path is String && path.startsWith('conformance/test_data/catalogs/') && path.endsWith('_v1_0.json'))
      A2UIDebugCatalog.document(_document(path)),
  // A catalog of another protocol version isn't available to a 1.0 surface.
];

Map<String, Object?> _document(String path) =>
    jsonDecode(File('$_root/$path').readAsStringSync()) as Map<String, Object?>;

List<A2UIDebugCatalog> _catalogsFor(Map<String, Object?> testCase) {
  final catalogs = <String, A2UIDebugCatalog>{
    A2UICatalogs.basicCatalogId: const A2UIDebugCatalog.basic(A2UICatalogs.basicCatalogId),
    'basic': const A2UIDebugCatalog.basic('basic'),
  };
  A2UIDebugCatalog inline(Map<String, Object?> spec, String fallbackId) {
    final catalogId = (spec['catalogId'] as String?) ?? fallbackId;
    if (spec.containsKey('components') || spec.containsKey('functions')) {
      return A2UIDebugCatalog.document({...spec, 'catalogId': catalogId});
    }
    return A2UIDebugCatalog.basic(catalogId);
  }

  final catalog = testCase['catalog'];
  if (catalog is Map<String, Object?>) {
    if (catalog['catalogSchema'] case final Map<String, Object?> schema) {
      final document = A2UIDebugCatalog.document(schema);
      catalogs[document.id] = document;
    }
    if (catalog.containsKey('components') || catalog.containsKey('catalogId')) {
      final built = inline(catalog, 'catalog-${testCase['name']}');
      catalogs[built.id] = built;
    }
  }
  for (final spec in (testCase['catalogs'] as List<Object?>?) ?? const []) {
    if (spec is! Map<String, Object?>) continue;
    final schema = spec['catalogSchema'];
    final version = spec['protocolVersion'] ?? (schema is Map<String, Object?> ? schema['protocolVersion'] : null);
    // A catalog of another protocol version isn't available to a 1.0 surface.
    if (_otherVersions.contains(version)) continue;
    if (schema is Map<String, Object?>) {
      final document = A2UIDebugCatalog.document(schema);
      catalogs[document.id] = document;
    } else if (spec.containsKey('catalogId')) {
      final built = inline(spec, '');
      catalogs[built.id] = built;
    }
  }
  for (final path in (testCase['catalogPaths'] as List<Object?>?) ?? const []) {
    if (path is! String || !path.startsWith('conformance/test_data/catalogs/') || !path.endsWith('_v1_0.json')) {
      continue;
    }
    final document = _document(path);
    final built = A2UIDebugCatalog.document(document);
    catalogs[built.id] = built;
    catalogs.putIfAbsent('test-catalog', () => A2UIDebugCatalog.document(document, id: 'test-catalog'));
  }
  // A surface that names an unknown catalog gets one with the basic
  // components, unless the case is about that catalog being missing.
  final expectError = testCase['expectError'];
  final expectsCatalogError = expectError is Map<String, Object?> && expectError['category'] == 'CatalogError';
  if (!expectsCatalogError) {
    for (final id in _createSurfaceCatalogIds(testCase)) {
      catalogs.putIfAbsent(id, () => A2UIDebugCatalog.basic(id));
    }
  }
  return catalogs.values.toList();
}

const _otherVersions = {'v0.8', 'v0.9', 'v0.9.1'};

List<String> _createSurfaceCatalogIds(Object? value) => switch (value) {
  final Map<String, Object?> map => [
    if (map['createSurface'] case {'catalogId': final String id}) id,
    for (final item in map.values) ..._createSurfaceCatalogIds(item),
  ],
  final List<Object?> list => [for (final item in list) ..._createSurfaceCatalogIds(item)],
  _ => const [],
};
