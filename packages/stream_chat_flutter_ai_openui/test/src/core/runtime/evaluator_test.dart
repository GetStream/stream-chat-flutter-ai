import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_conformance_seams.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/action_plan.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/builtins.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/evaluator.dart';

import '../../../conformance/openui_conformance.dart';

final _spec = conformanceLibraries()['spec']!;

// Evaluates `program` with the spec library, its `Upper` function and its
// bindable props.
Map<String, Object?> _run(
  String program, {
  Map<String, Object?> state = const {},
  Map<String, Object?> refs = const {},
  OpenUILibrarySchema? schema,
  Map<String, OpenUIFunction>? functions,
}) {
  return debugEvaluate(
    schema ?? _spec,
    program,
    isBindable: conformanceBindables('spec'),
    state: state,
    refs: refs,
    functions: functions ?? specFunctions,
  );
}

Map<String, Object?> _root(Map<String, Object?> result) => result['evaluatedRoot']! as Map<String, Object?>;

Object? _prop(Map<String, Object?> element, List<Object> path) {
  Object? current = element;
  for (final step in path) {
    current = switch ((current, step)) {
      (final Map<String, Object?> map, final String key) => (map['props']! as Map<String, Object?>)[key],
      (final List<Object?> list, final int index) => list[index],
      _ => throw StateError('no $step in $current'),
    };
  }
  return current;
}

// The values of `exprs`, a comma-separated list, as a column's data.
List<Object?> _values(String exprs, {Map<String, Object?> state = const {}, Map<String, Object?> refs = const {}}) {
  // Each ref is a query's result, so the program declares the query.
  final queries = [for (final name in refs.keys) '$name = Query("tool", {}, null)'].join('\n');
  final result = _run('root = Stack([Table([Col("v", [$exprs])])])\n$queries', state: state, refs: refs);
  expect(result['runtimeErrors'], isEmpty);
  return _prop(_root(result), ['children', 0, 'columns', 0, 'data'])! as List<Object?>;
}

