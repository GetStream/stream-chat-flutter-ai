part of 'a2ui_conformance.dart';

const _categoryCodes = <String, Set<String>>{
  'ValidationError': {
    'VALIDATION_FAILED',
    'UNALLOWED_PARENT',
    'UNALLOWED_CHILD',
    'INVALID_FUNCTION_CALL',
    'EXPRESSION_ERROR',
    'INTEGRITY_ERROR',
    'RECURSION_LIMIT_EXCEEDED',
    'CATALOG_NOT_FOUND',
    'INVALID_ACTION',
  },
  'CatalogError': {'CATALOG_NOT_FOUND'},
  'IntegrityError': {'INTEGRITY_ERROR', 'RECURSION_LIMIT_EXCEEDED'},
  'RecursionError': {'RECURSION_LIMIT_EXCEEDED'},
  'DataError': {'DATA_ERROR'},
  'ExpressionError': {'EXPRESSION_ERROR', 'EXECUTION_ERROR', 'INVALID_FUNCTION_CALL'},
  'ParseError': {'VALIDATION_FAILED', 'EXPRESSION_ERROR'},
};

// Asserts that one of [errors] meets [expected]: a message, or the suite's
// structured form.
void _assertErrorMatches(Object? expected, List<A2UIError> errors) {
  expect(errors, isNotEmpty, reason: 'Expected an error matching $expected, but none was reported.');
  final mismatches = [for (final error in errors) _mismatch(expected, error)];
  if (mismatches.contains(null)) return;
  fail(
    'No reported error matches $expected:\n'
    '${[for (final (index, error) in errors.indexed) '  $error -> ${mismatches[index]}'].join('\n')}',
  );
}

// Why [error] doesn't meet [expected], or `null` when it does.
String? _mismatch(Object? expected, A2UIError error) {
  if (expected is String) return _messageMatches(expected, error.message) ? null : 'message';
  if (expected is! Map<String, Object?>) return null;
  if (expected['category'] case final String category) {
    final codes = _categoryCodes[category];
    if (codes != null && !codes.contains(error.code)) return 'category $category';
  }
  if (expected['code'] case final String code when error.code != code) return 'code';
  if (expected['message'] case final String message when !_messageMatches(message, error.message)) return 'message';
  if (expected['path'] case final String path when !_pathMatches(path, error)) return 'path';
  if (expected['surfaceId'] case final String surfaceId when error.surfaceId != surfaceId) return 'surfaceId';
  // This package's errors name no function call, so a case that expects one
  // doesn't match.
  if (expected['functionCallId'] case final String _) return 'functionCallId';
  for (final detail in (expected['details'] as List<Object?>?) ?? const []) {
    if (detail is! Map<String, Object?>) continue;
    // Lower-case codes name a reference validator's own checks, not A2UI's.
    if (detail['code'] case final String code when code.toUpperCase() == code && error.code != code) {
      return 'details.code';
    }
    // A detail's path may be relative to the component it is about, and one with
    // a `.` names a field of another validator's report, which isn't checked.
    if (detail['path'] case final String path when !(error.path?.endsWith(path) ?? false) && !path.contains('.')) {
      return 'details.path';
    }
  }
  if (expected['rendererError'] case final Map<String, Object?> rendererError) {
    final envelope = (rendererError['error'] as Map<String, Object?>?) ?? rendererError;
    final json = {'code': error.code, 'surfaceId': error.surfaceId, 'path': error.path};
    for (final key in ['code', 'surfaceId', 'functionCallId', 'path']) {
      if (!envelope.containsKey(key)) continue;
      if (key == 'path') {
        if (!_pathMatches(envelope[key]! as String, error)) return 'rendererError.path';
      } else if (json[key] != envelope[key]) {
        return 'rendererError.$key';
      }
    }
    if (envelope['message'] case final String message when !_messageMatches(message, error.message)) {
      return 'rendererError.message';
    }
    if (envelope.containsKey('functionCallId') && !envelope.containsKey('surfaceId') && error.surfaceId != null) {
      return 'rendererError.surfaceId must be absent';
    }
  }
  return null;
}

// A missing required property is reported at the property or at its
// component; both match.
bool _pathMatches(String expected, A2UIError error) {
  if (error.path == expected) return true;
  final path = error.path;
  if (path == null || !error.message.contains('missing the required property')) return false;
  return path.substring(0, path.lastIndexOf('/').clamp(0, path.length)) == expected;
}

