import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';

import '../../core/runtime/fake_tools.dart';
import '../../openui_test_app.dart';

final _library = OpenUILibrary.standard;

const _columns = '[{type: "text", key: "name", header: "Name"}]';

void main() {
  group('EditableTable', () {
    testWidgets('counts edits from the rows a query delivers after the reply ended', (tester) async {
      final tools = FakeTools();
      final runtime = testRuntime(library: _library, tools: tools);
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program:
            '''
root = Stack([EditableTable("items", $_columns, q.rows)])
q = Query("list", {}, {rows: []})
''',
        library: _library,
      );
      await tester.pump();

      tools.calls.single.answer.complete(
        OpenUIValue.fromJson(const {
          'rows': [
            {
              'id': '1',
              'values': ['Pen'],
            },
          ],
        }),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('1 change'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Ink');
      await tester.pump();

      expect(find.text('1 change'), findsOneWidget);
    });
  });

  group('Table', () {
    testWidgets('shows placeholder rows while a query loads, before it has any columns', (tester) async {
      final runtime = testRuntime(library: _library, tools: FakeTools());
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program: 'root = Stack([Table([])])\nq = Query("list", {}, null)',
        library: _library,
      );
      await tester.pump();

      expect(find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_TableSkeleton'), findsOneWidget);
    });

    testWidgets('draws nothing without columns when no query loads', (tester) async {
      final runtime = testRuntime(library: _library);
      addTearDown(runtime.dispose);
      await pumpOpenUI(tester, runtime, program: 'root = Stack([Table([])])', library: _library);
      await tester.pump();

      expect(find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_TableSkeleton'), findsNothing);
    });
  });

  group('ListBlock', () {
    testWidgets('keeps its rows when an image src is not a string', (tester) async {
      final runtime = testRuntime(library: _library);
      addTearDown(runtime.dispose);
      await pumpOpenUI(
        tester,
        runtime,
        program: r'''
root = Stack([ListBlock([ListItem("Paris", null, $img)], "image")])
$img = {src: 5, alt: 7}
''',
        library: _library,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Paris'), findsOneWidget);
    });
  });
}
