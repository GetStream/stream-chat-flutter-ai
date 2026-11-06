import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

/// The A2UI messages in the UI of an agent's reply, in the order the agent
/// wrote them.
///
/// An agent writes A2UI as JSON objects one after another, usually one per
/// line, and the text grows while it writes. Each complete top-level object is
/// one message. An object still being written at the end of the text isn't one
/// yet, so a UI can show its messages as they arrive. A pretty-printed object
/// counts whole.
///
/// Text between the objects, such as a sentence before the first one, is
/// ignored, and so are the `[`, `,` and `]` of a list around them, unless it
/// holds a `{`: a `{…}` in that text counts as a message, which
/// [A2UIProcessor.apply] then skips, and a `{` that is never closed hides every
/// message after it.
///
/// ```dart
/// final messages = A2UIStream.messages(document.content);
/// final added = A2UIStream.added(messages, applied: applied);
/// if (added == null) {
///   processor
///     ..reset()
///     ..apply(messages);
/// } else {
///   processor.apply(added);
/// }
/// applied = messages;
/// ```
///
/// Internal to the package.
@internal
abstract final class A2UIStream {
  /// The complete messages in [content], each as the JSON text of one object.
  ///
  /// A [String] is split as described for [A2UIStream]. A `{` or `}` inside a
  /// string never starts or ends an object, and an escaped quote never ends the
  /// string. Text outside the objects isn't JSON, so a quote in it doesn't
  /// start a string.
  ///
  /// Content that is already JSON gives one message per object: each [Map] of
  /// a [List], or a [Map] itself. Other values, items of a list that aren't
  /// objects, and maps whose keys aren't all strings give no messages. A value
  /// inside an object must be JSON too; one that isn't throws.
  ///
  /// An object with a `messages` list, the form A2UI writes a batch in, is one
  /// message here; [A2UIProcessor.apply] applies the messages in it.
  static List<String> messages(Object? content) {
    return switch (content) {
      final String text => _split(text),
      final List<Object?> list => [
        for (final item in list)
          if (_isObject(item)) jsonEncode(item),
      ],
      final Map<Object?, Object?> map when _isObject(map) => [jsonEncode(map)],
      _ => const [],
    };
  }

  static bool _isObject(Object? value) => value is Map && value.keys.every((key) => key is String);

  static const _openBrace = 0x7B;
  static const _closeBrace = 0x7D;
  static const _quote = 0x22;
  static const _backslash = 0x5C;

  // Only `{`, `}`, `"` and `\` decide where an object ends. All four are
  // ASCII, so walking UTF-16 code units never splits a character they could be
  // part of. A quote outside the objects starts no string: text there isn't
  // JSON.
  static List<String> _split(String text) {
    final messages = <String>[];
    var depth = 0;
    var start = 0;
    var inString = false;
    var escaped = false;
    for (var index = 0; index < text.length; index += 1) {
      final unit = text.codeUnitAt(index);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (unit == _backslash) {
          escaped = true;
        } else if (unit == _quote) {
          inString = false;
        }
        continue;
      }
      if (unit == _quote && depth > 0) {
        inString = true;
      } else if (unit == _openBrace) {
        if (depth == 0) start = index;
        depth += 1;
      } else if (unit == _closeBrace && depth > 0) {
        depth -= 1;
        if (depth == 0) messages.add(text.substring(start, index + 1));
      }
    }
    return messages;
  }

  /// The messages of [latest] after [applied], or `null` when [latest] doesn't
  /// start with [applied].
  ///
  /// A text that only grew keeps its earlier messages, so this returns the ones
  /// that follow them, which is empty when no message was completed since. For
  /// a text that changed before its end, such as a message the agent rewrote or
  /// removed, this returns `null`: its messages have to be applied again from
  /// the start.
  static List<String>? added(List<String> latest, {required List<String> applied}) {
    if (latest.length < applied.length) return null;
    for (var index = 0; index < applied.length; index += 1) {
      if (latest[index] != applied[index]) return null;
    }
    return latest.sublist(applied.length);
  }
}
