import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
