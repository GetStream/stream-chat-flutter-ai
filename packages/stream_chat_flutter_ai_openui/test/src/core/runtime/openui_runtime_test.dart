import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

import 'fake_timers.dart';
import 'fake_tools.dart';
import 'spec_runtime.dart';

void main() {
  late FakeTools tools;
  late FakeTimers timers;
  late OpenUIRuntime runtime;
  late List<OpenUIActionEvent> events;

  setUp(() {
    tools = FakeTools();
    timers = FakeTimers();
    runtime = OpenUIRuntime(
      schema: specSchema,
      isBindable: specBindable,
      tools: tools,
      timer: timers.call,
    );
    events = [];
    runtime.actions.listen(events.add);
  });

  tearDown(() => runtime.dispose());

  ElementNode child(int index) => (runtime.root.value!.props['children']! as OpenUIArray).items[index].node;

  Future<void> click(int index, {String? form}) async {
    final button = child(index);
    await runtime.trigger(
      label: (button.props['label']! as OpenUIString).value,
      formName: form,
      action: button.props['action'],
    );
  }

  group('streaming', () {
    test('errors stay empty until the stream ends', () {
      const program = 'root = Stack([Unknown("x")])';
      runtime.update(program, isStreaming: true);

      expect(runtime.errors.value, isEmpty);
      runtime.update(program, isStreaming: false);
      expect(runtime.errors.value.map((error) => error.code), contains(OpenUIErrorCode.unknownComponent));
      runtime.update('$program\n', isStreaming: true);
      expect(runtime.errors.value, isEmpty);
    });

    test('no tool runs until the stream ends', () {
      const program = 'root = Stack([Text("x")])\nq = Query("list", {}, null)';
      runtime.update(program, isStreaming: true);

      expect(tools.calls, isEmpty);
      runtime.update(program, isStreaming: false);
      expect(tools.calls, hasLength(1));
    });

    test('text that is no program reports parse-failed once it ends', () {
      runtime.update('Hello there', isStreaming: false);

      expect(runtime.errors.value.single.code, OpenUIErrorCode.parseFailed);
      expect(runtime.errors.value.single.hint, contains('root = Stack(...)'));
    });

    test('replaced text is read again from the start', () {
      runtime
        ..update('root = Stack([Text("a")])', isStreaming: false)
        ..update('root = Stack([Text("b")])', isStreaming: false);

      expect(child(0).props['text'], _v('b'));
    });
  });

  group('actions', () {
    test('@Set writes the state', () async {
      runtime.update(
        r'$n = 1'
        '\nroot = Stack([Button("Go", @Set(\$n, \$n + 1))])',
        isStreaming: false,
      );
      await click(0);

      expect(runtime.state.value[r'$n'], _v(2));
    });

    test('@Reset writes back the default', () async {
      runtime.update(
        r'$n = 1'
        '\nroot = Stack([Button("Go", Action([@Set(\$n, \$n + 1), @Reset(\$n)]))])',
        isStreaming: false,
      );
      await click(0);

      expect(runtime.state.value[r'$n'], _v(1));
    });

    test('the events of an action carry the state as it is when they run', () async {
      runtime.update(
        r'$n = 1'
        '\nroot = Stack([Button("Go", Action([@Set(\$n, \$n + 1), @ToAssistant("hi", {k: 1}), @Reset(\$n), @OpenUrl("https://a.b")]))])',
        isStreaming: false,
      );
      await click(0);

      expect(events, hasLength(2));
      expect(events.first.type, OpenUIActionEvent.continueConversation);
      expect(events.first.message, 'hi');
      expect(events.first.label, 'Go');
      expect(events.first.params, {
        'context': _v({'k': 1}),
      });
      expect(events.first.formState, {r'$n': _v(2)});
      expect(events.last.type, OpenUIActionEvent.openUrl);
      expect(events.last.params, {'url': _v('https://a.b')});
      expect(events.last.label, '');
    });

    test('an action that changes the state reports the errors it leads to', () async {
      runtime.update(
        r'$t = true'
        '\nroot = \$t ? Stack([Button("b", @Set(\$t, false))]) : 5',
        isStreaming: false,
      );
      await click(0);

      expect(runtime.root.value, isNull);
      expect(runtime.errors.value.map((error) => error.code), [OpenUIErrorCode.noRoot]);
    });

    test(r'@Set declares a $variable no statement declared', () async {
      runtime.update(r'root = Stack([Button("Go", @Set($new, 5))])', isStreaming: false);
      await click(0);

      expect(runtime.state.value[r'$new'], _v(5));
    });

    test('a failed mutation stops the plan, a query run does not', () async {
      runtime.update(
        'm = Mutation("save", {})\nq = Query("list", {}, null)\n'
        'root = Stack([Button("A", Action([@Run(q), @ToAssistant("after query")])), '
        'Button("B", Action([@Run(m), @ToAssistant("after mutation")]))])',
        isStreaming: false,
      );
      tools.calls.single.answer.complete(_v(1));
      await pumpMicrotasks();
      await click(0);
      expect(events.map((event) => event.message), ['after query']);
      expect(tools.calls.where((call) => call.name == 'list'), hasLength(2));

      final run = click(1);
      tools.calls.last.answer.completeError(StateError('no'));
      await run;
      expect(events, hasLength(1));
    });

    test('a mutation runs with its args evaluated when it runs', () async {
      runtime.update(
        r'$t = "a"'
        '\nm = Mutation("save", {title: \$t})\nroot = Stack([Button("B", Action([@Set(\$t, "b"), @Run(m)]))])',
        isStreaming: false,
      );
      tools.results['save'] = _v('ok');
      await click(0);

      expect(tools.calls.single.args, {'title': _v('b')});
    });

    test('the steps of one action update the reply once', () async {
      runtime.update(
        r'$a = 0'
        '\n\$b = 0\nroot = Stack([Button("Go", Action([@Set(\$a, 1), @Set(\$b, 2), @Set(\$a, 3)])), Text(\$a + \$b)])',
        isStreaming: false,
      );
      var updates = 0;
      runtime.root.addListener(() => updates += 1);
      await click(0);

      expect(updates, 1);
      expect(runtime.state.value, {r'$a': _v(3), r'$b': _v(2)});
    });

    test('a query an action fetches again reads the state its earlier steps set', () async {
      runtime.update(
        r'$x = 1'
        '\nq = Query("list", {x: \$x}, null)\nroot = Stack([Button("Go", Action([@Set(\$x, 2), @Run(q)]))])',
        isStreaming: false,
      );
      tools.calls.single.answer.complete(_v(1));
      await pumpMicrotasks();
      await click(0);

      expect(tools.calls.last.args, {'x': _v(2)});
    });

    test('the state set while a mutation runs shows at once', () async {
      runtime.update(
        r'$x = "a"'
        '\nm = Mutation("save", {})\nroot = Stack([Button("Go", @Run(m)), Text(\$x)])',
        isStreaming: false,
      );
      final run = click(0);
      runtime.setFieldValue(null, r'$x', _v('b'));

      expect(child(1).props['text'], _v('b'));
      tools.calls.single.answer.complete(_v('ok'));
      await run;
    });

    test('a library action sends its event with the control label', () async {
      runtime.update('root = Stack([Button("Copy", @CopyToClipboard("t"))])', isStreaming: false);
      await click(0);

      expect(events.single.type, 'CopyToClipboard');
      expect(events.single.params, {'text': _v('t')});
      expect(events.single.label, 'Copy');
      expect(events.single.message, '');
    });

    test('no action, or a legacy object, sends a message labelled with the control', () async {
      await runtime.trigger(label: 'Plain');
      await runtime.trigger(
        label: 'Legacy',
        action: _v({
          'type': '',
          'params': {'a': 1},
          'context': 'c',
        }),
      );
      await runtime.trigger(label: 'Fake', action: _v({'type': 'CopyToClipboard'}));

      expect(events.map((event) => (event.type, event.message)), [
        (OpenUIActionEvent.continueConversation, 'Plain'),
        (OpenUIActionEvent.continueConversation, 'Legacy'),
      ]);
      expect(events.last.params, {'a': _v(1), 'context': _v('c')});
    });
  });

  group('fields', () {
    test(r'a bound field writes its $variable through its expression', () {
      runtime.update(
        r'$q = ""'
        '\nroot = Stack([Input("q", "Q", \$q = \$value + "!")])',
        isStreaming: false,
      );
      final field = runtime.stateField('q', binding: child(0).props['value']);
      field.set(_v('hi'));

      expect(field.isBound, isTrue);
      expect(runtime.state.value[r'$q'], _v('hi!'));
    });

    test('a binding whose expression gives nothing writes what was entered', () {
      runtime.update(r'root = Stack([Input("q", "Q", $q = $value[50])])', isStreaming: false);
      runtime.stateField('q', binding: child(0).props['value']).set(_v('typed'));

      expect(runtime.state.value[r'$q'], _v('typed'));
    });

    test('a field outside a binding is kept under its form with its component type', () {
      runtime.update('root = Stack([Form("f", [Input("e", "E")])])', isStreaming: false);
      runtime.stateField('e', formName: 'f', componentType: 'input').set(_v('x'));

      expect(
        runtime.state.value['f'],
        _v({
          'e': {'value': 'x', 'componentType': 'input'},
        }),
      );
      expect(runtime.fieldValue('f', 'e'), _v('x'));
    });

    test('a secret field is never bound and never leaves the store', () async {
      runtime.update(
        r'$p = ""'
        '\nroot = Stack([Form("f", [Input("pw", "P", \$p), Button("Go", Action([@ToAssistant("x")]))])])',
        isStreaming: false,
      );
      final form = (child(0).props['children']! as OpenUIArray).items;
      final field = runtime.stateField('pw', binding: form[0].node.props['value'], formName: 'f', isSecret: true)
        ..set(_v('hunter2'));
      await runtime.trigger(label: 'Go', formName: 'f', action: form[1].node.props['action']);

      expect(field.isBound, isFalse);
      expect(runtime.state.value[r'$p'], _v(''));
      expect(runtime.state.value['f'], _v({}));
      expect(events.single.formState, {'f': _v({})});
      expect(runtime.fieldValue('f', 'pw'), _v('hunter2'));
    });

    test('validate gives each failing field its first error', () {
      runtime.update('root = Stack([Form("f", [Input("e", "E")])])', isStreaming: false);
      runtime.stateField('e', formName: 'f').set(_v('ab'));

      expect(
        runtime.validate('f', {
          'e': _v({'minLength': 3}),
          'missing': _v({'required': true}),
        }),
        {
          'e': const FormValidationError(FormValidationErrorCode.minLength, 3),
          'missing': const FormValidationError(FormValidationErrorCode.required),
        },
      );
    });
  });

  test('clearing the text removes its queries', () async {
    runtime.update('q = Query("list", {}, null, 10)\nroot = Stack([Text("x")])', isStreaming: false);
    tools.calls.single.answer.complete(_v(1));
    await pumpMicrotasks();
    runtime.update('', isStreaming: false);
    await timers.elapse(const Duration(seconds: 30));

    expect(tools.calls, hasLength(1));
  });

  test('a step that is not an action is skipped, not the rest of the plan', () async {
    await runtime.trigger(
      label: 'Go',
      action: _v({
        'steps': [
          'junk',
          {'type': 'continue_conversation', 'message': 'hi'},
        ],
      }),
    );

    expect(events.single.message, 'hi');
  });

  test('a secret field named like a form never goes out as that form', () async {
    runtime.update('root = Stack([Text("x")])', isStreaming: false);
    runtime.stateField('f', componentType: 'input', isSecret: true).set(_v('hunter2'));
    await runtime.trigger(label: 'Go', formName: 'f');

    expect(events.single.formState.toString(), isNot(contains('hunter2')));
  });

  test('validate checks a bound field by its variable', () {
    runtime.update(
      r'$q = "typed"'
      '\nroot = Stack([Input("q", "Q", \$q)])',
      isStreaming: false,
    );

    expect(
      runtime.validate(
        null,
        {
          'q': _v({'required': true}),
        },
        bindings: {'q': child(0).props['value']},
      ),
      isEmpty,
    );
    expect(
      runtime.validate(null, {
        'q': _v({'required': true}),
      }),
      {'q': const FormValidationError(FormValidationErrorCode.required)},
    );
  });

  test('restored state applies over the defaults and is kept', () {
    runtime
      ..update(
        r'$a = 1'
        '\nroot = Stack([Text("" + \$a)])',
        isStreaming: false,
      )
      ..restore({r'$a': 7});

    expect(child(0).props['text'], _v('7'));
    expect(runtime.state.value[r'$a'], _v(7));
  });

  group('restored state', () {
    const first =
        r'$name = "X"'
        '\nroot = Stack([Input("n", "N", \$name)])';
    const second =
        r'$name = "X"'
        '\n\$other = 1'
        '\nroot = Stack([Input("n", "N", \$name)])';

    OpenUIRuntime restored(Map<String, Object?> initialState) => OpenUIRuntime(
      schema: specSchema,
      isBindable: specBindable,
      initialState: initialState,
    );

    OpenUIValue? read(OpenUIRuntime runtime, String name) => runtime.state.value[name];

    test(r'a typed $variable survives a later declaration while the reply streams', () {
      final rebuilt = restored({r'$name': 'A'})..update(first, isStreaming: true);
      expect(read(rebuilt, r'$name'), _v('A'));
      rebuilt.stateField('n', binding: _bindingTo(rebuilt, r'$name')).set(_v('B'));
      rebuilt.update(second, isStreaming: true);

      expect(read(rebuilt, r'$name'), _v('B'));
      expect(read(rebuilt, r'$other'), _v(1));
      rebuilt.dispose();
    });

    test('a typed form field survives a later declaration while the reply streams', () {
      final rebuilt = restored({'f': 'A'})..update(first, isStreaming: true);
      rebuilt.stateField('f').set(_v('B'));
      rebuilt.update(second, isStreaming: true);

      expect(rebuilt.fieldValue(null, 'f'), _v('B'));
      rebuilt.dispose();
    });

    test('restore() after typing still overwrites with the restored value', () {
      final rebuilt = restored({r'$name': 'A', 'f': 'A'})..update(first, isStreaming: true);
      rebuilt.stateField('n', binding: _bindingTo(rebuilt, r'$name')).set(_v('B'));
      rebuilt.stateField('f').set(_v('B'));
      rebuilt.restore({r'$name': 'C', 'f': 'C'});

      expect(read(rebuilt, r'$name'), _v('C'));
      expect(rebuilt.fieldValue(null, 'f'), _v('C'));
      rebuilt.dispose();
    });

    test(r'restore() runs the queries that read a restored $variable', () async {
      final rebuilt =
          OpenUIRuntime(
            schema: specSchema,
            isBindable: specBindable,
            tools: tools,
            timer: timers.call,
          )..update(
            r'$s = "a"'
            '\nq = Query("list", {s: \$s}, null)\nroot = Stack([Input("s", "S", \$s)])',
            isStreaming: false,
          );
      tools.calls.single.answer.complete(_v(1));
      await pumpMicrotasks();
      rebuilt.restore({r'$s': 'z'});
      await timers.elapse(const Duration(milliseconds: 300));

      expect(tools.calls.last.args, {'s': _v('z')});
      rebuilt.dispose();
    });

    test('state does not notify on a declaration-only change', () {
      final rebuilt = restored({r'$name': 'A'})..update(first, isStreaming: true);
      var notifications = 0;
      rebuilt.state.addListener(() => notifications += 1);
      // The declared default changes, the saved value still wins.
      rebuilt.update(first.replaceFirst('"X"', '"Y"'), isStreaming: true);
      expect(notifications, 0);
      rebuilt.update(second, isStreaming: true);

      expect(notifications, 1);
      expect(read(rebuilt, r'$name'), _v('A'));
      rebuilt.dispose();
    });

    test('a persisted value wins over the declared default on the first update', () {
      final rebuilt = restored({r'$name': 'A'})..update(first, isStreaming: false);

      expect(read(rebuilt, r'$name'), _v('A'));
      rebuilt.dispose();
    });

    test('a persisted value given before any text arrived wins over the default that arrives later', () {
      final rebuilt = restored({r'$name': 'A'})..update(null, isStreaming: true);
      expect(read(rebuilt, r'$name'), _v('A'));
      rebuilt.update(first, isStreaming: true);

      expect(read(rebuilt, r'$name'), _v('A'));
      rebuilt.dispose();
    });

    test('an untouched key follows its declaration as it changes', () {
      final rebuilt = restored({r'$kept': 'A'})
        ..update(
          r'$name = "X"'
          '\nroot = Stack([])',
          isStreaming: true,
        );
      expect(read(rebuilt, r'$name'), _v('X'));
      rebuilt.update(
        r'$name = "Y"'
        '\nroot = Stack([])',
        isStreaming: true,
      );

      expect(read(rebuilt, r'$name'), _v('Y'));
      expect(read(rebuilt, r'$kept'), _v('A'));
      rebuilt.dispose();
    });

    test('no key is removed when its declaration vanishes while streaming', () {
      final rebuilt = restored({r'$name': 'A'})
        ..update(second, isStreaming: true)
        ..update('root = Stack([])', isStreaming: true);

      expect(read(rebuilt, r'$other'), _v(1));
      expect(read(rebuilt, r'$name'), _v('A'));
      rebuilt.dispose();
    });
  });

  test('a first update evaluates the tree a number of times that does not grow with its declarations', () {
    int evaluations(int declarations) {
      var calls = 0;
      final counting =
          OpenUIRuntime(
            schema: specSchema,
            functions: {
              'Upper': OpenUIFunction((args) {
                calls += 1;
                return const OpenUIString('x');
              }),
            },
          )..update(
            [
              for (var i = 0; i < declarations; i += 1) '\$v$i = $i',
              'root = Stack([Text(@Upper("x"))])',
            ].join('\n'),
            isStreaming: false,
          );
      // ignore: cascade_invocations
      counting.dispose();
      return calls;
    }

    final few = evaluations(1);
    expect(few, greaterThan(0));
    expect(evaluations(20), few);
  });

  test(r'a query fetches again when a $variable in its args changes', () async {
    runtime.update(
      r'$s = "a"'
      '\nq = Query("list", {s: \$s}, null)\nroot = Stack([Input("s", "S", \$s)])',
      isStreaming: false,
    );
    tools.calls.single.answer.complete(_v(1));
    await pumpMicrotasks();
    runtime.stateField('s', binding: child(0).props['value']).set(_v('b'));
    await timers.elapse(const Duration(milliseconds: 300));

    expect(tools.calls.last.args, {'s': _v('b')});
    expect(runtime.isQueryLoading.value, isTrue);
  });

  test(r'a failed query is not fetched again by keystrokes in a field bound to a $variable', () async {
    runtime.update(
      r'$name = ""'
      '\nq = Query("missing_tool", {}, null)\nroot = Stack([Input("n", "N", \$name)])',
      isStreaming: false,
    );
    tools.calls.single.answer.completeError(Exception('no such tool'));
    await pumpMicrotasks();
    for (final text in ['a', 'ab', 'abc']) {
      runtime.stateField('n', binding: child(0).props['value']).set(_v(text));
      await timers.elapse(const Duration(milliseconds: 300));
    }

    expect(tools.calls, hasLength(1));
    expect(runtime.errors.value, isNotEmpty);
  });

  test('an update evaluates the tree at most 8 times when evaluating changes what it reads', () {
    late OpenUIRuntime looping;
    var calls = 0;
    looping = OpenUIRuntime(
      schema: specSchema,
      functions: {
        'Upper': OpenUIFunction((args) {
          calls += 1;
          // Writing state while the tree evaluates asks for another pass.
          looping.stateField(r'$n').set(OpenUINumber(calls.toDouble()));
          return const OpenUIString('X');
        }),
      },
    );
    // A cascade would run before `looping` is assigned, and `Upper` reads it.
    // ignore: cascade_invocations
    looping.update('root = Stack([Text(@Upper("x"))])', isStreaming: false);

    expect(calls, OpenUIRuntime.maxPasses);
    looping.dispose();
  });

  test(r'a $variable write keeps the identity of every element it did not change', () async {
    runtime.update(
      r'$n = 1'
      '\nroot = Stack([Text("a"), Text(\$n), Button("go", @Set(\$n, 2)), Text("b")])',
      isStreaming: false,
    );
    final before = [for (var i = 0; i < 4; i++) child(i)];
    await click(2);

    expect(child(1), isNot(before[1]));
    expect(child(0), same(before[0]));
    expect(child(2), same(before[2]));
    expect(child(3), same(before[3]));
  });

  test(r'an @Each template reads a $variable in a prop that takes no binding', () {
    runtime.update('\$label = "hi"\nroot = Stack(@Each([1, 2], "x", Text(\$label)))', isStreaming: false);

    expect([child(0).props['text'], child(1).props['text']], const [OpenUIString('hi'), OpenUIString('hi')]);
  });

  test('children that are reordered, added or removed keep the identity of the statements they came from', () {
    runtime.update('a = Text("a")\nb = Text("b")\nc = Text("c")\nroot = Stack([a, b, c])', isStreaming: false);
    final [a, b, c] = [child(0), child(1), child(2)];
    runtime.update(
      'a = Text("a")\nb = Text("b")\nc = Text("c")\nroot = Stack([c, a, b, Text("d")])',
      isStreaming: false,
    );

    expect(child(0), same(c));
    expect(child(1), same(a));
    expect(child(2), same(b));
    expect(child(3).props['text'], _v('d'));
    runtime.update('a = Text("a")\nb = Text("b")\nc = Text("c")\nroot = Stack([b])', isStreaming: false);
    expect(child(0), same(b));
  });

  test('evaluating any cut of a program never throws', () {
    // The example programs of the built-in libraries, each read against its
    // own library, cut at every twentieth of its length.
    final programs = [
      for (final library in [LibraryDefinition.chat, LibraryDefinition.standard])
        for (final example in library.defaultPromptOptions.examples)
          (library: library, program: example.split('\n').skip(1).join('\n').trim()),
    ];
    for (final (:library, :program) in programs) {
      for (var step = 0; step <= 20; step += 1) {
        final cut = program.substring(0, program.length * step ~/ 20);
        final fuzzed = OpenUIRuntime(schema: library.schema, isBindable: library.isBindable);
        expect(() => fuzzed.update(cut, isStreaming: step.isEven), returnsNormally, reason: cut);
        fuzzed.dispose();
      }
    }
  });

  test('nothing changes after dispose', () async {
    runtime
      ..update('q = Query("list", {}, null)\nroot = Stack([Text("x")])', isStreaming: false)
      ..dispose();
    tools.calls.single.answer.complete(_v(1));
    await pumpMicrotasks();
    runtime.update('root = Stack([Text("y")])', isStreaming: false);
    await runtime.trigger(label: 'x');

    expect(events, isEmpty);
  });
}

OpenUIValue? _bindingTo(OpenUIRuntime runtime, String target) => runtime.root.value!.props['children'] is OpenUIArray
    ? ((runtime.root.value!.props['children']! as OpenUIArray).items.first.node.props['value'])
    : null;

extension on OpenUIValue {
  ElementNode get node => (this as OpenUIElement).node;
}

OpenUIValue _v(Object? json) => OpenUIValue.fromJson(json);
