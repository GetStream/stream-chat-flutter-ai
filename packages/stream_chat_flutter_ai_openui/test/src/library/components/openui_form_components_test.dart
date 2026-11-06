import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/components/openui_fields.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_pickers.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view.dart';
import 'package:stream_core_flutter/core.dart';

import '../../openui_test_app.dart';

final _library = OpenUILibrary.standard;
final _theme = OpenUIThemeData.defaults(StreamTheme.light());

Future<(OpenUIRuntime, List<OpenUIActionEvent>)> _pump(
  WidgetTester tester,
  String program, {
  bool isStreaming = false,
}) async {
  final runtime = testRuntime(library: _library);
  addTearDown(runtime.dispose);
  final events = <OpenUIActionEvent>[];
  runtime.actions.listen(events.add);
  await pumpOpenUI(tester, runtime, program: program, isStreaming: isStreaming, library: _library);
  await tester.pump();
  return (runtime, events);
}

const _contact = '''
root = Stack([form])
form = Form("contact", buttons, [name, pass])
name = FormControl("Name", Input("name", "Your name", "text", {required: true, minLength: 2}), "As on your ID")
pass = FormControl("Password", Input("secret", "", "password"))
buttons = Buttons([send, later])
send = Button("Send", @ToAssistant("Send"))
later = Button("Later", @ToAssistant("Later"), "secondary")
''';

