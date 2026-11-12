/// The values OpenUI Lang programs compute with.
///
/// Internal to the package.
@internal
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';

/// A value of OpenUI Lang, with JavaScript's data model.
///
/// Programs are evaluated with JavaScript semantics, so a value is one of
/// JavaScript's JSON kinds — [OpenUINull], [OpenUIBool], [OpenUINumber],
/// [OpenUIString], [OpenUIArray] and [OpenUIObject] — or one of the two kinds
/// a parsed program adds: an [OpenUIElement], a component call the parser
/// resolved, and an [OpenUIExpression], an expression evaluated later.
///
/// JavaScript's `undefined` has no kind of its own: an absent value is a Dart
/// `null` of type `OpenUIValue?`, while the language's `null` is [OpenUINull].
///
/// Values are immutable and compare by content. An object keeps its keys in
/// the order they were added, but two objects with the same entries are equal
/// whatever their order. Numbers compare like JavaScript's `SameValueZero`:
/// `NaN` equals `NaN`, and `-0` equals `0`.
@immutable
sealed class OpenUIValue {
  const OpenUIValue();

  /// The value `json` decodes to, as JavaScript's `JSON.parse` gives it.
  ///
  /// The `json` argument is what `jsonDecode` returns: `null`, a [bool], a
  /// [num], a [String], or a [List] or [Map] with [String] keys holding more of
  /// the same. Every number becomes an [OpenUINumber], and a map keeps its key
  /// order, where JavaScript lists integer-like keys first.
  ///
  /// Throws a [FormatException] when `json` holds anything else, or nests
  /// lists and maps more than [maxJsonDepth] levels deep.
  factory OpenUIValue.fromJson(Object? json) => _fromJson(json, 0);

  /// How many levels of lists and maps [OpenUIValue.fromJson] reads.
  ///
  /// Converting recurses once per level. No library schema or tool result
  /// nests anywhere near this deep, and the stack stays safe well past it.
  static const maxJsonDepth = 512;

  static OpenUIValue _fromJson(Object? json, int depth) {
    switch (json) {
      case null:
        return OpenUINull.instance;
      case final bool value:
        return OpenUIBool(value);
      case final num value:
        return OpenUINumber(value.toDouble());
      case final String value:
        return OpenUIString(value);
      case final List<Object?> items:
        if (depth >= maxJsonDepth) throw _tooDeep();
        return OpenUIArray([for (final item in items) _fromJson(item, depth + 1)]);
      case final Map<Object?, Object?> fields:
        if (depth >= maxJsonDepth) throw _tooDeep();
        final object = <String, OpenUIValue>{};
        for (final MapEntry(:key, :value) in fields.entries) {
          if (key is! String) throw FormatException('A JSON object key that is not a string: $key');
          object[key] = _fromJson(value, depth + 1);
        }
        return OpenUIObject(object);
      default:
        throw FormatException('Not a JSON value: ${json.runtimeType}');
    }
  }

  static FormatException _tooDeep() => const FormatException('JSON nested more than $maxJsonDepth levels deep');

  @override
  String toString() => JS.jsonStringify(this) ?? 'undefined';
}

/// JavaScript's `null`.
final class OpenUINull extends OpenUIValue {
  const OpenUINull._();

  /// The one `null` value.
  static const instance = OpenUINull._();

  @override
  bool operator ==(Object other) => other is OpenUINull;

  @override
  int get hashCode => 0;
}

/// A boolean.
final class OpenUIBool extends OpenUIValue {
  /// Creates the boolean [value].
  // ignore: avoid_positional_boolean_parameters
  const OpenUIBool(this.value);

  /// Whether this is `true`.
  final bool value;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUIBool && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

/// A JavaScript number, always a double.
final class OpenUINumber extends OpenUIValue {
  /// Creates the number [value].
  const OpenUINumber(this.value);

  /// The number.
  final double value;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUINumber && JS.sameValueZero(other.value, value);
  }

  // `NaN` hashes alike, and `-0.0 == 0.0` already hashes alike in Dart.
  @override
  int get hashCode => value.isNaN ? double.nan.hashCode : value.hashCode;
}

/// A string of UTF-16 code units, as in JavaScript.
final class OpenUIString extends OpenUIValue {
  /// Creates the string [value].
  const OpenUIString(this.value);

  /// The string.
  final String value;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUIString && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

/// An array.
final class OpenUIArray extends OpenUIValue {
  /// Creates an array holding [items], in order.
  OpenUIArray(Iterable<OpenUIValue> items) : items = List.unmodifiable(items);

  /// The items, which can't be changed.
  final List<OpenUIValue> items;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUIArray && const ListEquality<OpenUIValue>().equals(other.items, items);
  }

  @override
  int get hashCode => const ListEquality<OpenUIValue>().hash(items);
}

/// An object whose keys keep the order they were added in.
final class OpenUIObject extends OpenUIValue {
  /// Creates an object holding [fields], in their iteration order.
  OpenUIObject(Map<String, OpenUIValue> fields) : fields = Map.unmodifiable(fields);

  /// The fields, in the order they were added; they can't be changed.
  final Map<String, OpenUIValue> fields;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUIObject && const MapEquality<String, OpenUIValue>().equals(other.fields, fields);
  }

  @override
  int get hashCode => const MapEquality<String, OpenUIValue>().hash(fields);
}

/// A component call the parser resolved.
final class OpenUIElement extends OpenUIValue {
  /// Creates the value of the component call [node].
  const OpenUIElement(this.node);

  /// The resolved call.
  final ElementNode node;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUIElement && other.node == node;
  }

  @override
  int get hashCode => node.hashCode;
}

/// An expression evaluated later, such as `$count + 1` or `@Count(rows)`.
final class OpenUIExpression extends OpenUIValue {
  /// Creates the value of the expression [node].
  const OpenUIExpression(this.node);

  /// The expression.
  final AstNode node;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpenUIExpression && other.node == node;
  }

  @override
  int get hashCode => node.hashCode;
}
