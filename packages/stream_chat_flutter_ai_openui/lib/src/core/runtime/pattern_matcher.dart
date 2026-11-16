/// Matching the regular expressions of `pattern` rules in time linear in the
/// input.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';

/// A regular expression of a `pattern` rule, written as JavaScript writes
/// one, matched in time linear in the input.
///
/// The model writes these patterns and they are matched as a person types, so
/// a backtracking matcher such as [RegExp], which can't be interrupted, would
/// freeze the app on a pattern such as `(a+)+$` or `x.*x.*y`. This one runs
/// every way through the pattern at once, a Pike virtual machine, so matching
/// costs at most the input's length times the pattern's size. A pattern is
/// rejected when it is longer than [maxPatternLength], or when it expands past
/// [maxProgramSize] items once its counts are written out, such as
/// `(?:a{100}){11}` or `a{0,600}b{0,600}`, or when compiling it costs more
/// than [maxCompileCost], such as a long class or an empty group counted many
/// times.
///
/// It takes JavaScript's syntax without flags: literals, `.`, classes,
/// `\d \D \w \W \s \S \b \B`, the character escapes, `^` and `$` at the
/// input's ends, groups, alternation and the counts `* + ? {n} {n,} {n,m}`,
/// greedy or lazy. `\u{X}` is a code point, as with the `u` flag, and the
/// input is read by code point. A lookahead right after a leading `^`, such as
/// `^(?=.*\d).{8,}$`, is matched on its own from the input's start, when no
/// `|` follows outside a group; any other lookahead, a lookbehind, a
/// backreference, a legacy octal or control escape, a Unicode property escape
/// or an inline flag makes the pattern invalid.
final class PatternMatcher {
  PatternMatcher._(this._program, this._required, this._forbidden);

  /// The most items a pattern may expand to once its counts are written out.
  static const maxProgramSize = 1000;

  /// The most work compiling a pattern may take: one for each part written
  /// out, one more for each class member past the first, and one for each
  /// instruction compiled.
  static const maxCompileCost = 4000;

  /// The longest pattern compiled, in UTF-16 code units.
  static const maxPatternLength = 1000;

  /// The longest input matched, in UTF-16 code units; longer input matches
  /// nothing.
  static const maxInputLength = 4096;

  final _Program _program;
  final List<_Program> _required;
  final List<_Program> _forbidden;

  /// [pattern] compiled, or `null` when it is rejected or isn't valid.
  static PatternMatcher? compile(String pattern) {
    if (pattern.length > maxPatternLength) return null;
    try {
      final parsed = _Parser(pattern.runes.toList()).parsePattern();
      final nodes = [parsed.rest, ...parsed.required, ...parsed.forbidden];
      if (nodes.fold(0, (sum, node) => _bounded(sum + node.size)) > maxProgramSize) return null;
      final budget = _Budget();
      return PatternMatcher._(
        _Program.compile(parsed.rest, budget),
        [for (final node in parsed.required) _Program.compile(node, budget)],
        [for (final node in parsed.forbidden) _Program.compile(node, budget)],
      );
    } on FormatException {
      return null;
    }
  }

  /// Whether the pattern finds a match in [input]; never for input longer
  /// than [maxInputLength].
  bool hasMatch(String input) {
    if (input.length > maxInputLength) return false;
    final runes = input.runes.toList();
    return _required.every((program) => program.matches(runes, anchored: true)) &&
        !_forbidden.any((program) => program.matches(runes, anchored: true)) &&
        _program.matches(runes, anchored: false);
  }

  /// How many items [pattern] expands to once its counts are written out,
  /// past [maxProgramSize] counted as one more, or `null` when it isn't
  /// valid: 4 for `a{0,3}b`, 6 for `(?:ab){3}` and 2 for `a+`, which is `aa*`.
  @visibleForTesting
  static int? sizeOf(String pattern) {
    try {
      final parsed = _Parser(pattern.runes.toList()).parsePattern();
      return [
        parsed.rest,
        ...parsed.required,
        ...parsed.forbidden,
      ].fold<int>(0, (sum, node) => _bounded(sum + node.size));
    } on FormatException {
      return null;
    }
  }
}

int _bounded(int size) => size > PatternMatcher.maxProgramSize ? PatternMatcher.maxProgramSize + 1 : size;

// The pattern, read.

sealed class _Node {
  const _Node();

  // The items it expands to once its counts are written out.
  int get size;
}

final class _Empty extends _Node {
  const _Empty();

  @override
  int get size => 0;
}

