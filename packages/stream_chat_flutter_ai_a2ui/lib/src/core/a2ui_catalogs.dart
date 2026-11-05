part of 'a2ui_adapter.dart';

/// The catalogs of components and functions a reply's surfaces are drawn with.
///
/// A surface names its catalog by id when it is created. This holds the A2UI
/// 1.0 basic catalog under its own id, [basicCatalogId], and under [catalogId],
/// the id an agent names the app's catalog by, so a surface naming either one
/// gets the basic components and functions.
///
/// A style property, such as a `Text`'s `variant` or a `Row`'s `justify`,
/// takes any value here: a component with a value its catalog doesn't list,
/// such as a `variant` of `h1`, is kept, and is drawn in the property's
/// default style. One bound to the data model is read from it, as any
/// property is, and is drawn in the default style too. An `Icon`'s `name`
/// takes any string, so an icon of a name the catalog doesn't have is kept
/// too, and shows a fallback. Every other property is checked as the catalog
/// lists it.
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

  /// The id an agent names the app's catalog by, unless it is told another.
  static const defaultCatalogId = 'getstream.io:app-catalog';

  /// The id of the A2UI 1.0 basic catalog.
  static const basicCatalogId = core.BasicCatalog.v1_0Id;

  // The properties that only choose how a component looks. The catalog lists
  // the strings each one takes, and the core would drop a whole component for
  // any other value; a builder reads the value and falls back to the default
  // style instead, so the component still shows.
  static const _styleProperties = {'variant', 'fit', 'justify', 'align', 'direction', 'axis', 'displayStyle'};

  // Any value the agent writes: a string, number, boolean, list or map as it
  // is, or a binding or function call, which the core reads as it reads a
  // `DynamicValue`.
  static const _anyValue = {
    'anyOf': [
      {r'$ref': r'common_types.json#/$defs/DynamicValue'},
      <String, Object?>{},
    ],
  };

  static final _noRefs = core.ComponentRefMap(const {});

  static List<core.Catalog<core.ComponentApi, core.FunctionImplementation>> _assemble(String catalogId) {
    final basic = core.BasicCatalog.v1_0();
    final components = [for (final component in basic.components.values) _withLooseStyle(component)];
    core.Catalog<core.ComponentApi, core.FunctionImplementation> named(String id) {
      return core.Catalog<core.ComponentApi, core.FunctionImplementation>(
        id: id,
        components: components,
        functions: basic.functions.values.toList(),
        themeSchema: basic.themeSchema,
        title: basic.title,
        description: basic.description,
        protocolVersion: basic.protocolVersion,
        instructions: basic.instructions,
        definitions: basic.definitions,
      );
    }

    if (catalogId == basic.id) return [named(basic.id)];
    return [named(catalogId), named(basic.id)];
  }

  static core.ComponentApi _withLooseStyle(core.ComponentApi component) {
    final loosened = _loosened(component.schema.value);
    return core.ComponentApi(
      name: component.name,
      schema: Schema.fromMap(component.name == 'Icon' ? _withAnyIconName(loosened) : loosened),
      allowedParents: component.allowedParents,
      allowedChildren: component.allowedChildren,
    );
  }

  // [schema] with its properties loosened, and those of each schema it is
  // made of, such as the parts of an `allOf`.
  static Map<String, Object?> _loosened(Map<String, Object?> schema) {
    final properties = schema['properties'];
    final parts = schema['allOf'];
    return {
      ...schema,
      if (properties is Map<String, Object?>)
        'properties': {
          for (final MapEntry(:key, :value) in properties.entries)
            key: _styleProperties.contains(key) && _isStringChoice(value) ? _anyValue : value,
        },
      if (parts is List<Object?>)
        'allOf': [
          for (final part in parts)
            if (part is Map<String, Object?>) _loosened(part) else part,
        ],
    };
  }

  static bool _isStringChoice(Object? schema) => schema is Map<String, Object?> && schema['enum'] is List<Object?>;

  // The `Icon` [schema] with any string allowed as its `name`, where it is
  // listed, so an icon the catalog doesn't have shows the help icon instead
  // of being dropped.
  static Map<String, Object?> _withAnyIconName(Map<String, Object?> schema) {
    final properties = schema['properties'];
    final parts = schema['allOf'];
    return {
      ...schema,
      if (properties is Map<String, Object?>)
        'properties': {
          for (final MapEntry(:key, :value) in properties.entries) key: key == 'name' ? _anyString(value) : value,
        },
      if (parts is List<Object?>)
        'allOf': [
          for (final part in parts)
            if (part is Map<String, Object?>) _withAnyIconName(part) else part,
        ],
    };
  }

  // [schema] with each list of the strings a value may be taken out, at any
  // depth, so any string passes.
  static Object? _anyString(Object? schema) {
    return switch (schema) {
      final Map<String, Object?> map => {
        for (final MapEntry(:key, :value) in map.entries)
          if (!(key == 'enum' && map['type'] == 'string')) key: _anyString(value),
      },
      final List<Object?> list => [for (final item in list) _anyString(item)],
      _ => schema,
    };
  }

  // The properties that name other components, for each component type of the
  // catalog with [catalogId], or of none when there is no such catalog.
  core.ComponentRefMap _refsOf(String? catalogId) {
    for (final catalog in _catalogs) {
      if (catalog.id == catalogId) return catalog.refMap;
    }
    return _noRefs;
  }
}
