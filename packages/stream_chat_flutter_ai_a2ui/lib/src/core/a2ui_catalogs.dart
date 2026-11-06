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
  A2UICatalogs({
    this.catalogId = defaultCatalogId,
    String locale = defaultLocale,
    Map<String, Map<String, Object?>> appComponents = const {},
  }) : assert(
         appComponents.entries.every((entry) => appComponentProblem(entry.key, entry.value) == null),
         "A2UICatalogs was given app components that can't join the catalogs: ${[
           for (final MapEntry(:key, :value) in appComponents.entries)
             if (appComponentProblem(key, value) case final problem?) '$key ($problem)',
         ].join(', ')}.",
       ),
       _catalogs = _assemble(catalogId, locale, appComponents);

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
  ) {
    final basic = core.BasicCatalog.v1_0(locale: locale, openUrl: _openUrl);
    final components = [
      for (final component in basic.components.values) _withLooseStyle(component),
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

  // Opens [link] with what the running action was given to open links with
  // (see `A2UINode.act`). A link an agent writes is untrusted, so only a web
  // page opens; anything else, such as a `mailto` or `tel` link the core
  // lets through, is refused. What this throws is reported as a problem of
  // the action's surface.
  static void _openUrl(Uri link) {
    final scheme = link.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || link.host.isEmpty) {
      throw core.A2uiExpressionError(
        "Function 'openUrl' may not open a '$scheme' link: only web links with a host open.",
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
