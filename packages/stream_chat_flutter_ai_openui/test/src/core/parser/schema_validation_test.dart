import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/materializer.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/schema_validation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

// Ported from OpenUI's `materialize.validation.test.ts` (thesysdev/openui
// @ `729ac8b`, `packages/lang-core/src/parser/__tests__/`), as both platforms
// port it.
void main() {
  test('a valid nested object reports nothing', () {
    expect(_errors('root = ObjBox({ author: "ann", views: 3 })'), isEmpty);
  });

  test('a nested violation is reported at its JSON pointer', () {
    final error = _errors('root = ObjBox({ author: "ann", views: "lots" })').single;

    expect((error.code, error.component, error.path), (OpenUIErrorCode.typeMismatch, 'ObjBox', '/info/views'));
  });

  test('a violation in an array item is reported at its index', () {
    expect(_errors('root = ArrBox([{ label: "a", value: "x" }])').single.path, '/rows/0/value');
  });

  test('a missing required key is reported at its path', () {
    final error = _errors('root = ObjBox({ views: 3 })').single;

    expect((error.code, error.path), (OpenUIErrorCode.missingRequired, '/info/author'));
  });

  test('a null required key is reported at its path', () {
    final error = _errors('root = ObjBox({ author: null, views: 3 })').single;

    expect((error.code, error.path), (OpenUIErrorCode.nullRequired, '/info/author'));
  });

  test('a string where an object goes is a type mismatch', () {
    expect(_errors('root = ObjBox("hello")').single.message, contains('expects object but got string'));
  });

  test('a number where an array goes is a type mismatch', () {
    expect(_errors('root = TagBox(42)').single.message, contains('expects array but got number'));
  });

  test('an object where a string goes is a type mismatch', () {
    expect(_errors(r'root = ScalarBox({ a: $x })').single.message, contains('expects string but got object'));
  });

  test('every violation in an array is reported', () {
    final errors = _errors('root = ArrBox([{ label: 1 }, { value: "x" }])');

    expect(errors.map((error) => '${error.code}:${error.path}'), [
      'type-mismatch:/rows/0/label',
      'missing-required:/rows/1/label',
      'type-mismatch:/rows/1/value',
    ]);
  });

  test('a type mismatch and extra arguments are both reported', () {
    expect(_errors('root = ScalarBox(1, 1, true, "extra")').map((error) => error.code), [
      OpenUIErrorCode.typeMismatch,
      OpenUIErrorCode.excessArgs,
    ]);
  });

  test('a missing argument names the signature', () {
    expect(
      _errors('root = ReqScalar()').single.message,
      'missing required field "/title" — signature: ReqScalar(title*: string)',
    );
  });

  test('a null argument names the signature with its enum values', () {
    expect(
      _errors('root = ChartBox(null, "grouped")').single.message,
      'required field "/labels" cannot be null — signature: ChartBox(labels*: array, variant: "grouped"|"stacked")',
    );
  });

  test('an unknown component lists the components available', () {
    expect(_errors('root = Nope()').first.message, contains('Available components: ObjBox, ArrBox'));
  });

  test('an error is attributed to the statement that holds the component', () {
    final error = _errors('root = ListBox([inner])\ninner = ObjBox({ author: "ann", views: "lots" })').single;

    expect((error.component, error.statementId), ('ObjBox', 'inner'));
  });

  test('an invalid value on an optional key is dropped', () {
    expect(_root('root = ObjBox({ author: "ann", views: "lots" })')!.props['info'], _object({'author': 'ann'}));
  });

  test('an invalid optional argument is dropped and the component kept', () {
    expect(_root('root = ScalarBox(5)')!.props.containsKey('title'), isFalse);
  });

  test('an object missing a required key is dropped from an optional argument', () {
    expect(_root('root = ObjBox({ views: 3 })')!.props.containsKey('info'), isFalse);
  });

  test('an invalid array item is dropped', () {
    expect(_root('root = TagBox(["a", 2, "c"])')!.props['tags'], _array(['a', 'c']));
  });

  test('an array item missing a required key is dropped', () {
    expect(
      _root('root = ArrBox([{ label: "a", value: 1 }, { value: 2 }])')!.props['rows'],
      _array([
        {'label': 'a', 'value': 1},
      ]),
    );
  });

  test('an invalid required key makes its object invalid', () {
    expect(_root('root = ObjBox({ author: { first: "a" }, views: 3 })')!.props.containsKey('info'), isFalse);
  });

  test('an invalid required argument drops the component', () {
    expect(_root('root = ReqScalar(5)'), isNull);
  });

  test('an invalid argument with a default takes the default', () {
    expect(_root('root = DefBox(5)')!.props['theme'], const OpenUIString('dark'));
  });

  test('an invalid argument with a default is still reported', () {
    expect(_errors('root = DefBox(5)'), hasLength(1));
  });

  test('a missing argument with a default reports nothing', () {
    expect(_errors('root = DefBox()'), isEmpty);
  });

  test('an invalid nested enum value takes its default', () {
    expect(
      _root('root = NestDefBox({ mode: "warp", retries: 1 })')!.props['cfg'],
      _object({'mode': 'fast', 'retries': 1}),
    );
  });

  test('an invalid nested enum value is reported at its path', () {
    final error = _errors('root = NestDefBox({ mode: "warp", retries: 1 })').single;

    expect((error.code, error.path), (OpenUIErrorCode.typeMismatch, '/cfg/mode'));
  });

  test('an invalid nested optional value takes its default', () {
    expect(
      _root('root = NestDefBox({ mode: "slow", retries: "many" })')!.props['cfg'],
      _object({'mode': 'slow', 'retries': 3}),
    );
  });

  test('a missing required key with a default is filled', () {
    expect(_root('root = NestDefBox({ retries: 2 })')!.props['cfg'], _object({'retries': 2, 'mode': 'fast'}));
  });

  test('a missing required key with a default is not reported', () {
    expect(_errors('root = NestDefBox({ retries: 2 })'), isEmpty);
  });

  test('a null required key with a default is filled', () {
    expect(
      _root('root = NestDefBox({ mode: null, retries: 2 })')!.props['cfg'],
      _object({'mode': 'fast', 'retries': 2}),
    );
  });

  test('a null required key with a default is not reported', () {
    expect(_errors('root = NestDefBox({ mode: null, retries: 2 })'), isEmpty);
  });

  test('a component in a required data slot drops its parent', () {
    expect(_root('root = ChartBox(CardBox("x"), "grouped")'), isNull);
  });

  test('a component in a data slot is reported as a type mismatch', () {
    expect(
      _errors('root = ChartBox(CardBox("x"), "grouped")').first.message,
      contains('expects array but got component "CardBox"'),
    );
  });

  test('a component in an optional enum slot is dropped', () {
    expect(_root('root = ChartBox(["a"], CardBox("x"))')!.props.containsKey('variant'), isFalse);
  });

  test('a component in an enum slot is reported as not a literal value', () {
    expect(
      _errors('root = ChartBox(["a"], CardBox("x"))').single.message,
      contains('expects a literal value but got component'),
    );
  });

  test('a component in a list of strings is dropped', () {
    expect(_root('root = TagBox(["a", CardBox("x"), "b"])')!.props['tags'], _array(['a', 'b']));
  });

  test('a component slot takes components', () {
    final children = _root('root = SlotBox([CardBox("hi"), EnumBox("active")])')!.props['children']! as OpenUIArray;

    expect(children.items, hasLength(2));
  });

  test('components in a component slot report nothing', () {
    expect(_errors('root = SlotBox([CardBox("hi"), EnumBox("active")])'), isEmpty);
  });

  test("a component's own error and its misplacement are both reported", () {
    final errors = _errors('root = ObjBox({ author: CardBox(9) })');

    expect(errors.map((error) => '${error.component}:${error.path}'), ['CardBox:/text', 'ObjBox:/info/author']);
  });

  test('data in a slot only components fill is dropped', () {
    final result = _parse('root = SlotBox([CardBox("hi"), { text: "a" }, "b", 3, [CardBox("x")]])');

    expect((result.root!.props['children']! as OpenUIArray).items, hasLength(1));
  });

  test('data in a slot only components fill is reported by its kind', () {
    expect(_errors('root = SlotBox([CardBox("hi"), { text: "a" }, "b", 3, [CardBox("x")]])').map((e) => e.message), [
      'field "/children/1" expects CardBox but got plain object',
      'field "/children/2" expects CardBox but got string',
      'field "/children/3" expects CardBox but got number',
      'field "/children/4" expects CardBox but got array',
    ]);
  });

  test('data reached through a reference in a component slot is dropped', () {
    expect(_root('root = SlotBox(items)\nitems = [{ text: "a" }]')!.props['children'], OpenUIArray(const []));
  });

  test('data reached through a reference in a component slot is reported at its index', () {
    expect(_errors('root = SlotBox(items)\nitems = [{ text: "a" }]').single.path, '/children/0');
  });

  test('a reference to a data shape is not a component slot', () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      'properties': {'Tree': <String, Object?>{}},
      r'$defs': {
        'Tree': {
          'properties': {
            'node': {r'$ref': r'#/$defs/__schema0'},
          },
          'required': ['node'],
        },
        '__schema0': {
          'type': 'object',
          'properties': {
            'label': {'type': 'string'},
          },
        },
      },
    });

    final result = OpenUILangParser(schema).parse('root = Tree({ label: "a" })');

    expect(result.root!.props['node'], _object({'label': 'a'}));
  });

  test('an expression in a list of strings is not checked', () {
    expect(_errors(r'root = TagBox(["a", $x])'), isEmpty);
  });

  test('a call in a number slot is not checked', () {
    expect(_errors('root = ObjBox({ author: "a", views: Sum([1, 2]) })'), isEmpty);
  });

  test('an anyOf slot is not checked', () {
    expect(_errors('root = AnyBox({ anything: true })'), isEmpty);
  });

  test('null in an optional object slot reports nothing', () {
    expect(_errors('root = ObjBox(null)'), isEmpty);
  });

  test('a missing optional argument reports nothing', () {
    expect(_errors('root = ObjBox()'), isEmpty);
  });

  test('keys the schema does not name are kept unchecked', () {
    expect(_errors('root = ObjBox({ author: "a", bonus: 99 })'), isEmpty);
  });

  test('an array without an item schema takes any items', () {
    expect(_errors('root = ListBox([1, "a", true])'), isEmpty);
  });

  test('a schema that is not an object checks nothing', () {
    expect(_directErrors(const OpenUINumber(5), OpenUINull.instance), isEmpty);
  });

  test('a schema that is a string checks nothing', () {
    expect(_directErrors(const OpenUINumber(5), const OpenUIString('string')), isEmpty);
  });

  test(r'a $ref schema checks nothing, even beside a type', () {
    final schema = _object({r'$ref': r'#/$defs/Thing', 'type': 'string'});

    expect(_directErrors(const OpenUINumber(5), schema), isEmpty);
  });

  test('an anyOf schema checks nothing, even beside a type', () {
    final schema = _object({
      'anyOf': [
        {'type': 'string'},
      ],
      'type': 'string',
    });

    expect(_directErrors(const OpenUINumber(5), schema), isEmpty);
  });

  test('an allOf schema checks nothing, even beside a type', () {
    final schema = _object({
      'allOf': [
        {'type': 'string'},
      ],
      'type': 'string',
    });

    expect(_directErrors(const OpenUINumber(5), schema), isEmpty);
  });

  test('an array type is described as array', () {
    expect(SchemaValidation.typeDescription(_object({'type': 'array'})), 'array');
  });

  test('an object type is described as object', () {
    expect(SchemaValidation.typeDescription(_object({'type': 'object'})), 'object');
  });

  test('an integer type is described as number', () {
    expect(SchemaValidation.typeDescription(_object({'type': 'integer'})), 'number');
  });

  test('a oneOf schema checks nothing, even beside a type', () {
    final schema = _object({
      'oneOf': [
        {'type': 'string'},
      ],
      'type': 'string',
    });

    expect(_directErrors(const OpenUINumber(5), schema), isEmpty);
  });

  test('items given as a list check nothing', () {
    final schema = _object({
      'type': 'array',
      'items': [
        {'type': 'string'},
      ],
    });

    expect(_directErrors(_array([5]), schema), isEmpty);
  });

  test('an unknown type checks nothing', () {
    expect(_directErrors(const OpenUIString('x'), _object({'type': 'date'})), isEmpty);
  });

  test('required given as a string checks nothing', () {
    expect(_directErrors(_object({}), _object({'type': 'object', 'required': 'author'})), isEmpty);
  });

  test('a required key missing from an object is reported', () {
    final schema = _object({
      'type': 'object',
      'required': ['a'],
    });

    expect(_directErrors(_object({}), schema).single.code, OpenUIErrorCode.missingRequired);
  });

  test('integer takes any number', () {
    expect(_directErrors(const OpenUINumber(1.5), _object({'type': 'integer'})), isEmpty);
  });

  test('integer rejects a string', () {
    expect(_directErrors(const OpenUIString('3'), _object({'type': 'integer'})), hasLength(1));
  });

  test('const lists its one value', () {
    expect(
      _directErrors(const OpenUIString('loose'), _object({'const': 'fixed'})).single.message,
      contains('one of ["fixed"]'),
    );
  });

  test('an enum does not check an object', () {
    final schema = _object({
      'enum': ['active'],
    });

    expect(_directErrors(_object({'a': 1}), schema), isEmpty);
  });

  test('while incomplete, a missing required key is not reported', () {
    expect(_errors('root = ObjBox({ views: 3 '), isEmpty);
  });

  test('while incomplete, an enum value is not checked', () {
    expect(_errors('root = EnumBox("bogus" '), isEmpty);
  });

  test('while incomplete, a scalar of the wrong type is still reported', () {
    expect(_errors('root = ObjBox({ author: "a", views: "lots" ').single.path, '/info/views');
  });

  test('while incomplete, a direct required check is skipped', () {
    final schema = _object({
      'type': 'object',
      'required': ['a'],
    });

    expect(_directErrors(_object({}), schema, partial: true), isEmpty);
  });

  test('while incomplete, a direct enum check is skipped', () {
    final schema = _object({
      'enum': ['active'],
    });

    expect(_directErrors(const OpenUIString('act'), schema, partial: true), isEmpty);
  });

  test('while incomplete, a direct scalar check still runs', () {
    expect(_directErrors(const OpenUINumber(5), _object({'type': 'string'}), partial: true), hasLength(1));
  });

  test('a value nothing changes comes back as the same instance', () {
    final value = _object({'author': 'a'});
    final schema = _object({
      'type': 'object',
      'properties': {
        'author': {'type': 'string'},
      },
    });

    expect(SchemaValidation.validate(value, schema, 'X', '/p', _context()).value, same(value));
  });
}

