import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';

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

  testWidgets('triggerAction runs nothing while the reply streams', (tester) async {
    final (_, events) = await _pump(tester, 'root = Stack([Button("Hello")])', isStreaming: true);

    await tester.tap(find.text('Hello'));
    await tester.pump();

    expect(events, isEmpty);
  });

  testWidgets('triggerAction runs while a field of the form fails', (tester) async {
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
}

// A form whose required field is empty, with a `Go` button.
const _formWithRequiredField =
    'root = Stack([Form("f", Buttons([Button("Go")]), [Input("email", "", "text", {required: true})])])';

// Pumps [program] with the standard library's `Button` drawn as its label,
// which runs its action when tapped, checking the form first when [validate]
// is `true`; gives the runtime and the actions it sent.
Future<(OpenUIRuntime, List<OpenUIActionEvent>)> _pump(
  WidgetTester tester,
  String program, {
  bool isStreaming = false,
  bool validate = false,
}) async {
  final library = OpenUILibrary.standard.replacing('Button', (context, scope) {
    final label = scope.text('label') ?? '';
    return GestureDetector(
      onTap: () => scope.triggerAction(label, validate: validate),
      child: Text(label),
    );
  });
  final runtime = testRuntime(library: library);
  addTearDown(runtime.dispose);
  final events = <OpenUIActionEvent>[];
  runtime.actions.listen(events.add);
  await pumpOpenUI(tester, runtime, library: library, program: program, isStreaming: isStreaming);
  return (runtime, events);
}
