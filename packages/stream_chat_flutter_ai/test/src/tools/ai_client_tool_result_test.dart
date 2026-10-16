import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  group('AIClientToolResult', () {
    test('completed carries its output and summary', () {
      final result = AIClientToolResult.completed(const {'lat': 52.1}, summary: 'Shared approximate location');

      expect(result, isA<AIClientToolCompleted>());
      result as AIClientToolCompleted;
      expect(result.output, {'lat': 52.1});
      expect(result.summary, 'Shared approximate location');
    });

    test('failed carries its reason', () {
      const result = AIClientToolResult.failed('Location not shared');

      expect(result, const AIClientToolFailed('Location not shared'));
      expect((result as AIClientToolFailed).reason, 'Location not shared');
    });

    test('completed throws on output JSON cannot encode', () {
      expect(() => AIClientToolResult.completed(Object()), throwsA(isA<JsonUnsupportedObjectError>()));
    });

    test('completed stores a deeply unmodifiable copy of its output', () {
      final list = [1];
      final output = {'list': list};
      final result = AIClientToolCompleted(output);
      list.add(2);
      output['other'] = [];

      expect(result.output, {
        'list': [1],
      });
      expect(() => (result.output! as Map<String, Object?>)['x'] = 1, throwsUnsupportedError);
      expect(() => ((result.output! as Map<String, Object?>)['list']! as List<Object?>).add(3), throwsUnsupportedError);
    });

    group('toJson', () {
      test('a completed result has output and summary', () {
        expect(
          AIClientToolResult.completed(const {'lat': 52.1}, summary: 'Shared').toJson(
            toolCallId: 'call_1',
            clientId: 'install-1',
          ),
          {
            'tool_call_id': 'call_1',
            'client_id': 'install-1',
            'output': {'lat': 52.1},
            'summary': 'Shared',
          },
        );
      });

      test('a completed result without output still has an output key', () {
        final json = AIClientToolResult.completed(null).toJson();

        expect(json, {'output': null});
        expect(json.containsKey('output'), isTrue);
      });

      test('a failed result has failure and no output', () {
        expect(const AIClientToolResult.failed('Location not shared').toJson(toolCallId: 'call_1'), {
          'tool_call_id': 'call_1',
          'failure': 'Location not shared',
        });
      });
    });

    test('compares by value, output deeply', () {
      // Built separately, so equality can't come from canonicalized constants.
      Map<String, Object?> output() => {
        'a': [1, 2],
      };

      expect(
        AIClientToolResult.completed(output(), summary: 's'),
        AIClientToolResult.completed(output(), summary: 's'),
      );
      expect(AIClientToolResult.completed(output()).hashCode, AIClientToolResult.completed(output()).hashCode);
      expect(AIClientToolResult.completed(output()), isNot(AIClientToolResult.completed(output(), summary: 's')));
      expect(AIClientToolResult.completed(null), isNot(const AIClientToolResult.failed('x')));
    });

    test('toString leaves the output out', () {
      expect(
        AIClientToolResult.completed(const {'secret': 'home address'}).toString(),
        isNot(contains('home address')),
      );
    });
  });
}
