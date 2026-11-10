import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_action.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_format.dart';

import 'genui_fixtures.dart';

void main() {
  test("AIUIAction.toJson writes the JSON an agent's backend reads", () {
    final action = _askAbout();

    final json = overTheWire(action.toJson());

    expect(json, genuiFixture('action_ask_about.json')[AIUIAction.customDataKey]);
  });

  test("AIUIAction.toCustomData puts the action under the message's ai_ui_action field", () {
    final action = _askAbout();

    final customData = overTheWire(action.toCustomData());

    expect(customData, genuiFixture('action_ask_about.json'));
  });

  test("AIUIAction.toCustomData writes the spec's A2UI form submission", () {
    const action = AIUIAction(
      messageId: '4f1c',
      format: AIUIFormat.a2ui,
      name: 'update_plan',
      label: 'Update the plan',
      payload: {
        'surfaceId': 'ohrid-weekend',
        'sourceComponentId': 'update',
        'context': {
          'pace': ['packed'],
          'interests': ['food', 'swimming'],
        },
      },
    );

    final customData = overTheWire(action.toCustomData());

    expect(customData, genuiFixture('action_update_plan_spec.json'));
  });

  test("AIUIAction.toCustomData writes the spec's OpenUI action", () {
    const action = AIUIAction(
      messageId: '4f1c',
      format: AIUIFormat.openUI,
      name: 'continue_conversation',
      label: 'Update the plan with my choices',
      payload: {
        'context': 'Update the plan with my choices',
        'form': 'refine',
        'values': {
          'pace': 'packed',
          'interests': ['food', 'swimming'],
        },
      },
    );

    final customData = overTheWire(action.toCustomData());

    expect(customData, genuiFixture('action_continue_conversation_spec.json'));
  });

  test("AIUIAction.toJson leaves the label out, as it is the message's text", () {
    final action = _askAbout();

    final json = action.toJson();

    expect(json, isNot(contains('label')));
  });

  test('AIUIAction.toJson writes an empty payload for an action without one', () {
    const action = AIUIAction(messageId: 'm1', format: AIUIFormat.openUI, name: 'dismiss', label: 'Dismiss');

    final json = action.toJson();

    expect(json['payload'], isEmpty);
  });

  test("AIUIAction.toJson writes a payload that doesn't change the action when it is changed", () {
    final action = _submitPlan(interests: ['food']);
    final json = action.toJson();

    ((json['payload']! as Map<String, Object?>)['interests']! as List<Object?>).add('swimming');

    expect(action, _submitPlan(interests: ['food']));
  });

  test('AIUIActions with the same fields are equal, their payload compared deeply', () {
    final action = _submitPlan(interests: ['food', 'swimming']);

    expect(action, _submitPlan(interests: ['food', 'swimming']));
  });

  test('AIUIActions with the same fields have the same hash code', () {
    final action = _submitPlan(interests: ['food', 'swimming']);

    expect(action.hashCode, _submitPlan(interests: ['food', 'swimming']).hashCode);
  });

  test('AIUIActions whose payloads differ deep inside are not equal', () {
    final action = _submitPlan(interests: ['food', 'swimming']);

    expect(action, isNot(_submitPlan(interests: ['food'])));
  });

  test('AIUIActions that differ only in their label are not equal', () {
    final action = _askAbout();

    expect(action, isNot(_askAbout(label: 'Tell me about Saint Naum')));
  });
}

// A submitted form, its values nested in the payload and new each time, so
// equality can't rest on identity.
AIUIAction _submitPlan({required List<String> interests}) => AIUIAction(
  messageId: 'm1',
  format: AIUIFormat.a2ui,
  name: 'update_plan',
  label: 'Update the plan',
  payload: {'interests': interests},
);

// A tap on a place card.
AIUIAction _askAbout({String label = 'Tell me more about St. Naum'}) => AIUIAction(
  messageId: 'm1',
  format: AIUIFormat.openUI,
  name: 'ask_about',
  label: label,
  payload: const {'title': 'Monastery of Saint Naum'},
);
