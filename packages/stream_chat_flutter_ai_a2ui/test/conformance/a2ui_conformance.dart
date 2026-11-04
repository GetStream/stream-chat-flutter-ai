import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:yaml/yaml.dart';

import 'a2ui_conformance_skips.dart';

part 'conformance_actions.dart';
part 'conformance_functions.dart';
part 'conformance_harness.dart';
part 'conformance_matching.dart';
part 'conformance_messages.dart';
part 'conformance_rpc.dart';

// Runs the A2UI conformance suites, vendored under `upstream/`, against this
// package's adapter: each case's messages go through `A2UIProcessor.apply`, as a
// reply's would, and what the adapter reports is checked against what the case
// expects. Cases about parts of A2UI a renderer never reaches on its own go
// through the seams of `a2ui_conformance_seams.dart`.
//
// Errors count as reported, not thrown: a case that expects one passes when any
// reported error matches it, and a step that expects none fails when one is
// reported. An expected object matches when it holds what the case states (a
// subset); an expected list must have the same length.

/// Registers a test for each case of the suite named `suite`, read from
/// `conformance/core/<suite>.yaml`, and one that checks the suite has cases.
void runConformanceSuite(String suite) {
  final cases = _cases(suite);

  test('the $suite suite has cases', () {
    expect(cases, isNotEmpty);
  });

  for (final testCase in cases) {
    final name = testCase['name']! as String;
    test(name, () => _run(testCase), skip: conformanceSkipReason(suite, name, testCase));
  }
}

/// Registers one skipped test for the suite named `suite`, which isn't run,
/// giving `reason`.
void skipConformanceSuite(String suite, {required String reason}) {
  test('the $suite suite', () {}, skip: reason);
}

const _root = 'test/conformance/upstream';

List<Map<String, Object?>> _cases(String suite) {
  final yaml = loadYaml(File('$_root/conformance/core/$suite.yaml').readAsStringSync());
  return [for (final item in _json(yaml)! as List<Object?>) item! as Map<String, Object?>];
}

// YAML as plain JSON values.
Object? _json(Object? yaml) => jsonDecode(jsonEncode(yaml));

Future<void> _run(Map<String, Object?> testCase) => switch (testCase['action']) {
  'validate' || 'process_messages' => _runProcessMessages(testCase),
  'evaluate_function' => _runEvaluateFunction(testCase),
  'parse_expression_template' => _runParseExpression(testCase),
  'data_model' => _runDataModel(testCase),
  'resolve_path' => _runResolvePath(testCase),
  'handle_rpc' => _runHandleRpc(testCase),
  'dispatch_action' => _runDispatchAction(testCase),
  'get_renderer_data_model' => _runRendererDataModel(testCase),
  final action => fail('No runner for the action $action.'),
};
