import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import 'a2ui_test_surfaces.dart';

// An obscured field only hides its text on screen. As in A2UI's own login
// form, what a person types into it is data like any other, which the agent
// that owns the surface reads when its action asks for it.
void main() {
  test("what a person typed into an obscured field is in an event's context", () async {
    final events = <A2UIActionEvent>[];
    final surface = _loginSurface(events: events);

    _node(surface, 'password').write('value', 'hunter2');
    await _node(surface, 'login').act('action');

    expect(events.single.context, {'user': 'ada', 'password': 'hunter2'});
  });

  test("what a person typed into an obscured field is in an event's userMessage", () async {
    final events = <A2UIActionEvent>[];
    final surface = _loginSurface(events: events);

    _node(surface, 'password').write('value', 'hunter2');
    await _node(surface, 'login').act('action');

    expect(events.single.userMessage, 'Log in as ada with hunter2');
  });

  test('a function an action sends to the agent carries what a person typed into an obscured field', () async {
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
    expect(call['args'], {'user': 'ada', 'password': 'hunter2'});
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
