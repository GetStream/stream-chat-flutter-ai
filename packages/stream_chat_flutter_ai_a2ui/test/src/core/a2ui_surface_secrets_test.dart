import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import 'a2ui_test_surfaces.dart';

void main() {
  test("what a person typed into an obscured field isn't in an event's context", () async {
    final events = <A2UIActionEvent>[];
    final surface = _loginSurface(events: events);

    _node(surface, 'password').write('value', 'hunter2');
    await _node(surface, 'login').act('action');

    expect(events.single.context['password'], isNull);
  });

  test("what a person typed into an obscured field isn't in an event's userMessage", () async {
    final events = <A2UIActionEvent>[];
    final surface = _loginSurface(events: events);

    _node(surface, 'password').write('value', 'hunter2');
    await _node(surface, 'login').act('action');

    expect(events.single.userMessage, 'Log in as ada with ');
  });

  test("what a person typed into a field that isn't obscured is in an event's context", () async {
    final events = <A2UIActionEvent>[];
    final surface = _loginSurface(events: events);

    _node(surface, 'password').write('value', 'hunter2');
    await _node(surface, 'login').act('action');

    expect(events.single.context['user'], 'ada');
  });

  test('an event still reaches onAction once a person typed a secret', () async {
    final events = <A2UIActionEvent>[];
    final surface = _loginSurface(events: events);

    _node(surface, 'password').write('value', 'hunter2');
    await _node(surface, 'login').act('action');

    expect(events.single.name, 'log_in');
  });

  test("what a person typed into an obscured field of a template's item isn't in an event", () async {
    final events = <A2UIActionEvent>[];
    final surface = planSurface(
      events: events,
      data: {
        'guests': [
          {'name': 'Ada'},
        ],
      },
      components: [
        {
          'id': 'root',
          'component': 'Column',
          'children': {'componentId': 'guest', 'path': '/guests'},
        },
        {
          'id': 'guest',
          'component': 'Column',
          'children': ['pin', 'save'],
        },
        {
          'id': 'pin',
          'component': 'TextField',
          'label': 'PIN',
          'variant': 'obscured',
          'value': {'@path': 'pin'},
        },
        {
          'id': 'save',
          'component': 'Button',
          'child': 'save_label',
          'action': {
            'event': {
              'name': 'save',
              'context': {
                'pin': {'@path': 'pin'},
              },
            },
          },
        },
        {'id': 'save_label', 'component': 'Text', 'text': 'Save'},
      ],
    );
    final guest = surface.root!.children('children').single;
    final [pin, save] = guest.children('children');

    pin.write('value', '1234');
    await save.act('action');

    expect(events.single.context['pin'], isNull);
  });

  test('a secret stays in the data model, for the field that shows it', () {
    final surface = _loginSurface();

    _node(surface, 'password').write('value', 'hunter2');

    expect(surface.read('/password'), 'hunter2');
  });

  test('readWithoutSecrets leaves out what a person typed into an obscured field', () {
    final surface = _loginSurface();

    _node(surface, 'password').write('value', 'hunter2');

    expect(surface.readWithoutSecrets('/password'), isNull);
  });

  test('readWithoutSecrets reads the rest of the data model', () {
    final surface = _loginSurface();

    _node(surface, 'password').write('value', 'hunter2');

    expect(surface.readWithoutSecrets('/user'), 'ada');
  });

  test("readWithoutSecrets doesn't change the data model", () {
    final surface = _loginSurface();
    _node(surface, 'password').write('value', 'hunter2');

    surface.readWithoutSecrets('/');

    expect(surface.read('/password'), 'hunter2');
  });

  test("a field whose variant is bound isn't taken for an obscured one", () async {
    final events = <A2UIActionEvent>[];
    final surface = _loginSurface(
      events: events,
      passwordVariant: {'@path': '/variant'},
      data: {'user': 'ada', 'variant': 'obscured'},
    );

    _node(surface, 'password').write('value', 'hunter2');
    await _node(surface, 'login').act('action');

    expect(events.single.context['password'], 'hunter2');
  });

  test('a value the agent put in an obscured field before anyone typed is in the context', () async {
    final events = <A2UIActionEvent>[];
    final surface = _loginSurface(events: events, data: {'user': 'ada', 'password': 'prefilled'});

    await _node(surface, 'login').act('action');

    expect(events.single.context['password'], 'prefilled');
  });

  test("a function an action calls doesn't read the secret", () async {
    final opened = <Uri>[];
    final surface = _loginSurface(
      loginAction: {
        'functionCall': {
          '@call': 'openUrl',
          'args': {
            'url': {
              '@call': 'formatString',
              'args': {'value': r'https://example.com/${/password}'},
            },
          },
        },
      },
    );

    _node(surface, 'password').write('value', 'hunter2');
    await _node(surface, 'login').act('action', onOpenLink: opened.add);

    expect(opened.single, Uri.parse('https://example.com/'));
  });

  test("a function an action sends to the agent doesn't carry the secret", () async {
    final sent = <Map<String, Object?>>[];
    final processor = A2UIProcessor.debug(catalogs: A2UICatalogs(), onOutbound: sent.add);
    addTearDown(processor.dispose);
    final surface = _loginSurface(
      processor: processor,
      loginAction: {
        'functionCall': {
          '@call': 'lookUpAccount',
          'args': {
            'user': {'@path': '/user'},
            'password': {'@path': '/password'},
          },
        },
      },
    );

    _node(surface, 'password').write('value', 'hunter2');
    unawaited(_node(surface, 'login').act('action'));
    await pumpEventQueue();

    final call = (sent.single['callAgentFunction']! as Map<String, Object?>)['callFunction']! as Map<String, Object?>;
    expect(call['args'], {'user': 'ada', 'password': null});
  });

  test('a function an action sends to the agent that fails is reported as without a secret', () async {
    Future<List<A2UIError>> errorsOf({required bool typed}) async {
      final errors = <A2UIError>[];
      final surface = _loginSurface(
        errors: errors,
        loginAction: {
          'functionCall': {'@call': 'lookUpAccount', 'args': <String, Object?>{}},
        },
      );
      if (typed) _node(surface, 'password').write('value', 'hunter2');
      await _node(surface, 'login').act('action');
      await pumpEventQueue();
      return errors;
    }

    final withSecret = await errorsOf(typed: true);

    expect(withSecret, await errorsOf(typed: false));
    expect(withSecret.single.code, A2UIErrorCode.executionError);
  });

  test("an agent's failed answer to an action's function is reported as without a secret", () async {
    Future<List<A2UIError>> errorsOf({required bool typed}) async {
      final sent = <Map<String, Object?>>[];
      final errors = <A2UIError>[];
      final processor = A2UIProcessor.debug(catalogs: A2UICatalogs(), onError: errors.add, onOutbound: sent.add);
      addTearDown(processor.dispose);
      final surface = _loginSurface(
        processor: processor,
        loginAction: {
          'functionCall': {'@call': 'lookUpAccount', 'args': <String, Object?>{}},
        },
      );
      if (typed) _node(surface, 'password').write('value', 'hunter2');
      final acted = _node(surface, 'login').act('action');
      await pumpEventQueue();
      final call = sent.single['callAgentFunction']! as Map<String, Object?>;
      processor.apply([
        jsonEncode({
          'version': '1.0',
          'agentFunctionResponse': {
            'functionCallId': call['functionCallId'],
            'error': {'code': 'NOT_FOUND', 'message': 'No such account.'},
          },
        }),
      ]);
      await acted;
      await pumpEventQueue();
      return errors;
    }

    final withSecret = await errorsOf(typed: true);

    expect(withSecret.single.surfaceId, isNull);
    expect(withSecret.single.code, (await errorsOf(typed: false)).single.code);
  });
}

// A login form, on [processor] when given: a user name field, a password field whose variant is
// [passwordVariant], and a button with [loginAction].
A2UISurface _loginSurface({
  List<A2UIActionEvent>? events,
  List<A2UIError>? errors,
  A2UIProcessor? processor,
  Object passwordVariant = 'obscured',
  Map<String, Object?> data = const {'user': 'ada'},
  Map<String, Object?>? loginAction,
}) {
  return planSurface(
    events: events,
    errors: errors,
    processor: processor,
    data: data,
    components: [
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
        'variant': passwordVariant,
        'value': {'@path': '/password'},
      },
      {
        'id': 'login',
        'component': 'Button',
        'child': 'login_label',
        'action':
            loginAction ??
            {
              'event': {
                'name': 'log_in',
                'userMessage': {
                  '@call': 'formatString',
                  'args': {'value': r'Log in as ${/user} with ${/password}'},
                },
                'context': {
                  'user': {'@path': '/user'},
                  'password': {'@path': '/password'},
                },
              },
            },
      },
      {'id': 'login_label', 'component': 'Text', 'text': 'Log in'},
    ],
  );
}

A2UINode _node(A2UISurface surface, String id) => rootChild(surface, id);
