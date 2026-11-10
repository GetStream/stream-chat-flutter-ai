/// Reading an OpenUI Lang program while it streams in.
///
/// Internal to the package.
@internal
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/expression_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/incremental_preprocessor.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/lexer.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/materialization_cache.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/statements.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';

/// A reader of one OpenUI Lang program that arrives a piece at a time, such
/// as a reply streamed from a model.
///
/// Each call takes the text so far and returns what it renders now. A
/// statement is finished once its line has ended and the next line doesn't
/// continue it; finished statements are read once, and are read again only
/// when the text they came from is dropped: replaced by text that doesn't
/// continue it, cut by the first Markdown code fence, or turned into a
/// comment. The statement still arriving is read again on each call, as if
/// its open strings and brackets were closed; when closing them was needed,
/// the result is marked [ParseMeta.incomplete].
///
/// Some calls return the previous result instead of reading again, which
/// keeps the cost of the statement still arriving, and of building the
/// result, from growing with every piece of a long reply:
///
///  * when the prepared text hasn't changed since the last call;
///  * when the statement still arriving holds at least [longStatement] code
///    units and has grown by less than an eighth since it was last read;
///  * when the program holds more than [manyStatements] finished statements
///    and the text has grown by less than a sixty-fourth since the result was
///    last built.
///
/// While the stream runs, a statement still arriving that needs closing
/// doesn't replace a finished statement of the same name, and a `$name` that
/// ends the text isn't declared, since more of its name may follow. When the
/// caller says the stream has ended, both rules are lifted, and the result is
/// what [OpenUILangParser.parse] gives for the whole text, except that
/// [ParseMeta.statementCount] counts each definition of a name defined twice.
/// `complete` applies to one call only: text given after it continues the same
/// program, and the result it gave isn't remembered between calls.
///
/// One parser reads one program. Reading never throws.
///
/// ```dart
/// final parser = OpenUIStreamParser(schema);
/// parser.set('root = Card([TextCon');
/// final result = parser.set(
///   'root = Card([TextContent("Hi")])',
///   complete: true,
/// );
/// ```
///
/// See also:
///
///  * [OpenUILangParser], which reads a whole program at once.
final class OpenUIStreamParser {
  /// Creates a reader of programs that call the components of [schema].
  OpenUIStreamParser(this.schema);

  /// The components, functions and actions programs can call, and the
  /// library's root component.
  final OpenUILibrarySchema schema;

  /// How many code units a statement still arriving holds before it is read
  /// again only after it grows by an eighth.
  static const longStatement = 2048;

  /// How many finished statements a program holds before its result is built
  /// again only after the text grows by a sixty-fourth.
  static const manyStatements = 256;

  // How much a long statement still arriving grows before it is read again:
  // one part in this many of its length at the last read.
  static const _growthBeforeReread = 8;

  // How much the text of a program of many statements grows before its result
  // is built again: one part in this many of its length.
  static const _growthBeforeRebuild = 64;

  static const _tab = 0x09;
  static const _lineFeed = 0x0a;
  static const _carriageReturn = 0x0d;
  static const _space = 0x20;
  static const _doubleQuote = 0x22;
  static const _dollar = 0x24;
  static const _singleQuote = 0x27;
  static const _leftParen = 0x28;
  static const _rightParen = 0x29;
  static const _zero = 0x30;
  static const _nine = 0x39;
  static const _colon = 0x3a;
  static const _question = 0x3f;
  static const _upperA = 0x41;
  static const _upperZ = 0x5a;
  static const _leftBracket = 0x5b;
  static const _backslash = 0x5c;
  static const _rightBracket = 0x5d;
  static const _underscore = 0x5f;
  static const _lowerA = 0x61;
  static const _lowerZ = 0x7a;
  static const _leftBrace = 0x7b;
  static const _rightBrace = 0x7d;

  var _buffer = '';
  var _prepared = IncrementalPreprocessor();

  // How far into the prepared text statements are finished.
  var _completedEnd = 0;
  final _completed = <String, Statement>{};
  // Every finished definition, a name defined twice counted twice.
  var _completedCount = 0;

