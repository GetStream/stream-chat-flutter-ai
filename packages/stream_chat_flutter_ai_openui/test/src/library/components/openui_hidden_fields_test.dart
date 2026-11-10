import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';

import '../../openui_test_app.dart';

final _library = OpenUILibrary.standard;

Future<(OpenUIRuntime, List<OpenUIActionEvent>)> _pump(
  WidgetTester tester,
  String program, {
  bool isStreaming = false,
  OpenUILibrary? library,
}) async {
  final lib = library ?? _library;
  final runtime = testRuntime(library: lib);
  addTearDown(runtime.dispose);
  final events = <OpenUIActionEvent>[];
  runtime.actions.listen(events.add);
  await pumpOpenUI(tester, runtime, program: program, isStreaming: isStreaming, library: lib);
  await tester.pump();
  await tester.pump();
  return (runtime, events);
}

Future<void> _update(
  WidgetTester tester,
  OpenUIRuntime runtime,
  String program, {
  bool isStreaming = false,
  OpenUILibrary? library,
}) async {
  runtime.update(program, isStreaming: isStreaming);
  await pumpOpenUI(tester, runtime, library: library ?? _library);
  await tester.pump();
  await tester.pump();
}

const _required = 'FormControl("Email", Input("email", "", "email", {required: true}))';
const _required2 = 'FormControl("Phone", Input("phone", "", "text", {required: true}))';

String _tabs(String first, String second) => 'Tabs([TabItem("a", "A", [$first]), TabItem("b", "B", [$second])])';

String _form(String fields) =>
    '''
root = Stack([Form("f", Buttons([Button("Go", @ToAssistant("Go"))]), [$fields])])
''';

Object? _valueOf(OpenUIRuntime runtime, String name) => runtime.fieldValue('f', name);

void main() {
  group('a form spread over tabs', () {
    testWidgets('blocks a submit from another tab and shows the tab with the error', (tester) async {
      final (_, events) = await _pump(tester, _form(_tabs(_required, 'TextContent("Other")')));
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(find.text('Email'), findsNothing);

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(events, isEmpty);
      expect(find.text('Email *', findRichText: true), findsOneWidget);
      expect(find.text('This field is required'), findsOneWidget);
      expect(find.text('Other'), findsNothing);
    });

    testWidgets('shows the tab of the first invalid field', (tester) async {
      final (_, events) = await _pump(
        tester,
        _form(
          'Tabs([TabItem("a", "A", [TextContent("Intro")]), TabItem("b", "B", [$_required]), TabItem("c", "C", [$_required2])])',
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(events, isEmpty);
      expect(find.text('Email *', findRichText: true), findsOneWidget);
      expect(find.text('Phone *', findRichText: true), findsNothing);
    });

    testWidgets('a valid hidden field does not block, and the defaults of hidden fields are kept', (tester) async {
      final (runtime, events) = await _pump(
        tester,
        _form(
          _tabs(
            'FormControl("Name", Input("name", "", "text", {required: true}, "Ann"))',
            'FormControl("Phone", Input("phone", "", "text", {required: true}, "123")), '
                'FormControl("Plan", RadioGroup("plan", [RadioItem("Free", "", "free"), RadioItem("Pro", "", "pro")], "pro", {required: true}))',
          ),
        ),
      );
      expect(_valueOf(runtime, 'phone'), const OpenUIString('123'));
      expect(_valueOf(runtime, 'plan'), const OpenUIString('pro'));

      await tester.tap(find.text('Go'));
      await tester.pump();

      final form = events.single.formState['f']! as OpenUIObject;
      expect((form.fields['phone']! as OpenUIObject).fields['value'], const OpenUIString('123'));
      expect((form.fields['plan']! as OpenUIObject).fields['value'], const OpenUIString('pro'));
    });

    testWidgets('keeps nothing while the reply streams, and the defaults once it ends', (tester) async {
      final program = _form(
        _tabs('TextContent("One")', 'FormControl("Phone", Input("phone", "", "text", {required: true}, "123"))'),
      );
      final (runtime, _) = await _pump(tester, program, isStreaming: true);
      expect(_valueOf(runtime, 'phone'), isNull);

      await _update(tester, runtime, program);

      expect(_valueOf(runtime, 'phone'), const OpenUIString('123'));
    });

    testWidgets('a reply written again drops the rules of what it no longer holds', (tester) async {
      final (runtime, events) = await _pump(tester, _form(_tabs(_required, 'TextContent("Other")')));

      await _update(tester, runtime, _form(_tabs('TextContent("One")', 'TextContent("Other")')));
      await tester.tap(find.text('Go'));
      await tester.pump();

      expect(events, hasLength(1));
    });

    testWidgets('a field that is on screen is checked with its own rules', (tester) async {
      final (_, events) = await _pump(
        tester,
        _form(_tabs(_required, 'TextContent("Other")')),
      );

      await tester.enterText(find.byType(TextField), 'a@b.c');
      await tester.tap(find.text('Go'));
      await tester.pump();

      expect(events, hasLength(1));
    });
  });

  group('a form spread over an accordion', () {
    testWidgets('opens the item with the first invalid field', (tester) async {
      final (_, events) = await _pump(
        tester,
        _form('Accordion([AccordionItem("a", "One", [$_required]), AccordionItem("b", "Two", [$_required2])])'),
      );
      expect(find.text('Email'), findsNothing);

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(events, isEmpty);
      expect(find.text('Email *', findRichText: true), findsOneWidget);
      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('reveals an accordion inside a tab, outermost first', (tester) async {
      final (_, events) = await _pump(
        tester,
        _form(
          _tabs(
            'TextContent("Intro")',
            'Accordion([AccordionItem("x", "Inner", [$_required])])',
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(events, isEmpty);
      expect(find.text('Email *', findRichText: true), findsOneWidget);
      expect(find.text('This field is required'), findsOneWidget);
    });
  });

  group('a form spread over sections', () {
    testWidgets('opens the section with the first invalid field', (tester) async {
      final (_, events) = await _pump(
        tester,
        '''
root = Card([Form("f", Buttons([Button("Go", @ToAssistant("Go"))]), [SectionBlock([SectionItem("a", "One", [TextContent("First")]), SectionItem("b", "Two", [$_required])])])])
''',
        library: OpenUILibrary.chat,
      );
      expect(find.text('Email'), findsNothing);

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(events, isEmpty);
      expect(find.text('Email *', findRichText: true), findsOneWidget);
    });
  });
}
