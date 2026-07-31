import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/code_block_view.dart';

/// Callback fired when the user taps a hyperlink in the rendered markdown.
///
/// Parameters mirror `flutter_markdown_plus`'s `MarkdownTapLinkCallback`:
/// [text] is the link label, [href] is the URL (may be null), and [title] is
/// the optional title attribute.
typedef MarkdownTapLinkCallback = void Function(String text, String? href, String title);

/// The set of languages whose fences are treated as chart blocks.
const _kChartLanguages = {'json', 'chart', 'chartjs', 'echarts', 'highcharts', 'plotly', 'vega'};

/// Regex that splits markdown into text and fenced-code segments.
///
/// Group 1: language identifier (possibly empty).
/// Group 2: the raw code content inside the fence.
final _kFenceRegex = RegExp(r'```(\w*)\n([\s\S]*?)```', multiLine: true);

/// How many chart-fence parses to remember. Comfortably more than the number of
/// charts visible at once, small enough to stay cheap.
const _kSpecCacheCapacity = 32;

/// Memoized [USpecParser.tryParse] results, keyed on the fence's exact content.
///
/// A fence's content stops changing the moment its closing ` ``` ` arrives, but
/// the enclosing message keeps rebuilding — once per typewriter tick while
/// streaming, so every ~10ms. Re-running `jsonDecode` plus a full schema walk on
/// each of those ticks (including the throw-and-catch for a fence that isn't
/// chart data at all) is pure waste. Failures are cached too, for exactly that
/// reason.
final _specCache = <String, USpec?>{};

USpec? _parseSpecCached(String code) {
  final cached = _specCache[code];
  if (cached != null || _specCache.containsKey(code)) return cached;

  // Evict in insertion order — a streaming message appends fences, so the
  // oldest entry is the one least likely to still be on screen.
  if (_specCache.length >= _kSpecCacheCapacity) _specCache.remove(_specCache.keys.first);

  return _specCache[code] = USpecParser.tryParse(code);
}

/// A markdown renderer tailored for AI-generated messages.
///
/// Parses the markdown string into segments and renders:
/// - Text segments via [MarkdownBody] (from `flutter_markdown_plus`).
/// - Code fences via [CodeBlockView] (dark box, copy button, language label).
/// - JSON / chart fences via [ChartView] when the content is a valid [USpec];
///   otherwise falls back to [CodeBlockView].
class AIMarkdownBody extends StatefulWidget {
  /// Creates an [AIMarkdownBody].
  const AIMarkdownBody({
    super.key,
    required this.data,
    this.onTapLink,
    this.selectable = false,
    this.styleSheet,
  });

  /// The markdown string to render.
  final String data;

  /// Called when the user taps a hyperlink.
  final MarkdownTapLinkCallback? onTapLink;

  /// Whether text content is selectable (pass `true` on desktop / web).
  final bool selectable;

  /// Style overrides for the rendered markdown (paragraph text, links,
  /// headings, etc.). Defaults to `flutter_markdown_plus`'s own
  /// `MarkdownStyleSheet.fromTheme(Theme.of(context))` when not provided.
  ///
  /// Host apps that also render non-AI messages via `stream_chat_flutter`
  /// can pass a sheet built from that package's own message text style (e.g.
  /// `context.streamTextTheme.bodyDefault`) so AI and regular messages share
  /// the same font size/weight — this package has no dependency on
  /// `stream_chat_flutter`/`stream_core_flutter`, so it can't do that itself.
  final MarkdownStyleSheet? styleSheet;

  @override
  State<AIMarkdownBody> createState() => _AIMarkdownBodyState();
}

class _AIMarkdownBodyState extends State<AIMarkdownBody> {
  late List<_Segment> _segments;

  @override
  void initState() {
    super.initState();
    _segments = _parse(widget.data);
  }

  @override
  void didUpdateWidget(covariant AIMarkdownBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-scan when the markdown itself changed — a rebuild triggered by a
    // theme change, a scroll, or an ancestor doesn't need one.
    if (widget.data != oldWidget.data) _segments = _parse(widget.data);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: _segments.map((s) => _buildSegment(context, s)).toList(),
    );
  }

  Widget _buildSegment(BuildContext context, _Segment segment) {
    if (segment is _TextSegment) {
      if (segment.text.trim().isEmpty) return const SizedBox.shrink();
      return MarkdownBody(
        data: segment.text,
        selectable: widget.selectable,
        styleSheet: widget.styleSheet,
        // Our own typedef is structurally identical to the one
        // `flutter_markdown_plus` expects, so it can be handed over directly.
        onTapLink: widget.onTapLink,
      );
    }

    final code = segment as _CodeSegment;

    // Try to render as a chart when the language suggests JSON / chart content.
    if (_kChartLanguages.contains(code.language.toLowerCase())) {
      final spec = _parseSpecCached(code.code);
      if (spec != null) return ChartView(spec: spec);
    }

    return CodeBlockView(
      code: code.code,
      language: code.language.isEmpty ? null : code.language,
    );
  }

  // ---------------------------------------------------------------------------
  // Markdown → segment list
  // ---------------------------------------------------------------------------

  static List<_Segment> _parse(String markdown) {
    final segments = <_Segment>[];
    var cursor = 0;

    for (final match in _kFenceRegex.allMatches(markdown)) {
      // Text before this fence.
      if (match.start > cursor) {
        segments.add(_TextSegment(markdown.substring(cursor, match.start)));
      }
      segments.add(
        _CodeSegment(
          language: match.group(1) ?? '',
          code: (match.group(2) ?? '').trimRight(),
        ),
      );
      cursor = match.end;
    }

    // Trailing text (or the whole string if there were no fences).
    if (cursor < markdown.length) {
      segments.add(_TextSegment(markdown.substring(cursor)));
    }

    return segments;
  }
}

// ---------------------------------------------------------------------------
// Internal segment types
// ---------------------------------------------------------------------------

sealed class _Segment {
  const _Segment();
}

final class _TextSegment extends _Segment {
  const _TextSegment(this.text);

  final String text;
}

final class _CodeSegment extends _Segment {
  const _CodeSegment({required this.language, required this.code});

  final String language;
  final String code;
}
