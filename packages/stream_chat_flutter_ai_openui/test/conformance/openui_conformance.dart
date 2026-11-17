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

/// Registers a test for each case of `generated/parser-conformance.json`
/// comparing what streaming its `chunks` gives at each of its `checkpoints`
/// with the `streamResults` it records, and one comparing what the stream
/// gives once it ends with its `completeResult`, and the checks that the
/// streaming keys were read.
void runParserStreamingConformance() {
  final cases = _parserCases();

  test('the parser suite has 1,636 streaming checkpoints', () {
    final checkpoints = cases.fold(0, (sum, testCase) => sum + (testCase['checkpoints']! as List<Object?>).length);

    expect(checkpoints, 1636);
  });

  test('every parser case records one stream result per checkpoint', () {
    final mismatched = [
      for (final testCase in cases)
        if ((testCase['checkpoints']! as List<Object?>).length != (testCase['streamResults']! as List<Object?>).length)
          testCase['name'],
    ];

    expect(mismatched, isEmpty);
  });

  test("a stream result differs from another program's expected complete result", () {
    final first = cases.first;
    final other = cases.firstWhere(
      (testCase) => testCase['library'] == first['library'] && testCase['input'] != first['input'],
    );
    final chunks = (first['chunks']! as List<Object?>).cast<String>();
    final actual = debugStreamParseComplete(conformanceLibraries()[first['library']]!, chunks);

    expect(firstDifference(actual, other['completeResult']), isNotNull);
  });

  test("a stream checkpoint differs from another program's checkpoint", () {
    final first = cases.firstWhere((testCase) => (testCase['checkpoints']! as List<Object?>).isNotEmpty);
    final other = cases.firstWhere(
      (testCase) => testCase['library'] == first['library'] && testCase['input'] != first['input'],
    );
    final chunks = (first['chunks']! as List<Object?>).cast<String>();
    final step = (first['checkpoints']! as List<Object?>).cast<int>().last;
    final actual = debugStreamParseSteps(conformanceLibraries()[first['library']]!, chunks)[step];

    expect(firstDifference(actual, (other['streamResults']! as List<Object?>).last), isNotNull);
  });

  for (final testCase in cases) {
    final name = testCase['name']! as String;
    final chunks = (testCase['chunks']! as List<Object?>).cast<String>();

    test('$name: streamed, at each checkpoint', () {
      final schema = conformanceLibraries()[testCase['library']]!;
      final steps = debugStreamParseSteps(schema, chunks);
      final checkpoints = (testCase['checkpoints']! as List<Object?>).cast<int>();
      final expected = testCase['streamResults']! as List<Object?>;
      final differences = [
        for (final (index, step) in checkpoints.indexed)
          if (firstDifference(steps[step], expected[index]) case final difference?) 'step $step: $difference',
      ];

      expect(differences, isEmpty);
    });

    test('$name: streamed to the end', () {
      final schema = conformanceLibraries()[testCase['library']]!;
      final actual = debugStreamParseComplete(schema, chunks);

      expect(firstDifference(actual, testCase['completeResult']), isNull);
    });
  }
}

const _generated = 'test/conformance/generated';

List<Map<String, Object?>> _parserCases() {
  final json = jsonDecode(File('$_generated/parser-conformance.json').readAsStringSync()) as List<Object?>;
  return json.cast<Map<String, Object?>>();
}

/// Registers a test for each case of `evaluator-conformance.json`: the
/// evaluated root, the queries and the runtime errors of each program, with
/// the case's state and references.
void runEvaluatorConformance() {
  final cases = evaluatorCases();

  test('the evaluator suite has its 190 cases', () {
    expect(cases, hasLength(190));
  });

  test("an evaluated root differs from another program's expected root", () {
    final first = cases.firstWhere((testCase) => testCase['evaluatedRoot'] != null);
    final other = cases.firstWhere(
      (testCase) =>
          testCase['library'] == first['library'] &&
          testCase['evaluatedRoot'] != null &&
          testCase['input'] != first['input'],
    );

    expect(firstDifference(_evaluate(first)['evaluatedRoot'], other['evaluatedRoot']), isNotNull);
  });

  for (final testCase in cases) {
    test('${testCase['name']} (${testCase['library']})', () {
      final actual = _evaluate(testCase);

      expect(firstDifference(actual['evaluatedRoot'], testCase['evaluatedRoot'], r'$.evaluatedRoot'), isNull);
      expect(firstDifference(actual['queries'], testCase['queries'], r'$.queries'), isNull);
      expect(firstDifference(actual['runtimeErrors'], testCase['runtimeErrors'], r'$.runtimeErrors'), isNull);
    }, skip: evaluatorCaseSkipReason(testCase['name']! as String));
  }
}

Map<String, Object?> _evaluate(Map<String, Object?> testCase) {
  final library = testCase['library']! as String;
  return debugEvaluate(
    conformanceLibraries()[library]!,
    testCase['input']! as String,
    isBindable: conformanceBindables(library),
    state: testCase['state']! as Map<String, Object?>,
    refs: testCase['refs']! as Map<String, Object?>,
    functions: library == 'spec' ? specFunctions : const {},
  );
}

/// Registers a test for each case of `spec-interactions.json`: the events,
/// state and tool calls of running each program through its interactions.
void runSpecInteractionsConformance() {
  final cases = (jsonDecode(File('$_generated/spec-interactions.json').readAsStringSync()) as List<Object?>)
      .cast<Map<String, Object?>>();

  test('the interactions suite has its 12 cases', () {
    expect(cases, hasLength(12));
  });

  for (final testCase in cases) {
    test(testCase['name']! as String, () async {
      final expected = testCase['expected']! as Map<String, Object?>;
      final actual = await debugInteract(
        conformanceLibraries()['spec']!,
        testCase['program']! as String,
        (testCase['interactions']! as List<Object?>).cast<Map<String, Object?>>(),
        isBindable: conformanceBindables('spec'),
        functions: specFunctions,
      );

      expect(_interactionDifference(actual, expected), isNull);
    });
  }
}

// Where `actual` first differs from `expected`, which lists only the keys
// it checks: each event's listed fields, the listed state keys, and the tool
// calls in full.
String? _interactionDifference(Map<String, Object?> actual, Map<String, Object?> expected) {
  final events = actual['events']! as List<Object?>;
  if (expected['events'] case final List<Object?> expectedEvents) {
    if (events.length != expectedEvents.length) return 'events: ${jsonEncode(events)}';
    for (final (index, event) in expectedEvents.cast<Map<String, Object?>>().indexed) {
      final actualEvent = events[index]! as Map<String, Object?>;
      for (final MapEntry(:key, :value) in event.entries) {
        if (firstDifference(actualEvent[key], value, '\$.events[$index].$key') case final difference?) {
          return difference;
        }
      }
    }
  }
  if (expected['state'] case final Map<String, Object?> state) {
    final actualState = actual['state']! as Map<String, Object?>;
    for (final MapEntry(:key, :value) in state.entries) {
      if (firstDifference(actualState[key], value, '\$.state.$key') case final difference?) return difference;
    }
  }
  if (expected['toolCalls'] case final List<Object?> calls) {
    return firstDifference(actual['toolCalls'], calls, r'$.toolCalls');
  }
  return null;
}

/// The cases of `evaluator-conformance.json`.
List<Map<String, Object?>> evaluatorCases() {
  return (jsonDecode(File('$_generated/evaluator-conformance.json').readAsStringSync()) as List<Object?>)
      .cast<Map<String, Object?>>();
}
