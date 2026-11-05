import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_view.dart';

import '../a2ui_test_app.dart';

// A surface shown in a reply's UI comes in as the reply's UI does: what shows
// with it comes in with it, and a component that shows later while the agent
// is still writing comes in on its own.
void main() {
  testWidgets('a component that shows after the surface starts clear', (tester) async {
    final processor = await _pumpReply(tester, isStreaming: true);
    await tester.pumpAndSettle();

    processor.apply([_addSecond()]);
    await tester.pump();
    await tester.pump();

    expect(_opacityOf(tester, 'Second'), 0);
  });

  testWidgets('a component that shows after the surface comes in', (tester) async {
    final processor = await _pumpReply(tester, isStreaming: true);
    await tester.pumpAndSettle();

    processor.apply([_addSecond()]);
    await tester.pumpAndSettle();

    expect(_opacityOf(tester, 'Second'), 1);
  });

  testWidgets('a component that shows after the surface rises into its place', (tester) async {
    final processor = await _pumpReply(tester, isStreaming: true);
    await tester.pumpAndSettle();

    processor.apply([_addSecond()]);
    await tester.pump();
    await tester.pump(_partWayIn);
    final coming = tester.getTopLeft(find.text('Second')).dy;
    await tester.pumpAndSettle();

    expect(coming - tester.getTopLeft(find.text('Second')).dy, greaterThan(0));
  });

  testWidgets('what showed with the surface does not move when a component comes in', (tester) async {
    final processor = await _pumpReply(tester, isStreaming: true);
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.text('First'));

    processor.apply([_addSecond()]);
    await tester.pump();

    expect(tester.getTopLeft(find.text('First')), first);
  });

  testWidgets('a component that shows with a new one around it comes in with it', (tester) async {
    final processor = await _pumpReply(tester, isStreaming: true);
    await tester.pumpAndSettle();

    processor.apply([
      updateComponents([
        {
          'id': 'root',
          'component': 'Column',
          'children': ['first', 'card'],
        },
        {'id': 'card', 'component': 'Card', 'child': 'inner'},
        {'id': 'inner', 'component': 'Text', 'text': 'Inner'},
      ]),
    ]);
    await tester.pump();
    await tester.pump();

    expect(_ownOpacityOf(tester, 'Inner'), 1);
  });

  testWidgets('a reply written before it showed shows its components at once', (tester) async {
    await _pumpReply(tester, isStreaming: false);

    expect(_opacityOf(tester, 'First'), 1);
  });

  testWidgets('with animations off, a component that shows later only fades in', (tester) async {
    final processor = await _pumpReply(tester, isStreaming: true, disableAnimations: true);
    await tester.pumpAndSettle();
    processor.apply([_addSecond()]);
    await tester.pump();
    await tester.pump(_partWayIn);
    final coming = tester.getTopLeft(find.text('Second')).dy;
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Second')).dy, coming);
  });
}

// A moment while a component is still coming in. `stream_chat_flutter_ai`
// keeps the entrance's length private (a 300 ms fade, or 900 ms with motion),
// so this is a time well inside both.
const _partWayIn = Duration(milliseconds: 50);

// The message that adds the text Second under First.
String _addSecond() => updateComponents([
  {
    'id': 'root',
    'component': 'Column',
    'children': ['first', 'second'],
  },
  {'id': 'second', 'component': 'Text', 'text': 'Second'},
]);

// Shows a reply whose UI is a surface with a column holding the text First,
// through a host's view, as a conversation shows it.
Future<A2UIProcessor> _pumpReply(
  WidgetTester tester, {
  required bool isStreaming,
  bool disableAnimations = false,
}) async {
  final processor = A2UIProcessor(catalogs: A2UICatalogs());
  addTearDown(processor.dispose);
  processor.apply([
    createSurface([
      {
        'id': 'root',
        'component': 'Column',
        'children': ['first'],
      },
      {'id': 'first', 'component': 'Text', 'text': 'First'},
    ]),
  ]);
  final host = AIUIHost(renderers: [_SurfaceRenderer(processor.surface('s')!)], send: (action) async {});
  addTearDown(host.dispose);
  final document = AIUIDocument(format: AIUIFormat.a2ui, isStreaming: isStreaming, content: 'reply');
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [StreamTheme.light()]),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: AIUIView(host: host, document: document, messageId: 'm1'),
            ),
          ),
        ),
      ),
    ),
  );
  return processor;
}

// How opaque [text] shows: the product of the opacities around it.
double _opacityOf(WidgetTester tester, String text) {
  return tester
      .widgetList<Opacity>(find.ancestor(of: find.text(text), matching: find.byType(Opacity)))
      .fold(1, (opacity, widget) => opacity * widget.opacity);
}

// How opaque the entrance of [text]'s own component makes it.
double _ownOpacityOf(WidgetTester tester, String text) {
  return tester.widget<Opacity>(find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first).opacity;
}

// Shows one surface as a reply's UI.
class _SurfaceRenderer extends AIUIRenderer {
  _SurfaceRenderer(this.surface);

  final A2UISurface surface;

  @override
  AIUIFormat get format => AIUIFormat.a2ui;

  @override
  AIUIEngine createEngine(AIUIHosting host) => _SurfaceEngine(surface);
}

class _SurfaceEngine extends AIUIEngine {
  _SurfaceEngine(this.surface);

  final A2UISurface surface;

  @override
  Widget? view(AIUIDocument document, String messageId) => A2UISurfaceView(surface: surface);
}
