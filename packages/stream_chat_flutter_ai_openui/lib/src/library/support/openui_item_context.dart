import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';

/// [action] with what [item] tells about the card block item a person chose
/// merged in.
///
/// - Without an action, the result is a `continue_conversation` action whose
///   params are [item].
/// - An action that is a plan of steps, such as one built with `@ToAssistant`,
///   gets `Selected item: ` and [item] as JSON added to the `context` of each
///   of its `continue_conversation` steps, after what it has; its other steps,
///   expressions in them included, are kept as they are. A plan is returned as
///   it is when [item] is empty.
/// - Any other action becomes `{type, params}`: its `params`, its `url` and
///   its `context` when it has one, and then [item], whose entries win.
///
/// Internal to the package.
@internal
OpenUIValue mergeOpenUIItemContext(OpenUIValue? action, Map<String, OpenUIValue> item) {
  if (action == null || action is OpenUINull) {
    return OpenUIObject({
      'type': const OpenUIString(OpenUIActionEvent.continueConversation),
      'params': OpenUIObject(item),
    });
  }
  if (action case OpenUIObject(:final fields) when fields['steps'] is OpenUIArray) {
    if (item.isEmpty) return action;
    final suffix = 'Selected item: ${JS.jsonStringify(OpenUIObject(item))}';
    return OpenUIObject({
      ...fields,
      'steps': OpenUIArray([
        for (final step in (fields['steps']! as OpenUIArray).items)
          if (step case OpenUIObject(
            fields: final stepFields,
          ) when stepFields['type'] == const OpenUIString(ActionStepType.continueConversation))
            OpenUIObject({
              ...stepFields,
              'context': OpenUIString(switch (stepFields['context']) {
                OpenUIString(:final value) when value.isNotEmpty => '$value\n$suffix',
                _ => suffix,
              }),
            })
          else
            step,
      ]),
    });
  }
  final fields = action is OpenUIObject ? action.fields : const <String, OpenUIValue>{};
  final type = fields['type'];
  return OpenUIObject({
    'type': JS.isTruthy(type)
        ? OpenUIString(JS.stringOf(type))
        : const OpenUIString(OpenUIActionEvent.continueConversation),
    'params': OpenUIObject({
      if (fields['params'] case OpenUIObject(fields: final own)) ...own,
      if (fields['url'] case final url? when url is! OpenUINull) 'url': url,
      if (fields['context'] case final context? when JS.isTruthy(context)) 'context': context,
      ...item,
    }),
  });
}
