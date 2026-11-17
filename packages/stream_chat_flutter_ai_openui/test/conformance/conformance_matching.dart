part of 'openui_conformance.dart';

/// Where [actual] first differs from [expected], or `null` when it doesn't.
///
/// Objects compare whatever the order of their keys, lists item by item, and
/// numbers by value, so `1` matches `1.0`.
String? firstDifference(Object? actual, Object? expected, [String path = r'$']) {
  if (actual is Map<String, Object?> && expected is Map<String, Object?>) {
    for (final key in expected.keys) {
      if (!actual.containsKey(key)) return '$path.$key: missing, expected ${jsonEncode(expected[key])}';
    }
    for (final key in actual.keys) {
      if (!expected.containsKey(key)) return '$path.$key: unexpected ${jsonEncode(actual[key])}';
    }
    for (final MapEntry(:key, :value) in expected.entries) {
      if (firstDifference(actual[key], value, '$path.$key') case final difference?) return difference;
    }
    return null;
  }
  if (actual is List<Object?> && expected is List<Object?>) {
    for (var i = 0; i < actual.length && i < expected.length; i += 1) {
      if (firstDifference(actual[i], expected[i], '$path[$i]') case final difference?) return difference;
    }
    if (actual.length != expected.length) return '$path: ${actual.length} items, expected ${expected.length}';
    return null;
  }
  if (actual is num && expected is num && actual.toDouble() == expected.toDouble()) return null;
  if (actual == expected) return null;
  return '$path: ${jsonEncode(actual)}, expected ${jsonEncode(expected)}';
}
