import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'genui_test_doubles.dart';

void main() {
  test("AIUIHost.canShow reads a renderer's format written without a version", () {
    expect(testHost().canShow(openUI('root = Card([])')), isTrue);
  });

  test("AIUIHost.canShow reads a version the format's renderer supports", () {
    expect(testHost().canShow(openUI('root = Card([])', version: '1.2.0')), isTrue);
  });

  test("AIUIHost.canShow doesn't read a version no renderer of the format supports", () {
    expect(testHost().canShow(openUI('root = Card([])', version: '2.0.0')), isFalse);
  });

  test("AIUIHost.canShow doesn't read a format no renderer reads", () {
    expect(testHost().canShow(const AIUIDocument(format: AIUIFormat.a2ui, content: '{}')), isFalse);
  });

  test('AIUIHost.canShow reads a format whose engine builds nothing for the document', () {
    const nothing = AIUIDocument(format: AIUIFormat.openUI, content: <Object?>[]);
    final host = testHost();

    expect(host.canShow(nothing), isTrue);
    expect(AIUIView(host: host, document: nothing, messageId: 'm1').canShow, isFalse);
  });

  test("AIUIView shows a renderer's format written without a version", () {
    expect(AIUIView(host: testHost(), document: openUI('root = Card([])'), messageId: 'm1').canShow, isTrue);
  });

  test("AIUIView shows a version the format's renderer supports", () {
    final view = AIUIView(
      host: testHost(),
      document: openUI('root = Card([])', version: '1.2.0'),
      messageId: 'm1',
    );

    expect(view.canShow, isTrue);
  });

  test("AIUIView can't show a version no renderer of the format supports", () {
    final view = AIUIView(
      host: testHost(),
      document: openUI('root = Card([])', version: '2.0.0'),
      messageId: 'm1',
    );

    expect(view.canShow, isFalse);
  });

  test("AIUIView can't show a format no renderer reads", () {
    final host = testHost();

    final view = AIUIView(
      host: host,
      document: const AIUIDocument(format: AIUIFormat.a2ui, content: '{}'),
      messageId: 'm1',
    );

    expect(view.canShow, isFalse);
  });

  test('AIUIHost makes one engine per renderer for the whole conversation', () {
    final renderer = TestRenderer();
    final host = testHost(renderers: [renderer]);

    AIUIView(host: host, document: openUI('root = Card([a])'), messageId: 'm1');
    AIUIView(host: host, document: openUI('root = Card([b])'), messageId: 'm2');

    expect(renderer.engines, hasLength(1));
  });

  test("AIUIHost makes its renderers' engines for itself", () {
    final renderer = TestRenderer();
    final host = testHost(renderers: [renderer]);

    AIUIView(host: host, document: openUI('root = Card([a])'), messageId: 'm1');

    expect(renderer.engines.single.host, same(host));
  });

  test('AIUIHost asks the engine for each reply it shows', () {
    final renderer = TestRenderer();
    final host = testHost(renderers: [renderer]);

    AIUIView(host: host, document: openUI('root = Card([a])'), messageId: 'm1');
    AIUIView(host: host, document: openUI('root = Card([b])'), messageId: 'm2');

    expect(renderer.engines.single.shown, [('m1', openUI('root = Card([a])')), ('m2', openUI('root = Card([b])'))]);
  });

  test('AIUIHost shows each version with the first renderer of its format that reads it', () {
    final first = TestRenderer();
    final second = TestRenderer(versions: '2.');
    final host = testHost(renderers: [first, second]);

    AIUIView(
      host: host,
      document: openUI('a', version: '1.0.0'),
      messageId: 'm1',
    );
    AIUIView(
      host: host,
      document: openUI('b', version: '2.0.0'),
      messageId: 'm2',
    );
    AIUIView(host: host, document: openUI('c'), messageId: 'm3');

    expect(
      [
        for (final renderer in [first, second]) renderer.engines.single.shown.map((shown) => shown.$1),
      ],
      [
        ['m1', 'm3'],
        ['m2'],
      ],
    );
  });

  test('AIUIHost asks its renderers in the order they are listed', () {
    final cards = TestRenderer(format: const AIUIFormat('cards'));
    final a2ui = TestRenderer(format: AIUIFormat.a2ui);
    final host = testHost(renderers: [TestRenderer(), a2ui, cards]);

    AIUIView(
      host: host,
      document: const AIUIDocument(format: AIUIFormat('cards'), content: 'x'),
      messageId: 'm1',
    );
    AIUIView(
      host: host,
      document: const AIUIDocument(format: AIUIFormat.a2ui, content: '{}'),
      messageId: 'm2',
    );

    expect((cards.engines.single.shown.single.$1, a2ui.engines.single.shown.single.$1), ('m1', 'm2'));
  });

  test("AIUIHost doesn't make a renderer's engine until the renderer shows something", () {
    final openUIRenderer = TestRenderer();
    final host = testHost(
      renderers: [
        openUIRenderer,
        TestRenderer(format: AIUIFormat.a2ui),
      ],
    );

    AIUIView(
      host: host,
      document: const AIUIDocument(format: AIUIFormat.a2ui, content: '{}'),
      messageId: 'm1',
    );

    expect(openUIRenderer.engines, isEmpty);
  });

  test("AIUIView can't show a reply's UI that its renderer reads but shows nothing of its own for", () {
    // The test engine shows nothing for content that isn't text.
    const nothing = AIUIDocument(format: AIUIFormat.openUI, content: <Object?>[]);

    final view = AIUIView(host: testHost(), document: nothing, messageId: 'm1');

    expect(view.canShow, isFalse);
  });

  testWidgets("AIUIView asks for the reply's widget once each time it is made, not each time it builds", (
    tester,
  ) async {
    final renderer = TestRenderer();
    final view = AIUIView(
      host: testHost(renderers: [renderer]),
      document: openUI('Ohrid'),
      messageId: 'm1',
    );

    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: view));
    await tester.pumpWidget(Directionality(textDirection: TextDirection.rtl, child: view));

    expect(renderer.engines.single.shown, hasLength(1));
  });

  test("AIUIHost asks the engine once for each of a reply's documents", () {
    final renderer = TestRenderer();
    final host = testHost(renderers: [renderer]);

    final first = AIUIView(host: host, document: openUI('Ohrid'), messageId: 'm1');
    final again = AIUIView(host: host, document: openUI('Ohrid'), messageId: 'm1');
    AIUIView(host: host, document: openUI('Ohrid and Struga'), messageId: 'm1');

    expect(renderer.engines.single.shown, [('m1', openUI('Ohrid')), ('m1', openUI('Ohrid and Struga'))]);
    expect(again.canShow, first.canShow);
  });

  test('AIUIHost asks the engine again for a reply that left the conversation and came back', () {
    final renderer = TestRenderer();
    final host = testHost(renderers: [renderer]);
    final reply = Reply('m1', uiDocument: openUI('Ohrid'));

    host.receive([reply]);
    AIUIView(host: host, document: openUI('Ohrid'), messageId: 'm1');
    host
      ..receive([])
      ..receive([reply]);
    AIUIView(host: host, document: openUI('Ohrid'), messageId: 'm1');

    expect(renderer.engines.single.shown, hasLength(2));
  });

  test('AIUIView shows nothing and makes no engine once the host is disposed', () {
    final renderer = TestRenderer();
    final host = AIUIHost(renderers: [renderer], send: (_) async {})..dispose();

    final view = AIUIView(host: host, document: openUI('Ohrid'), messageId: 'm1');

    expect(view.canShow, isFalse);
    expect(renderer.engines, isEmpty);
  });

  test('AIUIHost.dispose disposes the engines its renderers made', () {
    final renderer = TestRenderer();
    final host = AIUIHost(renderers: [renderer], send: (_) async {});
    AIUIView(host: host, document: openUI('root = Card([])'), messageId: 'm1');

    host.dispose();

    expect(renderer.engines.single.isDisposed, isTrue);
  });
}
