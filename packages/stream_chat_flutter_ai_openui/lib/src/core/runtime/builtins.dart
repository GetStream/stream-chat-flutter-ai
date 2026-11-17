/// The built-in data functions of OpenUI Lang: `@Count`, `@Sort`, `@Round`….
///
/// Internal to the package.
@internal
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
import 'package:stream_core/stream_core.dart' show normalizeStringForSort;

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
  //
  // Text is ordered by its sort key, then ignoring case, then lower case
  // before upper case. OpenUI orders text with the locale's collation
  // (`localeCompare`); the sort key is instead the order Stream's SDKs share:
  // it folds case and the accents and ligatures of Latin letters, so `é` sorts
  // next to `e`, and trims spaces and apostrophes from the ends; other scripts
  // keep their letters as they are.
  static OpenUIValue _sort(List<OpenUIValue?> args) {
    final array = _arg(args, 0);
    if (array is! OpenUIArray) return array ?? OpenUINull.instance;
    final field = JS.toStringOrEmpty(_arg(args, 1));
    final direction = _arg(args, 2);
    final descending = (JS.isNullish(direction) ? 'asc' : JS.stringOf(direction)) == 'desc';
    // Each item's field, read once, with its sort key.
    final decorated = [
      for (final (index, item) in array.items.indexed)
        _SortItem.of(index, field.isEmpty ? item : resolveField(item, field)),
    ];
    int compare(_SortItem a, _SortItem b) {
      final double order;
      if (a.number != null && b.number != null) {
        order = a.number! - b.number!;
      } else {
        final key = a.key.compareTo(b.key);
        order = (key != 0 ? key : _compareFolded(a.text, b.text)).toDouble();
      }
      final directed = descending ? -order : order;
      if (directed < 0) return -1;
      if (directed > 0) return 1;
      // List.sort isn't stable: ties, and NaN, keep their order through the
      // index.
      return a.index.compareTo(b.index);
    }

    decorated.sort(compare);
    final items = array.items;
    return OpenUIArray([for (final item in decorated) items[item.index]]);
  }

  // Ignoring case first, then lower case before upper case.
  static int _compareFolded(String a, String b) {
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

// An item of `@Sort`: its index, its field as a number when it is one, and as
// text with its sort key, each worked out once.
final class _SortItem {
  _SortItem(this.index, this.number, this.text, this.key);

  factory _SortItem.of(int index, OpenUIValue? value) {
    // Text too for a number, which is compared as text with a field that isn't.
    final text = JS.toStringOrEmpty(value);
    return _SortItem(
      index,
      Builtins._isNumericLike(value) ? JS.toNumber(value) : null,
      text,
      normalizeStringForSort(text),
    );
  }

  final int index;
  final double? number;
  final String text;
  final String key;
}
