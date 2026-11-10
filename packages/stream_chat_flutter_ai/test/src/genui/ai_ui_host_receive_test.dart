import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'genui_test_doubles.dart';

void main() {
  test("AIUIHost.receive gives the engines each reply's UI, oldest first", () {
    final renderer = TestRenderer();
    testHost(renderers: [renderer]).receive([
      Reply('a1', uiDocument: openUI('a')),
      Reply('a2', text: 'Ohrid it is'),
      Reply('a3', uiDocument: openUI('b')),
    ]);

    expect(renderer.engines.single.received, [('a1', openUI('a')), ('a3', openUI('b'))]);
  });

  test("AIUIHost.receive asks for no reply's widget", () {
    final renderer = TestRenderer();
    testHost(renderers: [renderer]).receive([Reply('a1', uiDocument: openUI('a'))]);

    expect(renderer.engines.single.shown, isEmpty);
  });

  test("AIUIHost.receive tells the engine that had a reply's UI when another renderer reads it now", () {
    final openUIRenderer = TestRenderer();
    testHost(
        renderers: [
          openUIRenderer,
          TestRenderer(format: AIUIFormat.a2ui),
        ],
      )
      ..receive([Reply('a1', uiDocument: openUI('a'))])
      ..receive([
        Reply(
          'a1',
          uiDocument: const AIUIDocument(format: AIUIFormat.a2ui, content: '{}'),
        ),
      ]);

    expect(openUIRenderer.engines.single.removed, ['a1']);
  });

  test("AIUIHost.receive tells the engine that had a reply's UI when no renderer reads it now", () {
    final renderer = TestRenderer();
    testHost(renderers: [renderer])
      ..receive([Reply('a1', uiDocument: openUI('a'))])
      ..receive([Reply('a1', uiDocument: openUI('a', version: '2.0'))]);

    expect(renderer.engines.single.removed, ['a1']);
  });

  test("AIUIHost.receive doesn't tell the engine a reply is gone when its UI changes within it", () {
    final renderer = TestRenderer();
    testHost(renderers: [renderer])
      ..receive([Reply('a1', uiDocument: openUI('a'))])
      ..receive([Reply('a1', uiDocument: openUI('a, b'))]);

    expect(renderer.engines.single.removed, isEmpty);
  });

  test("AIUIHost.receive leaves out the UI of a person's message", () {
    final renderer = TestRenderer();
    testHost(renderers: [renderer]).receive([
      Reply('q1', role: AIMessageRole.user, uiDocument: openUI('q')),
      Reply('a1', uiDocument: openUI('a')),
    ]);

    expect(renderer.engines.single.received.map((received) => received.$1), ['a1']);
  });

  test('AIUIHost.receive gives each document to the renderer that reads it', () {
    final openUIRenderer = TestRenderer();
    final a2uiRenderer = TestRenderer(format: AIUIFormat.a2ui);
    testHost(renderers: [openUIRenderer, a2uiRenderer]).receive([
      Reply('a1', uiDocument: openUI('a')),
      Reply(
        'a2',
        uiDocument: const AIUIDocument(format: AIUIFormat.a2ui, content: '{}'),
      ),
      Reply(
        'a3',
        uiDocument: const AIUIDocument(format: AIUIFormat('cards'), content: ''),
      ),
    ]);

    expect(
      [
        for (final renderer in [openUIRenderer, a2uiRenderer]) renderer.engines.single.received.single.$1,
      ],
      ['a1', 'a2'],
    );
  });

  test("AIUIHost.receive gives a reply's UI again when it changes", () {
    final renderer = TestRenderer();
    testHost(renderers: [renderer])
      ..receive([Reply('a1', uiDocument: openUI('a'))])
      ..receive([Reply('a1', uiDocument: openUI('a, c'))]);

    expect(renderer.engines.single.received.last, ('a1', openUI('a, c')));
  });

  test("AIUIHost.receive gives a reply's UI when the reply arrives", () {
    final renderer = TestRenderer();
    testHost(renderers: [renderer])
      ..receive([Reply('a1', uiDocument: openUI('a'))])
      ..receive([Reply('a1', uiDocument: openUI('a')), Reply('a2', uiDocument: openUI('b'))]);

    expect(renderer.engines.single.received.last, ('a2', openUI('b')));
  });

  test("AIUIHost.receive doesn't give a reply's UI again when it hasn't changed", () {
    final renderer = TestRenderer();
    final replies = [Reply('a1', uiDocument: openUI('a'))];
    testHost(renderers: [renderer])
      ..receive(replies)
      ..receive(replies);

    expect(renderer.engines.single.received, hasLength(1));
  });

  test('AIUIHost.receive tells the engine when a reply is gone', () {
    final renderer = TestRenderer();
    testHost(renderers: [renderer])
      ..receive([Reply('a1', uiDocument: openUI('a')), Reply('a2', uiDocument: openUI('b'))])
      ..receive([Reply('a2', uiDocument: openUI('b'))]);

    expect(renderer.engines.single.removed, ['a1']);
  });

  test("AIUIHost.receive tells the engine when a reply's UI is gone", () {
    final renderer = TestRenderer();
    testHost(renderers: [renderer])
      ..receive([Reply('a1', uiDocument: openUI('a'))])
      ..receive([Reply('a1')]);

    expect(renderer.engines.single.removed, ['a1']);
  });

  test("AIUIHost.receive doesn't tell the engine again about a reply that stays gone", () {
    final renderer = TestRenderer();
    testHost(renderers: [renderer])
      ..receive([Reply('a1', uiDocument: openUI('a'))])
      ..receive([])
      ..receive([]);

    expect(renderer.engines.single.removed, ['a1']);
  });

  test("AIUIHost.receive forgets the state a gone reply's UI was left in", () {
    final host = testHost()
      ..receive([Reply('a1', uiDocument: openUI('a'))])
      ..setState('a1', {'picked': 'Ohrid'})
      ..receive([]);

    expect(host.state('a1'), isNull);
  });

  test('AIUIHost.receive gives UI that comes back again', () {
    final renderer = TestRenderer();
    testHost(renderers: [renderer])
      ..receive([Reply('a1', uiDocument: openUI('a'))])
      ..receive([Reply('a1')])
      ..receive([Reply('a1', uiDocument: openUI('a'))]);

    expect(renderer.engines.single.received.map((received) => received.$1), ['a1', 'a1']);
  });

  test('AIUIView shows a reply with the engine that received it', () {
    final renderer = TestRenderer();
    final host = testHost(renderers: [renderer])..receive([Reply('a1', uiDocument: openUI('a'))]);

    AIUIView(host: host, document: openUI('a'), messageId: 'a1');

    expect(renderer.engines.single.asked, ['receive a1', 'view a1']);
  });
}
