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

    test('ignores keys it does not recognise', () {
      final invocation = AIToolInvocation.tryParse({
        'tool': {'name': 'greetUser'},
        'created_at': '2026-09-09T00:00:00Z',
        'user': {'id': 'ada'},
      })!;

      expect(invocation.tool.name, 'greetUser');
    });

    group('rejects', () {
      test('a payload with no tool', () {
        expect(AIToolInvocation.tryParse({'cid': 'messaging:general'}), isNull);
      });

      test('a tool that is not an object', () {
        expect(AIToolInvocation.tryParse({'tool': 'openTicket'}), isNull);
      });

      test('a tool with no name', () {
        expect(
          AIToolInvocation.tryParse({
            'tool': {'description': 'Nameless'},
          }),
          isNull,
        );
      });

      test('a tool whose name is empty', () {
        expect(
          AIToolInvocation.tryParse({
            'tool': {'name': ''},
          }),
          isNull,
        );
      });

      test('an event of some other type', () {
        // A host that pipes every channel event through here gets nothing,
        // rather than a tool call built out of a message.
        final other = _event()..['type'] = 'message.new';

        expect(AIToolInvocation.tryParse(other), isNull);
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

      test('reads absent, null and empty-string arguments as none', () {
        expect(AIToolInvocation.tryParse(_event())!.args, isEmpty);
        expect(AIToolInvocation.tryParse(_event(args: {}))!.args, isEmpty);
        expect(
          AIToolInvocation.tryParse({
            'tool': const {'name': 'greetUser'},
            'args': null,
          })!.args,
          isEmpty,
        );
        expect(AIToolInvocation.tryParse(_event(args: '   '))!.args, isEmpty);
      });

      test('rejects arguments that are not an object', () {
        // Running the tool with its arguments silently dropped would do the
        // wrong thing — open the wrong ticket — which beats not running it.
        expect(AIToolInvocation.tryParse(_event(args: ['42'])), isNull);
        expect(AIToolInvocation.tryParse(_event(args: 42)), isNull);
      });

      test('rejects a string of arguments that is not JSON', () {
        expect(AIToolInvocation.tryParse(_event(args: 'ticketId=42')), isNull);
      });

      test('rejects a string of arguments that decodes to something else', () {
        expect(AIToolInvocation.tryParse(_event(args: '["42"]')), isNull);
      });
    });

    test('toString names the tool and the argument keys, but not their values', () {
      // Arguments carry whatever the user was talking about; a toString that
      // spills them into a host's logs is a privacy problem, not a convenience.
      final invocation = AIToolInvocation.tryParse(
        _event(args: {'ticketId': 'ACME-SECRET-42'}),
      )!;

      expect(invocation.toString(), contains('openTicket'));
      expect(invocation.toString(), contains('ticketId'));
      expect(invocation.toString(), isNot(contains('ACME-SECRET-42')));
    });
  });
}
