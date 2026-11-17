/// Preparing a reply's text for reading as OpenUI Lang.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';

/// The preparation of a reply's text for reading as OpenUI Lang: taking the
/// program out of its Markdown code fences, removing comments and trimming
/// it.
abstract final class Preprocessor {
  /// The program in `text`, ready to be read.
  ///
  /// When `text` holds Markdown code fences, only the fenced blocks are kept,
  /// joined with line breaks; otherwise all of it is. Comments starting with
  /// `//` or `#` outside strings are then removed, and white space around the
  /// result is trimmed.
  static String prepare(String text) => JS.trim(stripComments(stripFences(JS.trim(text))));

  /// The code in the Markdown fences of `text`, or `text` unchanged when it
  /// has none.
  ///
  /// The fenced blocks are joined with line breaks, each without its opening
  /// line (which may name a language). A fence inside a `"…"` string doesn't
  /// count. A block whose closing fence hasn't arrived runs to the end, and an
  /// opening fence with nothing after its line gives an empty block.
  static String stripFences(String text) {
    final length = text.length;
    final blocks = <String>[];
    var i = 0;
    while (i < length) {
      var fenceStart = -1;
      while (i < length) {
        final next = _skipString(text, i);
        if (next > i) {
          i = next;
          continue;
        }
        if (_isFence(text, i)) {
          fenceStart = i;
          break;
        }
        i += 1;
      }
      if (fenceStart == -1) break;

      var j = fenceStart + 3;
      while (j < length && text.codeUnitAt(j) != _lineFeed) {
        j += 1;
      }
      if (j >= length) {
        // The opening line hasn't ended: no code has arrived yet.
        blocks.add('');
        break;
      }
      j += 1;

      var closing = -1;
      var k = j;
      while (k < length) {
        final next = _skipString(text, k);
        if (next > k) {
          k = next;
          continue;
        }
        if (_isFence(text, k)) {
          closing = k;
          break;
        }
        k += 1;
      }
      if (closing == -1) {
        blocks.add(text.substring(j));
        break;
      }
      blocks.add(text.substring(j, closing));
      i = closing + 3;
    }
    if (blocks.isEmpty) return text;
    return blocks.join('\n');
  }

  /// `text` without its `//` and `#` comments.
  ///
  /// A comment runs to the end of its line, and the line is trimmed at its
  /// end once the comment is cut. Markers inside `"…"` or `'…'` strings are
  /// kept, and a string left open at the end of a line stays open on the
  /// next. Lines are split on line feeds only.
  static String stripComments(String text) {
    int? quote;
    final lines = text.split('\n');
    final output = <String>[];
    for (final line in lines) {
      int? cut;
      var i = 0;
      while (i < line.length) {
        final unit = line.codeUnitAt(i);
        if (quote != null) {
          if (unit == _backslash && i + 1 < line.length) {
            i += 2;
            continue;
          }
          if (unit == quote) quote = null;
          i += 1;
          continue;
        }
        if (unit == _doubleQuote || unit == _singleQuote) {
          quote = unit;
          i += 1;
          continue;
        }
        if ((unit == _slash && i + 1 < line.length && line.codeUnitAt(i + 1) == _slash) || unit == _hash) {
          cut = i;
          break;
        }
        i += 1;
      }
      output.add(cut == null ? line : JS.trimEnd(line.substring(0, cut)));
    }
    return output.join('\n');
  }

  // The index just past the `"…"` string starting at [start], or [start] when
  // none starts there; the end of [text] when the string never closes.
  static int _skipString(String text, int start) {
    if (start >= text.length || text.codeUnitAt(start) != _doubleQuote) return start;
    var i = start + 1;
    while (i < text.length) {
      final unit = text.codeUnitAt(i);
      if (unit == _backslash) {
        i += 2;
      } else if (unit == _doubleQuote) {
        return i + 1;
      } else {
        i += 1;
      }
    }
    return text.length;
  }

  static bool _isFence(String text, int i) {
    return i + 2 < text.length &&
        text.codeUnitAt(i) == _backtick &&
        text.codeUnitAt(i + 1) == _backtick &&
        text.codeUnitAt(i + 2) == _backtick;
  }

  static const _lineFeed = 0x0a;
  static const _doubleQuote = 0x22;
  static const _hash = 0x23;
  static const _singleQuote = 0x27;
  static const _slash = 0x2f;
  static const _backslash = 0x5c;
  static const _backtick = 0x60;
}
