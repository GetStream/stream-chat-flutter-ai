import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/code_block_view.dart';
import 'package:stream_chat_flutter_ai/src/markdown/math_syntax.dart';
import 'package:stream_chat_flutter_ai/src/util/lru_cache.dart';

/// Callback fired when the user taps a hyperlink in the rendered markdown.
///
/// Parameters mirror `flutter_markdown_plus`'s `MarkdownTapLinkCallback`:
/// [text] is the link label, [href] is the URL (may be null), and [title] is
/// the optional title attribute.
typedef MarkdownTapLinkCallback = void Function(String text, String? href, String title);

/// Builds the widget for a LaTeX expression found in the markdown.
///
/// [tex] is the raw TeX source without its delimiters, [style] is the
/// surrounding text style, and [inline] distinguishes `\(…\)` from `\[…\]`.
///
/// Rendering TeX needs a math engine, and this package deliberately ships
/// without one — see [AIMarkdownBody.mathBuilder].
typedef MathBuilder = Widget Function(BuildContext context, String tex, TextStyle? style, {required bool inline});

/// The set of languages whose fences are treated as chart blocks, when
/// [AIMarkdownBody.chartLanguages] isn't given.
const kDefaultChartLanguages = {'json', 'chart', 'chartjs', 'echarts', 'highcharts', 'plotly', 'vega'};

/// How many code fences to remember the parse and built widget for.
///
/// Sized against the number of fences in a *message*, not the number on screen:
/// `MarkdownBody` builds every fence in the string it is given, so a message
/// with more than this many gets no reuse at all. Messages that long are rare
/// enough not to pay for a bigger cache in every other case.
const _kFenceCacheCapacity = 32;

/// Memoized [USpecParser.tryParse] results, keyed on the fence's exact content.
///
/// A fence's content stops changing the moment its closing ` ``` ` arrives, but
/// the enclosing message keeps rebuilding — once per typewriter tick while
/// streaming, so every ~10ms. Re-running `jsonDecode` plus a full schema walk on
/// each of those ticks (including the throw-and-catch for a fence that isn't
/// chart data at all) is pure waste. Failures are cached too, for exactly that
/// reason.
final _specCache = LruCache<String, USpec?>(_kFenceCacheCapacity);

/// Memoized fence *widgets*, keyed on language + content.
///
/// Caching the parse alone still left every completed chart rebuilding and
/// repainting on each typewriter tick, which is what actually shows up on a
/// low-end device rendering a message with several charts. Returning the
/// identical [Widget] instance lets the framework short-circuit the subtree's
/// rebuild entirely, and the [RepaintBoundary] each entry is wrapped in keeps
/// its rasterized pixels while only the growing trailing text repaints.
///
/// [LruCache] rather than a plain map because a fence that is still arriving
/// keys a new entry on every tick — see that class for why insertion-order
/// eviction turns those snapshots into a way of evicting the finished fences
/// above them.
final _fenceWidgetCache = LruCache<String, Widget>(_kFenceCacheCapacity);

/// Clears the fence caches. Exposed for tests.
@visibleForTesting
void debugClearFenceCaches() {
  _specCache.clear();
  _fenceWidgetCache.clear();
}

USpec? _parseSpecCached(String code) {
  if (_specCache.containsKey(code)) return _specCache.get(code);
  return _specCache.set(code, USpecParser.tryParse(code));
}

Widget _buildFenceCached(
  String? language,
  String source,
  Set<String> chartLanguages,
  CodeHighlighter? highlighter,
  Color codeBackgroundColor,
  Color codeForegroundColor,
) {
  final isChartFence = language != null && chartLanguages.contains(language.toLowerCase());
  // The chart flag and both colors are part of the key: two bodies configured
  // differently must not share one cached widget for the same fence.
  //
  // The highlighter deliberately is *not*. A host's inline closure differs on
  // every build, so keying on it would never hit and would evict continuously.
  // Swapping highlighters then leaves built fences alone until their source
  // next changes — the trade `_MathElementBuilder` documents.
  final key =
      '${isChartFence ? 'c' : 'x'}\n'
      '${codeBackgroundColor.toARGB32()}\n${codeForegroundColor.toARGB32()}\n'
      '${language ?? ''}\n$source';
  final cached = _fenceWidgetCache.get(key);
  if (cached != null) return cached;

  final spec = isChartFence ? _parseSpecCached(source) : null;
  final child = spec != null
      ? ChartView(spec: spec)
      : CodeBlockView(
          code: source,
          language: (language == null || language.isEmpty) ? null : language,
          highlighter: highlighter,
          backgroundColor: codeBackgroundColor,
          foregroundColor: codeForegroundColor,
        );

  return _fenceWidgetCache.set(key, RepaintBoundary(child: child));
}

