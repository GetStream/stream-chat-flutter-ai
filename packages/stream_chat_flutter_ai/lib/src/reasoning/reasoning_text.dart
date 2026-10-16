/// The text machinery behind `StreamingReasoningView`: splitting reasoning into
/// paragraphs, rendering a paragraph's inline markdown, and revealing new text
/// a little at a time.
///
/// Internal.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:markdown/markdown.dart' as md;

/// A blank line: what separates two paragraphs of reasoning.
final _blankLine = RegExp(r'\r?\n[ \t]*\r?\n');

/// Splits [text] at blank lines into trimmed, non-empty paragraphs.
@internal
List<String> splitReasoningParagraphs(String text) => [
  for (final paragraph in text.split(_blankLine))
    if (paragraph.trim() case final trimmed when trimmed.isNotEmpty) trimmed,
];

/// The paragraphs of a text that grows at its end, re-split incrementally.
///
/// Reasoning only ever grows, so every paragraph before the last blank line is
/// final: [update] only re-splits the text after it, which keeps a tick of a
/// 40 KB trace as cheap as one of a short one. Text that does not carry on from
/// the previous one is split from scratch.
@internal
class ReasoningParagraphs {
  final _done = <String>[];
  var _source = '';
  var _tailStart = 0;

  /// The paragraphs of the text last passed to [update].
  List<String> get paragraphs => _paragraphs;
  var _paragraphs = const <String>[];

  /// Splits [text], reusing the finished paragraphs of the previous text when
  /// [text] carries on from it.
  List<String> update(String text) {
    if (text == _source) return _paragraphs;
    if (!text.startsWith(_source)) {
      _done.clear();
      _tailStart = 0;
    }
    _source = text;

    var tail = text.substring(_tailStart);
    final lastBreak = _blankLine.allMatches(tail).lastOrNull;
    if (lastBreak != null) {
      _done.addAll(splitReasoningParagraphs(tail.substring(0, lastBreak.start)));
      _tailStart += lastBreak.end;
      tail = tail.substring(lastBreak.end);
    }

    final last = tail.trim();
    return _paragraphs = [..._done, if (last.isNotEmpty) last];
  }
}

/// Builds a link's tap recognizer, or `null` for a link that isn't tappable.
@internal
typedef ReasoningLinkRecognizer = GestureRecognizer? Function(String text, String? href, String? title);

/// The inline markdown of one paragraph of reasoning as spans: bold, italics,
/// inline code and links, as reasoning models write them.
///
/// A heading line reads as a bold line, since a paragraph of thinking has no
/// document to structure. Everything else is shown as written.
@internal
List<InlineSpan> reasoningInlineSpans(
  String paragraph, {
  required TextStyle codeStyle,
  required TextStyle linkStyle,
  ReasoningLinkRecognizer? linkRecognizer,
}) {
  final source = paragraph
      .split('\n')
      .map((line) {
        final trimmed = line.trimLeft();
        if (!trimmed.startsWith('#')) return line;
        final heading = trimmed.replaceFirst(RegExp('^#+'), '').trim();
        return heading.isEmpty ? line : '**$heading**';
      })
      .join('\n');

  final nodes = md.Document(encodeHtml: false).parseInline(source);
  return [for (final node in nodes) _span(node, codeStyle, linkStyle, linkRecognizer)];
}

InlineSpan _span(md.Node node, TextStyle codeStyle, TextStyle linkStyle, ReasoningLinkRecognizer? linkRecognizer) {
  if (node is! md.Element) return TextSpan(text: node.textContent);

  List<InlineSpan> children() => [
    for (final child in node.children ?? const <md.Node>[]) _span(child, codeStyle, linkStyle, linkRecognizer),
  ];

  return switch (node.tag) {
    'strong' => TextSpan(
      style: const TextStyle(fontWeight: FontWeight.w600),
      children: children(),
    ),
    'em' => TextSpan(
      style: const TextStyle(fontStyle: FontStyle.italic),
      children: children(),
    ),
    'del' => TextSpan(
      style: const TextStyle(decoration: TextDecoration.lineThrough),
      children: children(),
    ),
    'code' => TextSpan(text: node.textContent, style: codeStyle),
    'br' => const TextSpan(text: '\n'),
    'img' => TextSpan(text: node.attributes['alt'] ?? ''),
    'a' => TextSpan(
      style: linkStyle,
      recognizer: linkRecognizer?.call(node.textContent, node.attributes['href'], node.attributes['title']),
      children: children(),
    ),
    _ => TextSpan(children: children()),
  };
}

/// Reveals new text a little at a time, so thoughts that arrive in bursts read
/// as a steady stream: about 30 times a second, a sixth of what is still
/// hidden. Text that does not carry on from the target replaces what is shown
/// at once.
@internal
class ReasoningTextReveal extends ChangeNotifier {
  /// Starts out showing [text] in full.
  ReasoningTextReveal(String text) : _shown = text, _target = text;

  /// How often a tick reveals more.
  static const interval = Duration(milliseconds: 33);

  /// The text on screen.
  String get shown => _shown;
  String _shown;

  String _target;
  Timer? _timer;
  var _hurried = false;

  /// Whether text is still being revealed.
  bool get isRevealing => _timer != null;

  /// Moves towards [text]: revealed over a few ticks when [animated] and it
  /// carries on from the current target, shown at once otherwise.
  void update(String text, {required bool animated}) {
    if (text == _target) {
      if (!animated && isRevealing) _show(text);
      return;
    }
    if (!animated || !text.startsWith(_target)) return _show(text);
    _target = text;
    _timer ??= Timer.periodic(interval, (_) => tick());
  }

  /// Reveals the rest quickly — half of what is left per tick — for when the
  /// model has stopped thinking.
  void hurry() => _hurried = true;

  /// Reveals the next slice. Public for tests; the timer calls it.
  @visibleForTesting
  void tick() {
    final backlog = _target.length - _shown.length;
    if (backlog <= 0) return _stop();

    var end = _shown.length + math.max<int>(1, backlog ~/ (_hurried ? 2 : 6));
    // Never split a surrogate pair, which would paint half an emoji.
    if (end < _target.length && _isHighSurrogate(_target.codeUnitAt(end - 1))) end++;
    _shown = _target.substring(0, end);
    if (end == _target.length) _stop();
    notifyListeners();
  }

  void _show(String text) {
    _stop();
    _target = text;
    if (_shown == text) return;
    _shown = text;
    notifyListeners();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _hurried = false;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
}
