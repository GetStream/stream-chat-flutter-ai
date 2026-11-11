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
/// too, and shows a fallback. A string the catalog asks to be one of several
/// formats, such as a `DateTimeInput`'s `min` being a date or a time, is kept
/// whichever it is. Every other property is checked as the catalog lists it.
///
/// Only the basic components the app draws are in them: a basic component
/// the app's `A2UICatalog` has no builder for, such as one taken out with
/// `A2UICatalog.removing`, is unknown, as it is to the agent, which
/// [describe] leaves it out for.
///
/// The app's own components join both catalogs too, each under the A2UI type
/// it is placed by; see [A2UICatalogs.new]. They hold no other components and
/// no action.
///
/// It doesn't change, so one can be shared by several [A2UIProcessor]s, such
/// as those of every reply in a chat.
///
/// Internal to the package.
@internal
final class A2UICatalogs {
  /// Creates the catalogs, with the app's catalog named [catalogId] and the
  /// format functions in the [locale].
  ///
  /// Each of [appComponents] maps an A2UI type, such as `PlaceCard`, to the
  /// parameters of one of the app's components, written as a JSON Schema
  /// object. A component of that type takes those parameters as its
  /// properties, each written as any value or as a binding or a function call
  /// whose result is its value; the ones the schema lists as `required` must
  /// be there. What each parameter's schema says about its value isn't
  /// checked here. Each type must be one
  /// [appComponentProblem] finds nothing wrong with.
  ///
  /// Of the basic catalog's components, only those of [basicTypes] are in the
  /// catalogs, or all of them when it is `null`.
  factory A2UICatalogs({
    String catalogId = defaultCatalogId,
    String locale = defaultLocale,
    Map<String, Map<String, Object?>> appComponents = const {},
    Iterable<String>? basicTypes,
  }) {
    assert(
      appComponents.entries.every((entry) => appComponentProblem(entry.key, entry.value) == null),
      "A2UICatalogs was given app components that can't join the catalogs: ${[
        for (final MapEntry(:key, :value) in appComponents.entries)
          if (appComponentProblem(key, value) case final problem?) '$key ($problem)',
      ].join(', ')}.",
    );
    return A2UICatalogs._(catalogId, _assemble(catalogId, locale, appComponents, basicTypes?.toSet()));
  }

  // The catalogs of [_catalogs], the app's of which is named [catalogId].
  A2UICatalogs._(this.catalogId, this._catalogs);

  /// The id of the app's catalog.
  final String catalogId;

  final List<core.Catalog<core.ComponentApi, core.FunctionImplementation>> _catalogs;

  /// The id an agent names the app's catalog by, unless it is told another.
  static const defaultCatalogId = 'getstream.io:app-catalog';

  /// The id of the A2UI 1.0 basic catalog.
  static const basicCatalogId = core.BasicCatalog.v1_0Id;

  /// The locale the format functions use unless they are given another.
  static const defaultLocale = 'en-US';

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

  // A value, a binding or a function call.
  static const _dynamicValue = {r'$ref': r'common_types.json#/$defs/DynamicValue'};

  // The same, or `null`, which an optional parameter the agent leaves empty
  // may hold.
  static const _optionalDynamicValue = {
    'anyOf': [
      _dynamicValue,
      {'type': 'null'},
    ],
  };

  // The key of a component that holds its type.
  static const _typeKey = 'component';

  // The key of a component that holds its id, which its properties never
  // read.
  static const _idKey = 'id';

  // The properties every component may hold, its share of a `Row` or
  // `Column` and its accessibility label and description, which an app
  // component's parameters can't reuse.
  static const _commonKeys = {'weight', 'accessibility'};

  // The type of the surface itself, which a component may not take.
  static const _surfaceType = 'Surface';

  // The types of the basic catalog's components.
  static final _basicTypes = core.BasicCatalog.v1_0().components.keys.toSet();

  /// Why an app component of [type] whose parameters are [parametersSchema]
  /// can't join the catalogs, or `null` when it can.
  static String? appComponentProblem(String type, Map<String, Object?> parametersSchema) {
    if (!core.isValidUax31Identifier(type)) return "its type '$type' isn't an A2UI identifier";
    if (type == _surfaceType) return "its type '$type' is the surface's own";
    if (_basicTypes.contains(type)) return "its type '$type' is one of the basic catalog's";
    for (final name in _parameterNames(parametersSchema)) {
      if (name == _typeKey) return "its parameter '$name' is the key that holds a component's type";
      if (name == _idKey) return "its parameter '$name' is the key that holds a component's id";
      if (_commonKeys.contains(name)) return "its parameter '$name' is a property every component may hold";
      if (!core.isValidUax31Identifier(name)) return "its parameter '$name' isn't an A2UI identifier";
    }
    return null;
  }

  static Iterable<String> _parameterNames(Map<String, Object?> parametersSchema) {
    final properties = parametersSchema['properties'];
    if (properties is! Map<String, Object?>) return const [];
    return properties.keys;
  }

  // The definition of an app component of [type] with the parameters in
  // [parametersSchema]. Each property takes any value, a binding or a function
  // call, as a basic component's dynamic values do: the component itself
  // decides whether the value it resolves to fits, so the parameter's own
  // schema, which may refer to definitions it doesn't hold, isn't read.
  static core.ComponentApi _appComponent(String type, Map<String, Object?> parametersSchema) {
    final required = switch (parametersSchema['required']) {
      final List<Object?> names => names.whereType<String>().toSet(),
      _ => const <String>{},
    };
    return core.ComponentApi(
      name: type,
      schema: Schema.fromMap({
        'type': 'object',
        'properties': {
          _typeKey: {'const': type},
          for (final name in _parameterNames(parametersSchema))
            name: required.contains(name) ? _dynamicValue : _optionalDynamicValue,
        },
        'required': [_typeKey, ...required],
      }),
    );
  }

  static List<core.Catalog<core.ComponentApi, core.FunctionImplementation>> _assemble(
    String catalogId,
    String locale,
    Map<String, Map<String, Object?>> appComponents,
    Set<String>? basicTypes,
  ) {
    final basic = core.BasicCatalog.v1_0(locale: locale, openUrl: _openUrl);
    final components = [
      for (final component in basic.components.values)
        if (basicTypes == null || basicTypes.contains(component.name)) _withLooseStyle(component),
      for (final MapEntry(:key, :value) in appComponents.entries) _appComponent(key, value),
    ];
    core.Catalog<core.ComponentApi, core.FunctionImplementation> named(String id) {
      return core.Catalog<core.ComponentApi, core.FunctionImplementation>(
        id: id,
        components: components,
        functions: [for (final function in basic.functions.values) _withNumericStrings(function)],
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

  /// The catalog the agent writes with, as it is told about it: the JSON
  /// Schema document of the catalog named [catalogId], without guidelines.
  ///
  /// It holds the basic catalog's components of [basicTypes], or all of them
  /// when it is `null`, its functions, and [appComponents], each under the
  /// A2UI type it is placed by, with the parameters of its `parameters`
  /// schema as its properties, as they are written there, and its
  /// `description`. The basic components are described as the basic catalog
  /// lists them, not as loosely as [A2UICatalogs.new] reads them, so the
  /// agent writes the values the catalog lists.
  static Map<String, Object?> describe({
    String catalogId = defaultCatalogId,
    Iterable<String>? basicTypes,
    Map<String, ({String description, Map<String, Object?> parameters})> appComponents = const {},
  }) {
    final types = basicTypes?.toSet();
    final basic = core.BasicCatalog.v1_0();
    final catalog = core.Catalog<core.ComponentApi, core.FunctionImplementation>(
      id: catalogId,
      components: [
        for (final component in basic.components.values)
          if (types == null || types.contains(component.name)) component,
        for (final MapEntry(:key, :value) in appComponents.entries) _describedAppComponent(key, value),
      ],
      functions: basic.functions.values.toList(),
      themeSchema: basic.themeSchema,
      title: basic.title,
      description: basic.description,
      protocolVersion: basic.protocolVersion,
      definitions: basic.definitions,
    );
    return catalog.toJson();
  }

  // An app component of [type] as the agent is told about it: its parameters'
  // own schemas as its properties, as iOS and Android describe it.
  static core.ComponentApi _describedAppComponent(
    String type,
    ({String description, Map<String, Object?> parameters}) component,
  ) {
    final parameters = component.parameters['properties'];
    final required = switch (component.parameters['required']) {
      final List<Object?> names => names.whereType<String>(),
      _ => const <String>[],
    };
    return core.ComponentApi(
      name: type,
      schema: Schema.fromMap({
        'type': 'object',
        if (component.description.isNotEmpty) 'description': component.description,
        'properties': {
          if (parameters is Map<String, Object?>) ...parameters,
          _typeKey: {'const': type},
        },
        'required': ({_typeKey, ...required}.toList()..sort()),
      }),
    );
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
            key: _styleProperties.contains(key) && _isStringChoice(value) ? _anyValue : _anyFormat(value),
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

  // [schema] with each choice of string formats, at any depth, such as a
  // `DateTimeInput`'s `min` being a date, a time or a date and time, made a
  // choice of any of them: the schema library checks no format, so every
  // string matches all of them, and "exactly one" would drop the component.
  static Object? _anyFormat(Object? schema) {
    return switch (schema) {
      final Map<String, Object?> map => {
        for (final MapEntry(:key, :value) in map.entries)
          key == 'oneOf' && _isFormatChoice(value) ? 'anyOf' : key: _anyFormat(value),
      },
      final List<Object?> list => [for (final item in list) _anyFormat(item)],
      _ => schema,
    };
  }

  // The functions that read their `value` as a number. A number field writes
  // the text the person typed, so these read a string that holds a number as
  // that number, and give a check's result, not a problem, for one that
  // doesn't.
  static const _numericFunctions = {'numeric', 'formatNumber', 'formatCurrency'};

  static core.FunctionImplementation _withNumericStrings(core.FunctionImplementation function) {
    if (!_numericFunctions.contains(function.name)) return function;
    return _NumericStringFunction(function);
  }

  static bool _isFormatChoice(Object? schemas) {
    if (schemas is! List<Object?> || schemas.isEmpty) return false;
    return schemas.every((schema) => schema is Map<String, Object?> && schema.keys.every((key) => key == 'format'));
  }

  static const _openableSchemes = {'http', 'https', 'mailto', 'tel'};

  // Opens [link] with what the running action was given to open links with
  // (see `A2UINode.act`), which decides which links open: the host's `open`
  // opens only web and email links unless the app opens links itself. A link
  // an agent writes is untrusted, so only an `http`, `https`, `mailto` or
  // `tel` one reaches it, whatever the core lets through. What this throws is
  // reported as a problem of the action's surface.
  static void _openUrl(Uri link) {
    final scheme = link.scheme.toLowerCase();
    if (!_openableSchemes.contains(scheme)) {
      throw core.A2uiExpressionError(
        "Function 'openUrl' may not open a '$scheme' link.",
        expression: 'openUrl',
      );
    }
    final openLink = Zone.current[_openLinkKey];
    if (openLink is! A2UIOpenLink) {
      throw core.A2uiExpressionError(
        "Function 'openUrl' could not open the link: nothing opens links where its surface shows.",
        expression: 'openUrl',
      );
    }
    openLink(link);
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

// [_function], whose `value` may also be a string holding a finite number,
// read as that number. Any other string, such as an empty one, isn't a number,
// as iOS and Android read it: `numeric` fails it, and a function that formats
// a number reports it.
final class _NumericStringFunction extends core.FunctionImplementation {
  _NumericStringFunction(this._function)
    : super(
        name: _function.name,
        argumentSchema: Schema.fromMap(_withStringValue(_function.argumentSchema.value)),
        returnType: _function.returnType,
        description: _function.description,
        allowedCallers: _function.declaredAllowedCallers,
        requiresUserActivation: _function.declaredRequiresUserActivation,
        definition: _function.definition,
      );

  final core.FunctionImplementation _function;

  static Map<String, Object?> _withStringValue(Map<String, Object?> schema) {
    final properties = schema['properties'];
    if (properties is! Map<String, Object?> || !properties.containsKey('value')) return schema;
    return {
      ...schema,
      'properties': {
        ...properties,
        'value': {
          'anyOf': [
            properties['value'],
            {'type': 'string'},
          ],
        },
      },
    };
  }

  @override
  Object? execute(Map<String, dynamic> args, core.DataContext context, [core.CancellationSignal? cancellationSignal]) {
    final value = args['value'];
    if (value is! String) return _function.execute(args, context, cancellationSignal);
    final number = num.tryParse(value);
    if (number != null && number.isFinite) {
      return _function.execute({...args, 'value': number}, context, cancellationSignal);
    }
    if (name == 'numeric') return false;
    throw core.A2uiExpressionError("Function '$name' can't format its value, which isn't a number.");
  }
}