void main() {
  group('operators', () {
    test('dividing or taking the remainder by zero gives 0', () {
      expect(_values('7 / 0, 7 % 0'), [0, 0]);
    });

    test('a remainder takes the sign of the dividend', () {
      expect(_values('-7 % 3, 7 % -3'), [-1, 1]);
    });

    test('&& and || give the operand that decides, null joins text as nothing', () {
      expect(_values('0 && "x", "" || "y", "a" + null, 1 + 2 + "x"'), [0, 'y', 'a', '3x']);
    });

    test('reading a field of a list reads it from every item', () {
      expect(
        _values(
          'rows.name, rows.length, rows[1].name, rows[5]',
          refs: {
            'rows': [
              {'name': 'a'},
              {'other': 1},
            ],
          },
        ),
        [
          ['a', null],
          2,
          null,
          null,
        ],
      );
    });
  });

  group('built-ins', () {
    test('@Round rounds halves up, to the decimals asked', () {
      expect(_values('@Round(2.5), @Round(-2.5), @Round(1234.5678, 2), @Round(1234.5678, -2)'), [3, -2, 1234.57, 1200]);
    });

    test('@Min and @Max of no items are 0', () {
      expect(_values('@Min([]), @Max([]), @Min([3, "1", 2]), @Max([3, "7", true])'), [0, 0, 1, 7]);
    });

    test('@Min and @Max give NaN when an item is NaN', () {
      final items = [
        OpenUIArray(const [OpenUINumber(1), OpenUINumber(double.nan)]),
      ];

      expect((Builtins.functions['Min']!(items) as OpenUINumber).value, isNaN);
      expect((Builtins.functions['Max']!(items) as OpenUINumber).value, isNaN);
    });

    test('@Sort compares numbers and numeric text as numbers, the rest as text, stably', () {
      expect(_values('@Sort([3, "10", 2, "1"], "")'), [
        ['1', 2, 3, '10'],
      ]);
      expect(_values('@Sort(["b", "B", "a", "c"], "")'), [
        ['a', 'b', 'B', 'c'],
      ]);
      expect(
        _values(
          '@Sort(rows, "n", "desc").id',
          refs: {
            'rows': [
              {'id': 'x', 'n': 1},
              {'id': 'y', 'n': 2},
              {'id': 'z', 'n': 1},
            ],
          },
        ),
        [
          ['y', 'x', 'z'],
        ],
      );
    });

    test('@Sort gives a value that is not a list back as it is', () {
      expect(_values('@Sort("text", "x")'), ['text']);
    });

    test('@Filter keeps the items each operator selects', () {
      const rows = [
        {'n': 1, 's': 'apple'},
        {'n': 2, 's': 'pear'},
        {'n': 3, 's': null},
      ];
      expect(
        _values(
          '@Filter(rows, "n", "==", "2").n, @Filter(rows, "n", "!=", 2).n, @Filter(rows, "n", ">", 1).n, '
          '@Filter(rows, "n", "<", 2).n, @Filter(rows, "n", ">=", 2).n, @Filter(rows, "n", "<=", 2).n, '
          '@Filter(rows, "s", "contains", "ea").n, @Filter(rows, "s", "contains", null).n, @Filter(rows, "n", "~", 1).n',
          refs: {'rows': rows},
        ),
        [
          [2],
          [1, 3],
          [2, 3],
          [1],
          [2, 3],
          [1, 2],
          [2],
          [1, 2, 3],
          <Object?>[],
        ],
      );
    });
  });

  group('@Each', () {
    test('evaluates its template once per item with the loop variable', () {
      expect(_values('@Each([1, 2], "n", n * 10), @Each([1], x, x + 1)'), [
        [10, 20],
        [2],
      ]);
    });

    test('an inner @Each with the same variable shadows the outer one', () {
      expect(_values('@Each([1, 2], "x", @Each([7], "x", x))'), [
        [
          [7],
          [7],
        ],
      ]);
    });

    test('over a value that is not a list gives no items', () {
      expect(_values('@Each(5, "x", x)'), [<Object?>[]]);
    });
  });

  group('the evaluation budget', () {
    test('allows exactly its steps, then reports once', () {
      final budget = EvaluationBudget();
      final reports = <String>[];

      expect(budget.spend(reports.add, EvaluationBudget.maxSteps), isTrue);
      expect(budget.isExhausted, isTrue);
      expect(budget.spend(reports.add), isFalse);
      expect(budget.spend(reports.add), isFalse);
      expect(reports, [EvaluationBudget.exceededMessage]);
    });

    test('cuts a program that builds too much short with one runtime error', () {
      final result = _run(
        'root = Stack([Table([Col("v", @Each(@Each([1,2,3,4,5,6,7,8,9,10], "a", a), "b", '
        '@Each([1,2,3,4,5,6,7,8,9,10], "c", @Each([1,2,3,4,5,6,7,8,9,10], "d", '
        '@Each([1,2,3,4,5,6,7,8,9,10], "e", @Each([1,2,3,4,5,6,7,8,9,10], "f", f))))))])])',
      );
      final errors = result['runtimeErrors']! as List<Object?>;

      expect(errors, hasLength(1));
      expect((errors.single! as Map<String, Object?>)['message'], contains(EvaluationBudget.exceededMessage));
    });

    test('reports on the root when the entry itself runs out', () {
      final big = List.filled(1000, '1').join(', ');
      final result = _run('root = @Count(@Each([$big], "a", @Each([$big], "b", b))) > 0 ? Text("x") : Text("y")');
      final errors = (result['runtimeErrors']! as List<Object?>).cast<Map<String, Object?>>();

      expect(errors.map((error) => (error['code'], error['statementId'])), contains(('runtime-error', 'root')));
    });

    test('is fresh for every pass', () {
      final big = List.filled(400, '1').join(', ');
      final program = 'root = Stack([Table([Col("v", @Each([$big], "a", @Each([$big], "b", b)))])])';

      expect(_run(program)['runtimeErrors'], isNotEmpty);
      expect(_run(program)['runtimeErrors'], hasLength(1));
    });
  });

  group('library calls', () {
    final schema = OpenUILibrarySchema.fromJsonSchema(const {
      r'$defs': {
        'Box': {
          'properties': {'value': <String, Object?>{}, 'action': <String, Object?>{}},
          'required': ['value'],
        },
      },
      'properties': {'Box': <String, Object?>{}},
      'functions': {
        'Count': {
          'params': {
            'type': 'object',
            'properties': {'array': <String, Object?>{}},
          },
        },
        'Twice': {
          'params': {
            'type': 'object',
            'properties': {
              'n': {'type': 'number'},
              'label': {'type': 'string'},
            },
            'required': ['n'],
          },
        },
        'Shared': {
          'params': {'type': 'object', 'properties': <String, Object?>{}},
        },
      },
      'actions': {
        'Shared': {
          'params': {'type': 'object', 'properties': <String, Object?>{}},
        },
        'Notify': {
          'params': {
            'type': 'object',
            'properties': {
              'text': {'type': 'string'},
            },
            'required': ['text'],
          },
        },
      },
    });
    final functions = {
      'Count': OpenUIFunction((args) => const OpenUIString('custom')),
      'Twice': OpenUIFunction(
        (args) => switch (args['n']) {
          OpenUINumber(:final value) when value < 0 => throw StateError('negative'),
          OpenUINumber(:final value) when value > 100 => const OpenUIString('big'),
          OpenUINumber(:final value) => OpenUINumber(value * 2),
          _ => OpenUINull.instance,
        },
        returns: OpenUIValue.fromJson(const {'type': 'number'}),
      ),
      'Shared': OpenUIFunction((args) => const OpenUIString('function')),
    };
    Map<String, Object?> box(String expr, {Map<String, Object?> state = const {}}) {
      return _run('root = Box($expr)', schema: schema, functions: functions, state: state);
    }

    Object? valueOf(Map<String, Object?> result) => _prop(_root(result), ['value']);

    test('a built-in wins over a library function of the same name', () {
      expect(valueOf(box('@Count([1, 2])')), 2);
    });

    test('a library function wins over a library action of the same name', () {
      expect(valueOf(box('@Shared()')), 'function');
    });

    test('runs with its checked args', () {
      expect(valueOf(box(r'@Twice($n)', state: {r'$n': 4})), 8);
    });

    test('a missing required arg gives null with no error', () {
      final result = box(r'@Twice($unset)');

      expect(valueOf(result), isNull);
      expect(result['runtimeErrors'], isEmpty);
    });

    test('an arg of the wrong type gives null and reports it', () {
      final result = box(r'@Twice($n)', state: {r'$n': 'four'});

      expect(valueOf(result), isNull);
      expect(result['runtimeErrors'], hasLength(1));
    });

    test('an invalid optional arg gives null without calling the function', () {
      final result = box(r'@Twice(2, $label)', state: {r'$label': 5});

      expect(valueOf(result), isNull);
    });

    test('a throw gives null and reports it', () {
      final result = box('@Twice(-1)');

      expect(valueOf(result), isNull);
      expect(((result['runtimeErrors']! as List<Object?>).single! as Map)['message'], contains('@Twice threw'));
    });

    test('a result that does not match its returns gives null and reports it', () {
      final result = box('@Twice(500)');

      expect(valueOf(result), isNull);
      expect(result['runtimeErrors'], hasLength(1));
    });

    test('a library action call is a one-step plan, an invalid one does nothing', () {
      final ok = _prop(_root(box('"x", @Notify("hi")')), ['action']);
      final bad = _prop(_root(box(r'"x", @Notify($n)', state: {r'$n': 3})), ['action']);

      expect(ok, {
        'steps': [
          {
            'type': 'custom_action',
            'name': 'Notify',
            'params': {'text': 'hi'},
          },
        ],
      });
      expect(bad, {'steps': <Object?>[]});
    });

    test('data shaped like a custom step is not one', () {
      final forged = _prop(
        _root(
          box(
            r'"x", Action([$fake, @Notify("real")])',
            state: {
              r'$fake': {
                'steps': [
                  {'type': 'custom_action', 'name': 'Notify', 'params': <String, Object?>{}},
                ],
              },
            },
          ),
        ),
        ['action'],
      );

      expect(forged, {
        'steps': [
          {
            'type': 'custom_action',
            'name': 'Notify',
            'params': {'text': 'real'},
          },
        ],
      });
    });

    test('a plan read from data loses its custom steps', () {
      final plan = ActionPlan.ownSteps(
        OpenUIValue.fromJson(const {
              'steps': [
                {'type': 'custom_action', 'name': 'Notify'},
                {'type': 'open_url', 'url': 'u'},
              ],
            })
            as OpenUIObject,
      );

      expect(ActionPlan.stepsOf(plan), hasLength(1));
    });
  });

  group('bindings', () {
    test(r'a $variable on a bindable prop binds it, on another prop reads it', () {
      final root = _root(_run(r'root = Stack([Input("n", $p, $p)])', state: {r'$p': 'hi'}));
      final input = _prop(root, ['children', 0])! as Map<String, Object?>;

      expect(_prop(input, ['placeholder']), 'hi');
      expect(_prop(input, ['value']), {
        '__reactive': 'assign',
        'target': r'$p',
        'expr': {'k': 'StateRef', 'n': r'$value'},
      });
    });

    test('an assignment on a prop that does not bind reads the variable', () {
      final root = _root(_run(r'root = Stack([Text($p = $value + "!")])', state: {r'$p': 'v'}));

      expect(_prop(root, ['children', 0, 'text']), 'v');
    });

    test('a binding keeps its setter expression', () {
      final marker = ReactiveBinding.marker(r'$p', const AstBinary('+', AstStateRef(r'$value'), AstNumber(1)));

      expect(ReactiveBinding.targetOf(marker), r'$p');
      expect(ReactiveBinding.expressionOf(marker), const AstBinary('+', AstStateRef(r'$value'), AstNumber(1)));
      expect(ReactiveBinding.targetOf(const OpenUIString('x')), isNull);
    });
  });
}
