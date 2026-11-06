import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

import '../../../conformance/openui_conformance.dart';
import 'fake_timers.dart';
import 'fake_tools.dart';

OpenUIValue _v(Object? json) => OpenUIValue.fromJson(json);

void main() {
  late FakeTools tools;
  late FakeTimers timers;
  late OpenUIRuntime runtime;
  late List<OpenUIActionEvent> events;

  setUp(() {
    tools = FakeTools();
    timers = FakeTimers();
    runtime = OpenUIRuntime(
      schema: conformanceLibraries()['spec']!,
      isBindable: conformanceBindables('spec'),
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
    test('errors stay empty and no tool runs until the stream ends', () async {
      const program = 'root = Stack([Unknown("x")])\nq = Query("list", {}, null)';
      runtime.update(program, isStreaming: true);

      expect(runtime.errors.value, isEmpty);
      expect(tools.calls, isEmpty);
      runtime.update(program, isStreaming: false);
      expect(runtime.errors.value.map((error) => error.code), contains(OpenUIErrorCode.unknownComponent));
      expect(tools.calls, hasLength(1));
      runtime.update('$program\n', isStreaming: true);
      expect(runtime.errors.value, isEmpty);
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
    test('@Set and @Reset write the state, and events carry it as it is when they run', () async {
      runtime.update(
        r'$n = 1'
        '\nroot = Stack([Button("Go", Action([@Set(\$n, \$n + 1), @ToAssistant("hi", {k: 1}), @Reset(\$n), @OpenUrl("https://a.b")]))])',
        isStreaming: false,
      );
      await click(0);

      expect(runtime.state.value[r'$n'], _v(1));
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
          'e': 'Must be at least 3 characters',
          'missing': 'This field is required',
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
      {'q': 'This field is required'},
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

  test('an update evaluates the tree at most 8 times when evaluating changes what it reads', () {
    late OpenUIRuntime looping;
    var calls = 0;
    looping = OpenUIRuntime(
      schema: conformanceLibraries()['spec']!,
      functions: {
        'Upper': OpenUIFunction((args) {
          calls += 1;
          // Writing state while the tree evaluates asks for another pass.
          looping.stateField(r'$n').set(OpenUINumber(calls.toDouble()));
          return const OpenUIString('X');
        }),
      },
    );
    looping.update('root = Stack([Text(@Upper("x"))])', isStreaming: false);

    expect(calls, OpenUIRuntime.maxPasses);
    looping.dispose();
  });

  test('evaluating any cut of a program never throws', () {
    final programs = [
      for (final testCase in evaluatorCases()) testCase['input']! as String,
    ];
    for (final (index, program) in programs.indexed) {
      final cut = program.substring(0, (program.length * ((index * 37) % 100) / 100).floor());
      final fuzzed = OpenUIRuntime(schema: conformanceLibraries()['spec']!, isBindable: conformanceBindables('spec'));
      expect(() => fuzzed.update(cut, isStreaming: index.isEven), returnsNormally, reason: cut);
      fuzzed.dispose();
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

extension on OpenUIValue {
  ElementNode get node => (this as OpenUIElement).node;
}
