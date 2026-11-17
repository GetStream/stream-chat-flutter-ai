/// Preparing a reply's text for reading as OpenUI Lang while it streams.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/preprocessor.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';

/// The preparation of a text that only grows at its end, read a piece at a
/// time.
///
/// After each [append], the first [length] of [codeUnits] are what
/// [Preprocessor.prepare] gives for the whole text so far. Each append reads
/// what it adds, and again only the few code units at the end that what
/// follows can still drop: a `/` that may start a comment and the white
/// space before it, or backticks that may start a fence. Preparing a whole
/// text therefore costs time in proportion to its length.
final class IncrementalPreprocessor {
  /// The prepared text so far, as UTF-16 code units, followed by white space
  /// that isn't part of it: the prepared text is the first [length] of them.
  List<int> get codeUnits => _output;
  final List<int> _output = [];

  /// How many of [codeUnits] the prepared text holds.
  int get length => _length;
  var _length = 0;

  /// How many of [codeUnits] stay the same as text is appended, unless
  /// [append] returns `true`: every code unit that nothing still to come can
  /// drop.
  int get stableLength => _committed;

  /// A number that changes whenever an append may have changed the prepared
  /// text, and only then.
  int get revision => _revision;
  var _revision = 0;

  /// How many code units all appends have read.
  ///
  /// Only the tests read it.
  int get debugReadCodeUnits => _debugReadCodeUnits;
  var _debugReadCodeUnits = 0;

  final _fences = _FenceStripper();
  var _comments = _CommentStripper();

  // How many of `_output` won't change, and where the last code unit that
  // isn't white space ends among them.
  var _committed = 0;
  var _committedContentEnd = 0;

  // Whether any code unit that isn't white space has been kept: until then,
  // leading white space is dropped.
  var _keptContent = false;

  /// Appends the code units of `text` from `start` on, and returns whether
  /// the first Markdown code fence has just arrived.
  ///
  /// From then on only fenced text is kept, and what came before the fence
  /// is dropped, so the prepared text no longer starts with what it was. Its
  /// end can also be dropped without a fence, when the last line turns into
  /// a comment; [length] then gets shorter.
  bool append(String text, [int start = 0]) {
    final previousLength = _length;
    final previousStable = _committed;
    final previousEnd = previousLength > previousStable
        ? _output.sublist(previousStable, previousLength)
        : const <int>[];

    final stripped = _fences.feed(text, start);
    final startedOver = _fences.startedOver;
    if (startedOver) {
      _comments = _CommentStripper();
      _output.clear();
      _committed = 0;
      _committedContentEnd = 0;
      _keptContent = false;
    }
    _output.removeRange(_committed, _output.length);
    _comments.feed(stripped, _commit);
    final undecided = _trimmedStart(_comments.undecided(_fences.undecided));
    _output.addAll(undecided);
    final undecidedEnd = _contentEnd(undecided);
    _length = undecidedEnd == null ? _committedContentEnd : _committed + undecidedEnd;
    _debugReadCodeUnits += _fences.debugRead + _comments.debugRead;
    if (startedOver || _length != previousLength || !_endIs(previousEnd, previousStable)) _revision += 1;
    return startedOver;
  }

  // Whether the prepared text from [start] to its end holds [units].
  bool _endIs(List<int> units, int start) {
    for (var index = 0; index < units.length; index += 1) {
      if (_output[start + index] != units[index]) return false;
    }
    return true;
  }

  void _commit(int unit) {
    final isWhitespace = JS.isWhitespace(unit);
    if (isWhitespace && !_keptContent) return;
    _output.add(unit);
    _committed += 1;
    if (isWhitespace) return;
    _keptContent = true;
    _committedContentEnd = _committed;
  }

  List<int> _trimmedStart(List<int> units) {
    if (_keptContent) return units;
    var start = 0;
    while (start < units.length && JS.isWhitespace(units[start])) {
      start += 1;
    }
    return start == 0 ? units : units.sublist(start);
  }

  // Where the last code unit that isn't white space ends, or null when every
  // one is white space.
  static int? _contentEnd(List<int> units) {
    var end = units.length;
    while (end > 0 && JS.isWhitespace(units[end - 1])) {
      end -= 1;
    }
    return end == 0 ? null : end;
  }
}

// What `Preprocessor.stripFences` keeps, a code unit at a time: before any
// fence the text is kept as it is, and once one is found only the text inside
// fences is.
final class _FenceStripper {
  static const _fenceLength = 3;

  var _fenced = false;
  var _place = _Place.outside;
  var _quote = _Quote.none;
  var _blocks = 0;

  // One or two backticks at the end, which a fence needs the next code units
  // to tell apart.
  var _pending = '';

  // Whether the last `feed` found the first fence, which drops everything kept
  // before it.
  bool startedOver = false;

