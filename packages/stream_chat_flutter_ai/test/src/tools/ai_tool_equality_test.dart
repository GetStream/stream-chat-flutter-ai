import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_tool_definition.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_tool_invocation.dart';

Map<String, Object?> _schema() => <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'filter': <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'tags': <String, Object?>{'type': 'array'},
      },
    },
  },
};

AIToolDefinition _definition({Map<String, Object?>? parameters}) => AIToolDefinition(
  name: 'openTicket',
  description: 'Open a CRM ticket',
  instructions: 'Use it when a ticket is mentioned.',
  parameters: parameters ?? _schema(),
);

void main() {
  group('AIToolDefinition equality', () {
    test('compares a nested schema by value, not by identity', () {
      // The case the old identity comparison got wrong: two definitions built
      // from separately-constructed but identical schemas.
      final a = _definition();
      final b = _definition();

      expect(identical(a.parameters, b.parameters), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('sees a difference nested two levels into the schema', () {
      final differing = _schema();
      ((differing['properties']! as Map)['filter']! as Map)['type'] = 'array';

      expect(_definition(), isNot(_definition(parameters: differing)));
    });

    test('every scalar field participates', () {
      final base = _definition();

      expect(base, isNot(base.copyWith(name: 'other')));
      expect(base, isNot(base.copyWith(description: 'other')));
      expect(base, isNot(base.copyWith(instructions: 'other')));
      expect(base, isNot(base.copyWith(showExternalSourcesIndicator: true)));
    });

    test('a copyWith that changes nothing is equal to the original', () {
      expect(_definition().copyWith(), _definition());
    });

    test('works in a set', () {
      expect({_definition(), _definition(), _definition().copyWith(name: 'other')}, hasLength(2));
    });
  });

  group('AIToolInvocation equality', () {
    test('two invocations parsed from the same payload are equal', () {
      // What a host actually does with this: assert on a parsed event.
      Map<String, Object?> payload() => <String, Object?>{
        'type': kClientToolInvocationEventType,
        'cid': 'messaging:general',
        'message_id': '8f3c',
        'tool': <String, Object?>{'name': 'openTicket', 'parameters': _schema()},
        'args': <String, Object?>{
          'ticketId': '42',
          'meta': <String, Object?>{'source': 'chat'},
        },
      };

      final a = AIToolInvocation.tryParse(payload())!;
      final b = AIToolInvocation.tryParse(payload())!;

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('sees a difference in a nested argument', () {
      AIToolInvocation parse(String source) => AIToolInvocation.tryParse(<String, Object?>{
        'tool': const <String, Object?>{'name': 'openTicket'},
        'args': <String, Object?>{
          'meta': <String, Object?>{'source': source},
        },
      })!;

      expect(parse('chat'), isNot(parse('email')));
    });

    test('the channel and message participate', () {
      const tool = AIInvokedTool(name: 'openTicket');

      expect(
        const AIToolInvocation(tool: tool, channelId: 'a'),
        isNot(const AIToolInvocation(tool: tool, channelId: 'b')),
      );
      expect(
        const AIToolInvocation(tool: tool, messageId: 'a'),
        isNot(const AIToolInvocation(tool: tool, messageId: 'b')),
      );
    });

    test('the invoked tool participates, compared by value', () {
      expect(
        const AIToolInvocation(tool: AIInvokedTool(name: 'a')),
        isNot(const AIToolInvocation(tool: AIInvokedTool(name: 'b'))),
      );
      expect(
        const AIToolInvocation(
          tool: AIInvokedTool(name: 'a', description: 'x'),
        ),
        const AIToolInvocation(
          tool: AIInvokedTool(name: 'a', description: 'x'),
        ),
      );
    });
  });

  group('AIInvokedTool equality', () {
    test('an absent echoed schema is not an empty one', () {
      // The asymmetry the type documents: absent means "the event echoed no
      // schema", which equality must not collapse into "declares no arguments".
      expect(
        const AIInvokedTool(name: 'openTicket'),
        isNot(const AIInvokedTool(name: 'openTicket', parameters: <String, Object?>{})),
      );
    });
  });
}
