import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';

void main() {
  test('two events with equal contexts are equal', () {
    expect(
      _event(
        context: {
          'pace': ['relaxed'],
        },
      ),
      _event(
        context: {
          'pace': ['relaxed'],
        },
      ),
    );
  });

  test('two events with equal contexts have the same hash code', () {
    final first = _event(
      context: {
        'pace': ['relaxed'],
      },
    );
    final second = _event(
      context: {
        'pace': ['relaxed'],
      },
    );

    expect(first.hashCode, second.hashCode);
  });

  test('events with different contexts differ', () {
    expect(
      _event(
        context: {
          'pace': ['packed'],
        },
      ),
      isNot(
        _event(
          context: {
            'pace': ['relaxed'],
          },
        ),
      ),
    );
  });

  test('events with different names differ', () {
    expect(_event(name: 'ask'), isNot(_event()));
  });

  test('events on different surfaces differ', () {
    expect(_event(surfaceId: 'other'), isNot(_event()));
  });

  test('events from different components differ', () {
    expect(_event(sourceComponentId: 'other'), isNot(_event()));
  });

  test('events with different words differ', () {
    expect(_event(userMessage: 'Something else'), isNot(_event()));
  });

  test("toString leaves out the context's values", () {
    final event = _event(context: {'email': 'person@example.com'});

    expect(event.toString(), isNot(contains('person@example.com')));
  });

  test("toString names the context's keys", () {
    final event = _event(context: {'email': 'person@example.com'});

    expect(event.toString(), contains('email'));
  });
}

A2UIActionEvent _event({
  String name = 'update_plan',
  String surfaceId = 'plan',
  String sourceComponentId = 'update',
  Map<String, Object?> context = const {},
  String userMessage = 'Update the plan',
}) => A2UIActionEvent(
  name: name,
  surfaceId: surfaceId,
  sourceComponentId: sourceComponentId,
  context: context,
  userMessage: userMessage,
);
