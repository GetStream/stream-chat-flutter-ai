/// What an action evaluates to: a plan of steps.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// The `type` of each step a plan can hold.
abstract final class ActionStepType {
  /// `@Run(ref)`: runs a mutation or fetches a query again.
  static const run = 'run';

  /// `@ToAssistant(message, context?)`: sends a message back to the model.
  static const continueConversation = 'continue_conversation';

  /// `@OpenUrl(url)`: opens a link.
  static const openUrl = 'open_url';

  /// `@Set($x, value)`: writes a `$variable`.
  static const set = 'set';

  /// `@Reset($a, …)`: restores `$variables` to their declared defaults.
  static const reset = 'reset';

  /// `@Name(…)`: one of the library's own actions.
  static const customAction = 'custom_action';
}

/// Plans: `{steps: [...]}` objects, which every action call evaluates to.
///
/// A custom step is real only when a call of the library's action made it.
/// The steps calls make are remembered by identity, as OpenUI's own runtime
/// keeps them in a `WeakSet`, so data — an object literal, a `$variable`, an
/// item of a list — that looks like a custom step can't pose as one: it has
/// no field that marks it, so nothing a program reads or writes can copy the
/// mark.
abstract final class ActionPlan {
  static final _realSteps = Expando<bool>('custom steps made by calls');

  /// The plan of no steps, which does nothing.
  static final empty = plan(const []);

  /// The plan of `steps`, in order.
  static OpenUIObject plan(List<OpenUIValue> steps) => OpenUIObject({'steps': OpenUIArray(steps)});

  /// A step of the library's action `name` with `params`, made by a call.
  static OpenUIObject customStep(String name, OpenUIValue params) {
    final step = OpenUIObject({
      'type': const OpenUIString(ActionStepType.customAction),
      'name': OpenUIString(name),
      'params': params,
    });
    _realSteps[step] = true;
    return step;
  }

  /// Whether `value` is a plan: an object whose `steps` is a list.
  static bool isPlan(OpenUIValue? value) => value is OpenUIObject && value.fields['steps'] is OpenUIArray;

  /// The steps of `value` when it is a plan; otherwise none.
  static List<OpenUIValue> stepsOf(OpenUIValue? value) {
    if (value case OpenUIObject(fields: {'steps': OpenUIArray(:final items)})) return items;
    return const [];
  }

  /// One plan of the steps of every plan in `values`, in order; an object
  /// with a `type` and an element count as steps of their own, and anything
  /// else is left out. Custom steps no call made are dropped.
  static OpenUIObject flatten(List<OpenUIValue> values) {
    return ownSteps(
      plan([
        for (final value in values)
          if (isPlan(value))
            ...stepsOf(value)
          else if (value case OpenUIObject(:final fields) when fields.containsKey('type'))
            value
          else if (value is OpenUIElement)
            value,
      ]),
    );
  }

  /// `plan` without the custom steps no call made; the same instance when it
  /// has none.
  static OpenUIObject ownSteps(OpenUIObject plan) {
    final steps = stepsOf(plan);
    final own = steps.where(_isOwn).toList();
    if (own.length == steps.length) return plan;
    return OpenUIObject({...plan.fields, 'steps': OpenUIArray(own)});
  }

  static bool _isOwn(OpenUIValue step) {
    if (step case OpenUIObject(fields: {'type': OpenUIString(value: ActionStepType.customAction)})) {
      return _realSteps[step] ?? false;
    }
    return true;
  }
}
