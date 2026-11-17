/// The built-in data functions of OpenUI Lang: `@Count`, `@Sort`, `@Round`….
///
/// Internal to the package.
@internal
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// A built-in function: its arguments, positional and already evaluated
/// (absent when not written), to its result.
typedef BuiltinFunction = OpenUIValue Function(List<OpenUIValue?> args);

/// The 13 built-in data functions, by name; `@Each`, which evaluates its own
/// arguments, is the evaluator's.
///
/// Each coerces its arguments as OpenUI's own `builtins.ts` does, so none
/// fails: a value of the wrong kind gives the function's empty result.
abstract final class Builtins {
  /// The functions, by name, in the order OpenUI lists them.
  static final Map<String, BuiltinFunction> functions = Map.unmodifiable(<String, BuiltinFunction>{
    'Count': (args) => switch (_arg(args, 0)) {
      OpenUIArray(:final items) => OpenUINumber(items.length.toDouble()),
      _ => const OpenUINumber(0),
    },
    'First': (args) => switch (_arg(args, 0)) {
      OpenUIArray(:final items) when items.isNotEmpty => items.first,
      _ => OpenUINull.instance,
    },
    'Last': (args) => switch (_arg(args, 0)) {
      OpenUIArray(:final items) when items.isNotEmpty => items.last,
      _ => OpenUINull.instance,
    },
    'Sum': (args) => OpenUINumber(_numbers(args).fold(0, (sum, n) => sum + n)),
    'Avg': (args) {
      final numbers = _numbers(args);
      if (numbers.isEmpty) return const OpenUINumber(0);
      return OpenUINumber(numbers.fold<double>(0, (sum, n) => sum + n) / numbers.length);
    },
    'Min': (args) => _fold(args, JS.min),
    'Max': (args) => _fold(args, JS.max),
    'Sort': _sort,
    'Filter': _filter,
    'Round': (args) {
      final number = JS.toNumber(_arg(args, 0));
      final decimals = _arg(args, 1);
      final factor = math.pow(10, JS.isNullish(decimals) ? 0 : JS.toNumber(decimals)).toDouble();
      return OpenUINumber(JS.round(number * factor) / factor);
    },
    'Abs': (args) => OpenUINumber(JS.toNumber(_arg(args, 0)).abs()),
    'Floor': (args) => OpenUINumber(JS.toNumber(_arg(args, 0)).floorToDouble()),
    'Ceil': (args) => OpenUINumber(JS.toNumber(_arg(args, 0)).ceilToDouble()),
  });

  static OpenUIValue? _arg(List<OpenUIValue?> args, int index) => index < args.length ? args[index] : null;

  static List<double> _numbers(List<OpenUIValue?> args) => switch (_arg(args, 0)) {
    OpenUIArray(:final items) => [for (final item in items) JS.toNumber(item)],
    _ => const [],
  };

  // The items' numbers folded with `combine` from the first; 0 for no items.
  static OpenUIValue _fold(List<OpenUIValue?> args, double Function(double, double) combine) {
    final numbers = _numbers(args);
    if (numbers.isEmpty) return const OpenUINumber(0);
    return OpenUINumber(numbers.skip(1).fold(numbers.first, combine));
  }

  /// The value at the dot path `path` of `value`, such as `"user.name"`;
  /// absent for an empty path or when a step reads nothing.
  static OpenUIValue? resolveField(OpenUIValue? value, String path) {
    if (path.isEmpty || JS.isNullish(value)) return null;
    var current = value;
    for (final part in path.split('.')) {
      if (JS.isNullish(current)) return null;
      current = JS.property(current, part);
    }
    return current;
  }

  static bool _isNumericLike(OpenUIValue? value) => switch (value) {
    OpenUINumber() => true,
    OpenUIString(:final value) => value.isNotEmpty && !JS.stringToNumber(value).isNaN,
    _ => false,
  };

  // `@Sort(array, field, direction)`: a stable sort by `field` (the item
  // itself when empty), numbers and numeric text as numbers, the rest as text;
  // a value that isn't an array comes back as it is.
  static OpenUIValue _sort(List<OpenUIValue?> args) {
    final array = _arg(args, 0);
    if (array is! OpenUIArray) return array ?? OpenUINull.instance;
    final field = JS.toStringOrEmpty(_arg(args, 1));
    final direction = _arg(args, 2);
    final descending = (JS.isNullish(direction) ? 'asc' : JS.stringOf(direction)) == 'desc';
    double compare(OpenUIValue a, OpenUIValue b) {
      final left = field.isEmpty ? a : resolveField(a, field);
      final right = field.isEmpty ? b : resolveField(b, field);
      final order = _isNumericLike(left) && _isNumericLike(right)
          ? JS.toNumber(left) - JS.toNumber(right)
          : compareText(JS.toStringOrEmpty(left), JS.toStringOrEmpty(right)).toDouble();
      return descending ? -order : order;
    }

    // List.sort isn't stable: ties keep their order through the index.
    final indexed = array.items.indexed.toList()
      ..sort((a, b) {
        final order = compare(a.$2, b.$2);
        if (order < 0) return -1;
        if (order > 0) return 1;
        return a.$1.compareTo(b.$1);
      });
    return OpenUIArray([for (final (_, item) in indexed) item]);
  }

  /// How `@Sort` orders two texts: ignoring case first, then lower case
  /// before upper case.
  ///
  /// OpenUI orders text with the locale's collation (`localeCompare`), which
  /// also orders accented letters next to their base letter; this doesn't
  /// yet, so `é` sorts after `z`.
  static int compareText(String a, String b) {
    final folded = a.toLowerCase().compareTo(b.toLowerCase());
    if (folded != 0) return folded;
    return _swapCase(a).compareTo(_swapCase(b));
  }

  static String _swapCase(String text) {
    return String.fromCharCodes([
      for (final unit in text.codeUnits)
        if (unit >= 0x61 && unit <= 0x7a) unit - 0x20 else if (unit >= 0x41 && unit <= 0x5a) unit + 0x20 else unit,
    ]);
  }

  // `@Filter(array, field, operator, value)`: the items whose `field` (the
  // item itself when empty) compares with `value` by `operator`; an unknown
  // operator keeps nothing, and a value that isn't an array gives [].
  static OpenUIValue _filter(List<OpenUIValue?> args) {
    final array = _arg(args, 0);
    if (array is! OpenUIArray) return OpenUIArray(const []);
    final field = JS.toStringOrEmpty(_arg(args, 1));
    final operatorArg = _arg(args, 2);
    final operator = JS.isNullish(operatorArg) ? '==' : JS.stringOf(operatorArg);
    final target = _arg(args, 3);
    bool keeps(OpenUIValue item) {
      final value = field.isEmpty ? item : resolveField(item, field);
      return switch (operator) {
        '==' => JS.looseEquals(value, target),
        '!=' => !JS.looseEquals(value, target),
        '>' => JS.toNumber(value) > JS.toNumber(target),
        '<' => JS.toNumber(value) < JS.toNumber(target),
        '>=' => JS.toNumber(value) >= JS.toNumber(target),
        '<=' => JS.toNumber(value) <= JS.toNumber(target),
        // `String.prototype.includes`, by code unit.
        'contains' => JS.toStringOrEmpty(value).contains(JS.toStringOrEmpty(target)),
        _ => false,
      };
    }

    return OpenUIArray(array.items.where(keeps));
  }
}
