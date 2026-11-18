import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/action_plan.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

OpenUIObject _step(String type) => OpenUIObject({'type': OpenUIString(type)});

void main() {
  test('flattening plans gives their steps in order', () {
    final first = ActionPlan.plan([_step('set')]);
    final second = ActionPlan.plan([_step('reset'), _step('open_url')]);

    expect(ActionPlan.stepsOf(ActionPlan.flatten([first, second])), [_step('set'), _step('reset'), _step('open_url')]);
  });

  test('flattening keeps an object with a type as a step of its own', () {
    expect(ActionPlan.stepsOf(ActionPlan.flatten([_step('set')])), [_step('set')]);
  });

  test('flattening keeps an element as a step of its own', () {
    final element = OpenUIElement(
      ElementNode(typeName: 'Run', props: const {}, partial: false, hasDynamicProps: false),
    );

    expect(ActionPlan.stepsOf(ActionPlan.flatten([element])), [element]);
  });

  test('flattening leaves out an object with no type', () {
    final untyped = OpenUIObject(const {'name': OpenUIString('x')});

    expect(ActionPlan.stepsOf(ActionPlan.flatten([untyped])), isEmpty);
  });

  test('flattening leaves out a value that is not an object', () {
    expect(ActionPlan.stepsOf(ActionPlan.flatten([const OpenUIString('x'), const OpenUINumber(1)])), isEmpty);
  });
}
