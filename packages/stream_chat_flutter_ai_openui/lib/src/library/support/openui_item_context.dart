import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';

/// [action] with what [item] tells about the card block item a person chose
/// merged in, as JSON.
///
/// - Without an action, the result is a `continue_conversation` action whose
///   params are [item].
/// - An action that is a plan of steps, such as one built with `@ToAssistant`,
///   gets `Selected item: ` and [item] as JSON added to the `context` of each
///   of its `continue_conversation` steps, after what it has. A plan is
///   returned as it is when [item] is empty.
/// - Any other action becomes `{type, params}`: its `params`, its `url` and
///   its `context` when it has one, and then [item], whose entries win.
///
/// Internal to the package.
@internal
Object? mergeOpenUIItemContext(Object? action, Map<String, Object?> item) {
  if (action == null) return {'type': OpenUIActionEvent.continueConversation, 'params': item};
  if (action is Map<String, Object?> && action['steps'] is List) {
    if (item.isEmpty) return action;
    final suffix = 'Selected item: ${JS.jsonStringify(OpenUIValue.fromJson(item))}';
    return {
      ...action,
      'steps': [
        for (final step in action['steps']! as List<Object?>)
          if (step is Map<String, Object?> && step['type'] == ActionStepType.continueConversation)
            {
              ...step,
              'context': switch (step['context']) {
                final String existing when existing.isNotEmpty => '$existing\n$suffix',
                _ => suffix,
              },
            }
          else
            step,
      ],
    };
  }
  final fields = action is Map<String, Object?> ? action : const <String, Object?>{};
  final params = {
    if (fields['params'] case final Map<String, Object?> own) ...own,
    if (fields['url'] != null) 'url': fields['url'],
    if (_isTruthy(fields['context'])) 'context': fields['context'],
    ...item,
  };
  final type = fields['type'];
  return {
    'type': _isTruthy(type) ? JS.stringOf(OpenUIValue.fromJson(type)) : OpenUIActionEvent.continueConversation,
    'params': params,
  };
}

bool _isTruthy(Object? value) => JS.isTruthy(value == null ? null : OpenUIValue.fromJson(value));
