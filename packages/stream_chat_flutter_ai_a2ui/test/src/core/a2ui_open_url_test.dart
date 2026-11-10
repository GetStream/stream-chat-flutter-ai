import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import 'a2ui_test_surfaces.dart';

void main() {
  test("an action's openUrl opens an https link with the action's opener", () async {
    final opened = <Uri>[];
    final button = _linkButton('https://example.com/menu');

    await button.act('action', onOpenLink: opened.add);

    expect(opened, [Uri.parse('https://example.com/menu')]);
  });

  test("an action's openUrl opens an http link", () async {
    final opened = <Uri>[];
    final button = _linkButton('http://example.com/menu');

    await button.act('action', onOpenLink: opened.add);

    expect(opened, [Uri.parse('http://example.com/menu')]);
  });

  test("an action's openUrl opens the link the data model holds", () async {
    final opened = <Uri>[];
    final button = _linkButton(
      {'@path': '/link'},
      data: {'link': 'https://example.com/booked'},
    );

    await button.act('action', onOpenLink: opened.add);

    expect(opened, [Uri.parse('https://example.com/booked')]);
  });

  for (final link in ['mailto:ada@example.com', 'tel:+3590000000', 'javascript:alert(1)', 'file:///etc/passwd']) {
    test("an action's openUrl doesn't open $link", () async {
      final opened = <Uri>[];
      final button = _linkButton(link);

      await button.act('action', onOpenLink: opened.add);

      expect(opened, isEmpty);
    });
  }

  test("an action's openUrl reports a link it doesn't open", () async {
    final errors = <A2UIError>[];
    final button = _linkButton('mailto:ada@example.com', errors: errors);

    await button.act('action', onOpenLink: (_) {});
    await pumpEventQueue();

    expect(errors.single.message, contains("may not open a 'mailto' link"));
  });

  test("an action's openUrl doesn't open a mailto link with a host", () async {
    final opened = <Uri>[];
    final button = _linkButton('mailto://ada@example.com');

    await button.act('action', onOpenLink: opened.add);

    expect(opened, isEmpty);
  });

  test("an action's openUrl doesn't open a web link without a host", () async {
    final opened = <Uri>[];
    final button = _linkButton('https:/menu');

    await button.act('action', onOpenLink: opened.add);

    expect(opened, isEmpty);
  });

  test("an action's openUrl without an opener reports the link as not opened", () async {
    final errors = <A2UIError>[];
    final button = _linkButton('https://example.com/menu', errors: errors);

    await button.act('action');
    await pumpEventQueue();

    expect(errors.single.message, contains('could not open the link'));
  });

  test("an action opens its own link, not one in another component's property", () async {
    final opened = <Uri>[];
    final errors = <A2UIError>[];
    final surface = planSurface(
      errors: errors,
      components: [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['link_text', 'button'],
        },
        {
          'id': 'link_text',
          'component': 'Text',
          'text': {
            '@call': 'openUrl',
            'args': {'url': 'https://example.com/menu'},
          },
        },
        ..._linkButtonComponents('https://example.com/other', id: 'button'),
      ],
    );

    await rootChild(surface, 'button').act('action', onOpenLink: opened.add);

    expect(opened, [Uri.parse('https://example.com/other')]);
  });

  test("openUrl in a component's property is reported", () async {
    final errors = <A2UIError>[];
    planSurface(
      errors: errors,
      components: [
        {
          'id': 'root',
          'component': 'Text',
          'text': {
            '@call': 'openUrl',
            'args': {'url': 'https://example.com/menu'},
          },
        },
      ],
    );
    await pumpEventQueue();

    expect(errors.single.message, contains('requires user activation'));
  });

  test('the format functions use the locale of the catalogs', () {
    final processor = A2UIProcessor(catalogs: A2UICatalogs(locale: 'de-DE'));
    addTearDown(processor.dispose);
    processor.apply([
      createPlanSurface(data: {'price': 1234.5}),
      updatePlanComponents(
        components: [
          {
            'id': 'root',
            'component': 'Text',
            'text': {
              '@call': 'formatNumber',
              'args': {
                'value': {'@path': '/price'},
                'decimals': 1,
              },
            },
          },
        ],
      ),
    ]);

    expect(processor.surface('plan')!.root!.property('text'), '1.234,5');
  });

  test('the format functions use en-US by default', () {
    final root = planSurface(
      data: {'price': 1234.5},
      components: [
        {
          'id': 'root',
          'component': 'Text',
          'text': {
            '@call': 'formatNumber',
            'args': {
              'value': {'@path': '/price'},
              'decimals': 1,
            },
          },
        },
      ],
    ).root!;

    expect(root.property('text'), '1,234.5');
  });
}

List<Map<String, Object?>> _linkButtonComponents(Object url, {String id = 'root'}) {
  return [
    {
      'id': id,
      'component': 'Button',
      'child': '${id}_label',
      'action': {
        'functionCall': {
          '@call': 'openUrl',
          'args': {'url': url},
        },
      },
    },
    {'id': '${id}_label', 'component': 'Text', 'text': 'Open'},
  ];
}

// A surface whose root is a button opening [url].
A2UINode _linkButton(Object url, {Map<String, Object?> data = const {}, List<A2UIError>? errors}) {
  return planSurface(components: _linkButtonComponents(url), data: data, errors: errors).root!;
}