  // A new version for each statement read, so kept results can tell when a
  // statement they read has changed.
  final _completedVersions = <String, int>{};
  var _lastVersion = 0;
  var _cache = MaterializationCache();

  // Where the search for finished statements stopped: only the few code units
  // that later text can still drop are read again.
  var _scan = _ScanState(0);

  var _debugScannedCodeUnits = 0;

  // The result at the end of the stream for the text read so far, kept until
  // more text arrives.
  ParseResult? _completeResult;

  // The last result while the stream runs: the revision of the prepared text
  // and the `$name` ending the raw text it was built for, how long the
  // prepared text was, and the result.
  ({int revision, String? endingName, int length, ParseResult result})? _lastResult;

  // The last read of the statement still arriving: where it started, how
  // long it was, and its result. A statement finishing moves where the next
  // one starts, so a kept read never outlives its statement.
  ({int start, int length, ParseResult result})? _lastPendingRead;

  /// How many code units preparing the text has read since this parser last
  /// started over as if it had read nothing.
  ///
  /// Only the tests read it.
  int get debugPreparedCodeUnits => _prepared.debugReadCodeUnits;

  /// How many code units the search for finished statements has read since
  /// the text they came from was last dropped.
  ///
  /// Only the tests read it.
  int get debugScannedCodeUnits => _debugScannedCodeUnits;

  /// How many nodes have been resolved afresh, rather than reused, since the
  /// text the finished statements came from was last dropped.
  ///
  /// Only the tests read it.
  int get debugResolvedNodes => _cache.debugResolvedNodes;

  /// Reads `fullText`, the whole program so far, and returns what it renders.
  ///
  /// When `fullText` continues the text given before, only what was added is
  /// read. Otherwise this parser starts over, as if it had read nothing.
  ///
  /// If `complete` is `true`, the stream has ended: the statement still
  /// arriving counts as finished, replacing an earlier statement of the same
  /// name, and a `$name` that ends the text is declared.
  ParseResult set(String fullText, {bool complete = false}) {
    if (!fullText.startsWith(_buffer)) _reset();
    if (fullText.length > _buffer.length) {
      final start = _buffer.length;
      _buffer = fullText;
      _prepare(fullText, start);
    }
    return result(complete: complete);
  }

  /// Appends `chunk` to the text so far and returns what the program renders.
  ///
  /// `complete` is read as for [set].
  ParseResult push(String chunk, {bool complete = false}) {
    _buffer += chunk;
    _prepare(chunk, 0);
    return result(complete: complete);
  }

  /// What the text read so far renders, without reading anything new.
  ///
  /// `complete` is read as for [set].
  ParseResult result({bool complete = false}) {
    final pendingStart = _scanCompleted();
    if (complete) return _completeResult ??= _readWhole();
    final length = _prepared.length;
    final endingName = _endingName(_buffer);
    if (_lastResult case final last?) {
      if (last.revision == _prepared.revision && last.endingName == endingName) return last.result;
      if (_completedCount > manyStatements &&
          length >= last.length &&
          length - last.length < length ~/ _growthBeforeRebuild) {
        return last.result;
      }
    }
    final result = _readPendingIfGrown(math.min(pendingStart, length));
    _lastResult = (revision: _prepared.revision, endingName: endingName, length: length, result: result);
    return result;
  }

  // What the text renders with the statement still arriving, from `start` in
  // the prepared text, read again unless it is long and has grown too little
  // since its last read.
  ParseResult _readPendingIfGrown(int start) {
    final length = _prepared.length - start;
    if (_lastPendingRead case final last?
        when last.start == start &&
            last.length >= longStatement &&
            length >= last.length &&
            length - last.length < last.length ~/ _growthBeforeReread) {
      return last.result;
    }
    final result = _readPending(start);
    _lastPendingRead = (start: start, length: length, result: result);
    return result;
  }