final class _Char extends _Node {
  const _Char(this.test, {this.weight = 1});

  final bool Function(int rune) test;

  // How many tests [test] runs: a class's members, 1 otherwise.
  final int weight;

  @override
  int get size => 1;
}

enum _AssertKind { start, end, wordBoundary, notWordBoundary }

final class _Assert extends _Node {
  const _Assert(this.kind);

  final _AssertKind kind;

  @override
  int get size => 1;
}

final class _Sequence extends _Node {
  const _Sequence(this.items);

  final List<_Node> items;

  @override
  int get size => items.fold(0, (sum, item) => _bounded(sum + item.size));
}

final class _Alternation extends _Node {
  const _Alternation(this.options);

  final List<_Node> options;

  @override
  int get size => options.fold(0, (sum, option) => _bounded(sum + option.size));
}

final class _Repeat extends _Node {
  const _Repeat(this.item, this.min, this.max, {required this.plus});

  final _Node item;
  final int min;

  // `null` for no upper bound.
  final int? max;

  // Whether it was written `+`, which counts as the item twice.
  final bool plus;

  @override
  int get size {
    final int times;
    if (plus) {
      times = 2;
    } else if (min == 0 && (max == null || max == 1)) {
      // `*` and `?` add nothing.
      times = 1;
    } else if (max == null) {
      times = min + 1;
    } else {
      times = max!;
    }
    return _bounded(item.size * (times < 1 ? 1 : times));
  }
}

final class _ParsedPattern {
  const _ParsedPattern(this.rest, this.required, this.forbidden);

  final _Node rest;
  final List<_Node> required;
  final List<_Node> forbidden;
}

final class _Parser {
  _Parser(this._source);

  final List<int> _source;
  int _index = 0;

  static const _maxCount = PatternMatcher.maxProgramSize + 1;

  static final _groupName = RegExp(r'^[A-Za-z_$][\w$]*$');

  _ParsedPattern parsePattern() {
    final required = <_Node>[];
    final forbidden = <_Node>[];
    if (_at(0) == 0x5e) {
      var index = 1;
      while (_at(index) == 0x28 && _at(index + 1) == 0x3f && (_at(index + 2) == 0x3d || _at(index + 2) == 0x21)) {
        _index = index + 3;
        final body = _parseAlternation();
        _expect(0x29);
        (_at(index + 2) == 0x3d ? required : forbidden).add(body);
        index = _index;
      }
      if (required.isNotEmpty || forbidden.isNotEmpty) {
        _index = index;
        // `^(?=a)b|c` checks the lookahead in the first option only, so an
        // alternation after the lookaheads isn't matched on its own.
        final rest = _parseSequence();
        if (_current == 0x7c) throw const FormatException('Alternation after a lookahead');
        if (_index != _source.length) throw const FormatException('Unexpected )');
        return _ParsedPattern(
          _Sequence([const _Assert(_AssertKind.start), rest]),
          required,
          forbidden,
        );
      }
      _index = 0;
    }
    final node = _parseAlternation();
    if (_index != _source.length) throw const FormatException('Unexpected )');
    return _ParsedPattern(node, required, forbidden);
  }

  int? _at(int index) => index < _source.length ? _source[index] : null;

  int? get _current => _index < _source.length ? _source[_index] : null;

  void _expect(int rune) {
    if (_current != rune) throw FormatException('Expected ${String.fromCharCode(rune)}');
    _index++;
  }

  _Node _parseAlternation() {
    final options = [_parseSequence()];
    while (_current == 0x7c) {
      _index++;
      options.add(_parseSequence());
    }
    return options.length == 1 ? options.single : _Alternation(options);
  }

  _Node _parseSequence() {
    final items = <_Node>[];
    while (_current != null && _current != 0x7c && _current != 0x29) {
      final atom = _parseAtom();
      items.add(_parseCount(atom));
    }
    if (items.isEmpty) return const _Empty();
    return items.length == 1 ? items.single : _Sequence(items);
  }

  _Node _parseCount(_Node atom) {
    final rune = _current;
    int min;
    int? max;
    var plus = false;
    if (rune == 0x2a /* * */ ) {
      (min, max) = (0, null);
      _index++;
    } else if (rune == 0x2b) {
      (min, max, plus) = (1, null, true);
      _index++;
    } else if (rune == 0x3f) {
      (min, max) = (0, 1);
      _index++;
    } else if (rune == 0x7b && _braceCount() != null) {
      final (low, high, end) = _braceCount()!;
      (min, max) = (low, high);
      _index = end;
    } else {
      return atom;
    }
    if (atom is _Assert || atom is _Empty) throw const FormatException('Nothing to repeat');
    if (max != null && max < min) throw const FormatException('Numbers out of order');
    // Lazy and greedy counts match the same inputs.
    if (_current == 0x3f) _index++;
    final next = _current;
    if (next == 0x2a || next == 0x2b || next == 0x3f || (next == 0x7b && _braceCount() != null)) {
      throw const FormatException('Nothing to repeat');
    }
    return _Repeat(atom, min, max, plus: plus);
  }