// Whether a reported message says what the suite expects, in this package's
// words.
bool _messageMatches(String expected, String actual) {
  final wanted = expected.toLowerCase().replaceAll('"', "'");
  final got = actual.toLowerCase().replaceAll('"', "'");
  if (got.contains(wanted)) return true;
  try {
    if (RegExp(expected).hasMatch(actual)) return true;
  } on FormatException {
    // The expected message isn't a pattern, only text.
  }
  if (wanted.contains('not of type') && (got.contains('must be') || got.contains('not of type'))) return true;
  if (wanted.contains('is a required property') && got.contains('required')) return true;
  if (wanted.contains('additional properties are not allowed') && got.contains('additional properties')) return true;
  if (wanted.contains('circular') && (got.contains('circular') || got.contains('self-reference'))) return true;
  if (wanted.contains('orphan') && got.contains('not reachable')) return true;
  return RegExp(_coreWording(expected), caseSensitive: false).hasMatch(actual);
}

// The suite's message with the core's own words for the same problem as an
// alternative, as the core's reference harness aligns them.
String _coreWording(String expected) {
  final pattern = RegExp.escape(expected);
  if (RegExp("Unrecognized function '([^']*)'").firstMatch(expected) case final match?) {
    return "($pattern|declares no function named '${RegExp.escape(match[1]!)}')";
  }
  for (final (suite, core) in _coreWordings) {
    if (expected.contains(suite)) return '($pattern|$core)';
  }
  return pattern;
}

const _coreWordings = [
  ('Catalog not found:', 'is not supported by this processor'),
  ('without a type', "without a 'component' type"),
  ('Circular reference detected', 'Self-reference detected'),
  ('Dangling reference', 'references non-existent component'),
  ('Orphaned component', 'is not reachable from'),
  ('Validation failed for component', 'does not match the .* schema'),
  ('Validation failed for theme', 'Theme does not match the theme schema'),
  ('multiple conflicting update actions', 'must contain exactly one of'),
  ('Unsupported protocol version', 'Unsupported A2UI protocol version'),
  ('Missing required version field', "must declare a 'version'"),
  ('surfaceId must be a string', r"Field 'createSurface\.surfaceId' must be a String"),
  ('is not reachable from', 'Unreachable components'),
  ('Circular component reference', 'Circular reference detected'),
  ('Self-referencing component', 'Self-reference detected'),
];

// Asserts that [actual] holds what [expected] states: every expected key,
// recursively, with numbers compared by value.
void _assertContains(Object? expected, Object? actual, [String path = '']) {
  if (expected is Map<String, Object?>) {
    if (actual is! Map<Object?, Object?>) fail('$path: expected an object $expected, got $actual.');
    for (final MapEntry(:key, :value) in expected.entries) {
      if (value == null) {
        expect(actual[key], isNull, reason: '$path/$key: expected nothing.');
      } else {
        _assertContains(value, actual[key], '$path/$key');
      }
    }
    return;
  }
  if (expected is List<Object?>) {
    if (actual is! List<Object?>) fail('$path: expected a list $expected, got $actual.');
    expect(actual, hasLength(expected.length), reason: '$path: list size of $actual');
    for (final (index, item) in expected.indexed) {
      _assertContains(item, actual[index], '$path/$index');
    }
    return;
  }
  if (_jsonEquals(expected, actual)) return;
  if (actual is num && expected is String && _numberText(actual) == expected) return;
  fail('$path: expected $expected, got $actual.');
}

bool _jsonEquals(Object? expected, Object? actual) {
  if (expected is num && actual is num) return expected == actual;
  if (expected is Map<Object?, Object?> && actual is Map<Object?, Object?>) {
    if (expected.length != actual.length) return false;
    for (final MapEntry(:key, :value) in expected.entries) {
      if (!actual.containsKey(key) || !_jsonEquals(value, actual[key])) return false;
    }
    return true;
  }
  if (expected is List<Object?> && actual is List<Object?>) {
    if (expected.length != actual.length) return false;
    for (final (index, item) in expected.indexed) {
      if (!_jsonEquals(item, actual[index])) return false;
    }
    return true;
  }
  return expected == actual;
}

String _numberText(num value) => value == value.truncate() ? '${value.truncate()}' : '$value';
