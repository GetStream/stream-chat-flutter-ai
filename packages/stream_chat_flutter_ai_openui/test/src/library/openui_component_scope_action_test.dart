import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';

import '../core/runtime/fake_tools.dart';
import '../openui_test_app.dart';

void main() {
  testWidgets('triggerAction runs the steps of the action', (tester) async {
    final (_, events) = await _pump(tester, 'root = Stack([Button("Ask", @ToAssistant("Tell me more"))])');

    await tester.tap(find.text('Ask'));
    await tester.pump();

    expect(events.map((event) => (event.type, event.message)), [
      (OpenUIActionEvent.continueConversation, 'Tell me more'),
    ]);
  });

  testWidgets('triggerAction writes a variable with a @Set step', (tester) async {
    final (runtime, _) = await _pump(tester, r'root = Stack([Button("Set", @Set($q, "there"))])');

    await tester.tap(find.text('Set'));
    await tester.pump();

    expect(runtime.state.value[r'$q'], const OpenUIString('there'));
  });

  testWidgets('triggerAction continues the conversation with the label when there is no action', (tester) async {
    final (_, events) = await _pump(tester, 'root = Stack([Button("Hello")])');

    await tester.tap(find.text('Hello'));
    await tester.pump();

    expect(events.map((event) => (event.type, event.label)), [(OpenUIActionEvent.continueConversation, 'Hello')]);
  });

  testWidgets('triggerAction runs with the state of the form the component is in', (tester) async {
    final (runtime, events) = await _pump(tester, 'root = Stack([Form("f", Buttons([Button("Go")]), [])])');
    runtime.setFieldValue('f', 'n', const OpenUIString('v'));

    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(plainJson(OpenUIObject(events.single.formState)), {
      'f': {
        'n': {'value': 'v'},
      },
    });
  });

  testWidgets('triggerAction without inForm runs outside the form the component is in', (tester) async {
    final (_, events) = await _pump(tester, 'root = Stack([Form("f", Buttons([Button("Go")]), [])])', inForm: false);

    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(events.single.formName, isNull);
  });

  testWidgets('triggerAction runs nothing while the reply streams', (tester) async {
    final (_, events) = await _pump(tester, 'root = Stack([Button("Hello")])', isStreaming: true);

    await tester.tap(find.text('Hello'));
    await tester.pump();

    expect(events, isEmpty);
  });

  testWidgets('triggerAction without validate runs while a field of the form fails', (tester) async {
    final (_, events) = await _pump(tester, _formWithRequiredField);

    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(events, hasLength(1));
  });

  testWidgets('triggerAction with validate runs nothing while a field of the form fails', (tester) async {
    final (_, events) = await _pump(tester, _formWithRequiredField, validate: true);

    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(events, isEmpty);
  });

  testWidgets('triggerAction with validate checks the form before a mutation', (tester) async {
    final tools = FakeTools();
    await _pump(
      tester,
      'm = Mutation("save", {})\n'
      'root = Stack([Form("f", Buttons([Button("Go", @Run(m))]), [Input("email", "", "text", {required: true})])])',
      validate: true,
      tools: tools,
    );

    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(tools.calls, isEmpty);
  });

  testWidgets('triggerAction with validate sends nothing to the assistant while a field of the form fails', (
    tester,
  ) async {
    final (_, events) = await _pump(
      tester,
      'root = Stack([Form("f", Buttons([Button("Go", @ToAssistant("x"))]), [Input("email", "", "text", {required: true})])])',
      validate: true,
    );

    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(events, isEmpty);
  });

  testWidgets('triggerAction with validate checks the form for a plan with a step that sends to the assistant', (
    tester,
  ) async {
    final (runtime, _) = await _pump(
      tester,
      r'root = Stack([Form("f", Buttons([Button("Go", Action([@Set($q, "x"), @ToAssistant("y")]))]), [Input("email", "", "text", {required: true})])])',
      validate: true,
    );

    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(runtime.state.value[r'$q'], OpenUINull.instance);
  });

  testWidgets('triggerAction with validate runs a query while a field of the form fails', (tester) async {
    final tools = FakeTools()..results['list'] = const OpenUIString('ok');
    await _pump(
      tester,
      'q = Query("list", {}, null)\n'
      'root = Stack([Form("f", Buttons([Button("Go", @Run(q))]), [Input("email", "", "text", {required: true})])])',
      validate: true,
      tools: tools,
    );
    final before = tools.calls.length;

    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(tools.calls.length, before + 1);
  });

  testWidgets('triggerAction with validate runs once the fields of the form pass', (tester) async {
    final (runtime, events) = await _pump(tester, _formWithRequiredField, validate: true);
    runtime.setFieldValue('f', 'email', const OpenUIString('a@b.c'));
    await tester.pump();

    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(events, hasLength(1));
  });

  testWidgets('triggerAction with validate shows the error of a field that fails', (tester) async {
    await _pump(
      tester,
      'root = Stack([Form("f", Buttons([Button("Go")]), [FormControl("Email", Input("email", "", "text", {required: true}))])])',
      validate: true,
    );

    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(find.text('This field is required'), findsOneWidget);
  });

  testWidgets('triggerAction with validate runs an action of @Set steps alone without checking the form', (
    tester,
  ) async {
    final (runtime, _) = await _pump(
      tester,
      r'root = Stack([Form("f", Buttons([Button("Go", @Set($q, "x"))]), [Input("email", "", "text", {required: true})])])',
      validate: true,
    );

    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(runtime.state.value[r'$q'], const OpenUIString('x'));
  });

  testWidgets('triggerAction with validate runs outside a form', (tester) async {
    final (_, events) = await _pump(tester, 'root = Stack([Button("Hello")])', validate: true);

    await tester.tap(find.text('Hello'));
    await tester.pump();

    expect(events, hasLength(1));
  });

  testWidgets('triggerAction with validate runs without checking a form that left the tree', (tester) async {
    late OpenUIComponentScope captured;
    final library = OpenUILibrary.standard.replacing('Button', (context, scope) {
      captured = scope;
      return const SizedBox();
    });
    final runtime = testRuntime(library: library);
    addTearDown(runtime.dispose);
    final events = <OpenUIActionEvent>[];
    runtime.actions.listen(events.add);
    await pumpOpenUI(tester, runtime, library: library, program: _formWithRequiredField);
    await tester.pumpWidget(const SizedBox());

    await captured.triggerAction('Go', validate: true);

    expect(events.single.formName, 'f');
  });

  testWidgets('triggerAction completes once the action has run', (tester) async {
    late OpenUIComponentScope captured;
    final library = OpenUILibrary.standard.replacing('Button', (context, scope) {
      captured = scope;
      return const SizedBox();
    });
    final tools = FakeTools();
    final runtime = testRuntime(library: library, tools: tools);
    addTearDown(runtime.dispose);
    await pumpOpenUI(
      tester,
      runtime,
      library: library,
      program: 'm = Mutation("save", {})\nroot = Stack([Button("Go", @Run(m))])',
    );
    var completed = false;
    unawaited(captured.triggerAction('Go').then((_) => completed = true));
    await tester.pump();
    final completedWhileRunning = completed;

    tools.calls.single.answer.complete(const OpenUIString('ok'));
    await tester.pump();

    expect((completedWhileRunning, completed), (false, true));
  });

  testWidgets('triggerAction runs the action the named prop holds', (tester) async {
    final events = <OpenUIActionEvent>[];
    final library = OpenUILibrary.chat.replacing('Table', (context, scope) => scope.buildProp('columns')).replacing(
      'Col',
      (context, scope) {
        return GestureDetector(
          onTap: () => scope.triggerAction('Col', name: 'data'),
          child: Text(scope.text('label') ?? ''),
        );
      },
    );
    final runtime = testRuntime(library: library);
    addTearDown(runtime.dispose);
    runtime.actions.listen(events.add);
    await pumpOpenUI(
      tester,
      runtime,
      library: library,
      program: 'root = Card([Table([Col("Ask", @ToAssistant("from data"))])])',
    );

    await tester.tap(find.text('Ask'));
    await tester.pump();

    expect(events.single.message, 'from data');
  });
}

// A form whose required field is empty, with a `Go` button.
const _formWithRequiredField =
    'root = Stack([Form("f", Buttons([Button("Go")]), [Input("email", "", "text", {required: true})])])';

// Pumps [program] with the standard library's `Button` drawn as its label,
// which runs its action when tapped, checking the form first when [validate]
// is `true` and outside its form when [inForm] is `false`, with [tools]
// running its queries and mutations; gives the runtime and the actions it
// sent.
Future<(OpenUIRuntime, List<OpenUIActionEvent>)> _pump(
  WidgetTester tester,
  String program, {
  bool isStreaming = false,
  bool validate = false,
  bool inForm = true,
  FakeTools? tools,
}) async {
  final library = OpenUILibrary.standard.replacing('Button', (context, scope) {
    final label = scope.text('label') ?? '';
    return GestureDetector(
      onTap: () => scope.triggerAction(label, validate: validate, inForm: inForm),
      child: Text(label),
    );
  });
  final runtime = testRuntime(library: library, tools: tools);
  addTearDown(runtime.dispose);
  final events = <OpenUIActionEvent>[];
  runtime.actions.listen(events.add);
  await pumpOpenUI(tester, runtime, library: library, program: program, isStreaming: isStreaming);
  return (runtime, events);
}
