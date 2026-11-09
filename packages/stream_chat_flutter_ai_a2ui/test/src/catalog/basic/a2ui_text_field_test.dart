import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_view.dart';
import 'package:stream_core_flutter/core.dart';

import '../../a2ui_test_app.dart';

void main() {
  testWidgets('typing writes the text to the data model', (tester) async {
    final processor = await pumpSurface(tester, components: [_field()]);

    await tester.enterText(find.byType(TextField), 'Ada');

    expect(_surface(processor).read('/name'), 'Ada');
  });

  testWidgets('a field keeps a leading space the person types', (tester) async {
    final processor = await pumpSurface(tester, components: [_field()]);

    await tester.enterText(find.byType(TextField), ' Ada');

    expect(_surface(processor).read('/name'), ' Ada');
  });

  testWidgets("a field doesn't capitalize what the person types", (tester) async {
    await pumpSurface(tester, components: [_field()]);

    expect(tester.widget<TextField>(find.byType(TextField)).textCapitalization, TextCapitalization.none);
  });

  testWidgets('a field offers corrections as the person types', (tester) async {
    await pumpSurface(tester, components: [_field()]);

    expect(tester.widget<TextField>(find.byType(TextField)).autocorrect, isTrue);
  });

  testWidgets('a field shows in a surface with no Material around it', (tester) async {
    final processor = A2UIProcessor(catalogs: A2UICatalogs());
    addTearDown(processor.dispose);
    processor.apply([
      createSurface([_field()]),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [StreamTheme.light()]),
        home: A2UISurfaceView(surface: processor.surface('s')!),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets("the app's text input builder draws a field", (tester) async {
    await pumpSurface(
      tester,
      components: [_field()],
      builders: StreamComponentBuilders(textInput: (context, props) => const Text('App field')),
    );

    expect(find.text('App field'), findsOneWidget);
  });

  testWidgets("an obscured field never goes to the app's text input builder", (tester) async {
    await pumpSurface(
      tester,
      components: [_field(variant: 'obscured')],
      builders: StreamComponentBuilders(textInput: (context, props) => const Text('App field')),
    );

    expect(find.text('App field'), findsNothing);
  });

  testWidgets('a field shows the value of the data model', (tester) async {
    await pumpSurface(tester, components: [_field()], data: {'name': 'Ada'});

    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('a field whose value is written as text shows it read-only, and is reported', (tester) async {
    final errors = <A2UIError>[];
    await pumpSurface(
      tester,
      components: [_field(value: 'Fixed')],
      errors: errors,
    );

    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(find.text('Fixed'), findsOneWidget);
    expect(errors.single.code, A2UIErrorCode.validationFailed);
  });

  testWidgets('a field bound to the data model can be typed in', (tester) async {
    await pumpSurface(tester, components: [_field()], data: {'name': 'Ada'});

    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
  });

  testWidgets("a field whose value is written as text doesn't write to the data model", (tester) async {
    final processor = await pumpSurface(tester, components: [_field(value: 'Fixed')]);

    await tester.enterText(find.byType(TextField), 'Changed');

    expect(_surface(processor).read('/'), isEmpty);
  });

  testWidgets('a change from elsewhere shows in a field nobody is typing in', (tester) async {
    final processor = await pumpSurface(tester, components: [_field()], data: {'name': 'Ada'});

    _surface(processor).write('/name', 'Grace');
    await tester.pump();

    expect(find.text('Grace'), findsOneWidget);
  });

  testWidgets("a change from elsewhere doesn't replace what the person is typing", (tester) async {
    final processor = await pumpSurface(tester, components: [_field()]);
    await tester.enterText(find.byType(TextField), 'Ad');

    _surface(processor).write('/name', 'Grace');
    await tester.pump();

    expect(find.text('Ad'), findsOneWidget);
  });

  testWidgets('a change from elsewhere shows once the person stops typing', (tester) async {
    final processor = await pumpSurface(tester, components: [_field()]);
    await tester.enterText(find.byType(TextField), 'Ad');
    _surface(processor).write('/name', 'Grace');
    await tester.pump();

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(find.text('Grace'), findsOneWidget);
  });

  testWidgets('an obscured field hides its text', (tester) async {
    await pumpSurface(tester, components: [_field(variant: 'obscured')]);

    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
  });

  testWidgets("a field that isn't obscured shows its text", (tester) async {
    await pumpSurface(tester, components: [_field()]);

    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
  });

  testWidgets('a long text field takes several lines', (tester) async {
    await pumpSurface(tester, components: [_field(variant: 'longText')]);

    expect(tester.widget<TextField>(find.byType(TextField)).maxLines, isNull);
  });

  testWidgets('a long text field shows three lines while it holds fewer', (tester) async {
    await pumpSurface(tester, components: [_field(variant: 'longText')]);

    expect(tester.widget<TextField>(find.byType(TextField)).minLines, 3);
  });

  testWidgets('a number field asks for the keyboard of numbers', (tester) async {
    await pumpSurface(tester, components: [_field(variant: 'number')]);

    expect(
      tester.widget<TextField>(find.byType(TextField)).keyboardType,
      const TextInputType.numberWithOptions(signed: true, decimal: true),
    );
  });

  testWidgets('an obscured field asks for the keyboard of text', (tester) async {
    await pumpSurface(tester, components: [_field(variant: 'obscured')]);

    expect(tester.widget<TextField>(find.byType(TextField)).keyboardType, TextInputType.text);
  });

  testWidgets('a short text field takes one line', (tester) async {
    await pumpSurface(tester, components: [_field(variant: 'shortText')]);

    expect(tester.widget<TextField>(find.byType(TextField)).maxLines, 1);
  });

  testWidgets('a field shows its label above it', (tester) async {
    await pumpSurface(tester, components: [_field(placeholder: 'Ada Lovelace')]);

    expect(tester.getBottomLeft(find.text('Name')).dy, lessThan(tester.getTopLeft(find.byType(TextField)).dy));
  });

  testWidgets('an empty field shows its placeholder', (tester) async {
    await pumpSurface(tester, components: [_field(placeholder: 'Ada Lovelace')]);

    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('a field shows its label above it, drawn by the design system', (tester) async {
    await pumpSurface(tester, components: [_field()]);

    expect(find.descendant(of: find.byType(StreamTextInput), matching: find.text('Name')), findsOneWidget);
    expect(tester.widget<StreamTextInput>(find.byType(StreamTextInput)).props.labelText, 'Name');
  });

  testWidgets("an empty field doesn't show the messages of its failing checks", (tester) async {
    await pumpSurface(
      tester,
      components: [
        _field(checks: [_longEnough]),
      ],
    );

    expect(find.text('Use three letters or more.'), findsNothing);
  });

  testWidgets('a field shows the messages of its failing checks once the person typed', (tester) async {
    await pumpSurface(
      tester,
      components: [
        _field(checks: [_longEnough]),
      ],
    );

    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump();

    expect(find.text('Use three letters or more.'), findsOneWidget);
  });

  testWidgets('a field whose check fails is drawn in its error state', (tester) async {
    await pumpSurface(
      tester,
      components: [
        _field(checks: [_longEnough]),
      ],
    );

    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump();

    expect(tester.widget<StreamTextInput>(find.byType(StreamTextInput)).props.helperState, StreamHelperState.error);
  });

  testWidgets('an obscured field is outlined in the border color', (tester) async {
    const border = Color(0xFF123456);
    await pumpSurface(
      tester,
      components: [_field(variant: 'obscured')],
      theme: A2UIThemeData(border: border),
    );

    final outline = tester.widget<TextField>(find.byType(TextField)).decoration!.enabledBorder! as OutlineInputBorder;

    expect(outline.borderSide.color, border);
  });

  testWidgets("an obscured field is drawn with the text input theme's text, hint and cursor", (tester) async {
    const style = StreamTextInputStyle(
      textStyle: TextStyle(fontSize: 17),
      hintStyle: TextStyle(fontSize: 13),
      cursorColor: Color(0xFF0000AA),
      cursorWidth: 3,
    );
    await pumpSurface(
      tester,
      components: [_field(variant: 'obscured', placeholder: 'Password')],
      streamTheme: StreamTheme(textInputTheme: const StreamTextInputThemeData(style: style)),
    );

    final field = tester.widget<TextField>(find.byType(TextField));

    expect(field.style?.fontSize, 17);
    expect(field.decoration!.hintStyle?.fontSize, 13);
    expect(field.cursorColor, const Color(0xFF0000AA));
    expect(field.cursorWidth, 3);
  });

  testWidgets("an obscured field whose check fails has the text input theme's error cursor", (tester) async {
    await pumpSurface(
      tester,
      components: [
        _field(variant: 'obscured', checks: [_longEnough]),
      ],
      streamTheme: StreamTheme(
        textInputTheme: const StreamTextInputThemeData(
          style: StreamTextInputStyle(cursorErrorColor: Color(0xFFAA0000)),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).cursorColor, const Color(0xFFAA0000));
  });

  testWidgets('an obscured field whose check fails is outlined in the error color', (tester) async {
    await pumpSurface(
      tester,
      components: [
        _field(variant: 'obscured', checks: [_longEnough]),
      ],
    );

    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump();

    final border = tester.widget<TextField>(find.byType(TextField)).decoration!.enabledBorder! as OutlineInputBorder;

    expect(border.borderSide.color, lightTheme().error);
  });

  testWidgets("what a person types into an obscured field is in the form's event, as the agent asked", (tester) async {
    final events = <A2UIActionEvent>[];
    await pumpSurface(tester, components: _loginForm, events: events);

    await tester.enterText(find.byType(TextField).last, 'hunter2');
    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(events.single.context['password'], 'hunter2');
  });

  testWidgets('a field is read by its label, with its placeholder as a hint', (tester) async {
    await pumpSurface(tester, components: [_field(placeholder: 'As on your passport')]);

    expect(
      tester.getSemantics(find.byType(StreamTextInput)),
      isSemantics(label: 'Name', hint: 'As on your passport', isTextField: true),
    );
  });

  testWidgets("a field whose value isn't bound is read as read-only, and can't be tapped by assistive technologies", (
    tester,
  ) async {
    await pumpSurface(tester, components: [_field(value: 'Fixed')]);

    expect(
      tester.getSemantics(find.byType(StreamTextInput)),
      isSemantics(isTextField: true, isReadOnly: true, hasTapAction: false),
    );
  });

  testWidgets('a field bound to the data model is read as editable', (tester) async {
    await pumpSurface(tester, components: [_field()]);

    expect(
      tester.getSemantics(find.byType(StreamTextInput)),
      isSemantics(isTextField: true, isReadOnly: false, hasTapAction: true, hasFocusAction: true),
    );
  });

  testWidgets("typing into the app's text input through its props' controller writes the value", (tester) async {
    final processor = await pumpSurface(
      tester,
      components: [_field()],
      builders: StreamComponentBuilders(
        textInput: (context, props) => Material(
          child: TextField(controller: props.controller, onChanged: props.onChanged),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Ada');

    expect(_surface(processor).read('/name'), 'Ada');
  });

  testWidgets("the app's text input writes the value through its props' onChanged", (tester) async {
    late StreamTextInputProps props;
    final processor = await pumpSurface(
      tester,
      components: [_field()],
      builders: StreamComponentBuilders(
        textInput: (context, value) {
          props = value;
          return const SizedBox();
        },
      ),
    );

    props.onChanged!('Ada');

    expect(_surface(processor).read('/name'), 'Ada');
  });

  testWidgets("the app's text input is read-only when the field's value isn't bound", (tester) async {
    late StreamTextInputProps props;
    await pumpSurface(
      tester,
      components: [_field(value: 'Fixed')],
      builders: StreamComponentBuilders(
        textInput: (context, value) {
          props = value;
          return const SizedBox();
        },
      ),
    );

    expect(props.readOnly, isTrue);
  });

  testWidgets("the app's text input is in its error state when a check fails", (tester) async {
    late StreamTextInputProps props;
    await pumpSurface(
      tester,
      components: [
        _field(checks: [_longEnough]),
      ],
      data: {'name': 'A'},
      builders: StreamComponentBuilders(
        textInput: (context, value) {
          props = value;
          return const SizedBox();
        },
      ),
    );

    expect(props.helperState, StreamHelperState.error);
  });

  testWidgets('a field without an accessibility label is read with its label', (tester) async {
    await pumpSurface(tester, components: [_field()]);

    expect(tester.getSemantics(find.byType(StreamTextInput)), isSemantics(label: 'Name', isTextField: true));
  });

  testWidgets('a field beside a text in a row without weights fills the rest of the row', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Row',
          'children': ['caption', 'name'],
        },
        {'id': 'caption', 'component': 'Text', 'text': 'Who'},
        _field(id: 'name'),
      ],
    );

    expect(tester.getTopRight(find.byType(StreamTextInput)).dx, 400);
  });

  testWidgets('a field in a row that scrolls has a width of its own', (tester) async {
    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'List',
          'direction': 'horizontal',
          'children': ['name'],
        },
        _field(id: 'name'),
      ],
    );

    expect(tester.getSize(find.byType(StreamTextInput)).width, 280);
  });
}

const _longEnough = {
  'condition': {
    '@call': 'length',
    'args': {
      'value': {'@path': '/name'},
      'min': 3,
    },
  },
  'message': 'Use three letters or more.',
};

const _loginForm = [
  {
    'id': 'root',
    'component': 'Column',
    'children': ['user', 'password', 'login'],
  },
  {
    'id': 'user',
    'component': 'TextField',
    'label': 'User',
    'value': {'@path': '/user'},
  },
  {
    'id': 'password',
    'component': 'TextField',
    'label': 'Password',
    'variant': 'obscured',
    'value': {'@path': '/password'},
  },
  {
    'id': 'login',
    'component': 'Button',
    'child': 'login_label',
    'action': {
      'event': {
        'name': 'log_in',
        'context': {
          'password': {'@path': '/password'},
        },
      },
    },
  },
  {'id': 'login_label', 'component': 'Text', 'text': 'Log in'},
];

Map<String, Object?> _field({
  String id = 'root',
  Object value = const {'@path': '/name'},
  String? variant,
  String? placeholder,
  List<Map<String, Object?>>? checks,
  Map<String, Object?>? accessibility,
}) {
  return {
    'id': id,
    'component': 'TextField',
    'label': 'Name',
    'value': value,
    'variant': ?variant,
    'placeholder': ?placeholder,
    'checks': ?checks,
    'accessibility': ?accessibility,
  };
}

A2UISurface _surface(A2UIProcessor processor) => processor.surface('s')!;
