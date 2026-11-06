import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/stream_chat_flutter_ai_openui.dart';
import 'package:stream_core_flutter/core.dart';

import 'openui_test_app.dart';

// A host whose sends, links, tools and saved state the test reads.
final class _Host with AIUIHosting {
  _Host({this.components = const [], this.tools = const {}});

  @override
  final List<AIUIComponent<Object?>> components;

  final Map<String, Object? Function(Map<String, Object?> arguments)> tools;
  final sent = <AIUIAction>[];
  final opened = <Uri>[];
  final calls = <({String name, Map<String, Object?> arguments, bool userInitiated})>[];
  final states = <String, Object?>{};

  @override
  Future<void> send(AIUIAction action) async => sent.add(action);

  @override
  Future<Object?> runTool(String name, {Map<String, Object?> arguments = const {}, bool userInitiated = false}) async {
    calls.add((name: name, arguments: arguments, userInitiated: userInitiated));
    final tool = tools[name];
    if (tool == null) throw AIUIToolException('No tool named $name');
    return tool(arguments);
  }

  @override
  void open(Uri url) => opened.add(url);

  @override
  Object? state(String messageId) => states[messageId];

  @override
  void setState(String messageId, Object? state) => states[messageId] = state;
}

AIUIDocument _doc(String content, {bool isStreaming = false}) =>
    AIUIDocument(format: AIUIFormat.openUI, isStreaming: isStreaming, content: content);

// Pumps what [engine] builds for [document] of the reply `r1`, and returns
// whether it built anything.
Future<bool> _pump(WidgetTester tester, AIUIEngine engine, AIUIDocument document, {String id = 'r1'}) async {
  final view = engine.view(document, id);
  await tester.pumpWidget(testApp(view ?? const SizedBox.shrink()));
  await tester.pump();
  return view != null;
}

const _card = 'root = Card([CardHeader("Title"), TextContent("Body")])';

const _form = '''
root = Stack([form])
form = Form("contact", buttons, [name, pass])
name = FormControl("Name", Input("name", "", "text"))
pass = FormControl("Password", Input("secret", "", "password"))
buttons = Buttons([Button("Send", @ToAssistant("Send it", "ctx"))])
''';

// What the app's place card read from the agent.
typedef _Place = ({String title});

final class _PlaceCard extends AIUIComponent<_Place> {
  const _PlaceCard([this._name = 'place_card']);

  final String _name;

  @override
  AIUIComponentDefinition get definition => AIUIComponentDefinition(
    name: _name,
    description: 'A place.',
    parameters: const [AIUIParameter.required('title', AIUIParameterType.string)],
    events: const [AIUIComponentEvent(name: 'ask_about', description: 'Asks about the place.')],
  );

  @override
  _Place readArguments(AIUIArguments arguments) => (title: arguments.string('title'));

  @override
  Widget build(BuildContext context, _Place arguments, AIUIComponentContext ui) {
    return TextButton(
      onPressed: () => ui.emit('ask_about', label: 'About ${arguments.title}', payload: {'title': arguments.title}),
      child: Text('Place ${arguments.title}'),
    );
  }
}

// An app component whose build throws.
final class _Broken extends AIUIComponent<Object?> {
  const _Broken();

  @override
  AIUIComponentDefinition get definition => const AIUIComponentDefinition(name: 'broken', description: 'Breaks.');

  @override
  Object? readArguments(AIUIArguments arguments) => null;

  @override
  Widget build(BuildContext context, Object? arguments, AIUIComponentContext ui) => throw StateError('broken');
}

