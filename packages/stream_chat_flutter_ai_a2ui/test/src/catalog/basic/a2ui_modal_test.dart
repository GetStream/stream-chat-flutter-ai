import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_view.dart';
import 'package:stream_core_flutter/core.dart';

import '../../a2ui_test_app.dart';

void main() {
  testWidgets("a modal's content doesn't show until it is opened", (tester) async {
    await pumpSurface(tester, components: _modal());

    expect(find.text('Open daily, 9 to 5.'), findsNothing);
  });

  testWidgets("tapping a modal's button opens its content in a sheet", (tester) async {
    await pumpSurface(tester, components: _modal());

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(StreamSheet), matching: find.text('Open daily, 9 to 5.')), findsOneWidget);
  });

  testWidgets("the app's component builders draw the components in a modal's sheet", (tester) async {
    final processor = A2UIProcessor(catalogs: A2UICatalogs());
    addTearDown(processor.dispose);
    processor.apply([createSurface(_modal(contentIsButton: true))]);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [StreamTheme.light()]),
        home: StreamComponentFactory(
          builders: StreamComponentBuilders(
            button: (context, props) => GestureDetector(onTap: props.onPressed, child: props.child),
          ),
          child: Material(child: A2UISurfaceView(surface: processor.surface('s')!)),
        ),
      ),
    );

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(StreamSheet), matching: find.byType(ElevatedButton)), findsNothing);
    expect(find.descendant(of: find.byType(StreamSheet), matching: find.text('Book')), findsOneWidget);
  });

  testWidgets("a modal's button still sends its event", (tester) async {
    final events = <A2UIActionEvent>[];
    await pumpSurface(tester, components: _modal(), events: events);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(events.single.name, 'open_details');
  });

  testWidgets("a modal's button sends its event, and reports the sheet, with no Navigator to open it on", (
    tester,
  ) async {
    final events = <A2UIActionEvent>[];
    final errors = <A2UIError>[];
    final processor = A2UIProcessor(catalogs: A2UICatalogs(), onAction: events.add, onError: errors.add);
    addTearDown(processor.dispose);
    processor.apply([createSurface(_modal())]);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: ThemeData(extensions: [StreamTheme(brightness: Brightness.light)]),
            child: Material(child: A2UISurfaceView(surface: processor.surface('s')!)),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Details'));
    await tester.pump();

    expect(events.single.name, 'open_details');
    expect(errors.single.code, A2UIErrorCode.validationFailed);
  });

  testWidgets("a modal's disabled button doesn't open it", (tester) async {
    await pumpSurface(
      tester,
      components: _modal(
        buttonChecks: [
          {
            'condition': {'@path': '/ready'},
          },
        ],
      ),
      data: {'ready': false},
    );

    await tester.tap(find.text('Details'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(StreamSheet), findsNothing);
  });

  testWidgets('tapping a trigger that is not a button opens the sheet', (tester) async {
    await pumpSurface(tester, components: _modal(triggerIsButton: false));

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.byType(StreamSheet), findsOneWidget);
  });

  testWidgets('a trigger that is not a button is read as a button', (tester) async {
    await pumpSurface(tester, components: _modal(triggerIsButton: false));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Details')),
      isSemantics(isButton: true, hasTapAction: true),
    );
  });

  testWidgets('a tap outside the sheet closes it', (tester) async {
    await pumpSurface(tester, components: _modal());
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(StreamSheet), findsNothing);
  });

  testWidgets('dragging the sheet down by content that scrolls closes it', (tester) async {
    await pumpSurface(tester, components: _modal(content: List.filled(60, 'Open daily, 9 to 5.').join('\n\n')));
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, 500));
    await tester.pumpAndSettle();

    expect(find.byType(StreamSheet), findsNothing);
  });

  testWidgets("the sheet starts with the design system's sheet header", (tester) async {
    await pumpSurface(tester, components: _modal());
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(StreamSheet), matching: find.byType(StreamSheetHeader)), findsOneWidget);
  });

  testWidgets("the sheet's close button closes it", (tester) async {
    await pumpSurface(tester, components: _modal());
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(const DefaultMaterialLocalizations().closeButtonTooltip));
    await tester.pumpAndSettle();

    expect(find.byType(StreamSheet), findsNothing);
  });

  testWidgets("the sheet draws its content with the surface's catalog", (tester) async {
    final catalog = A2UICatalog.basic.replacing('Text', (context, scope) => Text('[${scope.string('text')}]'));
    await pumpSurface(tester, components: _modal(), catalog: catalog);

    await tester.tap(find.text('[Details]'));
    await tester.pumpAndSettle();

    expect(find.text('[Open daily, 9 to 5.]'), findsOneWidget);
  });

  testWidgets("the sheet's content follows the data model while it is open", (tester) async {
    final processor = await pumpSurface(
      tester,
      components: _modal(content: {'@path': '/hours'}),
      data: _hours,
    );
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    processor.surface('s')!.write('/hours', 'Closed today.');
    await tester.pump();

    expect(find.text('Closed today.'), findsOneWidget);
  });

  testWidgets("a replaced button in a modal's trigger opens it", (tester) async {
    final catalog = A2UICatalog.basic.replacing('Button', (context, scope) {
      return GestureDetector(onTap: scope.performAction, child: const Text('Open it'));
    });
    await pumpSurface(tester, components: _modal(), catalog: catalog);

    await tester.tap(find.text('Open it'));
    await tester.pumpAndSettle();

    expect(find.text('Open daily, 9 to 5.'), findsOneWidget);
  });

  testWidgets("a trigger's component without an action opens the modal when it performs its action", (tester) async {
    var hadAction = true;
    final catalog = A2UICatalog.basic.replacing('Text', (context, scope) {
      hadAction = scope.hasAction;
      return GestureDetector(onTap: scope.performAction, child: Text(scope.string('text') ?? ''));
    });
    await pumpSurface(tester, components: _modal(triggerIsButton: false), catalog: catalog);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(hadAction, isFalse);
    expect(find.text('Open daily, 9 to 5.'), findsOneWidget);
  });

  testWidgets('the sheet stays open when a list scrolls its modal out of view', (tester) async {
    final controller = await _pumpInList(tester);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    controller.jumpTo(2500);
    await tester.pumpAndSettle();

    expect(find.byType(StreamSheet), findsOneWidget);
  });

  testWidgets('a list lets a modal go once its sheet is closed', (tester) async {
    final controller = await _pumpInList(tester);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(const DefaultMaterialLocalizations().closeButtonTooltip));
    await tester.pumpAndSettle();

    controller.jumpTo(2500);
    await tester.pumpAndSettle();

    expect(find.text('Details', skipOffstage: false), findsNothing);
  });

  testWidgets('the sheet closes when the modal leaves the surface', (tester) async {
    final processor = await pumpSurface(tester, components: _modal());
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    processor.apply([
      updateComponents([
        {'id': 'root', 'component': 'Text', 'text': 'Gone'},
      ]),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(StreamSheet), findsNothing);
  });

  testWidgets('the open sheet shows the content the agent changes the modal to', (tester) async {
    final processor = await pumpSurface(tester, components: _modal());
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    processor.apply([
      updateComponents([
        {'id': 'root', 'component': 'Modal', 'trigger': 'trigger', 'content': 'other'},
        {'id': 'other', 'component': 'Text', 'text': 'Closed today.'},
      ]),
    ]);
    await tester.pump();
    await tester.pump();

    expect(find.text('Closed today.'), findsOneWidget);
  });

  testWidgets('a button inside a trigger that is not a button opens the sheet', (tester) async {
    final events = <A2UIActionEvent>[];
    await pumpSurface(
      tester,
      events: events,
      components: [
        {'id': 'root', 'component': 'Modal', 'trigger': 'card', 'content': 'content'},
        {'id': 'card', 'component': 'Card', 'child': 'open'},
        {
          'id': 'open',
          'component': 'Button',
          'child': 'open_label',
          'action': {
            'event': {'name': 'open_details'},
          },
        },
        {'id': 'open_label', 'component': 'Text', 'text': 'Details'},
        {'id': 'content', 'component': 'Text', 'text': 'Open daily, 9 to 5.'},
      ],
    );

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.text('Open daily, 9 to 5.'), findsOneWidget);
  });

  testWidgets("a button inside a trigger button's child doesn't open the sheet", (tester) async {
    await pumpSurface(
      tester,
      components: [
        {'id': 'root', 'component': 'Modal', 'trigger': 'open', 'content': 'content'},
        {
          'id': 'open',
          'component': 'Button',
          'child': 'inner',
          'action': {
            'event': {'name': 'open_details'},
          },
        },
        {
          'id': 'inner',
          'component': 'Button',
          'child': 'inner_label',
          'action': {
            'event': {'name': 'inner'},
          },
        },
        {'id': 'inner_label', 'component': 'Text', 'text': 'Inner'},
        {'id': 'content', 'component': 'Text', 'text': 'Open daily, 9 to 5.'},
      ],
    );

    await tester.tap(find.text('Inner'));
    await tester.pumpAndSettle();

    expect(find.byType(StreamSheet), findsNothing);
  });

  testWidgets('a button in the sheet sends its event', (tester) async {
    final events = <A2UIActionEvent>[];
    await pumpSurface(tester, components: _modal(contentIsButton: true), events: events);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();

    expect(events.last.name, 'book');
  });

  testWidgets('a button in the sheet opens its link', (tester) async {
    final opened = <Uri>[];
    await pumpSurface(
      tester,
      onOpenLink: opened.add,
      components: [
        {'id': 'root', 'component': 'Modal', 'trigger': 'trigger', 'content': 'menu'},
        {'id': 'trigger', 'component': 'Text', 'text': 'Details'},
        {
          'id': 'menu',
          'component': 'Button',
          'child': 'menu_label',
          'action': {
            'functionCall': {
              '@call': 'openUrl',
              'args': {'url': 'https://example.com/menu'},
            },
          },
        },
        {'id': 'menu_label', 'component': 'Text', 'text': 'Menu'},
      ],
    );
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    expect(opened, [Uri.parse('https://example.com/menu')]);
  });

  testWidgets("a trigger that isn't a button is read with the modal's description", (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Modal',
          'trigger': 'trigger',
          'content': 'content',
          'accessibility': {'label': 'Opening hours', 'description': 'Shows when it is open'},
        },
        {'id': 'trigger', 'component': 'Text', 'text': 'Details'},
        {'id': 'content', 'component': 'Text', 'text': 'Open daily.'},
      ],
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Opening hours')),
      isSemantics(hint: 'Shows when it is open', isButton: true),
    );
  });
}

