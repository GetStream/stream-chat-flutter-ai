import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';

import '../openui_test_app.dart';

void main() {
  testWidgets('children gives the components of a list prop in order', (tester) async {
    late List<OpenUIChild> children;
    await _pumpCard(tester, 'root = Card([CardHeader("A"), TextContent("B")])', (context, scope) {
      children = scope.children('children');
      return const SizedBox();
    });

    expect([for (final child in children) child.type], ['CardHeader', 'TextContent']);
  });

  testWidgets("children leaves out the items of a list prop that aren't components", (tester) async {
    late List<OpenUIChild> children;
    await _pumpColumns(tester, 'root = Card([Table([Col("L", [CardHeader("A"), "text", 7])])])', (context, scope) {
      children = scope.children('data');
      return const SizedBox();
    });

    expect(children, hasLength(1));
  });

  testWidgets('children gives the one component a prop holds', (tester) async {
    late List<OpenUIChild> children;
    final library = OpenUILibrary.chat.replacing('IconButton', (context, scope) {
      children = scope.children('icon');
      return const SizedBox();
    });
    await _pump(tester, library, 'root = Card([IconButton("Star", Icon("star"))])');

    expect([for (final child in children) child.type], ['Icon']);
  });

  testWidgets('children gives an empty list for a prop without components', (tester) async {
    late List<OpenUIChild> children;
    await _pumpCard(tester, 'root = Card([CardHeader("A")])', (context, scope) {
      children = scope.children('missing');
      return const SizedBox();
    });

    expect(children, isEmpty);
  });

  testWidgets('children gives components whose type has no builder', (tester) async {
    late List<String?> titles;
    final library = OpenUILibrary.chat.replacing('Tabs', (context, scope) {
      titles = [for (final tab in scope.children('items')) scope.scopeOf(tab).text('trigger')];
      return const SizedBox();
    });
    await _pump(
      tester,
      library,
      'root = Card([Tabs([TabItem("a", "First", [TextContent("1")]), TabItem("b", "Second", [])])])',
    );

    expect(titles, ['First', 'Second']);
  });

  testWidgets("build draws a child with its type's builder", (tester) async {
    await _pumpCard(tester, 'root = Card([CardHeader("A"), TextContent("B")])', (context, scope) {
      final children = scope.children('children');
      return Column(children: [for (final child in children.reversed) scope.build(child)]);
    });

    expect(tester.getTopLeft(find.text('B', findRichText: true)).dy, lessThan(tester.getTopLeft(find.text('A')).dy));
  });

  testWidgets('build draws nothing for a child whose type has no builder', (tester) async {
    late Widget built;
    final library = OpenUILibrary.chat.replacing('Tabs', (context, scope) {
      return built = scope.build(scope.child('items')!);
    });
    await _pump(tester, library, 'root = Card([Tabs([TabItem("a", "First", [TextContent("1")])])])');

    expect(tester.getSize(find.byWidget(built)).height, 0);
  });

  testWidgets('a child no statement defines is keyed by its place', (tester) async {
    late List<OpenUIChild> children;
    await _pumpCard(tester, 'root = Card([CardHeader("A"), TextContent("B")])', (context, scope) {
      children = scope.children('children');
      return const SizedBox();
    });

    expect([for (final child in children) child.key], ['0', '1']);
  });

  testWidgets('a child defined by a statement keeps its key when a sibling arrives before it', (tester) async {
    final keys = <List<String>>[];
    final library = OpenUILibrary.chat.replacing('Card', (context, scope) {
      keys.add([for (final child in scope.children('children')) child.key]);
      return const SizedBox();
    });
    final runtime = await _pump(
      tester,
      library,
      'root = Card([a, b])\nb = TextContent("B")',
      isStreaming: true,
    );
    runtime.update('root = Card([a, b])\nb = TextContent("B")\na = TextContent("A")', isStreaming: false);
    await tester.pump();

    expect(keys.last.last, keys.first.single);
  });

  testWidgets('the children of a statement placed again are keyed by how often it was placed before', (tester) async {
    late List<OpenUIChild> children;
    await _pumpCard(tester, 'root = Card([a, a, a])\na = TextContent("A")', (context, scope) {
      children = scope.children('children');
      return const SizedBox();
    });

    expect([for (final child in children) child.key], [r'$a', r'$a#1', r'$a#2']);
  });

  testWidgets('the children of a statement placed twice are not equal', (tester) async {
    late List<OpenUIChild> children;
    await _pumpCard(tester, 'root = Card([a, a])\na = TextContent("A")', (context, scope) {
      children = scope.children('children');
      return const SizedBox();
    });

    expect(children.first, isNot(children.last));
  });

  testWidgets('children read twice are equal', (tester) async {
    late List<OpenUIChild> first;
    late List<OpenUIChild> second;
    await _pumpCard(tester, 'root = Card([CardHeader("A"), TextContent("B")])', (context, scope) {
      first = scope.children('children');
      second = scope.children('children');
      return const SizedBox();
    });

    expect(second, first);
  });

  testWidgets('children read twice have equal hash codes', (tester) async {
    late List<OpenUIChild> first;
    late List<OpenUIChild> second;
    await _pumpCard(tester, 'root = Card([CardHeader("A"), TextContent("B")])', (context, scope) {
      first = scope.children('children');
      second = scope.children('children');
      return const SizedBox();
    });

    expect(second.map((child) => child.hashCode), first.map((child) => child.hashCode));
  });

  testWidgets('child gives the first component of a prop', (tester) async {
    late OpenUIChild? child;
    await _pumpCard(tester, 'root = Card([CardHeader("A"), TextContent("B")])', (context, scope) {
      child = scope.child('children');
      return const SizedBox();
    });

    expect(child?.type, 'CardHeader');
  });

  testWidgets('child gives null for a prop without components', (tester) async {
    late OpenUIChild? child;
    await _pumpCard(tester, 'root = Card([CardHeader("A")])', (context, scope) {
      child = scope.child('missing');
      return const SizedBox();
    });

    expect(child, isNull);
  });

  testWidgets('child with a field gives the component in that field of an object prop', (tester) async {
    late OpenUIChild? child;
    await _pumpColumns(tester, 'root = Card([Table([Col("L", {price: CardHeader("9"), label: "x"})])])', (
      context,
      scope,
    ) {
      child = scope.child('data', field: 'price');
      return const SizedBox();
    });

    expect(child?.type, 'CardHeader');
  });

  testWidgets('child with a field gives null for a field without a component', (tester) async {
    late OpenUIChild? child;
    await _pumpColumns(tester, 'root = Card([Table([Col("L", {price: CardHeader("9"), label: "x"})])])', (
      context,
      scope,
    ) {
      child = scope.child('data', field: 'label');
      return const SizedBox();
    });

    expect(child, isNull);
  });

  testWidgets('child with a field keys a child defined by a statement as children keys it', (tester) async {
    final keys = <String?>[];
    await _pumpColumns(tester, 'root = Card([Table([Col("A", [p]), Col("B", {price: p})])])\np = CardHeader("9")', (
      context,
      scope,
    ) {
      keys.add(scope.text('label') == 'A' ? scope.child('data')?.key : scope.child('data', field: 'price')?.key);
      return const SizedBox();
    });

    expect(keys.last, keys.first);
  });

  testWidgets('child with a field keys a child no statement defines by its field', (tester) async {
    late OpenUIChild? child;
    await _pumpColumns(tester, 'root = Card([Table([Col("L", {price: CardHeader("9"), label: "x"})])])', (
      context,
      scope,
    ) {
      child = scope.child('data', field: 'price');
      return const SizedBox();
    });

    expect(child?.key, 'price');
  });

  testWidgets('child with a field gives a statement held by two fields of a prop a key for each', (tester) async {
    final keys = <String?>[];
    await _pumpColumns(tester, 'root = Card([Table([Col("L", {price: p, label: p})])])\np = CardHeader("9")', (
      context,
      scope,
    ) {
      keys
        ..add(scope.child('data', field: 'price')?.key)
        ..add(scope.child('data', field: 'label')?.key);
      return const SizedBox();
    });

    expect(keys.toSet(), hasLength(2));
  });

  testWidgets('scopeOf reads the props of a child', (tester) async {
    late OpenUIComponentScope child;
    await _pumpCard(tester, 'root = Card([CardHeader("Title", "Subtitle")])', (context, scope) {
      child = scope.scopeOf(scope.child('children')!);
      return const SizedBox();
    });

    expect(child.text('subtitle'), 'Subtitle');
  });

  testWidgets('scopeOf gives a child whose stateField is kept in the form this component is in', (tester) async {
    late OpenUIComponentScope input;
    final runtime = await _pump(
      tester,
      OpenUILibrary.standard.replacing('FormControl', (context, scope) {
        input = scope.scopeOf(scope.child('input')!);
        return const SizedBox();
      }),
      'root = Stack([Form("f", Buttons([Button("Go")]), [FormControl("Name", Input("n"))])])',
    );

    input.stateField('n').set('v');

    expect(runtime.fieldValue('f', 'n'), const OpenUIString('v'));
  });
}

// Pumps [program] drawn with [library].
Future<OpenUIRuntime> _pump(
  WidgetTester tester,
  OpenUILibrary library,
  String program, {
  bool isStreaming = false,
}) async {
  final runtime = testRuntime(library: library);
  addTearDown(runtime.dispose);
  await pumpOpenUI(tester, runtime, library: library, program: program, isStreaming: isStreaming);
  return runtime;
}

// Pumps [program] with the chat `Card` drawn by [buildCard].
Future<void> _pumpCard(WidgetTester tester, String program, OpenUIComponentBuilder buildCard) {
  return _pump(tester, OpenUILibrary.chat.replacing('Card', buildCard), program);
}

// Pumps [program] with a `Table`'s columns, each `Col` drawn by [buildCol].
Future<void> _pumpColumns(WidgetTester tester, String program, OpenUIComponentBuilder buildCol) {
  final library = OpenUILibrary.chat
      .replacing('Table', (context, scope) => scope.buildProp('columns'))
      .replacing('Col', buildCol);
  return _pump(tester, library, program);
}
