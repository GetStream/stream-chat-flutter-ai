import 'package:flutter/foundation.dart';

// The messages already printed.
final _logged = <String>{};

/// Prints [message] once, in debug builds only, so a problem that a fallback
/// hides, such as an image that didn't load, still shows while developing.
///
/// Internal to the package.
@internal
void a2uiDebugLogOnce(String message) {
  if (!kDebugMode || !_logged.add(message)) return;
  debugPrint('stream_chat_flutter_ai_a2ui: $message');
}
