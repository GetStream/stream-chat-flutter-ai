import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_conformance_seams.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';

import 'openui_conformance_skips.dart';

part 'conformance_libraries.dart';
part 'conformance_matching.dart';
part 'conformance_spec.dart';

// Runs the OpenUI Lang conformance fixtures against this package's core,
// through the seams of `openui_conformance_seams.dart` only, so a replacement
// core passes the same suites.
//
// A case passes when what the core gives is what OpenUI's own implementation
// gave: the whole result, its errors included, so a case that expects no
// error fails when one is reported.

/// Registers a test for each case of `generated/parser-conformance.json`,
/// comparing the one-shot parse of its input with the `result` it records,
/// and the checks that the suite was read.
void runParserConformance() {
  final cases = _parserCases();

  test('the parser suite has its 193 cases', () {
    expect(cases, hasLength(193));
  });

  test('the parser suite reads its four libraries', () {
    expect(conformanceLibraries().keys, unorderedEquals(['chat', 'playground', 'mini', 'spec']));
  });

  test('156 parser cases render a root', () {
    final rooted = cases.where((testCase) => (testCase['result']! as Map<String, Object?>)['root'] != null);

    expect(rooted, hasLength(156));
  });

  test("a parse result differs from another program's expected result", () {
    final first = cases.first;
    final other = cases.firstWhere(
      (testCase) => testCase['library'] == first['library'] && testCase['input'] != first['input'],
    );
    final actual = debugParse(conformanceLibraries()[first['library']]!, first['input']! as String);

    expect(firstDifference(actual, other['result']), isNotNull);
  });

  for (final testCase in cases) {
    final name = testCase['name']! as String;
    test(name, () {
      final schema = conformanceLibraries()[testCase['library']]!;
      final actual = debugParse(schema, testCase['input']! as String);

      expect(firstDifference(actual, testCase['result']), isNull);
    });
  }
}

/// Registers one skipped test for the suite named `suite`, which isn't run,
/// giving `reason`.
void skipConformanceSuite(String suite, {required String reason}) {
  test('the $suite suite', () {}, skip: reason);
}

const _generated = 'test/conformance/generated';

List<Map<String, Object?>> _parserCases() {
  final json = jsonDecode(File('$_generated/parser-conformance.json').readAsStringSync()) as List<Object?>;
  return json.cast<Map<String, Object?>>();
}
