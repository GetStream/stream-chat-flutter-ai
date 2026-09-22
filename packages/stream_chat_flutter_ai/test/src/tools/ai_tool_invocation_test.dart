import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_tool_invocation.dart';

/// The event shape the AI agent actually emits, as documented.
Map<String, Object?> _event({Object? tool, Object? args, bool withType = true}) => <String, Object?>{
  if (withType) 'type': kClientToolInvocationEventType,
  'cid': 'messaging:general',
  'message_id': '8f3c',
  'tool': tool ?? {'name': 'openTicket'},
  if (args != null) 'args': args,
};

/// Runs [body] with [FlutterError.onError] collecting instead of failing, and
/// returns what it collected.
///
/// The override is lifted before returning, deliberately: left in place for the
/// rest of the test it would also intercept the test framework's own failure
/// reporting, turning a failed expectation below into a ten-minute hang.
List<FlutterErrorDetails> _collectingErrors(void Function() body) {
  final reported = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = reported.add;
  try {
    body();
  } finally {
    FlutterError.onError = previousOnError;
  }
  return reported;
}

void main() {
  group('AIToolInvocation.tryParse', () {
    test('parses a full invocation event', () {
      final invocation = AIToolInvocation.tryParse(
        _event(args: {'ticketId': '42'}),
      )!;

      expect(invocation.tool.name, 'openTicket');
      expect(invocation.channelId, 'messaging:general');
      expect(invocation.messageId, '8f3c');
      expect(invocation.args, {'ticketId': '42'});
    });

    test('keeps the tool declaration the event echoes back', () {
      // The server's copy, which is all a host has when the invoked tool is one
      // this build no longer registers.
      final invocation = AIToolInvocation.tryParse(
        _event(
          tool: {
            'name': 'openTicket',
            'description': 'Open a CRM ticket',
            'instructions': 'Use it when a ticket is mentioned.',
            'parameters': {'type': 'object'},
          },
        ),
      )!;

      expect(invocation.tool.description, 'Open a CRM ticket');
      expect(invocation.tool.instructions, 'Use it when a ticket is mentioned.');
      expect(invocation.tool.parameters, {'type': 'object'});
    });

    test('leaves the echoed declaration null when the event omits it', () {
      // Absent here means "the event echoed no schema", where an empty schema
      // on AIToolDefinition means "this tool declares no arguments". Collapsing
      // the two would lose that.
      final invocation = AIToolInvocation.tryParse({
        'tool': {'name': 'greetUser'},
      })!;

      expect(invocation.tool.description, isNull);
      expect(invocation.tool.instructions, isNull);
      expect(invocation.tool.parameters, isNull);
    });

    test('leaves an unreadable echoed schema null rather than sinking the parse', () {
      // Unlike args, the echoed schema never drives execution, so a malformed
      // one costs the host a label rather than the whole invocation.
      final invocation = AIToolInvocation.tryParse(
        _event(tool: {'name': 'greetUser', 'parameters': 'nope'}),
      )!;

      expect(invocation.tool.parameters, isNull);
    });

    test('leaves the channel and message null when the event omits them', () {
      final invocation = AIToolInvocation.tryParse({
        'tool': {'name': 'greetUser'},
      })!;

      expect(invocation.channelId, isNull);
      expect(invocation.messageId, isNull);
    });

    test('accepts channel_id and messageId as aliases', () {
      final invocation = AIToolInvocation.tryParse({
        'channel_id': 'messaging:other',
        'messageId': 'abc',
        'tool': {'name': 'greetUser'},
      })!;

      expect(invocation.channelId, 'messaging:other');
      expect(invocation.messageId, 'abc');
    });

    test('prefers the wire spelling when both aliases are present', () {
      final invocation = AIToolInvocation.tryParse({
        'cid': 'messaging:general',
        'channel_id': 'messaging:other',
        'message_id': '8f3c',
        'messageId': 'abc',
        'tool': {'name': 'greetUser'},
      })!;

      expect(invocation.channelId, 'messaging:general');
      expect(invocation.messageId, '8f3c');
    });

    test('ignores keys it does not recognise', () {
      final invocation = AIToolInvocation.tryParse({
        'tool': {'name': 'greetUser'},
        'created_at': '2026-09-09T00:00:00Z',
        'user': {'id': 'ada'},
      })!;

      expect(invocation.tool.name, 'greetUser');
    });

    group('rejects quietly', () {
      // A payload that never claimed to be an invocation is not reported: a
      // host piping every channel event through here would drown in it.

      test('a payload with no tool and no type', () {
        final reported = _collectingErrors(() {
          expect(AIToolInvocation.tryParse({'cid': 'messaging:general'}), isNull);
        });

        expect(reported, isEmpty);
      });

      test('a tool that is not an object', () {
        final reported = _collectingErrors(() {
          expect(AIToolInvocation.tryParse({'tool': 'openTicket'}), isNull);
        });

        expect(reported, isEmpty);
      });

      test('an event of some other type, even one the caller vouched for', () {
        // `isInvocationEvent` says the stream was filtered, not that a payload
        // naming a different event should be read as an invocation anyway.
        final other = _event()..['type'] = 'message.new';

        final reported = _collectingErrors(() {
          expect(AIToolInvocation.tryParse(other, isInvocationEvent: true), isNull);
        });

        expect(reported, isEmpty);
      });

      test('an event of some other type', () {
        // A host that pipes every channel event through here gets nothing,
        // rather than a tool call built out of a message.
        final other = _event()..['type'] = 'message.new';

        final reported = _collectingErrors(() {
          expect(AIToolInvocation.tryParse(other), isNull);
        });

        expect(reported, isEmpty);
      });
    });

    group('rejects and reports', () {
      // A payload that announced itself as an invocation and then failed to
      // parse means a tool the agent asked for will not run, and the agent is
      // never told. Silence there is invisible in debug and release alike.

      test('a typed payload with no tool object', () {
        final reported = _collectingErrors(() {
          expect(
            AIToolInvocation.tryParse({'type': kClientToolInvocationEventType, 'cid': 'messaging:general'}),
            isNull,
          );
        });

        expect(reported, hasLength(1));
        expect(reported.single.library, 'stream_chat_flutter_ai');
        expect(reported.single.exception, isFormatException);
      });

      test('a payload with no tool object that the caller vouched for', () {
        // The documented path: `type` is a field on `Event`, so it never
        // reaches the map, and without `isInvocationEvent` a renamed `tool` key
        // would vanish with no report at all.
        final reported = _collectingErrors(() {
          expect(
            AIToolInvocation.tryParse({'cid': 'messaging:general'}, isInvocationEvent: true),
            isNull,
          );
        });

        expect(reported, hasLength(1));
        expect(reported.single.exception, isFormatException);
      });

      test('a tool with no name', () {
        final reported = _collectingErrors(() {
          expect(
            AIToolInvocation.tryParse({
              'tool': {'description': 'Nameless'},
            }),
            isNull,
          );
        });

        expect(reported, hasLength(1));
      });

      test('a tool whose name is empty', () {
        final reported = _collectingErrors(() {
          expect(
            AIToolInvocation.tryParse({
              'tool': {'name': ''},
            }),
            isNull,
          );
        });

        expect(reported, hasLength(1));
      });

      test('a tool whose name is not a string', () {
        final reported = _collectingErrors(() {
          expect(
            AIToolInvocation.tryParse({
              'tool': {'name': 42},
            }),
            isNull,
          );
        });

        expect(reported, hasLength(1));
      });

      test('names the payload keys but not their values', () {
        // Same privacy rule as toString: the values are whatever the user was
        // talking about.
        final reported = _collectingErrors(() {
          AIToolInvocation.tryParse({
            'tool': {'name': ''},
            'cid': 'messaging:ACME-SECRET-42',
          });
        });

        final description = reported.single.context.toString();
        expect(description, contains('cid'));
        expect(description, isNot(contains('ACME-SECRET-42')));
      });
    });

    test('parses an event with no type at all', () {
      // The `channel.on(...)` path: the type is a field on the event object,
      // not part of the payload the host forwards.
      final invocation = AIToolInvocation.tryParse(_event(withType: false));

      expect(invocation?.tool.name, 'openTicket');
    });

    group('args', () {
      test('decodes arguments delivered as a JSON string', () {
        // What the Anthropic and OpenAI tool-calling APIs emit.
        final invocation = AIToolInvocation.tryParse(_event(args: '{"ticketId": "42"}'))!;

        expect(invocation.args, {'ticketId': '42'});
      });

      test('accepts `arguments` as an alias for `args`', () {
        final invocation = AIToolInvocation.tryParse({
          'tool': {'name': 'openTicket'},
          'arguments': {'ticketId': '42'},
        })!;

        expect(invocation.args, {'ticketId': '42'});
      });

      test('reads absent, null and empty-object arguments as none', () {
        expect(AIToolInvocation.tryParse(_event())!.args, isEmpty);
        expect(AIToolInvocation.tryParse(_event(args: {}))!.args, isEmpty);
        expect(
          AIToolInvocation.tryParse({
            'tool': const {'name': 'greetUser'},
            'args': null,
          })!.args,
          isEmpty,
        );
      });

      test('is unmodifiable whether or not the event carried arguments', () {
        // One contract rather than one per input shape: a host that writes to
        // `args` must not succeed on an invocation that carried some and throw
        // on the next one that carried none.
        final withArgs = AIToolInvocation.tryParse(_event(args: {'ticketId': '42'}))!;
        final withoutArgs = AIToolInvocation.tryParse(_event())!;

        expect(() => withArgs.args['x'] = 1, throwsUnsupportedError);
        expect(() => withoutArgs.args['x'] = 1, throwsUnsupportedError);
      });

      test('rejects arguments that are not an object', () {
        // Running the tool with its arguments silently dropped would do the
        // wrong thing — open the wrong ticket — which beats not running it.
        _collectingErrors(() {
          expect(AIToolInvocation.tryParse(_event(args: ['42'])), isNull);
          expect(AIToolInvocation.tryParse(_event(args: 42)), isNull);
        });
      });

      test('rejects a string of arguments that is not JSON', () {
        _collectingErrors(() {
          expect(AIToolInvocation.tryParse(_event(args: 'ticketId=42')), isNull);
        });
      });

      test('rejects a string of arguments that decodes to something else', () {
        _collectingErrors(() {
          expect(AIToolInvocation.tryParse(_event(args: '["42"]')), isNull);
        });
      });

      test('rejects an empty string of arguments', () {
        // No exemption for `""`: it is not a readable JSON object, and a tool
        // that takes none omits the key or sends `{}`. An empty string is far
        // more likely an argument stream that was cut short, and running on
        // what survived is the wrong-ticket failure this parser refuses.
        final reported = _collectingErrors(() {
          expect(AIToolInvocation.tryParse(_event(args: '')), isNull);
          expect(AIToolInvocation.tryParse(_event(args: '   ')), isNull);
        });

        expect(reported, hasLength(2));
      });
    });

    test('toString names the tool and the argument keys, but not their values', () {
      // Arguments carry whatever the user was talking about; a toString that
      // spills them into a host's logs is a privacy problem, not a convenience.
      final invocation = AIToolInvocation.tryParse(
        _event(
          args: {
            'ticketId': 'ACME-SECRET-42',
            'count': 7,
            'nested': {'token': 'hunter2'},
          },
        ),
      )!;

      expect(invocation.toString(), contains('openTicket'));
      expect(invocation.toString(), contains('ticketId'));
      expect(invocation.toString(), contains('nested'));
      expect(invocation.toString(), isNot(contains('ACME-SECRET-42')));
      expect(invocation.toString(), isNot(contains('hunter2')));
      expect(invocation.toString(), isNot(contains('7')));
    });
  });
}