  // What the text renders with the statement still arriving, from `start` in
  // the prepared text, read again.
  ParseResult _readPending(int start) {
    final pendingText = JS.trim(String.fromCharCodes(_prepared.codeUnits, start, _prepared.length));

    // A statement is finished only once text that isn't white space follows
    // its line, so with nothing left to read no statement is finished either.
    if (pendingText.isEmpty) return ParseResult.empty();

    final (closed, :wasIncomplete) = Statements.autoClose(pendingText);
    final pending = Statements.split(Lexer.tokenize(closed));
    if (pending.isEmpty) {
      if (_completedCount == 0) return ParseResult.empty(incomplete: wasIncomplete);
      return _build(_completed, _completedVersions, incomplete: wasIncomplete, statementCount: _completedCount);
    }

    final statements = Map.of(_completed);
    final versions = Map.of(_completedVersions);
    final pendingIds = <String>{};
    for (final raw in pending) {
      // A definition still being closed doesn't hide the finished one it
      // would replace.
      if (wasIncomplete && _completed.containsKey(raw.id)) continue;
      statements[raw.id] = OpenUILangParser.classify(raw, ExpressionParser.parse(raw.tokens));
      versions[raw.id] = _nextVersion();
      pendingIds.add(raw.id);
    }
    final tail = partialStateName(_buffer, pendingText);
    return _build(
      statements,
      versions,
      incomplete: wasIncomplete,
      statementCount: _completedCount + pending.length,
      partialReference: tail == null ? null : PartialReference(tail, pendingIds),
    );
  }

  // The whole text read again in one piece, as the end of the stream reads
  // it: the statement still arriving counts as finished, and the text splits
  // into statements, and closes, exactly as it does when read at once.
  ParseResult _readWhole() {
    final read = OpenUILangParser.readStatements(String.fromCharCodes(_prepared.codeUnits, 0, _prepared.length));
    if (read.statements.isEmpty) return ParseResult.empty(incomplete: read.incomplete);
    return _build(
      read.statements,
      {for (final name in read.statements.keys) name: _nextVersion()},
      incomplete: read.incomplete,
      statementCount: read.definitions,
    );
  }

  ParseResult _build(
    Map<String, Statement> statements,
    Map<String, int> versions, {
    required bool incomplete,
    required int statementCount,
    PartialReference? partialReference,
  }) {
    return OpenUILangParser.buildResult(
      statements,
      schema,
      versions: versions,
      incomplete: incomplete,
      statementCount: statementCount,
      partialReference: partialReference,
      cache: _cache,
    );
  }

  void _reset() {
    _completeResult = null;
    _buffer = '';
    _prepared = IncrementalPreprocessor();
    _resetCompleted();
  }

  // Forgets the finished statements, so the prepared text is read again from
  // its start.
  void _resetCompleted() {
    _lastResult = null;
    _lastPendingRead = null;
    _completedEnd = 0;
    _completed.clear();
    _completedCount = 0;
    _completedVersions.clear();
    _cache = MaterializationCache();
    _scan = _ScanState(0);
    _debugScannedCodeUnits = 0;
  }

  // Prepares `text` from `start` on. The finished statements are read again
  // when the prepared text before their end changed: the first fence arrived
  // after unfenced text, or the line after them turned into a comment or a
  // closing fence, so the text they were read from is gone.
  void _prepare(String text, int start) {
    _completeResult = null;
    final startedOver = _prepared.append(text, start);
    if (startedOver || _prepared.length < _completedEnd) _resetCompleted();
  }

  int _nextVersion() => _lastVersion += 1;

