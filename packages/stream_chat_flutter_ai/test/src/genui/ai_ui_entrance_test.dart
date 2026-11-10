import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_stage.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  testWidgets("AIUIView shows a reply's UI written before it showed at once", (tester) async {
    await _pumpUI(tester, ['a'], isStreaming: false);

    expect(_opacityOfUI(tester), 1);
  });

  testWidgets("AIUIView starts a reply's UI that first shows while the agent writes it clear", (tester) async {
    await _pumpUI(tester, ['a']);

    expect(_opacityOfUI(tester), 0);
  });

  testWidgets("AIUIView brings a reply's UI that first shows while the agent writes it in", (tester) async {
    await _pumpUI(tester, ['a']);
    await tester.pumpAndSettle();

    expect(_opacityOfUI(tester), 1);
  });

  testWidgets("AIUIEntrance brings a part that shows with the reply's UI in with it", (tester) async {
    await _pumpUI(tester, ['a']);

    expect(_opacityOfPart(tester, 'a'), 1);
  });

  testWidgets("AIUIEntrance brings a part an engine adds in the frame after the reply's UI shows in with it", (
    tester,
  ) async {
    final host = _host(engine: _AddingEngine());
    const document = AIUIDocument(format: AIUIFormat.openUI, content: 'a');
    host.receive([_Reply(document)]);

    await tester.pumpWidget(_ui(AIUIView(host: host, document: document, messageId: 'm1')));
    await tester.pump();

    expect(_opacityOfPart(tester, 'added'), 1);
  });

  testWidgets("AIUIEntrance starts a part that shows after the reply's UI clear", (tester) async {
    await _pumpUI(tester, ['a']);
    await tester.pumpAndSettle();

    await _pumpUI(tester, ['a', 'b']);

    expect(_opacityOfPart(tester, 'b'), 0);
  });

  testWidgets("AIUIEntrance brings a part that shows after the reply's UI in on its own", (tester) async {
    await _pumpUI(tester, ['a']);
    await tester.pumpAndSettle();

    await _pumpUI(tester, ['a', 'b']);
    await tester.pumpAndSettle();

    expect(_opacityOfPart(tester, 'b'), 1);
  });

  testWidgets('AIUIEntrance has parts that show at once follow one another', (tester) async {
    await _pumpUI(tester, ['a']);
    await tester.pumpAndSettle();

    await _pumpUI(tester, ['a', 'b', 'c']);
    // After the second part starts coming in, before the third does.
    await tester.pump(AIUICascade.step * 1.5);

    expect(_opacityOfPart(tester, 'b'), greaterThan(_opacityOfPart(tester, 'c')));
  });

  testWidgets('AIUIEntrance brings what a part holds in with the part', (tester) async {
    await _pumpUI(tester, ['a']);
    await tester.pumpAndSettle();

    await _pumpUI(tester, ['a', 'b>c']);

    expect(_opacityOfPart(tester, 'c'), 1);
  });

  testWidgets('AIUIEntrance fades a part in with animations disabled', (tester) async {
    await _pumpPartMidwayWithAnimationsDisabled(tester);

    expect(_opacityOfPart(tester, 'b'), inExclusiveRange(0, 1));
  });

  testWidgets("AIUIEntrance doesn't move a part with animations disabled", (tester) async {
    await _pumpPartMidwayWithAnimationsDisabled(tester);

    final transforms = tester.widgetList<Transform>(
      find.ancestor(of: find.text('b'), matching: find.byType(Transform)),
    );
    expect(transforms.map((transform) => transform.transform), everyElement(Matrix4.identity()));
  });

  testWidgets("AIUIEntrance doesn't blur a part with animations disabled", (tester) async {
    await _pumpPartMidwayWithAnimationsDisabled(tester);

    final filters = tester.widgetList<ImageFiltered>(
      find.ancestor(of: find.text('b'), matching: find.byType(ImageFiltered)),
    );
    expect(filters.map((filter) => filter.enabled), everyElement(isFalse));
  });

  testWidgets("AIUIEntrance shows a part outside a reply's UI at once", (tester) async {
    await tester.pumpWidget(const AIUIEntrance(child: Text('a', textDirection: TextDirection.ltr)));

    expect(_opacityOfPart(tester, 'a'), 1);
  });
}