  // `{n}`, `{n,}` or `{n,m}` at the current index, with the index after it;
  // `null` when the brace starts no count, and is a literal brace.
  (int, int?, int)? _braceCount() {
    var index = _index + 1;
    int? readNumber() {
      final start = index;
      var value = 0;
      while (_isDigit(_at(index) ?? 0)) {
        if (value < _maxCount) value = value * 10 + _at(index)! - 0x30;
        index++;
      }
      if (index == start) return null;
      return value > _maxCount ? _maxCount : value;
    }

    final min = readNumber();
    if (min == null) return null;
    int? max = min;
    if (_at(index) == 0x2c) {
      index++;
      max = readNumber();
    }
    if (_at(index) != 0x7d) return null;
    return (min, max, index + 1);
  }

  _Node _parseAtom() {
    final rune = _current!;
    switch (rune) {
      case 0x5e: // ^
        _index++;
        return const _Assert(_AssertKind.start);
      case 0x24: // $
        _index++;
        return const _Assert(_AssertKind.end);
      case 0x2e: // .
        _index++;
        return _Char((r) => !_isLineTerminator(r));
      case 0x28: // (
        return _parseGroup();
      case 0x5b: // [
        return _parseClass();
      case 0x5c: // \
        return _parseEscape();
      case 0x2a || 0x2b || 0x3f: // * + ?
        throw const FormatException('Nothing to repeat');
      case 0x7b when _braceCount() != null: // {
        throw const FormatException('Nothing to repeat');
      default:
        _index++;
        return _Char((r) => r == rune);
    }
  }

  _Node _parseGroup() {
    _index++;
    if (_current == 0x3f) {
      final kind = _at(_index + 1);
      if (kind == 0x3a) {
        _index += 2;
      } else if (kind == 0x3c && _at(_index + 2) != 0x3d && _at(_index + 2) != 0x21) {
        // A named group.
        final close = _source.indexOf(0x3e, _index + 2);
        if (close < 0 || !_groupName.hasMatch(String.fromCharCodes(_source.sublist(_index + 2, close)))) {
          throw const FormatException('Invalid group name');
        }
        _index = close + 1;
      } else {
        // A lookahead past the pattern's start, a lookbehind or a flag.
        throw const FormatException('Unsupported group');
      }
    }
    final body = _parseAlternation();
    _expect(0x29);
    return body;
  }

  _Node _parseEscape() {
    _index++;
    final rune = _current;
    if (rune == null) throw const FormatException(r'\ at end of pattern');
    switch (rune) {
      case 0x62: // b
        _index++;
        return const _Assert(_AssertKind.wordBoundary);
      case 0x42: // B
        _index++;
        return const _Assert(_AssertKind.notWordBoundary);
      default:
        if (_classEscape() case final test?) return _Char(test);
        final value = _characterEscape(inClass: false);
        return _Char((r) => r == value);
    }
  }

  // The class of `\d \D \w \W \s \S` at the index, past it; `null` for
  // another escape.
  bool Function(int)? _classEscape() {
    final test = switch (_current) {
      0x64 => _isDigit,
      0x44 => (int r) => !_isDigit(r),
      0x77 => _isWord,
      0x57 => (int r) => !_isWord(r),
      0x73 => _isSpace,
      0x53 => (int r) => !_isSpace(r),
      _ => null,
    };
    if (test != null) _index++;
    return test;
  }