const _hours = {'hours': 'Open daily, 9 to 5.'};

// The modal's surface at the top of a list long enough to scroll it out of
// view, with the list's controller.
Future<ScrollController> _pumpInList(WidgetTester tester) async {
  final processor = A2UIProcessor(catalogs: A2UICatalogs());
  addTearDown(processor.dispose);
  processor.apply([createSurface(_modal())]);
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [StreamTheme.light()]),
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: [
            A2UISurfaceView(surface: processor.surface('s')!),
            const SizedBox(height: 3000),
          ],
        ),
      ),
    ),
  );
  return controller;
}

List<Map<String, Object?>> _modal({
  bool triggerIsButton = true,
  bool contentIsButton = false,
  Object content = 'Open daily, 9 to 5.',
  List<Map<String, Object?>>? buttonChecks,
}) {
  return [
    {'id': 'root', 'component': 'Modal', 'trigger': 'trigger', 'content': 'content'},
    if (triggerIsButton) ...[
      {
        'id': 'trigger',
        'component': 'Button',
        'child': 'trigger_label',
        'checks': ?buttonChecks,
        'action': {
          'event': {'name': 'open_details'},
        },
      },
      {'id': 'trigger_label', 'component': 'Text', 'text': 'Details'},
    ] else
      {'id': 'trigger', 'component': 'Text', 'text': 'Details'},
    if (contentIsButton) ...[
      {
        'id': 'content',
        'component': 'Button',
        'child': 'content_label',
        'action': {
          'event': {'name': 'book'},
        },
      },
      {'id': 'content_label', 'component': 'Text', 'text': 'Book'},
    ] else
      {'id': 'content', 'component': 'Text', 'text': content},
  ];
}