// An engine that shows each line of an OpenUI document as a part, and a line
// `outer>inner` as a part holding another.
class _PartsEngine extends AIUIEngine {
  @override
  Widget? view(AIUIDocument document, String messageId) => Column(
    children: [
      for (final line in document.text!.split('\n'))
        switch (line.split('>')) {
          [final outer, final inner] => AIUIEntrance(
            key: ValueKey(outer),
            child: Column(
              children: [
                _text(outer),
                AIUIEntrance(child: _text(inner)),
              ],
            ),
          ),
          _ => AIUIEntrance(key: ValueKey(line), child: _text(line)),
        },
    ],
  );

  static Widget _text(String text) => Text(text, textDirection: TextDirection.ltr);
}

// An engine that shows a reply's UI, and adds a part to it after the frame it
// receives it in, as engines change what is on screen.
class _AddingEngine extends AIUIEngine {
  final _parts = ValueNotifier<List<String>>(const []);

  @override
  void receive(AIUIDocument document, String messageId) {
    _parts.value = [document.text!];
    SchedulerBinding.instance.addPostFrameCallback((_) => _parts.value = [..._parts.value, 'added']);
  }

  @override
  Widget? view(AIUIDocument document, String messageId) => ValueListenableBuilder(
    valueListenable: _parts,
    builder: (context, parts, _) => Column(
      children: [for (final part in parts) AIUIEntrance(key: ValueKey(part), child: _PartsEngine._text(part))],
    ),
  );

  @override
  void dispose() {
    _parts.dispose();
    super.dispose();
  }
}

class _Reply with AIMessage {
  _Reply(this.uiDocument);

  @override
  String get id => 'm1';

  @override
  AIMessageRole get role => AIMessageRole.assistant;

  @override
  String get text => '';

  @override
  final AIUIDocument uiDocument;
}

class _PartsRenderer extends AIUIRenderer {
  _PartsRenderer(this.engine);

  final AIUIEngine engine;

  @override
  AIUIFormat get format => AIUIFormat.openUI;

  @override
  AIUIEngine createEngine(AIUIHosting host) => engine;
}

AIUIHost _host({AIUIEngine? engine}) {
  final host = AIUIHost(renderers: [_PartsRenderer(engine ?? _PartsEngine())], send: (_) async {});
  addTearDown(host.dispose);
  return host;
}

Widget _ui(Widget view, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Directionality(textDirection: TextDirection.ltr, child: view),
);

Future<void> _pumpUI(WidgetTester tester, List<String> parts, {bool isStreaming = true, bool reduceMotion = false}) =>
    tester.pumpWidget(
      _ui(
        AIUIView(
          host: _host(),
          document: AIUIDocument(format: AIUIFormat.openUI, isStreaming: isStreaming, content: parts.join('\n')),
          messageId: 'm1',
        ),
        reduceMotion: reduceMotion,
      ),
    );

// Shows a part after the reply's UI with animations disabled, and stops
// partway through its fade.
Future<void> _pumpPartMidwayWithAnimationsDisabled(WidgetTester tester) async {
  await _pumpUI(tester, ['a'], reduceMotion: true);
  await tester.pumpAndSettle();
  await _pumpUI(tester, ['a', 'b'], reduceMotion: true);
  await tester.pump(AIUICascade.step);
}

double _opacityOfUI(WidgetTester tester) =>
    tester.widget<Opacity>(find.descendant(of: find.byType(AIUIView), matching: find.byType(Opacity)).first).opacity;

double _opacityOfPart(WidgetTester tester, String text) =>
    tester.widget<Opacity>(find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first).opacity;