void main() {
  group('Form', () {
    testWidgets('a FormControl shows its label, a required mark and its hint', (tester) async {
      await _pump(tester, _contact);

      expect(find.text('Name *', findRichText: true), findsOneWidget);
      expect(find.text('As on your ID'), findsOneWidget);
    });

    testWidgets('an Input writes its value and type under the form', (tester) async {
      final (runtime, _) = await _pump(tester, _contact);

      await tester.enterText(find.byType(TextField).first, 'Ann');
      await tester.pump();

      expect(runtime.fieldValue('contact', 'name'), const OpenUIString('Ann'));
      final form = runtime.state.value['contact']! as OpenUIObject;
      expect((form.fields['name']! as OpenUIObject).fields['componentType'], const OpenUIString('Input'));
    });

    testWidgets('a field is checked when it loses focus, and its error hides while it is edited', (tester) async {
      await _pump(tester, _contact);

      await tester.enterText(find.byType(TextField).first, 'A');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.text('Must be at least 2 characters'), findsOneWidget);
      expect(find.text('As on your ID'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'An');
      await tester.pump();
      expect(find.text('Must be at least 2 characters'), findsNothing);
    });

    testWidgets('a primary button checks the form and runs nothing while a field fails', (tester) async {
      final (_, events) = await _pump(tester, _contact);

      await tester.tap(find.text('Send'));
      await tester.pump();

      expect(events, isEmpty);
      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('a secondary button runs without checking the form', (tester) async {
      final (_, events) = await _pump(tester, _contact);

      await tester.tap(find.text('Later'));
      await tester.pump();

      expect(events.single.label, 'Later');
      expect(events.single.formName, 'contact');
      expect(find.text('This field is required'), findsNothing);
    });

    testWidgets('a primary button sends the form state without the password', (tester) async {
      final (_, events) = await _pump(tester, _contact);

      await tester.enterText(find.byType(TextField).first, 'Ann');
      await tester.enterText(find.byType(TextField).last, 'hunter2');
      await tester.tap(find.text('Send'));
      await tester.pump();

      final event = events.single;
      expect(event.type, OpenUIActionEvent.continueConversation);
      expect(event.message, 'Send');
      final form = event.formState['contact']! as OpenUIObject;
      expect(form.fields.keys, ['name']);
      expect(event.formState.toString(), isNot(contains('hunter2')));
    });

    testWidgets('a password is obscured', (tester) async {
      await _pump(tester, _contact);

      expect(tester.widget<TextField>(find.byType(TextField).last).obscureText, isTrue);
    });

    testWidgets('a primary button whose plan neither talks nor mutates skips the check', (tester) async {
      final (runtime, _) = await _pump(tester, r'''
$done = false
root = Stack([Form("f", Buttons([Button("Mark", Action([@Set($done, true)]))]), [FormControl("N", Input("n", "", "text", {required: true}))])])
''');

      await tester.tap(find.text('Mark'));
      await tester.pump();

      expect(runtime.state.value[r'$done'], const OpenUIBool(true));
      expect(find.text('This field is required'), findsNothing);
    });

    testWidgets('fields and buttons are disabled while the reply streams', (tester) async {
      await _pump(tester, _contact, isStreaming: true);

      expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isFalse);
      expect(tester.widget<StreamButton>(find.widgetWithText(StreamButton, 'Send')).props.onPressed, isNull);
    });
  });

  group('bound fields', () {
    testWidgets('an Input shows its variable as it changes and writes it back', (tester) async {
      final (runtime, _) = await _pump(tester, r'''
$q = "hi"
root = Stack([Input("q", "", "text", null, $q), Button("Set", @Set($q, "there"))])
''');
      expect(find.text('hi'), findsOneWidget);

      await tester.tap(find.text('Set'));
      await tester.pump();
      await tester.pump();
      expect(find.text('there'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'typed');
      await tester.pump();
      expect(runtime.state.value[r'$q'], const OpenUIString('typed'));
    });
  });

  group('choices', () {
    testWidgets('a Select opens its options and writes the one chosen', (tester) async {
      final (runtime, _) = await _pump(tester, '''
root = Stack([Select("size", [SelectItem("s", "Small"), SelectItem("l", "Large")], "Pick one")])
''');
      expect(find.text('Pick one'), findsOneWidget);

      await tester.tap(find.text('Pick one'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();

      expect(runtime.fieldValue(null, 'size'), const OpenUIString('l'));
      expect(find.text('Large'), findsOneWidget);
    });

    testWidgets('a CheckBoxGroup keeps its defaults once the reply ends, and writes each toggle', (tester) async {
      const program = '''
root = Stack([CheckBoxGroup("opts", [CheckBoxItem("A", "", "a", true), CheckBoxItem("B", "", "b")])])
''';
      final (runtime, _) = await _pump(tester, program, isStreaming: true);
      expect(runtime.fieldValue(null, 'opts'), isNull);

      runtime.update(program, isStreaming: false);
      await pumpOpenUI(tester, runtime, library: _library);
      await tester.pump();
      expect(runtime.fieldValue(null, 'opts'), OpenUIValue.fromJson(const {'a': true, 'b': false}));

      await tester.tap(find.text('B'));
      await tester.pump();
      expect(runtime.fieldValue(null, 'opts'), OpenUIValue.fromJson(const {'a': true, 'b': true}));
      expect(tester.widgetList<StreamCheckbox>(find.byType(StreamCheckbox)).map((box) => box.props.value), [
        true,
        true,
      ]);
    });

    testWidgets('a SwitchGroup draws switches', (tester) async {
      await _pump(tester, 'root = Stack([SwitchGroup("s", [SwitchItem("Wifi", "", "wifi", true)])])');

      expect(tester.widget<StreamSwitch>(find.byType(StreamSwitch)).props.value, isTrue);
    });

    testWidgets('a RadioGroup keeps its default and writes the value tapped', (tester) async {
      final (runtime, _) = await _pump(tester, '''
root = Stack([RadioGroup("plan", [RadioItem("Free", "", "free"), RadioItem("Pro", "", "pro")], "free")])
''');
      expect(runtime.fieldValue(null, 'plan'), const OpenUIString('free'));

      await tester.tap(find.text('Pro'));
      await tester.pump();

      expect(runtime.fieldValue(null, 'plan'), const OpenUIString('pro'));
      expect(
        tester.getSemantics(find.text('Pro')),
        matchesSemantics(
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: true,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: 'Pro',
          isSelected: true,
          hasSelectedState: true,
        ),
      );
    });

    testWidgets('Chips choose several, and a single choice clears when tapped again', (tester) async {
      final (runtime, _) = await _pump(tester, '''
root = Stack([Chips("tags", "multiple", [ChipItem("a", "A"), ChipItem("b", "B")]), Chips("one", "single", [ChipItem("x", "X")])])
''');

      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(runtime.fieldValue(null, 'tags'), OpenUIValue.fromJson(const ['a', 'b']));

      await tester.tap(find.text('X'));
      await tester.pump();
      expect(runtime.fieldValue(null, 'one'), const OpenUIString('x'));
      await tester.tap(find.text('X'));
      await tester.pump();
      expect(runtime.fieldValue(null, 'one'), OpenUINull.instance);
    });

    testWidgets('a disabled chip can not be chosen', (tester) async {
      final (runtime, _) = await _pump(
        tester,
        'root = Stack([Chips("t", "multiple", [ChipItem("a", "A", null, true)])])',
      );

      await tester.tap(find.text('A'));
      await tester.pump();

      expect(runtime.fieldValue(null, 't'), isNull);
    });

    testWidgets('OptionCards choose one by default', (tester) async {
      final (runtime, _) = await _pump(tester, '''
root = Stack([OptionCards("plan", null, [OptionCard("a", "Basic"), OptionCard("b", "Plus")])])
''');

      await tester.tap(find.text('Basic'));
      await tester.pump();
      await tester.tap(find.text('Plus'));
      await tester.pump();

      expect(runtime.fieldValue(null, 'plan'), const OpenUIString('b'));
    });
  });

  group('Slider', () {
    testWidgets('keeps its default once the reply ends, rounded', (tester) async {
      final (runtime, _) = await _pump(tester, 'root = Stack([Slider("v", "continuous", 0, 10, null, [3.33333])])');

      expect(runtime.fieldValue(null, 'v'), OpenUIValue.fromJson(const [3.333]));
      expect(find.text('3.333'), findsOneWidget);
    });

    testWidgets('draws a thumb for each end of a range, labelled', (tester) async {
      await _pump(tester, 'root = Stack([Slider("p", "discrete", 0, 100, 10, [20, 80], "Price")])');

      expect(find.byType(Slider), findsNWidgets(2));
      expect(tester.getSemantics(find.byType(Slider).first).label, startsWith('Price, minimum'));
      expect(tester.getSemantics(find.byType(Slider).last).label, startsWith('Price, maximum'));
    });

    testWidgets('snaps a drag to its step and writes it when the drag ends', (tester) async {
      final (runtime, _) = await _pump(tester, 'root = Stack([Slider("v", "continuous", 0, 10, 5)])');

      await tester.drag(find.byType(Slider), const Offset(130, 0));
      await tester.pump();

      expect(runtime.fieldValue(null, 'v'), anyOf(OpenUIValue.fromJson(const [5]), OpenUIValue.fromJson(const [10])));
    });

    test('bounds default to 0 and 100 and keep max above min', () {
      expect(openUISliderBounds(null, null), (lower: 0.0, upper: 100.0));
      expect(openUISliderBounds(5, 5), (lower: 5.0, upper: 6.0));
      expect(openUISliderBounds(double.nan, 1e20), (lower: 0.0, upper: 1e15));
    });

    test('a step larger than the range or not positive is dropped; discrete steps by 1', () {
      expect(openUISliderStep(20, discrete: false, span: 10), isNull);
      expect(openUISliderStep(-1, discrete: false, span: 10), isNull);
      expect(openUISliderStep(null, discrete: true, span: 10), 1);
      expect(openUISliderStep(2, discrete: false, span: 10), 2);
    });

    test('values are clamped, ordered, and at most two', () {
      expect(openUISliderValues(OpenUIValue.fromJson(const [80, 20, 50]), 0, 100), [20, 80]);
      expect(openUISliderValues(OpenUIValue.fromJson(const [-5]), 0, 100), [0]);
      expect(openUISliderValues(const OpenUIString('x'), 0, 100), [0]);
    });
  });

  group('DatePicker', () {
    testWidgets('writes the day picked as yyyy-MM-dd', (tester) async {
      final (runtime, _) = await _pump(tester, 'root = Stack([DatePicker("d")])');

      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(runtime.fieldValue(null, 'd'), OpenUIString(openUIDateString(DateTime.now())));
    });

    testWidgets('a range shows its days and a picked end sets an unset start', (tester) async {
      final (runtime, _) = await _pump(tester, '''
root = Stack([DatePicker("r", "range", null, {from: "2026-01-02", to: "2026-01-05"}), DatePicker("e", "range")])
''');
      expect(find.text('2026-01-02'), findsOneWidget);
      expect(find.text('2026-01-05'), findsOneWidget);

      await tester.tap(find.text('Choose').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final today = OpenUIString(openUIDateString(DateTime.now()));
      expect(runtime.fieldValue(null, 'e'), OpenUIObject({'to': today, 'from': today}));
    });

    test('reads the day a string starts with, and no impossible day', () {
      expect(openUIParseDate('2026-02-03T10:00:00Z'), DateTime(2026, 2, 3));
      expect(openUIParseDate('2026-02-30'), isNull);
      expect(openUIParseDate('0005-03-01'), isNull);
      expect(openUIParseDate('03/02/2026'), isNull);
      expect(openUIDateString(DateTime(7, 1, 9)), '0007-01-09');
    });
  });

  group('buttons', () {
    testWidgets('variants map to core button styles and types', (tester) async {
      await _pump(tester, '''
root = Stack([Button("P"), Button("S", null, "secondary"), Button("T", null, "tertiary"), Button("D", null, "primary", "destructive", "large")])
''');
      StreamButtonProps props(String label) =>
          tester.widget<StreamButton>(find.widgetWithText(StreamButton, label)).props;

      expect(
        (props('P').style, props('P').type, props('P').size),
        (StreamButtonStyle.primary, StreamButtonType.solid, StreamButtonSize.medium),
      );
      expect((props('S').style, props('S').type), (StreamButtonStyle.secondary, StreamButtonType.outline));
      expect((props('T').style, props('T').type), (StreamButtonStyle.secondary, StreamButtonType.ghost));
      expect((props('D').style, props('D').size), (StreamButtonStyle.destructive, StreamButtonSize.large));
    });

    testWidgets('a button without an action sends its label to the assistant', (tester) async {
      final (_, events) = await _pump(tester, 'root = Stack([Button("Hello")])');

      await tester.tap(find.text('Hello'));
      await tester.pump();

      expect(events.single.type, OpenUIActionEvent.continueConversation);
      expect(events.single.message, 'Hello');
    });

    testWidgets('Buttons in a row go to a column when they do not fit', (tester) async {
      await _pump(tester, '''
root = Stack([Buttons([Button("A very long first button label here"), Button("A very long second button label here")])])
''');

      expect(
        tester.getTopLeft(find.text('A very long second button label here')).dy,
        greaterThan(tester.getTopLeft(find.text('A very long first button label here')).dy),
      );
    });

    testWidgets('an IconButton reads as its name and runs its action labelled with it', (tester) async {
      final (_, events) = await _pump(tester, 'root = Stack([IconButton("Refresh", Icon("refresh"))])');

      expect(find.bySemanticsLabel('Refresh'), findsOneWidget);
      await tester.tap(find.byType(StreamButton));
      await tester.pump();

      expect(events.single.label, 'Refresh');
    });
  });

  testWidgets('an IconButton in a form never checks it', (tester) async {
    final (_, events) = await _pump(tester, '''
root = Stack([Form("f", Buttons([IconButton("Go", Icon("send"))]), [FormControl("N", Input("n", "", "text", {required: true}))])])
''');

    await tester.tap(find.byType(StreamButton));
    await tester.pump();

    expect(events.single.label, 'Go');
    expect(find.text('This field is required'), findsNothing);
  });

  testWidgets('Chips keep their default once the reply ends', (tester) async {
    const program = 'root = Stack([Chips("t", "multiple", [ChipItem("a", "A"), ChipItem("b", "B")], null, ["b"])])';
    final (runtime, _) = await _pump(tester, program, isStreaming: true);
    expect(runtime.fieldValue(null, 't'), isNull);

    runtime.update(program, isStreaming: false);
    await pumpOpenUI(tester, runtime, library: _library);
    await tester.pump();

    expect(runtime.fieldValue(null, 't'), OpenUIValue.fromJson(const ['b']));
  });

  group('review fixes', () {
    testWidgets('a required password bound to a variable submits once typed', (tester) async {
      final (_, events) = await _pump(tester, r'''
$pw = ""
root = Stack([Form("f", Buttons([Button("Go")]), [FormControl("P", Input("pw", "", "password", {required: true}, $pw))])])
''');

      await tester.enterText(find.byType(TextField), 'secret');
      await tester.tap(find.text('Go'));
      await tester.pump();

      expect(events, hasLength(1));
    });

    testWidgets('a field that replaces one of the same name stays checked', (tester) async {
      final (_, events) = await _pump(tester, '''
root = Stack([Form("f", Buttons([Button("Go")]), [Tabs([TabItem("a", "A", [FormControl("X", Input("x", "", "text", {required: true}))]), TabItem("b", "B", [FormControl("Y", Input("x", "", "text", {required: true}))])])])])
''');

      await tester.tap(find.text('B'));
      await tester.pump();
      await tester.tap(find.text('Go'));
      await tester.pump();

      expect(events, isEmpty);
      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('a field shows, checks and sends its own value', (tester) async {
      final (_, events) = await _pump(tester, '''
root = Stack([Form("f", Buttons([Button("Go")]), [FormControl("N", Input("n", "", "text", {required: true}, "Ann"))])])
''');

      await tester.tap(find.text('Go'));
      await tester.pump();

      final form = events.single.formState['f']! as OpenUIObject;
      expect((form.fields['n']! as OpenUIObject).fields['value'], const OpenUIString('Ann'));
    });

    testWidgets('a single choice with a default can be cleared', (tester) async {
      await _pump(tester, 'root = Stack([Chips("c", "single", [ChipItem("a", "A")], null, "a")])');
      expect(find.byIcon(StreamTheme.light().icons.checkmark), findsOneWidget);

      await tester.tap(find.text('A'));
      await tester.pump();

      expect(find.byIcon(StreamTheme.light().icons.checkmark), findsNothing);
    });

    testWidgets('a stepped slider moves by one step from assistive technologies', (tester) async {
      await _pump(tester, 'root = Stack([Slider("v", "continuous", 0, 100, 25)])');

      expect(tester.widget<Slider>(find.byType(Slider)).divisions, 4);
    });
  });

  group('sizes', () {
    testWidgets('a select box grows with the text size', (tester) async {
      final runtime = testRuntime(library: _library);
      addTearDown(runtime.dispose);
      runtime.update('root = Stack([Select("s", [SelectItem("a", "A")])])', isStreaming: false);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: testApp(OpenUIView(runtime: runtime, library: _library)),
        ),
      );

      final box = tester.widget<Container>(
        find.ancestor(of: find.text('Select...'), matching: find.byType(Container)).first,
      );
      expect(box.constraints!.minHeight, 80);
      expect(_theme.mSpacing, isNotNull);
    });
  });
}
