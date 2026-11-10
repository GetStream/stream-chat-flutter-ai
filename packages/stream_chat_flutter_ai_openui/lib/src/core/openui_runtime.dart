/// The runtime a reply's program runs in, and what it needs from the app.
///
/// One of the core's boundary files: code outside `lib/src/core/` may import
/// it.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';

export 'package:stream_chat_flutter_ai_openui/src/core/runtime/evaluator.dart' show BindablePropTest, OpenUIFunction;
export 'package:stream_chat_flutter_ai_openui/src/core/runtime/openui_runtime.dart';
export 'package:stream_chat_flutter_ai_openui/src/core/runtime/query_manager.dart' show OpenUITimerFactory;
export 'package:stream_chat_flutter_ai_openui/src/core/runtime/tool_provider.dart';