final _schema = OpenUILibrarySchema.fromJsonSchema(const {
  r'$defs': {
    'ObjBox': {
      'properties': {
        'info': {
          'type': 'object',
          'properties': {
            'author': {'type': 'string'},
            'views': {'type': 'number'},
          },
          'required': ['author'],
        },
      },
      'required': <String>[],
    },
    'ArrBox': {
      'properties': {
        'rows': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'label': {'type': 'string'},
              'value': {'type': 'number'},
            },
            'required': ['label'],
          },
        },
      },
    },
    'TagBox': {
      'properties': {
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      },
    },
    'EnumBox': {
      'properties': {
        'status': {
          'enum': ['active', 'inactive'],
        },
      },
    },
    'AnyBox': {
      'properties': {
        'combo': {
          'anyOf': [
            {'type': 'string'},
            {'type': 'number'},
          ],
        },
      },
    },
    'ScalarBox': {
      'properties': {
        'title': {'type': 'string'},
        'count': {'type': 'number'},
        'flag': {'type': 'boolean'},
      },
    },
    'ListBox': {
      'properties': {
        'children': {'type': 'array'},
      },
    },
    'CardBox': {
      'properties': {
        'text': {'type': 'string'},
      },
    },
    'ReqScalar': {
      'properties': {
        'title': {'type': 'string'},
      },
      'required': ['title'],
    },
    'DefBox': {
      'properties': {
        'theme': {'type': 'string', 'default': 'dark'},
      },
      'required': ['theme'],
    },
    'SlotBox': {
      'properties': {
        'children': {
          'type': 'array',
          'items': {
            'anyOf': [
              {r'$ref': r'#/$defs/CardBox'},
            ],
          },
        },
      },
    },
    'ChartBox': {
      'properties': {
        'labels': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'variant': {
          'enum': ['grouped', 'stacked'],
        },
      },
      'required': ['labels'],
    },
    'NestDefBox': {
      'properties': {
        'cfg': {
          'type': 'object',
          'properties': {
            'mode': {
              'enum': ['fast', 'slow'],
              'default': 'fast',
            },
            'retries': {'type': 'number', 'default': 3},
          },
          'required': ['mode'],
        },
      },
    },
  },
});

ParseResult _parse(String text) => OpenUILangParser(_schema).parse(text);

ElementNode? _root(String text) => _parse(text).root;

List<ValidationError> _errors(String text) => _parse(text).meta.errors;

MaterializeContext _context({bool partial = false}) {
  return MaterializeContext(
    symbols: const {},
    schema: _schema,
    partial: partial,
    currentStatementId: null,
    unreached: const [],
  );
}

List<ValidationError> _directErrors(OpenUIValue value, OpenUIValue schema, {bool partial = false}) {
  final context = _context(partial: partial);
  SchemaValidation.validate(value, schema, 'X', '/p', context);
  return context.errors;
}

OpenUIValue _object(Map<String, Object?> json) => OpenUIValue.fromJson(json);

OpenUIValue _array(List<Object?> json) => OpenUIValue.fromJson(json);