/// A markdown renderer tailored for AI-generated messages.
///
/// Renders the whole message with a single [MarkdownBody], overriding two
/// elements:
///
/// - **Code fences** (`pre`) become a [CodeBlockView] — dark box, copy button,
///   language label, and syntax highlighting when [codeHighlighter] is given.
/// - **Code fences whose language suggests chart data** become a [ChartView]
///   when the content parses as a [USpec]; otherwise they fall back to
///   [CodeBlockView].
/// - **LaTeX** (`\(…\)` and `\[…\]`) is handed to [mathBuilder], when one is
///   supplied.
///
/// Letting `package:markdown` find the fences — rather than pre-splitting the
/// string with a regex and stitching several [MarkdownBody] widgets together —
/// is what makes streaming behave. CommonMark requires an unclosed fence to run
/// to the end of the document, so a code block that is still arriving renders as
/// a [CodeBlockView] straight away instead of showing raw ` ``` ` markers until
/// its closing fence lands. It also keeps one parser across the whole message,
/// so an ordered list interrupted by a fence keeps counting, and fences nested
/// in list items or blockquotes are styled like any other.
class AIMarkdownBody extends StatefulWidget {
  /// Creates an [AIMarkdownBody].
  const AIMarkdownBody({
    super.key,
    required this.data,
    this.onTapLink,
    this.selectable = false,
    this.styleSheet,
    this.mathBuilder,
    this.useDollarDelimitersForMath = false,
    this.chartLanguages = kDefaultChartLanguages,
    this.codeHighlighter,
    this.codeBackgroundColor = kDefaultCodeBackgroundColor,
    this.codeForegroundColor = kDefaultCodeForegroundColor,
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
  ///
  /// `codeblockDecoration` is always overridden, because code fences are
  /// rendered by [CodeBlockView], which brings its own background.
  final MarkdownStyleSheet? styleSheet;

  /// Renders LaTeX expressions. When null, math is left as plain text.
  ///
  /// Typesetting TeX requires a math engine, and every Flutter option pulls in a
  /// non-trivial dependency tree (`flutter_math_fork`, the usual choice, brings
  /// `flutter_svg` and `provider` with it). This package stays standalone and
  /// lets the host inject one instead — the same trade [styleSheet] makes:
  ///
  /// ```dart
  /// AIMarkdownBody(
  ///   data: message,
  ///   mathBuilder: (context, tex, style, {required inline}) => Math.tex(tex, textStyle: style),
  /// )
  /// ```
  ///
  /// The LaTeX *syntax* is recognised either way, so leaving this null degrades
  /// to showing the TeX source rather than dropping it.
  final MathBuilder? mathBuilder;

  /// Whether `$…$` and `$$…$$` are also treated as LaTeX delimiters, on top of
  /// `\(…\)` and `\[…\]`.
  ///
  /// Off by default: `$` collides with currency in ordinary prose, so
  /// "it costs $5 to $10" would otherwise typeset as math.
  final bool useDollarDelimitersForMath;

  /// The fence languages whose contents are offered to [USpecParser], defaulting
  /// to [kDefaultChartLanguages].
  ///
  /// Worth narrowing when a host renders replies that also carry data payloads:
  /// `json` is in the default set — models label chart data that way constantly
  /// — but it means a plain ```json fence that happens to be shaped like a chart
  /// spec renders as a chart with no way to read the source. Pass a set without
  /// `json` to keep those as code, or an empty set to turn chart rendering off
  /// entirely.
  ///
  /// Languages are matched lower-case.
  final Set<String> chartLanguages;

  /// Syntax-highlights code fences. When null, they render as plain text.
  ///
  /// Grammars are far larger than this package, so it takes one from the host
  /// instead — the same trade [mathBuilder] makes. See
  /// [CodeBlockView.highlighter], and `example/lib/code_highlighter.dart`.
  final CodeHighlighter? codeHighlighter;

  /// Fills code fences. See [CodeBlockView.backgroundColor].
  final Color codeBackgroundColor;

  /// Colors the text in code fences. See [CodeBlockView.foregroundColor].
  final Color codeForegroundColor;

  @override
  State<AIMarkdownBody> createState() => _AIMarkdownBodyState();
}

class _AIMarkdownBodyState extends State<AIMarkdownBody> {
  late Map<String, MarkdownElementBuilder> _builders;
  late List<md.InlineSyntax> _inlineSyntaxes;
  late List<md.BlockSyntax> _blockSyntaxes;

  /// Bumped whenever the parser configuration changes, and used to key the
  /// [MarkdownBody].
  ///
  /// `MarkdownWidget` parses in `initState` and re-parses only when `data` or
  /// `styleSheet` changes — new syntax lists alone are never consulted again, so
  /// without a fresh key a flipped [AIMarkdownBody.useDollarDelimitersForMath]
  /// did nothing at all until the text happened to change.
  int _configGeneration = 0;

  @override
  void initState() {
    super.initState();
    _rebuildParserConfig();
  }

  @override
  void didUpdateWidget(covariant AIMarkdownBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The syntaxes and builders are independent of `data`, so streaming text
    // doesn't churn them. Only the delimiter choice feeds into them.
    if (widget.useDollarDelimitersForMath != oldWidget.useDollarDelimitersForMath ||
        !setEquals(widget.chartLanguages, oldWidget.chartLanguages) ||
        widget.codeBackgroundColor != oldWidget.codeBackgroundColor ||
        widget.codeForegroundColor != oldWidget.codeForegroundColor) {
      _configGeneration++;
      _rebuildParserConfig();
    }
  }

  void _rebuildParserConfig() {
    _builders = <String, MarkdownElementBuilder>{
      'pre': _CodeFenceBuilder(
        widget.chartLanguages,
        () => widget.codeHighlighter,
        widget.codeBackgroundColor,
        widget.codeForegroundColor,
      ),
      kMathTag: _MathElementBuilder(() => widget.mathBuilder),
    };
    _blockSyntaxes = <md.BlockSyntax>[
      MathBlockSyntax(useDollarDelimiters: widget.useDollarDelimitersForMath),
    ];
    _inlineSyntaxes = <md.InlineSyntax>[
      // Must precede the math syntax. `package:markdown` evaluates
      // caller-supplied inline syntaxes ahead of its own defaults, so without
      // this the `$x$` inside `` `$x$` `` would be claimed as math before the
      // backticks are considered. A second CodeSyntax in the default list is
      // harmless — the first match wins.
      md.CodeSyntax(),
      MathInlineSyntax(useDollarDelimiters: widget.useDollarDelimitersForMath),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sheet = widget.styleSheet ?? MarkdownStyleSheet.fromTheme(Theme.of(context));

    return MarkdownBody(
      key: ValueKey(_configGeneration),
      data: widget.data,
      selectable: widget.selectable,
      // `flutter_markdown_plus` wraps a custom `pre` builder's widget in a
      // Container carrying `codeblockDecoration` — unlike its `hr` branch, that
      // one isn't skipped when a builder is registered. CodeBlockView and
      // ChartView draw their own backgrounds, so neutralize it rather than
      // letting a stray grey box show through. An empty decoration, not null:
      // Container asserts a non-null decoration when it clips.
      styleSheet: sheet.copyWith(codeblockDecoration: const BoxDecoration()),
      builders: _builders,
      blockSyntaxes: _blockSyntaxes,
      inlineSyntaxes: _inlineSyntaxes,
      // Our own typedef is structurally identical to the one
      // `flutter_markdown_plus` expects, so it can be handed over directly.
      onTapLink: widget.onTapLink,
    );
  }
}

/// Renders a fenced or indented code block as a [CodeBlockView], or as a
/// [ChartView] when its language and content say it is chart data.
class _CodeFenceBuilder extends MarkdownElementBuilder {
  _CodeFenceBuilder(this._chartLanguages, this._highlighter, this._backgroundColor, this._foregroundColor);

  final Set<String> _chartLanguages;

  /// Read through a closure for the same reason [_MathElementBuilder] does:
  /// hosts pass an inline closure, so its identity differs on every build, and
  /// rebuilding the builder map once per typewriter tick would be pure waste.
  final CodeHighlighter? Function() _highlighter;

  final Color _backgroundColor;
  final Color _foregroundColor;

  // Deliberately NOT `isBlockElement() => true`. `pre` is already in
  // `flutter_markdown_plus`' block-tag list, so the block layout path is taken
  // either way — and returning true would append `'pre'` to that
  // process-global list on every single build, which under a streaming
  // message's ~10ms rebuild cadence grows without bound.

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // A fenced block parses to `<pre><code class="language-dart">…</code></pre>`;
    // an indented block has no class attribute, hence the null language.
    final code = element.children?.whereType<md.Element>().firstOrNull;
    final className = code?.attributes['class'];
    final language = className != null && className.startsWith('language-')
        ? className.substring('language-'.length)
        : null;

    // `md.Document` is created with `encodeHtml: false`, so this is the raw
    // source. The parser appends a trailing newline to the code element.
    final source = element.textContent.trimRight();

    return _buildFenceCached(language, source, _chartLanguages, _highlighter(), _backgroundColor, _foregroundColor);
  }
}

/// Renders a [kMathTag] element via the host-supplied [MathBuilder], falling
/// back to the raw TeX when none is available.
class _MathElementBuilder extends MarkdownElementBuilder {
  _MathElementBuilder(this._builder);

  /// Read through a closure so the builder map survives a changed
  /// [AIMarkdownBody.mathBuilder] — hosts typically pass an inline closure whose
  /// identity differs on every build, and rebuilding the map (and with it
  /// `MathInlineSyntax`' RegExp) once per typewriter tick would be pure waste.
  ///
  /// It is read during a *parse*, not during a build, so swapping the builder on
  /// a message whose text has stopped changing takes effect on the next change
  /// to [AIMarkdownBody.data] rather than immediately. That is the streaming
  /// case, where `data` changes every tick anyway.
  final MathBuilder? Function() _builder;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final tex = element.textContent;
    final style = preferredStyle ?? parentStyle;
    final inline = element.attributes[kMathDisplayAttribute] != kMathDisplayBlock;

    final builder = _builder();
    // No math engine wired up — show the source instead of swallowing it.
    if (builder == null) return Text(tex, style: style);

    return builder(context, tex, style, inline: inline);
  }
}
