import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_tool_definition.dart';

void main() {
  group('AIToolDefinition', () {
    test('declares an empty object schema when the tool takes no arguments', () {
      const definition = AIToolDefinition(name: 'greetUser', description: 'Greet the user');

      expect(definition.parameters, {'type': 'object', 'properties': <String, Object?>{}});
    });

    test('rejects an empty name', () {
      expect(() => AIToolDefinition(name: '', description: 'Nameless'), throwsAssertionError);
    });

    group('toJson', () {
      test('emits every field, with camelCase keys', () {
        const definition = AIToolDefinition(
          name: 'openTicket',
          description: 'Open a CRM ticket',
          instructions: 'Use openTicket when the user asks about a ticket.',
          parameters: {
            'type': 'object',
            'properties': {
              'ticketId': {'type': 'string'},
            },
            'required': ['ticketId'],
          },
          showExternalSourcesIndicator: true,
        );

        expect(definition.toJson(), {
          'name': 'openTicket',
          'description': 'Open a CRM ticket',
          'instructions': 'Use openTicket when the user asks about a ticket.',
          'parameters': {
            'type': 'object',
            'properties': {
              'ticketId': {'type': 'string'},
            },
            'required': ['ticketId'],
          },
          'showExternalSourcesIndicator': true,
        });
      });

      test('omits instructions when there are none', () {
        const definition = AIToolDefinition(name: 'greetUser', description: 'Greet the user');

        expect(definition.toJson().containsKey('instructions'), isFalse);
      });

      test('emits showExternalSourcesIndicator even when false', () {
        // The backend reads it either way; leaving it out would make "no" and
        // "unspecified" the same request.
        const definition = AIToolDefinition(name: 'greetUser', description: 'Greet the user');

        expect(definition.toJson()['showExternalSourcesIndicator'], isFalse);
      });

      test('passes a nested parameters schema through unchanged', () {
        const schema = {
          'type': 'object',
          'properties': {
            'filter': {
              'type': 'object',
              'properties': {
                'tags': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
              },
            },
          },
        };
        const definition = AIToolDefinition(name: 'search', description: 'Search', parameters: schema);

        expect(definition.toJson()['parameters'], schema);
      });

      test('copies the parameters out rather than aliasing them', () {
        // A host that rewrites its payload before sending — adding
        // `additionalProperties`, say — must not also rewrite the definition it
        // registered.
        final schema = <String, Object?>{'type': 'object', 'properties': <String, Object?>{}};
        final definition = AIToolDefinition(name: 'search', description: 'Search', parameters: schema);

        final payload = definition.toJson();
        (payload['parameters']! as Map<String, Object?>)['additionalProperties'] = false;

        expect(definition.parameters, isNot(contains('additionalProperties')));
        expect(schema, isNot(contains('additionalProperties')));
      });

      test('copies one level only, which is what the payload documents', () {
        // Pinned rather than fixed: deep copying every payload costs more than
        // it is worth on a real schema. The doc on toJson says to build a new
        // map instead of editing a nested one, and this is what it is warning
        // about.
        final schema = <String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'query': <String, Object?>{'type': 'string'},
          },
        };
        final definition = AIToolDefinition(name: 'search', description: 'Search', parameters: schema);

        final payload = definition.toJson();
        final properties = (payload['parameters']! as Map<String, Object?>)['properties']! as Map<String, Object?>;
        properties['limit'] = <String, Object?>{'type': 'integer'};

        expect(definition.parameters['properties'], contains('limit'));
      });

      test('produces something jsonEncode accepts', () {
        // Cheap guard on the whole payload: the host hands this straight to an
        // HTTP body, where anything non-encodable surfaces as a throw far from
        // the definition that caused it.
        const definition = AIToolDefinition(
          name: 'greetUser',
          description: 'Greet the user',
          instructions: 'Greet on request.',
        );

        expect(jsonDecode(jsonEncode(definition.toJson())), definition.toJson());
      });
    });

    group('copyWith', () {
      const definition = AIToolDefinition(
        name: 'greetUser',
        description: 'Greet the user',
        instructions: 'Greet on request.',
      );

      test('replaces only what it is given', () {
        final copy = definition.copyWith(description: 'Say hello');

        expect(copy.toJson(), {
          ...definition.toJson(),
          'description': 'Say hello',
        });
      });

      test('keeps every field when given nothing', () {
        expect(definition.copyWith().toJson(), definition.toJson());
      });
    });
  });
}
