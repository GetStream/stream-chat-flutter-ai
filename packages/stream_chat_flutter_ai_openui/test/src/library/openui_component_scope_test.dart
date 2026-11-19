import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';

import '../openui_test_app.dart';

void main() {
  // A library that draws a `Table`'s columns, each `Col` with [buildCol].
  OpenUILibrary columns(OpenUIComponentBuilder buildCol) {
    return OpenUILibrary.chat
        .replacing('Table', (context, scope) => scope.buildProp('columns'))
        .replacing('Col', buildCol);
  }

  // Reads the scope of a `Col` labelled `L` whose `data`, a prop that takes
  // any value, is [data]; its `type` is left out.
  Future<OpenUIComponentScope> scopeOf(WidgetTester tester, String data, {bool isStreaming = false}) async {
    OpenUIComponentScope? captured;
    final library = columns((context, scope) {
      captured = scope;
      return const SizedBox();
    });
    final runtime = testRuntime(library: library);
    addTearDown(runtime.dispose);
    await pumpOpenUI(
      tester,
      runtime,
      library: library,
      program: 'root = Card([Table([Col("L", $data)])])',
      isStreaming: isStreaming,
    );
    return captured!;
  }

  testWidgets('type and isStreaming', (tester) async {
    final scope = await scopeOf(tester, '"a"', isStreaming: true);

    expect(scope.type, 'Col');
    expect(scope.isStreaming, isTrue);
    expect((await scopeOf(tester, '"a"')).isStreaming, isFalse);
  });

  testWidgets('the scope follows the same runtime from streaming to done', (tester) async {
    final isStreaming = <bool>[];
    final library = columns((context, scope) {
      isStreaming.add(scope.isStreaming);
      return const SizedBox();
    });
    final runtime = testRuntime(library: library);
    addTearDown(runtime.dispose);
    await pumpOpenUI(
      tester,
      runtime,
      library: library,
      program: 'root = Card([Table([Col("L", "a")])])',
      isStreaming: true,
    );
    expect(isStreaming.last, isTrue);

    runtime.update('root = Card([Table([Col("L", "a")])])', isStreaming: false);
    await tester.pump();

    expect(isStreaming.last, isFalse);
  });

  testWidgets('string gives a string only', (tester) async {
    expect((await scopeOf(tester, '"a"')).string('data'), 'a');
    expect((await scopeOf(tester, '"a"')).string('label'), 'L');
    expect((await scopeOf(tester, '3')).string('data'), isNull);
    expect((await scopeOf(tester, '"a"')).string('type'), isNull);
  });

  testWidgets('text reads any value as text, and a missing prop as null', (tester) async {
    expect((await scopeOf(tester, '3')).text('data'), '3');
    expect((await scopeOf(tester, '2.5')).text('data'), '2.5');
    expect((await scopeOf(tester, 'true')).text('data'), 'true');
    expect((await scopeOf(tester, '"a"')).text('data'), 'a');
    expect((await scopeOf(tester, '[1, "b"]')).text('data'), '1,b');
    expect((await scopeOf(tester, '"a"')).text('type'), isNull);
  });

  testWidgets('number reads numbers and numeric strings', (tester) async {
    expect((await scopeOf(tester, '2.5')).number('data'), 2.5);
    expect((await scopeOf(tester, '"2.5"')).number('data'), 2.5);
    expect((await scopeOf(tester, '"x"')).number('data'), isNull);
    expect((await scopeOf(tester, '" "')).number('data'), isNull);
    expect((await scopeOf(tester, 'true')).number('data'), isNull);
    expect((await scopeOf(tester, '"a"')).number('type'), isNull);
  });

  testWidgets('boolean reads booleans and the strings true and false', (tester) async {
    expect((await scopeOf(tester, 'true')).boolean('data'), isTrue);
    expect((await scopeOf(tester, '"false"')).boolean('data'), isFalse);
    expect((await scopeOf(tester, '"True"')).boolean('data'), isNull);
    expect((await scopeOf(tester, '1')).boolean('data'), isNull);
  });

  testWidgets('stringList and numberList read lists, wrap single values and give [] for null', (tester) async {
    final list = await scopeOf(tester, '["a", 2, null, true]');
    expect(list.stringList('data'), ['a', '2', '', 'true']);
    final numbers = (await scopeOf(tester, '[true, 1, "2", "x"]')).numberList('data');
    expect(numbers.take(3), [1, 1, 2]);
    expect(numbers.last, 0);
    expect((await scopeOf(tester, '"a"')).stringList('data'), ['a']);
    expect((await scopeOf(tester, '4')).numberList('data'), [4]);
    expect((await scopeOf(tester, '"a"')).stringList('type'), isEmpty);
    expect((await scopeOf(tester, '"a"')).numberList('type'), isEmpty);
  });

  testWidgets('value gives JSON, with null for a component', (tester) async {
    final scope = await scopeOf(tester, '{a: [1, "b", true, null], c: CardHeader("t")}');

    expect(scope.value('data'), {
      'a': [1.0, 'b', true, null],
      'c': null,
    });
    expect(scope.value('type'), isNull);
  });

  testWidgets('buildProp draws a component, a list of parts and a value', (tester) async {
    late OpenUIComponentScope captured;
    final library = columns((context, scope) {
      captured = scope;
      return Column(children: [scope.buildProp('data'), scope.buildProp('label'), scope.buildProp('type')]);
    });
    final runtime = testRuntime(library: library);
    addTearDown(runtime.dispose);
    await pumpOpenUI(
      tester,
      runtime,
      library: library,
      program: 'root = Card([Table([Col("plain", [CardHeader("Head"), 7, null, "", Unknown()])])])',
    );

    expect(captured.type, 'Col');
    expect(find.text('Head'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('plain'), findsOneWidget);
    // The null, the empty string and the component without a builder take no
    // place in the column.
    final column = tester.widget<Column>(find.ancestor(of: find.text('7'), matching: find.byType(Column)).first);
    expect(column.children, hasLength(2));
  });

  testWidgets('buildDefault draws what this package draws for a replaced component', (tester) async {
    final library = OpenUILibrary.chat.replacing('TextContent', (context, scope) => scope.buildDefault());
    final runtime = testRuntime(library: library);
    addTearDown(runtime.dispose);
    await pumpOpenUI(tester, runtime, library: library, program: 'root = Card([TextContent("hi")])');

    expect(find.text('hi', findRichText: true), findsOneWidget);
  });

  testWidgets('buildDefault draws nothing for a type this package does not draw', (tester) async {
    Widget? built;
    final library = columns((context, scope) => built = scope.buildDefault());
    final runtime = testRuntime(library: library);
    addTearDown(runtime.dispose);
    await pumpOpenUI(tester, runtime, library: library, program: 'root = Card([Table([Col("L", 1)])])');

    expect(built, isA<SizedBox>().having((box) => (box.width, box.height), 'size', (0.0, 0.0)));
  });

  testWidgets('a builder that throws draws nothing and reports the error', (tester) async {
    final library = OpenUILibrary.chat.replacing('CardHeader', (context, scope) => throw StateError('boom'));
    final runtime = testRuntime(library: library);
    addTearDown(runtime.dispose);
    await pumpOpenUI(tester, runtime, library: library, program: 'root = Card([CardHeader("t"), TextContent("ok")])');

    expect(tester.takeException(), isA<StateError>());
    expect(find.text('ok', findRichText: true), findsOneWidget);
  });

  group('children', () {
    // Pumps [program] with the chat `Card` replaced by [buildCard].
    Future<void> pumpCard(WidgetTester tester, String program, OpenUIComponentBuilder buildCard) async {
      final library = OpenUILibrary.chat.replacing('Card', buildCard);
      final runtime = testRuntime(library: library);
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, library: library, program: program);
    }

    testWidgets('children gives the components of a list prop in order, leaving out other items', (tester) async {
      late List<OpenUIChild> children;
      await pumpCard(tester, 'root = Card([CardHeader("A"), "text", TextContent("B")])', (context, scope) {
        children = scope.children('children');
        return const SizedBox();
      });

      expect([for (final child in children) child.type], ['CardHeader', 'TextContent']);
    });

    testWidgets('children gives the one component a prop holds', (tester) async {
      late List<OpenUIChild> children;
      final library = OpenUILibrary.chat.replacing('IconButton', (context, scope) {
        children = scope.children('icon');
        return const SizedBox();
      });
      final runtime = testRuntime(library: library);
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, library: library, program: 'root = Card([IconButton("Star", Icon("star"))])');

      expect([for (final child in children) child.type], ['Icon']);
    });

    testWidgets('children gives an empty list for a prop without components', (tester) async {
      late List<OpenUIChild> children;
      await pumpCard(tester, 'root = Card([CardHeader("A")])', (context, scope) {
        children = scope.children('missing');
        return const SizedBox();
      });

      expect(children, isEmpty);
    });

    testWidgets('children gives components whose type has no builder, to read with scopeOf', (tester) async {
      late List<String?> titles;
      final library = OpenUILibrary.chat.replacing('Tabs', (context, scope) {
        titles = [for (final tab in scope.children('items')) scope.scopeOf(tab).text('trigger')];
        return const SizedBox();
      });
      final runtime = testRuntime(library: library);
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        library: library,
        program: 'root = Card([Tabs([TabItem("a", "First", [TextContent("1")]), TabItem("b", "Second", [])])])',
      );

      expect(titles, ['First', 'Second']);
    });

    testWidgets("build draws a child with its type's builder", (tester) async {
      await pumpCard(tester, 'root = Card([CardHeader("A"), TextContent("B")])', (context, scope) {
        final children = scope.children('children');
        return Column(children: [for (final child in children.reversed) scope.build(child)]);
      });

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B', findRichText: true), findsOneWidget);
      expect(tester.getTopLeft(find.text('B', findRichText: true)).dy, lessThan(tester.getTopLeft(find.text('A')).dy));
    });

    testWidgets('a child defined by a statement keeps its key when a sibling arrives before it', (tester) async {
      final keys = <List<String>>[];
      final library = OpenUILibrary.chat.replacing('Card', (context, scope) {
        keys.add([for (final child in scope.children('children')) child.key]);
        return const SizedBox();
      });
      final runtime = testRuntime(library: library);
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        library: library,
        program: 'root = Card([a, b])\nb = TextContent("B")',
        isStreaming: true,
      );
      runtime.update('root = Card([a, b])\nb = TextContent("B")\na = TextContent("A")', isStreaming: false);
      await tester.pump();

      expect(keys.first, hasLength(1));
      expect(keys.last, hasLength(2));
      expect(keys.last.last, keys.first.single);
    });

    testWidgets('a statement placed twice gives children with different keys', (tester) async {
      late List<OpenUIChild> children;
      await pumpCard(tester, 'root = Card([a, a])\na = TextContent("A")', (context, scope) {
        children = scope.children('children');
        return const SizedBox();
      });

      expect(children, hasLength(2));
      expect(children.first.key, isNot(children.last.key));
      expect(children.first, isNot(children.last));
    });

    testWidgets('children read twice are equal', (tester) async {
      late List<OpenUIChild> first;
      late List<OpenUIChild> second;
      await pumpCard(tester, 'root = Card([CardHeader("A"), TextContent("B")])', (context, scope) {
        first = scope.children('children');
        second = scope.children('children');
        return const SizedBox();
      });

      expect(second, first);
      expect(second.map((child) => child.hashCode), first.map((child) => child.hashCode));
    });

    testWidgets('child gives the first component of a prop, or null without one', (tester) async {
      late OpenUIChild? first;
      late OpenUIChild? missing;
      await pumpCard(tester, 'root = Card([CardHeader("A"), TextContent("B")])', (context, scope) {
        first = scope.child('children');
        missing = scope.child('missing');
        return const SizedBox();
      });

      expect(first?.type, 'CardHeader');
      expect(missing, isNull);
    });

    testWidgets('child with a field gives the component in that field of an object prop', (tester) async {
      late OpenUIChild? price;
      late OpenUIChild? missing;
      final library = columns((context, scope) {
        price = scope.child('data', field: 'price');
        missing = scope.child('data', field: 'label');
        return const SizedBox();
      });
      final runtime = testRuntime(library: library);
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        library: library,
        program: 'root = Card([Table([Col("L", {price: CardHeader("9"), label: "x"})])])',
      );

      expect(price?.type, 'CardHeader');
      expect(missing, isNull);
    });

    testWidgets('scopeOf reads the props of a child', (tester) async {
      late OpenUIComponentScope child;
      await pumpCard(tester, 'root = Card([CardHeader("Title", "Subtitle")])', (context, scope) {
        child = scope.scopeOf(scope.child('children')!);
        return const SizedBox();
      });

      expect(child.type, 'CardHeader');
      expect(child.text('title'), 'Title');
      expect(child.text('subtitle'), 'Subtitle');
    });
  });

  group('state', () {
    // The standard library with an `Input` that shows its field and writes
    // `typed` to it when tapped.
    final library = OpenUILibrary.standard.replacing('Input', (context, scope) {
      return scope.watchState((context) {
        final field = scope.stateField(scope.text('name') ?? '', bindingProp: 'value');
        return GestureDetector(
          onTap: () => field.set('typed'),
          child: Text('${scope.text('name')}: ${field.value} ${field.isBound ? 'bound' : 'unbound'}'),
        );
      });
    });

    Future<OpenUIRuntime> pump(WidgetTester tester, String program) async {
      final runtime = testRuntime(library: library);
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, library: library, program: program);
      return runtime;
    }

    testWidgets('a bound field writes its variable, which every component bound to it shows', (tester) async {
      await pump(tester, r'root = Stack([Input("a", "", "text", null, $q), Input("b", "", "text", null, $q)])');
      expect(find.text('b: null bound'), findsOneWidget);

      await tester.tap(find.text('a: null bound'));
      await tester.pump();

      expect(find.text('a: typed bound'), findsOneWidget);
      expect(find.text('b: typed bound'), findsOneWidget);
    });

    testWidgets('an unbound field shows its prop until written', (tester) async {
      await pump(tester, 'root = Stack([Input("n", "", "text", null, "start")])');
      expect(find.text('n: start unbound'), findsOneWidget);

      await tester.tap(find.text('n: start unbound'));
      await tester.pump();

      expect(find.text('n: typed unbound'), findsOneWidget);
    });

    testWidgets('an unbound field in a form is kept in the form', (tester) async {
      final runtime = await pump(tester, 'root = Stack([Form("f", Buttons([Button("Go")]), [Input("n")])])');

      await tester.tap(find.text('n: null unbound'));
      await tester.pump();

      expect(runtime.fieldValue('f', 'n'), const OpenUIString('typed'));
      expect(runtime.fieldValue(null, 'n'), isNull);
    });

    testWidgets("an unbound field outside a form is kept in the reply's state", (tester) async {
      final runtime = await pump(tester, 'root = Stack([Input("n")])');

      await tester.tap(find.text('n: null unbound'));
      await tester.pump();

      expect(runtime.fieldValue(null, 'n'), const OpenUIString('typed'));
    });

    testWidgets('set writes JSON and rejects a value that is not JSON', (tester) async {
      late OpenUIStateField field;
      final library = OpenUILibrary.standard.replacing('Input', (context, scope) {
        field = scope.stateField('n');
        return const SizedBox();
      });
      final runtime = testRuntime(library: library);
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, library: library, program: 'root = Stack([Input("n")])');

      field.set({
        'a': [1, true, null],
      });

      expect(
        runtime.fieldValue(null, 'n'),
        OpenUIObject({
          'a': OpenUIValue.fromJson(const [1, true, null]),
        }),
      );
      expect(() => field.set(DateTime(2026)), throwsArgumentError);
    });
  });

  group('triggerAction', () {
    // The standard library with a `Button` that runs its action when tapped.
    final library = OpenUILibrary.standard.replacing('Button', (context, scope) {
      final label = scope.text('label') ?? '';
      return GestureDetector(onTap: () => scope.triggerAction(label), child: Text(label));
    });

    Future<(OpenUIRuntime, List<OpenUIActionEvent>)> pump(
      WidgetTester tester,
      String program, {
      bool isStreaming = false,
    }) async {
      final runtime = testRuntime(library: library);
      addTearDown(runtime.dispose);
      final events = <OpenUIActionEvent>[];
      runtime.actions.listen(events.add);
      await pumpOpenUI(tester, runtime, library: library, program: program, isStreaming: isStreaming);
      return (runtime, events);
    }

    testWidgets('runs the steps of the action', (tester) async {
      final (_, events) = await pump(tester, 'root = Stack([Button("Ask", @ToAssistant("Tell me more"))])');

      await tester.tap(find.text('Ask'));
      await tester.pump();

      expect(events.map((event) => (event.type, event.message)), [
        (OpenUIActionEvent.continueConversation, 'Tell me more'),
      ]);
    });

    testWidgets('writes a variable with a @Set step', (tester) async {
      final (runtime, _) = await pump(tester, r'root = Stack([Button("Set", @Set($q, "there"))])');

      await tester.tap(find.text('Set'));
      await tester.pump();

      expect(runtime.state.value[r'$q'], const OpenUIString('there'));
    });

    testWidgets('continues the conversation with the label when there is no action', (tester) async {
      final (_, events) = await pump(tester, 'root = Stack([Button("Hello")])');

      await tester.tap(find.text('Hello'));
      await tester.pump();

      expect(events.map((event) => (event.type, event.label)), [(OpenUIActionEvent.continueConversation, 'Hello')]);
    });

    testWidgets('runs with the state of the form the component is in', (tester) async {
      final (runtime, events) = await pump(tester, 'root = Stack([Form("f", Buttons([Button("Go")]), [])])');
      runtime.setFieldValue('f', 'n', const OpenUIString('v'));

      await tester.tap(find.text('Go'));
      await tester.pump();

      expect(events.single.formName, 'f');
      expect(plainJson(OpenUIObject(events.single.formState)), {
        'f': {
          'n': {'value': 'v'},
        },
      });
    });

    testWidgets('runs nothing while the reply streams', (tester) async {
      final (_, events) = await pump(tester, 'root = Stack([Button("Hello")])', isStreaming: true);

      await tester.tap(find.text('Hello'));
      await tester.pump();

      expect(events, isEmpty);
    });
  });
}
