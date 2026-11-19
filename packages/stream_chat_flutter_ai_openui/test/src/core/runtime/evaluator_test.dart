import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_test_interface.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/action_plan.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/builtins.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/evaluator.dart';

import 'spec_runtime.dart';

void main() {
  test('dividing by zero gives 0', () {
    expect(_value('7 / 0'), 0);
  });

  test('taking the remainder by zero gives 0', () {
    expect(_value('7 % 0'), 0);
  });

  for (final (expr, expected) in [('-7 % 3', -1), ('7 % -3', 1)]) {
    test('a remainder takes the sign of the dividend ($expr is $expected)', () {
      expect(_value(expr), expected);
    });
  }

  for (final (expr, expected) in [('0 && "x"', 0), ('1 && "x"', 'x')]) {
    test('&& gives the operand that decides ($expr is $expected)', () {
      expect(_value(expr), expected);
    });
  }

  for (final (expr, expected) in [('"" || "y"', 'y'), ('"z" || "y"', 'z')]) {
    test('|| gives the operand that decides ($expr is $expected)', () {
      expect(_value(expr), expected);
    });
  }

  test('adding null to text joins it as nothing', () {
    expect(_value('"a" + null'), 'a');
  });

  test('adding a number to text joins it as text, after the sum before it', () {
    expect(_value('1 + 2 + "x"'), '3x');
  });

  for (final (expr, expected) in [('!0', true), ('!"x"', false)]) {
    test('the unary ! negates truthiness ($expr is $expected)', () {
      expect(_value(expr), expected);
    });
  }

  test('the unary - negates numeric text as a number', () {
    expect(_value('-"3"'), -3);
  });

  for (final (expr, expected) in [('5 - 2', 3), ('"5" - 2', 3)]) {
    test('subtracting reads numeric text as a number ($expr is $expected)', () {
      expect(_value(expr), expected);
    });
  }

  for (final (expr, expected) in [
    ('1 == "1"', true),
    ('"a" == "b"', false),
    ('null == 0', false),
    ('null == null', true),
  ]) {
    test("== is JavaScript's loose equality ($expr is $expected)", () {
      expect(_value(expr), expected);
    });
  }

  for (final (expr, expected) in [('1 != "1"', false), ('1 != 2', true)]) {
    test("!= is the negation of JavaScript's loose equality ($expr is $expected)", () {
      expect(_value(expr), expected);
    });
  }

  for (final (expr, expected) in [
    ('1 < 2', true),
    ('2 < 1', false),
    ('2 >= 2', true),
    ('1 >= 2', false),
    ('2 <= 2', true),
    ('3 <= 2', false),
    ('"3" < 10', true),
  ]) {
    test('a comparison orders numbers and numeric text ($expr is $expected)', () {
      expect(_value(expr), expected);
    });
  }

  final rows = {
    'rows': [
      {'name': 'a'},
      {'other': 1},
    ],
  };

  test('reading a field of a list reads it from every item', () {
    expect(_value('rows.name', refs: rows), ['a', null]);
  });

  test('the length of a list is its item count', () {
    expect(_value('rows.length', refs: rows), 2);
  });

  test('reading a field an item lacks gives null', () {
    expect(_value('rows[1].name', refs: rows), isNull);
  });

  test('reading past the end of a list gives null', () {
    expect(_value('rows[5]', refs: rows), isNull);
  });

  for (final (expr, expected) in [
    ('@Round(2.5)', 3),
    ('@Round(-2.5)', -2),
    ('@Round(1234.5678, 2)', 1234.57),
    ('@Round(1234.5678, -2)', 1200),
  ]) {
    test('@Round rounds halves up, to the decimals asked ($expr is $expected)', () {
      expect(_value(expr), expected);
    });
  }

  for (final (expr, expected) in [('@Min([])', 0), ('@Max([])', 0)]) {
    test('@Min and @Max of no items are 0 ($expr)', () {
      expect(_value(expr), expected);
    });
  }

  for (final (expr, expected) in [('@Min([3, "1", 2])', 1), ('@Max([3, "7", true])', 7)]) {
    test('@Min and @Max read numeric text as numbers ($expr is $expected)', () {
      expect(_value(expr), expected);
    });
  }

  for (final name in ['Min', 'Max']) {
    test('@$name gives NaN when an item is NaN', () {
      final items = [
        OpenUIArray(const [OpenUINumber(1), OpenUINumber(double.nan)]),
      ];

      expect((Builtins.functions[name]!(items) as OpenUINumber).value, isNaN);
    });
  }

  for (final (behavior, expr, expected) in [
    ('@First gives the first item', '@First([4, 5])', 4),
    ('@First of no items gives null', '@First([])', null),
    ('@Last gives the last item', '@Last([4, 5])', 5),
    ('@Last of no items gives null', '@Last([])', null),
    ('@Sum adds numbers and numeric text', '@Sum([1, 2, "3"])', 6),
    ('@Sum of no items is 0', '@Sum([])', 0),
    ('@Avg is the sum over the item count', '@Avg([2, 4])', 3),
    ('@Avg of no items is 0', '@Avg([])', 0),
    ('@Abs drops the sign', '@Abs(-3)', 3),
    ('@Abs of text that is not a number is 0', '@Abs("x")', 0),
    ('@Floor rounds toward the lower number', '@Floor(-2.5)', -3),
    ('@Ceil rounds toward the higher number', '@Ceil(-2.5)', -2),
  ]) {
    test(behavior, () {
      expect(_value(expr), expected);
    });
  }

  test('@Sort compares numbers and numeric text as numbers', () {
    expect(_value('@Sort([3, "10", 2, "1"], "")'), ['1', 2, 3, '10']);
  });

  test('@Sort compares text ignoring case first, then lower case before upper case', () {
    expect(_value('@Sort(["b", "B", "a", "c"], "")'), ['a', 'b', 'B', 'c']);
  });

  test('@Sort descending keeps equal items in their order', () {
    final rows = {
      'rows': [
        {'id': 'x', 'n': 1},
        {'id': 'y', 'n': 2},
        {'id': 'z', 'n': 1},
      ],
    };

    expect(_value('@Sort(rows, "n", "desc").id', refs: rows), ['y', 'x', 'z']);
  });

  test('@Sort orders accented letters next to their base letter', () {
    expect(_value('@Sort(["zoe", "Émile", "eve", "Ana", "élan"], "")'), ['Ana', 'élan', 'Émile', 'eve', 'zoe']);
  });

  test('@Sort orders an accented letter after its base letter', () {
    expect(_value('@Sort(["f", "é", "e"], "")'), ['e', 'é', 'f']);
  });

  test('@Sort gives a value that is not a list back as it is', () {
    expect(_value('@Sort("text", "x")'), 'text');
  });

  final filterRows = {
    'rows': [
      {'n': 1, 's': 'apple'},
      {'n': 2, 's': 'pear'},
      {'n': 3, 's': null},
    ],
  };

  for (final (behavior, args, expected) in [
    ('keeps the items equal to the value with ==', '"n", "==", "2"', [2]),
    ('keeps the items different from the value with !=', '"n", "!=", 2', [1, 3]),
    ('keeps the items above the value with >', '"n", ">", 1', [2, 3]),
    ('keeps the items below the value with <', '"n", "<", 2', [1]),
    ('keeps the items from the value up with >=', '"n", ">=", 2', [2, 3]),
    ('keeps the items up to the value with <=', '"n", "<=", 2', [1, 2]),
    ('keeps the items whose text holds the value with contains', '"s", "contains", "ea"', [2]),
    ('keeps every item when it contains null', '"s", "contains", null', [1, 2, 3]),
    ('keeps nothing for an unknown operator', '"n", "~", 1', <Object?>[]),
  ]) {
    test('@Filter $behavior', () {
      expect(_value('@Filter(rows, $args).n', refs: filterRows), expected);
    });
  }

  test('@Each evaluates its template once per item with the loop variable', () {
    expect(_value('@Each([1, 2], "n", n * 10)'), [10, 20]);
  });

  test('@Each takes the loop variable written without quotes', () {
    expect(_value('@Each([1], x, x + 1)'), [2]);
  });

  test('an inner @Each with the same variable shadows the outer one', () {
    expect(_value('@Each([1, 2], "x", @Each([7], "x", x))'), [
      [7],
      [7],
    ]);
  });

  test('@Each over a value that is not a list gives no items', () {
    expect(_value('@Each(5, "x", x)'), <Object?>[]);
  });

  test('@Each writes the loop variable into a negation', () {
    expect(_setter('-n'), {
      'k': 'UnaryOp',
      'op': '-',
      'operand': {'k': 'Num', 'v': 3},
    });
  });

  test('@Each writes the loop variable into an operation', () {
    expect(_setter('n + 1'), {
      'k': 'BinOp',
      'op': '+',
      'left': {'k': 'Num', 'v': 3},
      'right': {'k': 'Num', 'v': 1},
    });
  });

  test('@Each writes the loop variable into a ternary', () {
    expect(_setter('n > 2 ? n : 0'), {
      'k': 'Ternary',
      'cond': {
        'k': 'BinOp',
        'op': '>',
        'left': {'k': 'Num', 'v': 3},
        'right': {'k': 'Num', 'v': 2},
      },
      'then': {'k': 'Num', 'v': 3},
      'else': {'k': 'Num', 'v': 0},
    });
  });

  test('@Each writes the loop variable into a list', () {
    expect(_setter('[n, 1]'), {
      'k': 'Arr',
      'els': [
        {'k': 'Num', 'v': 3},
        {'k': 'Num', 'v': 1},
      ],
    });
  });

  test('@Each writes the loop variable into an object', () {
    expect(_setter('{v: n}'), {
      'k': 'Obj',
      'entries': [
        [
          'v',
          {'k': 'Num', 'v': 3},
        ],
      ],
    });
  });

  test('@Each writes a field of an item as the field it holds', () {
    final named = {
      'rows': [
        {'name': 'a'},
      ],
    };

    expect(_setter('n.name', items: 'rows', refs: named), {'k': 'Str', 'v': 'a'});
  });

  test('@Each keeps the read of a field an item lacks', () {
    final named = {
      'rows': [
        {'name': 'a'},
      ],
    };

    expect(_setter('n.other', items: 'rows', refs: named), {
      'k': 'Member',
      'obj': {
        'k': 'Obj',
        'entries': [
          [
            'name',
            {'k': 'Str', 'v': 'a'},
          ],
        ],
      },
      'field': 'other',
    });
  });

  test('@Each writes the loop variable into an index of an item', () {
    final pairs = {
      'rows': [
        [1, 2],
      ],
    };

    expect(_setter('n[1]', items: 'rows', refs: pairs), {
      'k': 'Index',
      'obj': {
        'k': 'Arr',
        'els': [
          {'k': 'Num', 'v': 1},
          {'k': 'Num', 'v': 2},
        ],
      },
      'index': {'k': 'Num', 'v': 1},
    });
  });

  test('@Each writes a true or false item as it is', () {
    expect(_setter('n', items: '[true]'), {'k': 'Bool', 'v': true});
  });

  test('@Each writes a text item as it is', () {
    expect(_setter('n', items: '["a"]'), {'k': 'Str', 'v': 'a'});
  });

  test('@Each writes a list item as it is', () {
    final lists = {
      'rows': [
        [1, 2],
      ],
    };

    expect(_setter('n', items: 'rows', refs: lists), {
      'k': 'Arr',
      'els': [
        {'k': 'Num', 'v': 1},
        {'k': 'Num', 'v': 2},
      ],
    });
  });

  test('@Each writes an object item as it is', () {
    final objects = {
      'rows': [
        {'a': 1},
      ],
    };

    expect(_setter('n', items: 'rows', refs: objects), {
      'k': 'Obj',
      'entries': [
        [
          'a',
          {'k': 'Num', 'v': 1},
        ],
      ],
    });
  });

  test('the evaluation budget allows exactly its steps', () {
    expect(EvaluationBudget().spend((_) {}, EvaluationBudget.maxSteps), isTrue);
  });

  test('the evaluation budget is exhausted once its steps are spent', () {
    final budget = EvaluationBudget()..spend((_) {}, EvaluationBudget.maxSteps);

    expect(budget.isExhausted, isTrue);
  });

  test('the evaluation budget refuses a step once its steps are spent', () {
    final budget = EvaluationBudget()..spend((_) {}, EvaluationBudget.maxSteps);

    expect(budget.spend((_) {}), isFalse);
  });

  test('the evaluation budget reports its exhaustion once', () {
    final reports = <String>[];
    EvaluationBudget()
      ..spend(reports.add, EvaluationBudget.maxSteps)
      ..spend(reports.add)
      ..spend(reports.add);

    expect(reports, [EvaluationBudget.exceededMessage]);
  });

  test('a program that builds too much is cut short with one runtime error', () {
    expect(_overBudgetErrors(), hasLength(1));
  });

  test('a program that builds too much is told it exceeded the budget', () {
    expect(
      (_overBudgetErrors().single! as Map<String, Object?>)['message'],
      contains(EvaluationBudget.exceededMessage),
    );
  });

  test('an entry that runs out of steps is reported on the root', () {
    final big = List.filled(1000, '1').join(', ');
    final result = _run('root = @Count(@Each([$big], "a", @Each([$big], "b", b))) > 0 ? Text("x") : Text("y")');
    final errors = (result['runtimeErrors']! as List<Object?>).cast<Map<String, Object?>>();

    expect(errors.map((error) => (error['code'], error['statementId'])), contains(('runtime-error', 'root')));
  });

  test('the evaluation budget is fresh for every pass', () {
    final big = List.filled(400, '1').join(', ');
    final program = 'root = Stack([Table([Col("v", @Each([$big], "a", @Each([$big], "b", b)))])])';
    _run(program);

    expect(_run(program)['runtimeErrors'], hasLength(1));
  });

  for (final count in [500, 2000, 4000]) {
    test('a share-of-total table of $count rows renders every row', () {
      final result = _run(
        r'root = Stack(@Each($rows, "r", Text("" + r.v / @Sum($rows.v))))',
        state: {
          r'$rows': [
            for (var i = 0; i < count; i += 1) {'v': 1},
          ],
        },
      );

      expect(result['runtimeErrors'], isEmpty);
      expect(_texts(result).last, '${1 / count}');
    });
  }

  test('a share-of-total table whose total loops with the same name renders every row', () {
    final result = _run(
      r'root = Stack(@Each($rows, "r", Text("" + r.v / @Sum(@Each($rows, "r", r.v)))))',
      state: {
        r'$rows': [
          for (var i = 0; i < 2000; i += 1) {'v': 1},
        ],
      },
    );

    expect(result['runtimeErrors'], isEmpty);
    expect(_texts(result).last, '${1 / 2000}');
  });

  test('a total read in a nested loop is the total of its own group', () {
    final result = _run(
      r'root = Stack(@Each($groups, "g", Text("" + @Sum(g.v))))',
      state: {
        r'$groups': [
          {
            'v': [1, 2],
          },
          {
            'v': [3, 4],
          },
        ],
      },
    );

    expect(_texts(result), ['3', '7']);
  });

  test('a built-in that filters every row for each row runs out of steps', () {
    // 1,000 rows filtered once per row walk 1,000,000 items, past
    // EvaluationBudget.maxSteps.
    final result = _run(
      r'root = Stack(@Each($rows, "r", Text("" + @Count(@Filter($rows, "v", "==", r.v)))))',
      state: {
        r'$rows': [
          for (var i = 0; i < 1000; i += 1) {'v': i},
        ],
      },
    );
    final errors = (result['runtimeErrors']! as List<Object?>).cast<Map<String, Object?>>();

    expect(errors.single['message'], contains(EvaluationBudget.exceededMessage));
  });

  test('a loop reading a large field of each item renders every row', () {
    final result = _run(
      r'root = Stack(@Each($rows, "r", Text("" + @Count(r.data))))',
      state: {
        r'$rows': [
          for (var i = 0; i < 60; i += 1) {'data': List.filled(3000, 0)},
        ],
      },
    );

    expect(result['runtimeErrors'], isEmpty);
    expect(_texts(result).last, '3000');
  });

  test('a sum of 210,000 items outside any loop renders', () {
    // More items than EvaluationBudget.maxSteps, walked once.
    final result = _run(
      r'root = Stack([Text("" + @Sum($big))])',
      state: {r'$big': List.filled(210000, 1)},
    );

    expect(result['runtimeErrors'], isEmpty);
    expect(_texts(result), ['210000']);
  });

  test('a sum of 210,000 items read in each row of a loop renders every row', () {
    // Walked once, as the sum reads no row.
    final result = _run(
      r'root = Stack(@Each([1, 2], "r", Text("" + @Sum($big))))',
      state: {r'$big': List.filled(210000, 1)},
    );

    expect(result['runtimeErrors'], isEmpty);
    expect(_texts(result), ['210000', '210000']);
  });

  test("a sum of each row's own list renders every row", () {
    final result = _run(
      r'root = Stack(@Each($rows, "r", Text("" + @Sum(r.data))))',
      state: {
        r'$rows': [
          for (var i = 0; i < 40; i += 1) {'data': List.filled(3500, 1)},
        ],
      },
    );

    expect(result['runtimeErrors'], isEmpty);
    expect(_texts(result).last, '3500');
  });

  test('four totals of the same 100,000-item list render', () {
    // Each total walks the list once; walking it four times in all would pass
    // EvaluationBudget.maxSteps if only the first walk were free.
    final result = _run(
      r'root = Stack([Text("" + @Sum($big) + @Avg($big) + @Max($big) + @Min($big))])',
      state: {r'$big': List.filled(100000, 1)},
    );

    expect(result['runtimeErrors'], isEmpty);
    expect(_texts(result), ['100000111']);
  });

  test('a filter of every row for each row of a nested loop runs out of steps', () {
    final result = _run(
      r'root = Stack(@Each($rows, "r", Stack(@Each([1], "c", Text("" + @Count(@Filter($rows, "v", "==", r.v)))))))',
      state: {
        r'$rows': [
          for (var i = 0; i < 1000; i += 1) {'v': i},
        ],
      },
    );
    final errors = (result['runtimeErrors']! as List<Object?>).cast<Map<String, Object?>>();

    expect(errors.single['message'], contains(EvaluationBudget.exceededMessage));
  });

  test("a filter of every row's field for each row runs out of steps", () {
    final result = _run(
      r'root = Stack(@Each($rows, "r", Text("" + @Count(@Filter($rows.v, "", "==", r.v)))))',
      state: {
        r'$rows': [
          for (var i = 0; i < 1000; i += 1) {'v': i},
        ],
      },
    );
    final errors = (result['runtimeErrors']! as List<Object?>).cast<Map<String, Object?>>();

    expect(errors.single['message'], contains(EvaluationBudget.exceededMessage));
  });

  test(r'a filter of a $variable read as a new list each time, for each row, runs out of steps', () {
    // `@Each($rows, "r", @Count(@Filter($rows, "v", "==", r.v)))`, its state
    // read as the runtime reads it, a new copy on each read.
    final loop = AstCall('Each', [
      const AstStateRef(r'$rows'),
      const AstString('r'),
      AstCall('Count', [
        AstCall('Filter', const [
          AstStateRef(r'$rows'),
          AstString('v'),
          AstString('=='),
          AstMember(AstRef('r'), 'v'),
        ]),
      ]),
    ]);
    final reports = <String>[];
    final context = EvaluationContext(
      getState: (_) => OpenUIArray([
        for (var i = 0; i < 1000; i += 1) OpenUIObject({'v': OpenUINumber(i.toDouble())}),
      ]),
      resolveRef: (_) => null,
      reportError: reports.add,
    );
    Evaluator.evaluate(loop, context);

    expect(reports, [EvaluationBudget.exceededMessage]);
  });

  test('a count of a 12,000-item list read in each of 1,000 rows renders every row', () {
    // A count doesn't walk its list, so the 12,000,000 items it is given
    // aren't charged.
    final result = _run(
      r'root = Stack(@Each($rows, "r", Text("" + @Count(r.big ? $a : $b))))',
      state: {
        r'$rows': [
          for (var i = 0; i < 1000; i += 1) {'big': i.isEven},
        ],
        r'$a': List.filled(12000, 0),
        r'$b': List.filled(11000, 0),
      },
    );

    expect(result['runtimeErrors'], isEmpty);
    expect(_texts(result).last, '11000');
  });

  test('a count of 2,000 rows for each of 10 categories renders every category', () {
    final result = _run(
      r'root = Stack(@Each($cats, "c", Text(c + ": " + @Count(@Filter($rows, "cat", "==", c)))))',
      state: {
        r'$cats': [for (var i = 0; i < 10; i += 1) 'c$i'],
        r'$rows': [
          for (var i = 0; i < 2000; i += 1) {'cat': 'c${i % 10}'},
        ],
      },
    );

    expect(result['runtimeErrors'], isEmpty);
    expect(_texts(result).last, 'c9: 200');
  });

  test('a loop variable hides a query of the same name inside the loop', () {
    final result = _run(
      'r = Query("tool", {}, [7, 8, 9, 10])\n'
      'total = @Count(r)\n'
      r'root = Stack(@Each($lists, "r", Text("" + total)))',
      state: {
        r'$lists': [
          [1],
          [1, 2],
          [1, 2, 3],
        ],
      },
    );

    expect(_texts(result), ['1', '2', '3']);
  });

  test('a built-in call nested 40 deep in a loop evaluates', () {
    final nested = '${'@Abs(' * 40}-1${')' * 40}';

    final result = _run('root = Stack(@Each([1, 2, 3], "r", Text("" + $nested)))');

    expect(_texts(result), ['1', '1', '1']);
  });

  test(r'a loop over a built-in reading $value gives the value of the scope it is evaluated in', () {
    final loop = AstCall('Each', [
      AstArray(const [AstNumber(1), AstNumber(2)]),
      const AstString('x'),
      AstCall('Count', const [AstStateRef(r'$value')]),
    ]);
    final context = EvaluationContext(
      getState: (_) => null,
      resolveRef: (_) => null,
      extraScope: {
        r'$value': OpenUIArray(const [OpenUINumber(1)]),
      },
    );
    final other = context.copyWith(
      extraScope: {
        r'$value': OpenUIArray(const [OpenUINumber(1), OpenUINumber(2)]),
      },
    );
    // The same loop, evaluated first in the pass with another `$value`.
    final first = Evaluator.evaluate(loop, context);

    expect(first, OpenUIArray(const [OpenUINumber(1), OpenUINumber(1)]));
    expect(Evaluator.evaluate(loop, other), OpenUIArray(const [OpenUINumber(2), OpenUINumber(2)]));
  });

  test('a count of the rows past a computed threshold, read in each of 4,000 rows, renders every row', () {
    final result = _run(
      r'root = Stack(@Each($rows, "r", Text(r.v + " of " + @Count(@Filter($rows, "v", ">", 1 + 1)))))',
      state: {
        r'$rows': [
          for (var i = 0; i < 4000; i += 1) {'v': i},
        ],
      },
    );

    expect(result['runtimeErrors'], isEmpty);
    expect(_texts(result).last, '3999 of 3997');
  });

  group('with a library of Box, Twice, Shared and Notify', () {
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

    List<Object?> errorsOf(Map<String, Object?> result) => result['runtimeErrors']! as List<Object?>;

    test('a built-in wins over a library function of the same name', () {
      expect(valueOf(box('@Count([1, 2])')), 2);
    });

    test('a library function wins over a library action of the same name', () {
      expect(valueOf(box('@Shared()')), 'function');
    });

    test('a library function runs with its checked args', () {
      expect(valueOf(box(r'@Twice($n)', state: {r'$n': 4})), 8);
    });

    test('a library function with a missing required arg gives null', () {
      expect(valueOf(box(r'@Twice($unset)')), isNull);
    });

    test('a library function with a missing required arg reports nothing', () {
      expect(errorsOf(box(r'@Twice($unset)')), isEmpty);
    });

    test('a library function with an arg of the wrong type gives null', () {
      expect(valueOf(box(r'@Twice($n)', state: {r'$n': 'four'})), isNull);
    });

    test('a library function with an arg of the wrong type reports it once', () {
      expect(errorsOf(box(r'@Twice($n)', state: {r'$n': 'four'})), hasLength(1));
    });

    test('a library function with an invalid optional arg gives null', () {
      expect(valueOf(box(r'@Twice(2, $label)', state: {r'$label': 5})), isNull);
    });

    test('a library function that throws gives null', () {
      expect(valueOf(box('@Twice(-1)')), isNull);
    });

    test('a library function that throws is reported by name', () {
      expect((errorsOf(box('@Twice(-1)')).single! as Map)['message'], contains('@Twice threw'));
    });

    test('a library function that throws inside a built-in in a loop is reported for every item', () {
      final errors = errorsOf(box('@Each([1, 2, 3], "r", @Count([@Twice(-1)]))'));

      expect(errors, hasLength(3));
    });

    test('a library function whose result does not match its returns gives null', () {
      expect(valueOf(box('@Twice(500)')), isNull);
    });

    test('a library function whose result does not match its returns is reported once', () {
      expect(errorsOf(box('@Twice(500)')), hasLength(1));
    });

    test('a library action call is a one-step plan', () {
      final plan = _prop(_root(box('"x", @Notify("hi")')), ['action']);

      expect(plan, {
        'steps': [
          {
            'type': 'custom_action',
            'name': 'Notify',
            'params': {'text': 'hi'},
          },
        ],
      });
    });

    test('a library action call with an invalid arg does nothing', () {
      final plan = _prop(_root(box(r'"x", @Notify($n)', state: {r'$n': 3})), ['action']);

      expect(plan, {'steps': <Object?>[]});
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

  test(r'a $variable on a bindable prop binds it', () {
    expect(_prop(_boundInput(), ['value']), {
      '__reactive': 'assign',
      'target': r'$p',
      'expr': {'k': 'StateRef', 'n': r'$value'},
    });
  });

  test(r'a $variable on a prop that is not bindable reads it', () {
    expect(_prop(_boundInput(), ['placeholder']), 'hi');
  });

  test('an assignment on a prop that does not bind reads the variable', () {
    final root = _root(_run(r'root = Stack([Text($p = $value + "!")])', state: {r'$p': 'v'}));

    expect(_prop(root, ['children', 0, 'text']), 'v');
  });

  test('a binding keeps its target', () {
    expect(ReactiveBinding.targetOf(_marker()), r'$p');
  });

  test('a binding keeps its setter expression', () {
    expect(ReactiveBinding.expressionOf(_marker()), const AstBinary('+', AstStateRef(r'$value'), AstNumber(1)));
  });

  test('a value that is not a binding has no target', () {
    expect(ReactiveBinding.targetOf(const OpenUIString('x')), isNull);
  });
}

final _spec = specSchema;

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
    isBindable: specBindable,
    state: state,
    refs: refs,
    functions: functions ?? specFunctions,
  );
}

Map<String, Object?> _root(Map<String, Object?> result) => result['evaluatedRoot']! as Map<String, Object?>;

// The texts of the root's children, each a `Text`.
List<Object?> _texts(Map<String, Object?> result) => [
  for (final child in (_prop(_root(result), ['children'])! as List<Object?>).cast<Map<String, Object?>>())
    _prop(child, ['text']),
];

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

// The value of the single expression `expr`.
Object? _value(String expr, {Map<String, Object?> state = const {}, Map<String, Object?> refs = const {}}) {
  return _values(expr, state: state, refs: refs).single;
}

// The setter expression the binding `$x = template` gets from the one item of
// `items`, which `template` reads as `n`.
Object? _setter(String template, {String items = '[3]', Map<String, Object?> refs = const {}}) {
  final bindings = _value('@Each($items, "n", \$x = $template)', refs: refs)! as List<Object?>;
  return (bindings.single! as Map<String, Object?>)['expr'];
}

// The runtime errors of a program whose loops build more than its budget allows.
List<Object?> _overBudgetErrors() {
  final result = _run(
    'root = Stack([Table([Col("v", @Each(@Each([$_ten], "a", a), "b", '
    '@Each([$_ten], "c", @Each([$_ten], "d", '
    '@Each([$_ten], "e", @Each([$_ten], "f", f))))))])])',
  );

  return result['runtimeErrors']! as List<Object?>;
}

// Ten items to make a loop long, written as a list's contents.
const _ten = '1, 2, 3, 4, 5, 6, 7, 8, 9, 10';

// The input of a program that binds its value to `$p`, which holds 'hi'.
Map<String, Object?> _boundInput() {
  final root = _root(_run(r'root = Stack([Input("n", $p, $p)])', state: {r'$p': 'hi'}));
  return _prop(root, ['children', 0])! as Map<String, Object?>;
}

// A binding of `$p` whose setter adds 1 to what was entered.
OpenUIValue _marker() => ReactiveBinding.marker(r'$p', const AstBinary('+', AstStateRef(r'$value'), AstNumber(1)));
