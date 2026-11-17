/// The evaluated tree a reply's program renders, and the values in it.
///
/// One of the core's boundary files: code outside `lib/src/core/` may import
/// it.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';

export 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart' show ElementNode;
export 'package:stream_chat_flutter_ai_openui/src/core/runtime/action_plan.dart' show ActionPlan, ActionStepType;
export 'package:stream_chat_flutter_ai_openui/src/core/runtime/evaluator.dart' show ReactiveBinding;
export 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart' show JS;
export 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
