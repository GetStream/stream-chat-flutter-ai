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
/// property is, and is drawn in the default style too. Any other property the
/// catalog lists the strings of, such as an `Icon`'s `name`, takes any
/// string, so an icon of a name the catalog doesn't have is kept too, and a
/// string the catalog asks to be one of several formats, such as a
/// `DateTimeInput`'s `min` being a date or a time, is kept whichever it is.
///
/// Its functions format numbers and dates for `locale`, a BCP 47 tag such as
/// `de-DE`; a tag the functions don't know formats as `en-US`. Its `openUrl`
/// opens a link only while a node runs an action the person started (see
/// [A2UINode.act]), and only an `http` or `https` link with a host; it reports
/// any other.
///
/// It doesn't change, so one can be shared by several [A2UIProcessor]s, such
/// as those of every reply in a chat.
///
/// Internal to the package.
@internal
final class A2UICatalogs {
  /// Creates the catalogs, with the app's catalog named [catalogId] and the
  /// format functions in the [locale].
  A2UICatalogs({this.catalogId = defaultCatalogId, String locale = defaultLocale})
    : _catalogs = _assemble(catalogId, locale);

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

  static List<core.Catalog<core.ComponentApi, core.FunctionImplementation>> _assemble(String catalogId, String locale) {
    final basic = core.BasicCatalog.v1_0(locale: locale, openUrl: _openUrl);
    final components = [for (final component in basic.components.values) _withLooseStyle(component)];
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
    return core.ComponentApi(
      name: component.name,
      schema: Schema.fromMap(_loosened(component.schema.value)),
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
            key: _styleProperties.contains(key) && _isStringChoice(value) ? _anyValue : _anyString(value),
        },
      if (parts is List<Object?>)
        'allOf': [
          for (final part in parts)
            if (part is Map<String, Object?>) _loosened(part) else part,
        ],
    };
  }

  static bool _isStringChoice(Object? schema) => schema is Map<String, Object?> && schema['enum'] is List<Object?>;

  // [schema] with each list of the strings a value may be taken out, at any
  // depth, so any string passes; a builder shows a fallback for one it
  // doesn't know, such as the help icon for an icon name.
  //
  // A choice of string formats, such as a `DateTimeInput`'s `min` being a
  // date, a time or a date and time, becomes a choice of any of them: the
  // schema library checks no format, so every string matches all of them,
  // and "exactly one" would drop the component.
  static Object? _anyString(Object? schema) {
    return switch (schema) {
      final Map<String, Object?> map => {
        for (final MapEntry(:key, :value) in map.entries)
          if (!(key == 'enum' && map['type'] == 'string'))
            key == 'oneOf' && _isFormatChoice(value) ? 'anyOf' : key: _anyString(value),
      },
      final List<Object?> list => [for (final item in list) _anyString(item)],
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
    throw core.A2uiExpressionError("Function '$name' can't format '$value', which isn't a number.");
  }
}