void main() {
  group('capabilities', () {
    test('give the fence and the instructions, with the app instructions first', () {
      const renderer = OpenUIRenderer(instructions: 'Answer trips as UI.');
      final capabilities = renderer.capabilities(const [], const [
        AIToolDefinition(name: 'list_trips', description: 'Lists trips.', isReadOnly: true),
        AIToolDefinition(name: 'book_trip', description: 'Books a trip.'),
      ]);

      expect(capabilities.keys, ['fence', 'instructions']);
      expect(capabilities['fence'], OpenUIRenderer.fence);
      final instructions = capabilities['instructions']! as String;
      expect(instructions, startsWith('Answer trips as UI.\n\n'));
      expect(instructions, contains('Lists trips. Read-only: use it in Query() or Mutation().'));
      expect(instructions, contains('Books a trip. It changes something: use it only in Mutation()'));
    });

    test("list the app's components the agent can place, but not one whose name is taken", () {
      const renderer = OpenUIRenderer();
      final instructions =
          renderer.capabilities(const [_PlaceCard(), _PlaceCard('card')], const [])['instructions']! as String;

      expect(instructions, contains('PlaceCard('));
      expect(RegExp(r'^Card\(', multiLine: true).allMatches(instructions), hasLength(1));
    });

    test('use the chat library by default', () {
      expect(const OpenUIRenderer().library, OpenUILibrary.chat);
      expect(const OpenUIRenderer().format, AIUIFormat.openUI);
    });
  });

  group('view', () {
    testWidgets('shows nothing while the program has no root, then draws it', (tester) async {
      final engine = const OpenUIRenderer().createEngine(_Host());
      addTearDown(engine.dispose);

      expect(await _pump(tester, engine, _doc('root = Ca', isStreaming: true)), isFalse);
      expect(await _pump(tester, engine, _doc(_card)), isTrue);
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('shows nothing for a reply that ends without a root, nor for content that is no text', (tester) async {
      final errors = <OpenUIErrorCode>[];
      final engine = OpenUIRenderer(onError: (error, _) => errors.add(error.code)).createEngine(_Host());
      addTearDown(engine.dispose);

      expect(engine.view(_doc('Sorry, I can only answer in words.'), 'r1'), isNull);
      expect(errors, [OpenUIErrorCode.parseFailed]);
      expect(engine.view(const AIUIDocument(format: AIUIFormat.openUI, content: {'root': 1}), 'r2'), isNull);
    });

    testWidgets('a button runs only once the reply is written', (tester) async {
      final host = _Host();
      final engine = OpenUIRenderer(library: OpenUILibrary.standard).createEngine(host);
      addTearDown(engine.dispose);
      const program = 'root = Stack([Button("Go", @ToAssistant("Go"))])';

      await _pump(tester, engine, _doc(program, isStreaming: true));
      await tester.tap(find.text('Go'));
      expect(host.sent, isEmpty);

      await _pump(tester, engine, _doc(program));
      await tester.tap(find.text('Go'));
      expect(host.sent.single.name, 'continue_conversation');
    });

    for (final (label, fence) in [
      ('```Enjoy!', '```Enjoy!'),
      ('four backticks', '````\n'),
      ('a tab-indented', '\t```\n'),
    ]) {
      testWidgets('a fence the backend never closed ($label) keeps the card', (tester) async {
        final engine = const OpenUIRenderer().createEngine(_Host());
        addTearDown(engine.dispose);

        expect(await _pump(tester, engine, _doc('$_card\n$fence')), isTrue);
        expect(find.text('Title'), findsOneWidget);
      });
    }

    testWidgets('a fence the backend never closed keeps the card when the reply goes on after it', (tester) async {
      final engine = const OpenUIRenderer().createEngine(_Host());
      addTearDown(engine.dispose);

      expect(await _pump(tester, engine, _doc('$_card\n```Enjoy!\n\nHave fun.')), isTrue);
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('a document received while the conversation builds is applied after the frame, the latest winning', (
      tester,
    ) async {
      final engine = const OpenUIRenderer().createEngine(_Host());
      addTearDown(engine.dispose);
      final view = engine.view(_doc('root = Card([CardHeader("One")])', isStreaming: true), 'r1')!;

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) {
              engine
                ..receive(_doc('root = Card([CardHeader("Two")])', isStreaming: true), 'r1')
                ..receive(_doc('root = Card([CardHeader("Three")])'), 'r1');
              return view;
            },
          ),
        ),
      );
      expect(find.text('One'), findsOneWidget);
      await tester.pump();

      expect(find.text('Three'), findsOneWidget);
      expect(find.text('Two'), findsNothing);
    });

    testWidgets('content in its own fenced block is read as before', (tester) async {
      final engine = const OpenUIRenderer().createEngine(_Host());
      addTearDown(engine.dispose);

      expect(await _pump(tester, engine, _doc('```openui-lang\n$_card\n```')), isTrue);
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('a fence inside a multi-line string keeps the rest of the card', (tester) async {
      final engine = const OpenUIRenderer().createEngine(_Host());
      addTearDown(engine.dispose);
      const program =
          'root = Card([CardHeader("Title"), t, CardHeader("After")])\nt = TextContent("code:\n```\nx\n```\n")';

      expect(await _pump(tester, engine, _doc(program)), isTrue);
      expect(find.text('After'), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets('a button in a form sends its label, context, message, form and values without passwords', (
      tester,
    ) async {
      final host = _Host();
      final engine = OpenUIRenderer(library: OpenUILibrary.standard).createEngine(host);
      addTearDown(engine.dispose);
      await _pump(tester, engine, _doc(_form));

      await tester.enterText(find.byType(TextField).first, 'Ann');
      await tester.enterText(find.byType(TextField).last, 'hunter2');
      await tester.tap(find.text('Send'));
      await tester.pump();

      final action = host.sent.single;
      expect(action.messageId, 'r1');
      expect(action.format, AIUIFormat.openUI);
      expect(action.name, 'continue_conversation');
      expect(action.label, 'Send');
      expect(action.payload, {
        'context': 'ctx',
        'message': 'Send it',
        'form': 'contact',
        'values': {
          'contact': {
            'name': {'value': 'Ann', 'componentType': 'Input'},
          },
        },
      });
    });

    testWidgets('a button without a label sends Continue', (tester) async {
      final host = _Host();
      final engine = OpenUIRenderer(library: OpenUILibrary.standard).createEngine(host);
      addTearDown(engine.dispose);
      await _pump(tester, engine, _doc('root = Stack([Button("", @ToAssistant("Next"))])'));

      await tester.tap(find.byType(StreamButton).first);

      expect(host.sent.single.label, 'Continue');
      expect(host.sent.single.payload, {'message': 'Next'});
    });

    testWidgets('a web link opens through the host, never as an action', (tester) async {
      final host = _Host();
      final engine = OpenUIRenderer(library: OpenUILibrary.standard).createEngine(host);
      addTearDown(engine.dispose);
      await _pump(
        tester,
        engine,
        _doc('root = Stack([Button("Web", @OpenUrl("https://getstream.io")), Button("Js", @OpenUrl("javascript:x"))])'),
      );

      await tester.tap(find.text('Web'));
      await tester.tap(find.text('Js'));

      expect(host.opened, [Uri.parse('https://getstream.io')]);
      expect(host.sent, isEmpty);
    });

    testWidgets('a removed reply sends nothing', (tester) async {
      final host = _Host();
      final engine = OpenUIRenderer(library: OpenUILibrary.standard).createEngine(host);
      addTearDown(engine.dispose);
      await _pump(tester, engine, _doc('root = Stack([Button("Go", @ToAssistant("Go"))])'));

      engine.remove('r1');
      await tester.tap(find.text('Go'));

      expect(host.sent, isEmpty);
    });
  });

  group('tools and state', () {
    testWidgets('a query runs its tool once the reply is written, and a mutation as the person asked', (tester) async {
      final host = _Host(tools: {'list': (_) => <Object?>[], 'save': (_) => true});
      final engine = OpenUIRenderer(library: OpenUILibrary.standard).createEngine(host);
      addTearDown(engine.dispose);
      const program =
          'q = Query("list", {}, [])\nm = Mutation("save", {})\nroot = Stack([Button("Save", Action([@Run(m)]))])';

      await _pump(tester, engine, _doc(program, isStreaming: true));
      expect(host.calls, isEmpty);

      engine.view(_doc(program), 'r1');
      expect(host.calls, isEmpty, reason: "the app's tool doesn't run inside the conversation's build");
      await _pump(tester, engine, _doc(program));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(seconds: 1));

      expect([for (final call in host.calls) (call.name, call.userInitiated)], [('list', false), ('save', true)]);
    });

    testWidgets("the reply's state is saved in the host and given back to a new engine", (tester) async {
      final host = _Host();
      final renderer = OpenUIRenderer(library: OpenUILibrary.standard);
      const program =
          r'$n = "a"'
          '\nroot = Stack([Input("q", "", "text", null, \$n), Button("B", @Set(\$n, "b"))])';
      final engine = renderer.createEngine(host);
      await _pump(tester, engine, _doc(program));

      await tester.tap(find.text('B'));
      await tester.pump();
      expect(host.states['r1'], containsPair(r'$n', 'b'));
      engine.dispose();

      final again = renderer.createEngine(host);
      addTearDown(again.dispose);
      await _pump(tester, again, _doc(program));

      expect(find.widgetWithText(TextField, 'b'), findsOneWidget);
    });

    testWidgets('state kept as a map of any key type is given back', (tester) async {
      final host = _Host()..states['r1'] = <dynamic, dynamic>{r'$n': 'kept'};
      final engine = OpenUIRenderer(library: OpenUILibrary.standard).createEngine(host);
      addTearDown(engine.dispose);

      await _pump(
        tester,
        engine,
        _doc(
          r'$n = "a"'
          '\nroot = Stack([Input("q", "", "text", null, \$n)])',
        ),
      );

      expect(find.widgetWithText(TextField, 'kept'), findsOneWidget);
    });
  });

  testWidgets('a reply written without a root stops its queries', (tester) async {
    final host = _Host(tools: {'list': (_) => <Object?>[]});
    final engine = OpenUIRenderer(onError: (_, _) {}).createEngine(host);
    addTearDown(engine.dispose);

    expect(engine.view(_doc('q = Query("list", {}, [], 10)\nSorry.'), 'r1'), isNull);
    await tester.pump(const Duration(seconds: 30));

    expect(host.calls, isEmpty);
  });

  group('errors', () {
    testWidgets("the program's problems reach onError once, after the reply is written", (tester) async {
      final errors = <(OpenUIErrorCode, String)>[];
      final engine = OpenUIRenderer(
        onError: (error, messageId) => errors.add((error.code, messageId)),
      ).createEngine(_Host());
      addTearDown(engine.dispose);
      const program = 'root = Card([CardHeader("Title"), Nope("x")])';

      await _pump(tester, engine, _doc(program, isStreaming: true));
      expect(errors, isEmpty);

      await _pump(tester, engine, _doc(program));
      await _pump(tester, engine, _doc(program));

      expect(errors, [(OpenUIErrorCode.unknownComponent, 'r1')]);
    });

    testWidgets('a builder that throws reaches onError as a render error', (tester) async {
      final errors = <OpenUIError>[];
      final engine = OpenUIRenderer(
        onError: (error, _) => errors.add(error),
      ).createEngine(_Host(components: const [_Broken()]));
      addTearDown(engine.dispose);

      const program = 'root = Card([CardHeader("Title"), b])\nb = Broken()';
      await _pump(tester, engine, _doc(program, isStreaming: true));
      expect(errors, isEmpty);
      await _pump(tester, engine, _doc(program));
      await _pump(tester, engine, _doc('$program\n'));

      expect(errors.single.code, OpenUIErrorCode.renderError);
      expect(errors.single.component, 'Broken');
      expect(errors.single.statementId, 'b');
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('a builder that throws goes to FlutterError without onError', (tester) async {
      final engine = const OpenUIRenderer().createEngine(_Host(components: const [_Broken()]));
      addTearDown(engine.dispose);

      await _pump(tester, engine, _doc('root = Card([CardHeader("Title"), Broken()])'));

      expect(tester.takeException(), isA<StateError>());
    });
  });

  group('app components', () {
    testWidgets('are drawn with their arguments, and their events name them', (tester) async {
      final host = _Host(components: const [_PlaceCard()]);
      final engine = const OpenUIRenderer().createEngine(host);
      addTearDown(engine.dispose);

      await _pump(tester, engine, _doc('root = Card([PlaceCard("Ohrid")])'));
      await tester.tap(find.text('Place Ohrid'));

      expect(
        host.sent.single,
        const AIUIAction(
          messageId: 'r1',
          format: AIUIFormat.openUI,
          name: 'ask_about',
          label: 'About Ohrid',
          payload: {'title': 'Ohrid', 'component': 'place_card'},
        ),
      );
    });

    testWidgets('draw nothing while their values are still arriving', (tester) async {
      final engine = const OpenUIRenderer().createEngine(_Host(components: const [_PlaceCard()]));
      addTearDown(engine.dispose);

      await _pump(tester, engine, _doc('root = Card([CardHeader("Title"), PlaceCard(1)])', isStreaming: true));

      expect(find.textContaining('Place'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one whose name the library has is left out, and the built-in one is drawn', (tester) async {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      final engine = const OpenUIRenderer().createEngine(_Host(components: const [_PlaceCard('card_header')]));
      FlutterError.onError = previous;
      addTearDown(engine.dispose);

      await _pump(tester, engine, _doc('root = Card([CardHeader("Title")])'));

      expect(find.text('Title'), findsOneWidget);
      expect(find.textContaining('Place'), findsNothing);
      expect(reported.single.exception.toString(), contains("'card_header'"));
    });
  });
}