  // Reads the statements finished since the last call, and returns where the
  // statement still arriving starts.
  //
  // A statement ends at a line break outside strings and brackets, unless a
  // `?` is still waiting for its `:`, or the next line that isn't blank starts
  // with `?`. The search resumes at the first code unit that later text can
  // still drop, so the text it read before stays the same as more arrives.
  int _scanCompleted() {
    final text = _prepared.codeUnits;
    final end = _prepared.length;
    final stable = math.min(_prepared.stableLength, end);
    var state = _scan.copy();
    var resumeAt = state;
    var position = state.position;
    while (position < end) {
      if (position == stable) resumeAt = state.copy()..position = position;
      final unit = text[position];
      _debugScannedCodeUnits += 1;
      if (state.escaped) {
        state.escaped = false;
      } else if (unit == _backslash && state.quote != null) {
        state.escaped = true;
      } else if (state.quote != null) {
        if (unit == state.quote) state.quote = null;
      } else if (unit == _doubleQuote || unit == _singleQuote) {
        state.quote = unit;
      } else if (unit == _leftParen || unit == _leftBracket || unit == _leftBrace) {
        state.depth += 1;
      } else if (unit == _rightParen || unit == _rightBracket || unit == _rightBrace) {
        state.depth = math.max(0, state.depth - 1);
      } else if (unit == _question && state.depth == 0) {
        state.ternaryDepth += 1;
      } else if (unit == _colon && state.depth == 0 && state.ternaryDepth > 0) {
        state.ternaryDepth -= 1;
      } else if (unit == _lineFeed && state.depth == 0 && state.ternaryDepth == 0 && !_continues(text, position, end)) {
        _addCompleted(String.fromCharCodes(text, state.statementStart, position));
        _completedEnd = position + 1;
        state = _ScanState(position + 1);
      }
      position += 1;
    }
    if (position <= stable) resumeAt = state.copy()..position = position;
    _scan = resumeAt;
    return state.statementStart;
  }

  // Whether the next line that isn't blank after the line break at
  // [lineBreak] starts with `?`, which continues the statement. A line
  // starting with `:` can't, since no `?` waits at a line break that ends a
  // statement.
  static bool _continues(List<int> text, int lineBreak, int end) {
    var peek = lineBreak + 1;
    while (peek < end && _isSpace(text[peek])) {
      peek += 1;
    }
    return peek < end && text[peek] == _question;
  }

  // The blanks a statement's continuation may start after: space, tab, and
  // line ends, not every white space JavaScript trims.
  static bool _isSpace(int unit) => unit == _space || unit == _tab || unit == _carriageReturn || unit == _lineFeed;

  void _addCompleted(String text) {
    final trimmed = JS.trim(text);
    if (trimmed.isEmpty) return;
    for (final raw in Statements.split(Lexer.tokenize(trimmed))) {
      _completed[raw.id] = OpenUILangParser.classify(raw, ExpressionParser.parse(raw.tokens));
      _completedVersions[raw.id] = _nextVersion();
      _completedCount += 1;
    }
  }

  /// The `$name` that ends `buffer`, the raw text so far, when it may still
  /// be growing and isn't declared yet; otherwise `null`.
  ///
  /// It is the end of `pendingText`, the prepared statement still arriving,
  /// and the same name doesn't appear in full earlier in it.
  static String? partialStateName(String buffer, String pendingText) {
    final tail = _endingName(buffer);
    if (tail == null || !pendingText.endsWith(tail)) return null;
    final before = pendingText.substring(0, pendingText.length - tail.length);
    var index = before.indexOf(tail);
    while (index != -1) {
      final next = index + tail.length;
      if (next >= before.length || !_isWordUnit(before.codeUnitAt(next))) return null;
      index = before.indexOf(tail, index + 1);
    }
    return tail;
  }

  // The `$name` that `text` ends with, or null when it ends otherwise.
  static String? _endingName(String text) {
    var start = text.length;
    while (start > 0 && _isWordUnit(text.codeUnitAt(start - 1))) {
      start -= 1;
    }
    if (start == 0 || start == text.length || text.codeUnitAt(start - 1) != _dollar) return null;
    return text.substring(start - 1);
  }

  static bool _isWordUnit(int unit) {
    if (unit == _underscore) return true;
    if (unit >= _lowerA && unit <= _lowerZ) return true;
    if (unit >= _upperA && unit <= _upperZ) return true;
    return unit >= _zero && unit <= _nine;
  }
}

// Where the search for finished statements is: the next code unit to read,
// where the current statement starts, and what is open at that point.
final class _ScanState {
  _ScanState(this.statementStart) : position = statementStart;

  int position;
  final int statementStart;
  int depth = 0;
  int ternaryDepth = 0;
  int? quote;
  bool escaped = false;

  _ScanState copy() {
    return _ScanState(statementStart)
      ..position = position
      ..depth = depth
      ..ternaryDepth = ternaryDepth
      ..quote = quote
      ..escaped = escaped;
  }
}
