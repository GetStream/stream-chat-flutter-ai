import 'dart:convert';

/// Lenient reads from a decoded JSON object, shared by the message-part
/// decoders: a field that is missing, `null` or of the wrong type reads as
/// `null`, and nothing here throws.
///
/// Not exported — the parts' `fromJson` factories are the public surface.
extension JsonFields on Map<String, Object?> {
  /// The non-empty string at [key].
  String? stringField(String key) => switch (this[key]) {
    final String value when value.isNotEmpty => value,
    _ => null,
  };

  /// The integer at [key]. An integral double (`1.0`, as some JSON encoders
  /// write whole numbers) reads as an int; any other double does not.
  int? intField(String key) => switch (this[key]) {
    final int value => value,
    final double value when value.isFinite && value == value.roundToDouble() => value.toInt(),
    _ => null,
  };

  /// The JSON object at [key], or — for a backend that sends it
  /// JSON-encoded — the object a string at [key] decodes to.
  Map<String, Object?>? objectField(String key) {
    final value = this[key];
    if (value is String) {
      try {
        return asJsonObject(jsonDecode(value));
      } on FormatException {
        return null;
      }
    }
    return asJsonObject(value);
  }
}

/// [value] as a JSON object with string keys, or `null` when it is not a map.
///
/// Entries whose key is not a string are dropped rather than failing the whole
/// object.
Map<String, Object?>? asJsonObject(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is! Map) return null;
  return {
    for (final MapEntry(:key, :value) in value.entries)
      if (key is String) key: value,
  };
}
