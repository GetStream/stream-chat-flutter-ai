/// The calls every OpenUI Lang program can make, and the names it reserves.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';

/// The built-in functions and action steps of OpenUI Lang, and its reserved
/// statement calls.
abstract final class BuiltinCalls {
  /// The parameters of each built-in function, in positional order.
  static const functionParams = <String, List<String>>{
    'Count': ['array'],
    'First': ['array'],
    'Last': ['array'],
    'Sum': ['numbers'],
    'Avg': ['numbers'],
    'Min': ['numbers'],
    'Max': ['numbers'],
    'Sort': ['array', 'field', 'direction'],
    'Filter': ['array', 'field', 'operator', 'value'],
    'Round': ['number', 'decimals'],
    'Abs': ['number'],
    'Floor': ['number'],
    'Ceil': ['number'],
    'Each': ['array', 'varName', 'template'],
  };

  /// The built-in functions whose arguments are evaluated by the function
  /// itself rather than before the call.
  static const lazyFunctions = {'Each'};

  /// The parameters of each built-in action step, in positional order.
  static const stepParams = <String, List<String>>{
    'Run': ['ref'],
    'ToAssistant': ['message', 'context'],
    'OpenUrl': ['url'],
    'Set': ['variable', 'value'],
    'Reset': ['variable'],
  };

  /// The built-in action steps whose arguments are read unevaluated.
  static const lazySteps = {'Run', 'Set', 'Reset'};

  /// The call that groups action steps: `Action([…])`.
  static const action = 'Action';

  /// The reserved statement call of a query.
  static const query = 'Query';

  /// The reserved statement call of a mutation.
  static const mutation = 'Mutation';

  /// The built-in functions, steps and [action]: the calls every library
  /// starts from.
  ///
  /// Built-ins coerce their arguments, so their parameters are named but not
  /// checked, and only [action] requires its `steps`.
  static final Map<String, CallDef> calls = Map.unmodifiable({
    for (final MapEntry(key: name, value: params) in functionParams.entries)
      name: CallDef(
        CallKind.function,
        [for (final param in params) ParamDef(param)],
        isBuiltin: true,
        isLazy: lazyFunctions.contains(name),
      ),
    for (final MapEntry(key: name, value: params) in stepParams.entries)
      name: CallDef(
        CallKind.action,
        [for (final param in params) ParamDef(param)],
        isBuiltin: true,
        isLazy: lazySteps.contains(name),
      ),
    action: const CallDef(CallKind.action, [ParamDef('steps', required: true)], isBuiltin: true, isLazy: true),
  });

  /// Whether `name` is a built-in function, a built-in step or [action], so
  /// not a component.
  static bool isBuiltin(String name) => calls.containsKey(name);

  /// Whether `name` is [query] or [mutation], which only a statement can call.
  static bool isReservedCall(String name) => name == query || name == mutation;
}