  // The character a character escape names, the index past it.
  int _characterEscape({required bool inClass}) {
    final rune = _current!;
    _index++;
    switch (rune) {
      case 0x74: // t
        return 0x09;
      case 0x6e: // n
        return 0x0a;
      case 0x76: // v
        return 0x0b;
      case 0x66: // f
        return 0x0c;
      case 0x72: // r
        return 0x0d;
      case 0x62 when inClass: // b, a backspace in a class
        return 0x08;
      case 0x30: // 0
        // `\0` followed by a digit is a legacy octal escape.
        if (_isDigit(_current ?? 0)) throw const FormatException('Octal escape');
        return 0x00;
      case 0x63: // c
        final letter = _current;
        if (letter != null && ((letter | 0x20) >= 0x61 && (letter | 0x20) <= 0x7a)) {
          _index++;
          return letter % 32;
        }
        // `\c` without a letter is a backslash and a `c`, but a legacy
        // control escape in a class.
        if (inClass) throw const FormatException(r'Invalid \c escape');
        _index--;
        return 0x5c;
      case 0x78: // x
        if (_hex(2) case final value?) return value;
        return 0x78;
      case 0x75: // u
        if (_current == 0x7b) {
          final close = _source.indexOf(0x7d, _index);
          if (close > _index + 1 && close <= _index + 7) {
            final value = int.tryParse(String.fromCharCodes(_source.sublist(_index + 1, close)), radix: 16);
            if (value != null && value <= 0x10ffff) {
              _index = close + 1;
              return value;
            }
          }
          throw const FormatException(r'Invalid \u{} escape');
        }
        if (_hex(4) case final value?) return value;
        return 0x75;
      case 0x6b: // k, a named backreference
      case 0x70 || 0x50: // p P, a Unicode property
        throw const FormatException('Unsupported escape');
      default:
        // A backreference, or a legacy octal escape in a class.
        if (rune >= 0x31 && rune <= 0x39) throw const FormatException('Backreference');
        // Any other escaped character stands for itself.
        return rune;
    }
  }

  int? _hex(int digits) {
    if (_index + digits > _source.length) return null;
    final text = String.fromCharCodes(_source.sublist(_index, _index + digits));
    if (!RegExp(r'^[0-9A-Fa-f]+$').hasMatch(text)) return null;
    _index += digits;
    return int.parse(text, radix: 16);
  }

  _Node _parseClass() {
    _index++;
    var negated = false;
    if (_current == 0x5e) {
      negated = true;
      _index++;
    }
    final tests = <bool Function(int)>[];
    while (true) {
      final rune = _current;
      if (rune == null) throw const FormatException('Unterminated class');
      if (rune == 0x5d) {
        _index++;
        break;
      }
      final (lowTest, low) = _classAtom();
      if (lowTest != null) {
        tests.add(lowTest);
        continue;
      }
      if (_current == 0x2d && _at(_index + 1) != null && _at(_index + 1) != 0x5d) {
        _index++;
        final (highTest, high) = _classAtom();
        if (highTest != null) {
          // `[a-\d]` is `a`, `-` and the digits.
          tests
            ..add((r) => r == low || r == 0x2d)
            ..add(highTest);
          continue;
        }
        if (high! < low!) throw const FormatException('Range out of order');
        tests.add((r) => r >= low && r <= high);
      } else {
        tests.add((r) => r == low);
      }
    }
    return _Char((r) => tests.any((test) => test(r)) != negated, weight: tests.isEmpty ? 1 : tests.length);
  }

  // One class member: a class escape's test, or a character.
  (bool Function(int)?, int?) _classAtom() {
    final rune = _current!;
    if (rune != 0x5c) {
      _index++;
      return (null, rune);
    }
    _index++;
    if (_current == null) throw const FormatException(r'\ at end of pattern');
    if (_classEscape() case final test?) return (test, null);
    // `\B` and `\-` in a class are the characters themselves.
    return (null, _characterEscape(inClass: true));
  }
}

bool _isDigit(int rune) => rune >= 0x30 && rune <= 0x39;

bool _isWord(int rune) =>
    _isDigit(rune) || (rune >= 0x41 && rune <= 0x5a) || (rune >= 0x61 && rune <= 0x7a) || rune == 0x5f;

bool _isLineTerminator(int rune) => rune == 0x0a || rune == 0x0d || rune == 0x2028 || rune == 0x2029;

// JavaScript's `\s`: its white space and line terminators.
bool _isSpace(int rune) =>
    (rune >= 0x09 && rune <= 0x0d) ||
    rune == 0x20 ||
    rune == 0xa0 ||
    rune == 0x1680 ||
    (rune >= 0x2000 && rune <= 0x200a) ||
    rune == 0x2028 ||
    rune == 0x2029 ||
    rune == 0x202f ||
    rune == 0x205f ||
    rune == 0x3000 ||
    rune == 0xfeff;

// The pattern, compiled for the Pike virtual machine.

sealed class _Instruction {}

final class _Test extends _Instruction {
  _Test(this.test);

  final bool Function(int) test;
}

final class _Split extends _Instruction {
  _Split(this.first, this.second);

