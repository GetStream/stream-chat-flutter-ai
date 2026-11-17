import 'dart:async';

import 'package:stream_chat_flutter_ai_openui/src/core/runtime/tool_provider.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// A tool provider whose calls the test answers.
final class FakeTools implements OpenUIToolProvider {
  /// Every call, in order.
  final calls = <({String name, Map<String, OpenUIValue> args, bool userInitiated, Completer<OpenUIValue> answer})>[];

  /// Tools that answer at once, by name.
  final results = <String, OpenUIValue>{};

  @override
  Future<OpenUIValue> callTool(String name, Map<String, OpenUIValue> args, {required bool userInitiated}) {
    final answer = Completer<OpenUIValue>();
    calls.add((name: name, args: args, userInitiated: userInitiated, answer: answer));
    if (results[name] case final result?) answer.complete(result);
    return answer.future;
  }
}
