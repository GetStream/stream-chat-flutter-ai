import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';

import '../openui_test_app.dart';

void main() {
  testWidgets('stateField writes the variable its binding prop is bound to', (tester) async {
    final runtime = await _pump(tester, r'root = Stack([Input("a", "", "text", null, $q)])');

    await tester.tap(find.text('a: null bound'));
    await tester.pump();

    expect(runtime.state.value[r'$q'], const OpenUIString('typed'));
  });

  testWidgets('a field bound to a variable shows what another field bound to it writes', (tester) async {
    await _pump(tester, r'root = Stack([Input("a", "", "text", null, $q), Input("b", "", "text", null, $q)])');

    await tester.tap(find.text('a: null bound'));
    await tester.pump();

    expect(find.text('b: typed bound'), findsOneWidget);
  });

  testWidgets('stateField without a binding prop reads the variable the prop of its own name is bound to', (
    tester,
  ) async {
    late OpenUIStateField field;
    final library = OpenUILibrary.standard.replacing('Input', (context, scope) {
      field = scope.stateField('value');
      return const SizedBox();
    });
    await _pump(tester, '\$q = "hi"\nroot = Stack([Input("n", "", "text", null, \$q)])', library: library);

    expect(field.value, 'hi');
  });

  testWidgets("stateField of an unbound prop shows the prop's own value until written", (tester) async {
    await _pump(tester, 'root = Stack([Input("n", "", "text", null, "start")])');

    expect(find.text('n: start unbound'), findsOneWidget);
  });

  testWidgets('stateField of an unbound prop shows what is written', (tester) async {
    await _pump(tester, 'root = Stack([Input("n", "", "text", null, "start")])');

    await tester.tap(find.text('n: start unbound'));
    await tester.pump();

    expect(find.text('n: typed unbound'), findsOneWidget);
  });

  testWidgets('stateField of an unbound field in a form keeps it in the form', (tester) async {
    final runtime = await _pump(tester, 'root = Stack([Form("f", Buttons([Button("Go")]), [Input("n")])])');

    await tester.tap(find.text('n: null unbound'));
    await tester.pump();

    expect(runtime.fieldValue('f', 'n'), const OpenUIString('typed'));
  });

  testWidgets("stateField of an unbound field outside a form keeps it in the reply's state", (tester) async {
    final runtime = await _pump(tester, 'root = Stack([Input("n")])');

    await tester.tap(find.text('n: null unbound'));
    await tester.pump();

    expect(runtime.fieldValue(null, 'n'), const OpenUIString('typed'));
  });

  testWidgets('stateField of a field in a form sends its value and component type with an action', (tester) async {
    final events = <OpenUIActionEvent>[];
    final runtime = await _pump(tester, 'root = Stack([Form("f", Buttons([Button("Go")]), [Input("n")])])');
    runtime.actions.listen(events.add);

    await tester.tap(find.text('n: null unbound'));
    await tester.pump();
    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(plainJson(OpenUIObject(events.single.formState)), {
      'f': {
        'n': {'value': 'typed', 'componentType': 'Input'},
      },
    });
  });

  testWidgets('stateField keeps a field written after the component left the tree in its form', (tester) async {
    late OpenUIComponentScope captured;
    final library = OpenUILibrary.standard.replacing('Input', (context, scope) {
      captured = scope;
      return const SizedBox();
    });
    final runtime = await _pump(
      tester,
      'root = Stack([Form("f", Buttons([Button("Go")]), [Input("n")])])',
      library: library,
    );
    await tester.pumpWidget(const SizedBox());

    captured.stateField('n').set('later');

    expect(runtime.fieldValue('f', 'n'), const OpenUIString('later'));
  });

  testWidgets('stateField of a password Input is left out of the form state an action sends', (tester) async {
    final events = <OpenUIActionEvent>[];
    final runtime = await _pump(
      tester,
      'root = Stack([Form("f", Buttons([Button("Go")]), [Input("pw", "", "password")])])',
    );
    runtime.actions.listen(events.add);

    await tester.tap(find.text('pw: null unbound'));
    await tester.pump();
    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(plainJson(OpenUIObject(events.single.formState)), {'f': <String, Object?>{}});
  });

  testWidgets('stateField of a password Input is never bound to a variable', (tester) async {
    await _pump(tester, r'root = Stack([Input("pw", "", "password", null, $p)])');

    expect(find.text('pw: null unbound'), findsOneWidget);
  });

  testWidgets('OpenUIStateField.set writes JSON', (tester) async {
    late OpenUIStateField field;
    final library = OpenUILibrary.standard.replacing('Input', (context, scope) {
      field = scope.stateField('n');
      return const SizedBox();
    });
    final runtime = await _pump(tester, 'root = Stack([Input("n")])', library: library);

    field.set({
      'a': [1, true, null],
    });

    expect(
      runtime.fieldValue(null, 'n'),
      OpenUIObject({
        'a': OpenUIValue.fromJson(const [1, true, null]),
      }),
    );
  });

  testWidgets("OpenUIStateField's toString leaves out the value", (tester) async {
    late OpenUIComponentScope input;
    final library = OpenUILibrary.standard.replacing('Input', (context, scope) {
      input = scope;
      return const SizedBox();
    });
    await _pump(tester, 'root = Stack([Input("pw", "", "password")])', library: library);
    input.stateField('pw').set('hunter2');

    expect(input.stateField('pw').toString(), isNot(contains('hunter2')));
  });

  testWidgets("OpenUIStateField.set throws an ArgumentError for a value that isn't JSON", (tester) async {
    late OpenUIStateField field;
    final library = OpenUILibrary.standard.replacing('Input', (context, scope) {
      field = scope.stateField('n');
      return const SizedBox();
    });
    await _pump(tester, 'root = Stack([Input("n")])', library: library);

    expect(() => field.set(DateTime(2026)), throwsArgumentError);
  });
}

// The standard library with an `Input` that shows its field, read with its
// `value` as the binding prop, and writes `typed` to it when tapped.
final _library = OpenUILibrary.standard.replacing('Input', (context, scope) {
  return scope.watchState((context) {
    final field = scope.stateField(scope.text('name') ?? '', bindingProp: 'value');
    return GestureDetector(
      onTap: () => field.set('typed'),
      child: Text('${scope.text('name')}: ${field.value} ${field.isBound ? 'bound' : 'unbound'}'),
    );
  });
});

// Pumps [program] drawn with [library], [_library] by default.
Future<OpenUIRuntime> _pump(WidgetTester tester, String program, {OpenUILibrary? library}) async {
  final drawn = library ?? _library;
  final runtime = testRuntime(library: drawn);
  addTearDown(runtime.dispose);
  await pumpOpenUI(tester, runtime, library: drawn, program: program);
  return runtime;
}