  int first;
  int second;
}

final class _Jump extends _Instruction {
  _Jump(this.target);

  int target;
}

final class _Check extends _Instruction {
  _Check(this.kind);

  final _AssertKind kind;
}

final class _Match extends _Instruction {}

// The work spent compiling a pattern's programs, besides their instructions.
final class _Budget {
  int spent = 0;
}

final class _Program {
  _Program._(this._instructions);

  // Throws a [FormatException] when compiling [node] would take [budget]
  // past [PatternMatcher.maxCompileCost].
  factory _Program.compile(_Node node, _Budget budget) {
    final instructions = <_Instruction>[];
    _emit(node, instructions, budget);
    instructions.add(_Match());
    budget.spent += instructions.length;
    return _Program._(instructions);
  }

  final List<_Instruction> _instructions;

  static void _emit(_Node node, List<_Instruction> out, _Budget budget) {
    budget.spent += node is _Char ? node.weight : 1;
    if (budget.spent + out.length > PatternMatcher.maxCompileCost) {
      throw const FormatException('Pattern too costly');
    }
    switch (node) {
      case _Empty():
        break;
      case _Char(:final test):
        out.add(_Test(test));
      case _Assert(:final kind):
        out.add(_Check(kind));
      case _Sequence(:final items):
        for (final item in items) {
          _emit(item, out, budget);
        }
      case _Alternation(:final options):
        final jumps = <_Jump>[];
        for (var i = 0; i < options.length; i++) {
          if (i < options.length - 1) {
            final split = _Split(out.length + 1, 0);
            out.add(split);
            _emit(options[i], out, budget);
            final jump = _Jump(0);
            out.add(jump);
            jumps.add(jump);
            split.second = out.length;
          } else {
            _emit(options[i], out, budget);
          }
        }
        for (final jump in jumps) {
          jump.target = out.length;
        }
      case _Repeat(:final item, :final min, :final max):
        for (var i = 0; i < min; i++) {
          _emit(item, out, budget);
        }
        if (max == null) {
          // item*: L: split body, end; body; jump L.
          final split = _Split(out.length + 1, 0);
          final loop = out.length;
          out.add(split);
          _emit(item, out, budget);
          out.add(_Jump(loop));
          split.second = out.length;
        } else {
          // Up to max - min more, each optional: (item(item(...)?)?)?.
          final splits = <_Split>[];
          for (var i = min; i < max; i++) {
            final split = _Split(out.length + 1, 0);
            out.add(split);
            splits.add(split);
            _emit(item, out, budget);
          }
          for (final split in splits) {
            split.second = out.length;
          }
        }
    }
  }

  /// Whether the program matches in [input]: from its start when [anchored],
  /// anywhere in it otherwise.
  bool matches(List<int> input, {required bool anchored}) {
    // The position each instruction was last added at, so each thread is
    // added once per position.
    final added = List.filled(_instructions.length, -1);
    var current = <int>[];
    var next = <int>[];

    // Adds [pc], and what it reaches without reading, to [list] at
    // [position]; true when that reaches the match.
    bool add(List<int> list, int pc, int position) {
      final stack = [pc];
      while (stack.isNotEmpty) {
        final at = stack.removeLast();
        if (added[at] == position) continue;
        added[at] = position;
        switch (_instructions[at]) {
          case _Match():
            return true;
          case _Test():
            list.add(at);
          case _Jump(:final target):
            stack.add(target);
          case _Split(:final first, :final second):
            stack
              ..add(second)
              ..add(first);
          case _Check(:final kind):
            if (_holds(kind, input, position)) stack.add(at + 1);
        }
      }
      return false;
    }

    for (var position = 0; position <= input.length; position++) {
      if ((position == 0 || !anchored) && add(current, 0, position)) return true;
      if (position == input.length || (current.isEmpty && anchored)) return false;
      final rune = input[position];
      for (final pc in current) {
        if ((_instructions[pc] as _Test).test(rune) && add(next, pc + 1, position + 1)) return true;
      }
      final done = current..clear();
      current = next;
      next = done;
    }
    return false;
  }

  static bool _holds(_AssertKind kind, List<int> input, int position) {
    bool wordAt(int index) => index >= 0 && index < input.length && _isWord(input[index]);
    return switch (kind) {
      _AssertKind.start => position == 0,
      _AssertKind.end => position == input.length,
      _AssertKind.wordBoundary => wordAt(position - 1) != wordAt(position),
      _AssertKind.notWordBoundary => wordAt(position - 1) == wordAt(position),
    };
  }
}
