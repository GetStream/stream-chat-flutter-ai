import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/builtin_calls.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

void main() {
  test(r'with properties, the components are the $defs it names', () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      'properties': {'Card': <String, Object?>{}},
      r'$defs': {'Card': <String, Object?>{}, 'Shape': <String, Object?>{}},
    });

    expect(schema.componentNames, ['Card']);
  });

  test(r'without properties, every $def but the action shapes is a component', () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      r'$defs': {'Card': <String, Object?>{}, 'ActionExpression': <String, Object?>{}, 'OpenUrl': <String, Object?>{}},
    });

    expect(schema.componentNames, ['Card']);
  });

  test(r'components keep the order of $defs', () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      r'$defs': {'Zeta': <String, Object?>{}, 'Alpha': <String, Object?>{}},
    });

    expect(schema.componentNames, ['Zeta', 'Alpha']);
  });

  test('an action shape that properties names is a component', () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      'properties': {'OpenUrl': <String, Object?>{}},
      r'$defs': {'OpenUrl': <String, Object?>{}},
    });

    expect(schema.componentNames, ['OpenUrl']);
  });

  test(r'a $defs entry that is not a component has its properties as a definition', () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      'properties': {'Card': <String, Object?>{}},
      r'$defs': {
        'Card': <String, Object?>{},
        'Shape': {
          'properties': {'kind': <String, Object?>{}},
          'required': ['kind'],
        },
      },
    });

    expect(schema.definitionParamsOf('Shape')!.map((param) => (param.name, param.required)), [('kind', true)]);
  });

  test(r'a $defs entry without properties has no definition', () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      r'$defs': {'Card': <String, Object?>{}},
    });

    expect(schema.definitionParamsOf('Card'), isNull);
  });

  test('arguments follow the order of properties', () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      r'$defs': {
        'Card': {
          'properties': {'z': <String, Object?>{}, 'a': <String, Object?>{}},
        },
      },
    });

    expect(schema.paramsOf('Card')!.map((param) => param.name), ['z', 'a']);
  });

  test('required arguments are marked', () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      r'$defs': {
        'Card': {
          'properties': {'a': <String, Object?>{}, 'b': <String, Object?>{}},
          'required': ['b'],
        },
      },
    });

    expect(schema.paramsOf('Card')!.map((param) => param.required), [false, true]);
  });

  test("an argument's default is read", () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      r'$defs': {
        'Card': {
          'properties': {
            'tone': {'default': 'neutral'},
          },
        },
      },
    });

    expect(schema.paramsOf('Card')!.single.defaultValue, const OpenUIString('neutral'));
  });

  test(r"an action prop's $ref is replaced by the shape it names", () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      'properties': {'Button': <String, Object?>{}},
      r'$defs': {
        'Button': {
          'properties': {
            'action': {r'$ref': r'#/$defs/ActionExpression'},
          },
        },
        'ActionExpression': {'anyOf': <Object?>[]},
      },
    });

    expect(schema.paramsOf('Button')!.single.schema, OpenUIValue.fromJson(const {'anyOf': <Object?>[]}));
  });

  test(r'a $ref back to an action shape being inlined stays a $ref', () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      'properties': {'Button': <String, Object?>{}},
      r'$defs': {
        'Button': {
          'properties': {
            'action': {r'$ref': r'#/$defs/ActionExpression'},
          },
        },
        'ActionExpression': {
          'anyOf': [
            {r'$ref': r'#/$defs/OpenUrl'},
          ],
        },
        'OpenUrl': {
          'properties': {
            'next': {r'$ref': r'#/$defs/ActionExpression'},
          },
        },
      },
    });

    expect(
      schema.paramsOf('Button')!.single.schema,
      OpenUIValue.fromJson(const {
        'anyOf': [
          {
            'properties': {
              'next': {r'$ref': r'#/$defs/ActionExpression'},
            },
          },
        ],
      }),
    );
  });

  test("the library's functions join the calls", () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      'functions': {
        'Upper': {
          'params': {
            'properties': {'text': <String, Object?>{}},
          },
        },
      },
    });

    expect(schema.callOf('Upper')!.kind, CallKind.function);
  });

  test("the library's actions join the calls", () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      'actions': {
        'Copy': {
          'params': {
            'properties': {'text': <String, Object?>{}},
          },
        },
      },
    });

    expect(schema.callOf('Copy')!.kind, CallKind.action);
  });

  test('every library can make the built-in calls', () {
    expect(OpenUILibrarySchema.fromJsonSchema(const {}).callOf('Count'), BuiltinCalls.calls['Count']);
  });

  for (final MapEntry(key: name, value: params) in {
    ...BuiltinCalls.functionParams,
    ...BuiltinCalls.stepParams,
  }.entries) {
    test('the built-in $name takes ${params.join(', ')}', () {
      expect(BuiltinCalls.calls[name]!.params.map((param) => param.name), params);
    });
  }

  test('of the built-ins, only Action requires an argument', () {
    final requiring = [
      for (final MapEntry(:key, :value) in BuiltinCalls.calls.entries)
        if (value.params.any((param) => param.required)) key,
    ];

    expect(requiring, ['Action']);
  });

  test('the lazy built-ins are Each, Run, Set, Reset and Action', () {
    final lazy = [
      for (final MapEntry(:key, :value) in BuiltinCalls.calls.entries)
        if (value.isLazy) key,
    ];

    expect(lazy, unorderedEquals(['Each', 'Run', 'Set', 'Reset', 'Action']));
  });

  test('a spec gives its root component', () {
    expect(_spec('upstream-chat-library.spec.json').root, 'Card');
  });

  test('a schema without a root has none', () {
    expect(OpenUILibrarySchema.fromJsonSchema(const {}).root, isNull);
  });

  test("the chat library's spec compiles all its components", () {
    expect(_spec('upstream-chat-library.spec.json').componentNames, hasLength(84));
  });

  test("the standard library's spec compiles all its components", () {
    expect(_spec('upstream-playground-library.spec.json').componentNames, hasLength(82));
  });

  test("the specification's test library compiles all its components", () {
    expect(_spec('spec-library.json').componentNames, hasLength(12));
  });

  test('a schema holding something that is not JSON throws', () {
    expect(() => OpenUILibrarySchema.fromJsonSchema({'x': DateTime(2026)}), throwsA(isA<FormatException>()));
  });

  test('a spec without a schema object throws', () {
    expect(() => OpenUILibrarySchema.fromSpec(const {'root': 'Card'}), throwsA(isA<FormatException>()));
  });

  test('a spec whose root is not a string throws', () {
    expect(
      () => OpenUILibrarySchema.fromSpec(const {'root': 5, 'schema': <String, Object?>{}}),
      throwsA(isA<FormatException>()),
    );
  });
}

OpenUILibrarySchema _spec(String file) {
  final json = jsonDecode(File('test/conformance/generated/$file').readAsStringSync()) as Map<String, Object?>;
  return OpenUILibrarySchema.fromSpec(json);
}