  // How many code units the last `feed` read, for the tests.
  int debugRead = 0;

  // What the undecided backticks read as if the text ended here: text, unless
  // they are outside fences, which drop text.
  String get undecided => !_fenced || _place == _Place.content ? _pending : '';

  List<int> feed(String text, int start) {
    final input = start == 0 && _pending.isEmpty ? text : _pending + text.substring(start);
    _pending = '';
    startedOver = false;
    debugRead = input.length;
    final output = <int>[];
    var index = 0;
    while (index < input.length) {
      final unit = input.codeUnitAt(index);
      if (_place == _Place.language) {
        if (unit == _lineFeed) {
          _place = _Place.content;
          _quote = _Quote.none;
        }
        index += 1;
        continue;
      }
      if (_quote == _Quote.none && unit == _backtick) {
        final isFence = _fenceAt(input, index);
        if (isFence == null) {
          _pending = input.substring(index);
          break;
        }
        if (isFence) {
          if (!_fenced) {
            _fenced = true;
            startedOver = true;
            output.clear();
          }
          if (_place == _Place.content) {
            _place = _Place.outside;
          } else {
            _blocks += 1;
            if (_blocks > 1) output.add(_lineFeed);
            _place = _Place.language;
          }
          index += _fenceLength;
          continue;
        }
      }
      _quote = switch (_quote) {
        _Quote.escaped => _Quote.open,
        _Quote.open when unit == _backslash => _Quote.escaped,
        _Quote.open when unit == _doubleQuote => _Quote.none,
        _Quote.open => _Quote.open,
        _Quote.none => unit == _doubleQuote ? _Quote.open : _Quote.none,
      };
      if (!_fenced || _place == _Place.content) output.add(unit);
      index += 1;
    }
    return output;
  }

  // Whether three backticks start at [index], or null when the text ends
  // before that is known.
  static bool? _fenceAt(String input, int index) {
    if (index + 1 < input.length && input.codeUnitAt(index + 1) != _backtick) return false;
    if (index + 2 >= input.length) return null;
    return input.codeUnitAt(index + 2) == _backtick;
  }
}

enum _Place { outside, language, content }

enum _Quote { none, open, escaped }

// What `Preprocessor.stripComments` keeps, a code unit at a time. A code unit
// is passed on as soon as nothing that follows can drop it: only white space
// and a `/` outside strings wait, since a comment that starts after them drops
// them too.
final class _CommentStripper {
  // The string open at this point, and whether a `\` inside it waits for the
  // code unit it escapes.
  int? _quote;
  var _escaped = false;

  // Whether the rest of the line is a comment.
  var _inComment = false;

  // White space and a `/` outside strings, which a comment starting next
  // would drop.
  final _held = <int>[];

  // How many code units the last `feed` and `undecided` read, for the
  // tests.
  int debugRead = 0;

  // Passes on to `keep`, in order, the code units of `input` that stay in the
  // text whatever follows.
  void feed(List<int> input, void Function(int unit) keep) {
    debugRead = input.length;
    for (final unit in input) {
      _step(unit, keep);
    }
  }

  void _step(int unit, void Function(int unit) keep) {
    if (unit == _lineFeed) {
      // A comment drops the white space before it, as trimming the line's
      // end would.
      if (!_inComment) _held.forEach(keep);
      _held.clear();
      _inComment = false;
      _escaped = false;
      keep(_lineFeed);
      return;
    }
    if (_inComment) return;
    if (_quote case final quote?) {
      if (_escaped) {
        _escaped = false;
      } else if (unit == _backslash) {
        _escaped = true;
      } else if (unit == quote) {
        _quote = null;
      }
      keep(unit);
      return;
    }
    if (_held.lastOrNull == _slash) {
      if (unit == _slash) {
        _inComment = true;
        return;
      }
      _release(keep);
    }
    if (unit == _hash) {
      _inComment = true;
      return;
    }
    if (unit == _slash || JS.isWhitespace(unit)) {
      _held.add(unit);
      return;
    }
    _release(keep);
    if (unit == _doubleQuote || unit == _singleQuote) _quote = unit;
    keep(unit);
  }

  void _release(void Function(int unit) keep) {
    _held
      ..forEach(keep)
      ..clear();
  }

  // What the code units still waiting read as if `rest` ended the text.
  // White space with nothing after it isn't part of the text, so it is left
  // out rather than copied again on every append.
  List<int> undecided(String rest) {
    if (_inComment) return const [];
    if (rest.isEmpty && _held.lastOrNull != _slash) return const [];
    debugRead += _held.length + rest.length;
    return [..._held, ...rest.codeUnits];
  }
}

const _lineFeed = 0x0a;
const _doubleQuote = 0x22;
const _hash = 0x23;
const _singleQuote = 0x27;
const _slash = 0x2f;
const _backslash = 0x5c;
const _backtick = 0x60;
