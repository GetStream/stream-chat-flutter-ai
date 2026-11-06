part of 'a2ui_adapter.dart';

/// The catalogs of components and functions a reply's surfaces are drawn with.
///
/// A surface names its catalog by id when it is created. This holds the A2UI
/// 1.0 basic catalog under its own id, [basicCatalogId], and under [catalogId],
/// the id an agent names the app's catalog by, so a surface naming either one
/// gets the basic components and functions.
///
/// It doesn't change, so one can be shared by several [A2UIProcessor]s, such
/// as those of every reply in a chat.
///
/// Internal to the package.
@internal
final class A2UICatalogs {
  /// Creates the catalogs, with the app's catalog named [catalogId].
  A2UICatalogs({this.catalogId = defaultCatalogId}) : _catalogs = _assemble(catalogId);

  /// The catalogs a conformance case needs, the first of which is the app's.
  ///
  /// Only the conformance tests use it.
  A2UICatalogs.debug(List<A2UIDebugCatalog> catalogs)
    : catalogId = catalogs.first.id,
      _catalogs = [for (final catalog in catalogs) catalog._build()];

  /// The id of the app's catalog.
  final String catalogId;

  final List<core.Catalog<core.ComponentApi, core.FunctionImplementation>> _catalogs;

  static List<core.Catalog<core.ComponentApi, core.FunctionImplementation>> _assemble(String catalogId) {
    final basic = core.BasicCatalog.v1_0();
    if (catalogId == basic.id) return [basic];
    return [
      core.Catalog<core.ComponentApi, core.FunctionImplementation>(
        id: catalogId,
        components: basic.components.values.toList(),
        functions: basic.functions.values.toList(),
        themeSchema: basic.themeSchema,
        title: basic.title,
        description: basic.description,
        protocolVersion: basic.protocolVersion,
        instructions: basic.instructions,
        definitions: basic.definitions,
      ),
      basic,
    ];
  }

  /// The id an agent names the app's catalog by, unless it is told another.
  static const defaultCatalogId = 'getstream.io:app-catalog';

  /// The id of the A2UI 1.0 basic catalog.
  static const basicCatalogId = core.BasicCatalog.v1_0Id;
}
