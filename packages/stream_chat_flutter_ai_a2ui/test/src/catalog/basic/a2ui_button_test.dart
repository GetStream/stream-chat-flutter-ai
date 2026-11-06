import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_view.dart';
import 'package:stream_core_flutter/core.dart';

import '../../a2ui_test_app.dart';

void main() {
  testWidgets("tapping a button sends its action's event", (tester) async {
    final events = <A2UIActionEvent>[];
    await pumpSurface(tester, components: _button(), events: events);

    await tester.tap(find.text('Book'));
    await tester.pump();

    expect(events.single.name, 'book');
  });

  testWidgets('a primary button is drawn in the accent color', (tester) async {
    await pumpSurface(tester, components: _button(variant: 'primary'));

    expect(_background(tester), lightTheme().accent);
  });

  testWidgets("a primary button's text is drawn in the color on the accent", (tester) async {
    await pumpSurface(tester, components: _button(variant: 'primary'));

    expect(_textColor(tester), lightTheme().onAccent);
  });

  testWidgets('a default button is drawn on the subtle surface', (tester) async {
    await pumpSurface(tester, components: _button(variant: 'default'));

    expect(_background(tester), lightTheme().subtleSurface);
  });

  testWidgets("a default button's text is drawn in the text color", (tester) async {
    await pumpSurface(tester, components: _button(variant: 'default'));

    expect(_textColor(tester), lightTheme().text);
  });

  testWidgets('a borderless button has no background', (tester) async {
    await pumpSurface(tester, components: _button(variant: 'borderless'));

    expect(_background(tester)?.a, 0);
  });

  testWidgets("a borderless button's text starts at the button's edge", (tester) async {
    await pumpSurface(tester, components: _button(variant: 'borderless'));

    expect(tester.getTopLeft(find.text('Book')).dx, tester.getTopLeft(_face).dx);
  });

  testWidgets("a borderless button's text is drawn in the accent color", (tester) async {
    await pumpSurface(tester, components: _button(variant: 'borderless'));

    expect(_textColor(tester), lightTheme().accent);
  });

  testWidgets('a button of a variant A2UI has no name for is drawn as a default one', (tester) async {
    await pumpSurface(tester, components: _button(variant: 'outlined'));

    expect(_background(tester), lightTheme().subtleSurface);
  });

  testWidgets("the app's button builder draws a button", (tester) async {
    await pumpSurface(
      tester,
      components: _button(),
      builders: StreamComponentBuilders(button: (context, props) => const Text('App button')),
    );

    expect(find.text('App button'), findsOneWidget);
  });

  testWidgets("the app's button builder is given the button's action", (tester) async {
    final events = <A2UIActionEvent>[];
    await pumpSurface(
      tester,
      components: _button(),
      events: events,
      builders: StreamComponentBuilders(
        button: (context, props) => GestureDetector(onTap: props.onPressed, child: const Text('App button')),
      ),
    );

    await tester.tap(find.text('App button'));
    await tester.pump();

    expect(events.single.name, 'book');
  });

  testWidgets('a button of text is as tall as a medium button', (tester) async {
    await pumpSurface(tester, components: _button());

    expect(tester.getSize(_face).height, StreamButtonSize.medium.value);
  });

  testWidgets('a button is as wide as its child, not as the width it is given', (tester) async {
    await pumpSurface(tester, components: _button(), width: 400);

    expect(tester.getSize(_face).width, lessThan(400));
  });

  testWidgets('a button is as tall as a child taller than a line of text', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Button',
          'child': 'lines',
          'action': {
            'event': {'name': 'book'},
          },
        },
        {
          'id': 'lines',
          'component': 'Column',
          'children': ['first', 'second', 'third'],
        },
        {'id': 'first', 'component': 'Text', 'text': 'Table for two'},
        {'id': 'second', 'component': 'Text', 'text': 'By the window'},
        {'id': 'third', 'component': 'Text', 'text': 'At eight'},
      ],
    );

    final face = find.descendant(of: find.byType(ElevatedButton), matching: find.byType(Material)).first;

    expect(tester.getSize(face).height, greaterThanOrEqualTo(tester.getSize(find.byType(Column).last).height));
  });

  testWidgets('a button has the corners of buttons', (tester) async {
    await pumpSurface(tester, components: _button(variant: 'primary'));

    final shape = _material(tester).shape! as RoundedSuperellipseBorder;

    expect(shape.borderRadius, BorderRadius.all(Radius.circular(lightTheme().buttonCornerRadius)));
  });

  testWidgets('a button sends nothing while one of its checks fails', (tester) async {
    final events = <A2UIActionEvent>[];
    await pumpSurface(
      tester,
      components: _button(checks: [_acceptedCheck]),
      data: _notAccepted,
      events: events,
    );

    await tester.tap(find.text('Book'), warnIfMissed: false);
    await tester.pump();

    expect(events, isEmpty);
  });

  testWidgets('a button whose check fails is drawn disabled', (tester) async {
    await pumpSurface(
      tester,
      components: _button(checks: [_acceptedCheck]),
      data: _notAccepted,
    );

    expect(tester.widget<StreamButton>(find.byType(StreamButton)).props.onPressed, isNull);
  });

  testWidgets('a button shows the messages of its failing checks', (tester) async {
    await pumpSurface(
      tester,
      components: _button(checks: [_acceptedCheck]),
      data: _notAccepted,
    );

    expect(find.text('Accept the terms first.'), findsOneWidget);
  });

  testWidgets("the message of a button's failing check is drawn in the error color", (tester) async {
    await pumpSurface(
      tester,
      components: _button(checks: [_acceptedCheck]),
      data: _notAccepted,
    );

    expect(tester.widget<Text>(find.text('Accept the terms first.')).style?.color, lightTheme().error);
  });

  testWidgets('a button is enabled again once its check passes', (tester) async {
    final events = <A2UIActionEvent>[];
    final processor = await pumpSurface(
      tester,
      components: _button(checks: [_acceptedCheck]),
      data: _notAccepted,
      events: events,
    );

    processor.surface('s')!.write('/accepted', true);
    await tester.pump();
    await tester.tap(find.text('Book'));
    await tester.pump();

    expect(events.single.name, 'book');
  });

  testWidgets("a check that only warns doesn't disable its button", (tester) async {
    final events = <A2UIActionEvent>[];
    await pumpSurface(
      tester,
      components: _button(checks: [_warning]),
      data: _warningData,
      events: events,
    );

    await tester.tap(find.text('Book'));
    await tester.pump();

    expect(events.single.name, 'book');
  });

  testWidgets("a warning's message is drawn in the warning color", (tester) async {
    await pumpSurface(
      tester,
      components: _button(checks: [_warning]),
      data: _warningData,
    );

    expect(tester.widget<Text>(find.text('Seats are almost gone.')).style?.color, lightTheme().warning);
  });

  testWidgets("an information check's message is drawn in the secondary text color", (tester) async {
    await pumpSurface(
      tester,
      components: _button(
        checks: [
          {
            'condition': {'@path': '/note'},
          },
        ],
      ),
      data: {
        'note': {'valid': false, 'severity': 'info', 'message': 'Tables free up at 9.'},
      },
    );

    expect(tester.widget<Text>(find.text('Tables free up at 9.')).style?.color, lightTheme().secondaryText);
  });

  testWidgets("a primary button is drawn in a custom theme's accent", (tester) async {
    final theme = A2UIThemeData(accent: const Color(0xFFE65100));
    await pumpSurface(
      tester,
      components: _button(variant: 'primary'),
      theme: theme,
    );

    expect(_background(tester), const Color(0xFFE65100));
  });

  testWidgets('tapping a button closes the keyboard of a field being typed in', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['name', 'book'],
        },
        {
          'id': 'name',
          'component': 'TextField',
          'label': 'Name',
          'value': {'@path': '/name'},
        },
        ..._button(id: 'book'),
      ],
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.tap(find.text('Book'));
    await tester.pump();

    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isFalse);
  });

  testWidgets("a button's label is the agent's accessibility label, on the button itself", (tester) async {
    await pumpSurface(
      tester,
      components: _button(accessibility: {'label': 'Book a table', 'description': 'Sends the booking'}),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Book a table')),
      isSemantics(label: 'Book a table', hint: 'Sends the booking', isButton: true, hasTapAction: true),
    );
  });

  testWidgets("a button without an accessibility label is read as its child's text", (tester) async {
    await pumpSurface(tester, components: _button());

    expect(tester.getSemantics(find.bySemanticsLabel('Book')), isSemantics(isButton: true, hasTapAction: true));
  });

  testWidgets('a disabled button is read as disabled', (tester) async {
    await pumpSurface(
      tester,
      components: _button(checks: [_acceptedCheck]),
      data: _notAccepted,
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Book')),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
    );
  });

  group('a button of an icon', () {
    const icon = {'component': 'Icon', 'name': 'favorite'};
    const label = {'label': 'Save the place'};

    testWidgets("is an icon button whose tooltip is the agent's label", (tester) async {
      final events = <A2UIActionEvent>[];
      await pumpSurface(
        tester,
        components: _button(child: icon, accessibility: label),
        events: events,
      );

      final button = tester.widget<StreamButton>(find.byType(StreamButton));
      expect((button.props.child, button.props.tooltip), (null, 'Save the place'));
      expect(
        find.byType(Semantics).evaluate().where((e) => (e.widget as Semantics).properties.label == 'Save the place'),
        isEmpty,
      );
      expect(
        tester.getSemantics(find.byType(StreamButton)),
        isSemantics(
          label: '',
          tooltip: 'Save the place',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.byType(StreamButton));
      await tester.pump();
      expect(events.single.name, 'book');
    });

    testWidgets('is read as disabled, and sends nothing, while a check fails', (tester) async {
      final events = <A2UIActionEvent>[];
      await pumpSurface(
        tester,
        components: _button(child: icon, accessibility: label, checks: [_acceptedCheck]),
        data: _notAccepted,
        events: events,
      );

      expect(
        tester.getSemantics(find.byType(StreamButton)),
        isSemantics(
          tooltip: 'Save the place',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      await tester.tap(find.byType(StreamButton), warnIfMissed: false);
      await tester.pump();
      expect(events, isEmpty);
    });

    testWidgets("keeps the agent's description as a hint", (tester) async {
      await pumpSurface(
        tester,
        components: _button(child: icon, accessibility: {...label, 'description': 'Adds it to your list'}),
      );

      expect(
        tester.getSemantics(find.byType(StreamButton)),
        isSemantics(tooltip: 'Save the place', hint: 'Adds it to your list', isButton: true),
      );
    });

    testWidgets('without a label is a button of its icon, with no tooltip', (tester) async {
      await pumpSurface(tester, components: _button(child: icon));

      final button = tester.widget<StreamButton>(find.byType(StreamButton));
      expect(button.props.child, isNotNull);
      expect(button.props.tooltip, isNull);
      expect(find.byType(Tooltip), findsNothing);
    });
  });

  testWidgets("a button of text with the agent's label is read by the label in place of its text", (tester) async {
    await pumpSurface(tester, components: _button(accessibility: {'label': 'Book a table'}));

    expect(find.byType(StreamButton), findsOneWidget);
    expect(tester.widget<StreamButton>(find.byType(StreamButton)).props.tooltip, isNull);
    expect(find.bySemanticsLabel('Book'), findsNothing);
  });

  testWidgets("a button of an image with the agent's label is read by the label", (tester) async {
    await pumpSurface(
      tester,
      components: _button(
        child: {'component': 'Image', 'url': 'https://example.com/a.png'},
        accessibility: {'label': 'Open the menu'},
      ),
    );

    expect(tester.widget<StreamButton>(find.byType(StreamButton)).props.tooltip, isNull);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Open the menu')),
      isSemantics(label: 'Open the menu', isButton: true, hasTapAction: true),
    );
  });

  testWidgets('a button is at least as tall as a person can tap', (tester) async {
    await pumpSurface(tester, components: _button(variant: 'borderless'));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('a button starts at the right edge right to left', (tester) async {
    await pumpSurface(
      tester,
      components: _button(variant: 'primary'),
      direction: TextDirection.rtl,
    );

    expect(tester.getTopRight(_face).dx, tester.getTopRight(find.byType(A2UISurfaceView)).dx);
  });

  testWidgets('a button with long text at twice the text size wraps within its width', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpSurface(tester, components: _button(text: 'Book the table by the window for the whole evening'));

    expect(tester.takeException(), isNull);
  });
}

const _acceptedCheck = {
  'condition': {'@path': '/accepted'},
  'message': 'Accept the terms first.',
};

const _notAccepted = {'accepted': false};

const _warning = {
  'condition': {'@path': '/seats'},
};

const _warningData = {
  'seats': {'valid': false, 'severity': 'warning', 'message': 'Seats are almost gone.'},
};

List<Map<String, Object?>> _button({
  String id = 'root',
  String? variant,
  String text = 'Book',
  List<Map<String, Object?>>? checks,
  Map<String, Object?>? accessibility,
  Map<String, Object?>? child,
}) {
  return [
    {
      'id': id,
      'component': 'Button',
      'child': '${id}_label',
      'variant': ?variant,
      'checks': ?checks,
      'accessibility': ?accessibility,
      'action': {
        'event': {'name': 'book'},
      },
    },
    {
      'id': '${id}_label',
      ...child ?? {'component': 'Text', 'text': text},
    },
  ];
}

// The button's face: the material of the design system's button around its
// child.
final _face = find.descendant(of: find.byType(ElevatedButton), matching: find.byType(Material)).first;

Material _material(WidgetTester tester) => tester.widget<Material>(_face);

Color? _background(WidgetTester tester) => _material(tester).color;

Color? _textColor(WidgetTester tester) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text('Book'));
  return paragraph.text.style?.color;
}
