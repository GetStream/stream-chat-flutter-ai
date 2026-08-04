import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';
import 'package:stream_chat_flutter_ai/src/code_block_view.dart';
import 'package:stream_chat_flutter_ai/src/markdown/math_syntax.dart';

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

/// The set of languages whose fences are treated as chart blocks.
const _kChartLanguages = {'json', 'chart', 'chartjs', 'echarts', 'highcharts', 'plotly', 'vega'};

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
/// Renders the whole message with a single [MarkdownBody], overriding two
/// elements:
///
/// - **Code fences** (`pre`) become a [CodeBlockView] — dark box, copy button,
///   language label.
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

  @override
  State<AIMarkdownBody> createState() => _AIMarkdownBodyState();
}

class _AIMarkdownBodyState extends State<AIMarkdownBody> {
  late Map<String, MarkdownElementBuilder> _builders;
  late List<md.InlineSyntax> _inlineSyntaxes;
  late List<md.BlockSyntax> _blockSyntaxes;

  @override
  void initState() {
    super.initState();
    _rebuildParserConfig();
  }

  @override
  void didUpdateWidget(covariant AIMarkdownBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The syntaxes and builders are independent of `data`, so streaming text
    // doesn't churn them. Only the delimiter choice feeds into them: a changed
    // `mathBuilder` is picked up lazily by _MathElementBuilder, deliberately —
    // hosts typically pass an inline closure, whose identity differs on every
    // build, and rebuilding here would recompile MathInlineSyntax's RegExp once
    // per typewriter tick.
    if (widget.useDollarDelimitersForMath != oldWidget.useDollarDelimitersForMath) {
      _rebuildParserConfig();
    }
  }

  void _rebuildParserConfig() {
    _builders = <String, MarkdownElementBuilder>{
      'pre': _CodeFenceBuilder(),
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

    if (language != null && _kChartLanguages.contains(language.toLowerCase())) {
      final spec = _parseSpecCached(source);
      if (spec != null) return ChartView(spec: spec);
    }

    return CodeBlockView(
      code: source,
      language: (language == null || language.isEmpty) ? null : language,
    );
  }
}

/// Renders a [kMathTag] element via the host-supplied [MathBuilder], falling
/// back to the raw TeX when none is available.
class _MathElementBuilder extends MarkdownElementBuilder {
  _MathElementBuilder(this._builder);

  /// Read lazily so a changed [AIMarkdownBody.mathBuilder] is picked up without
  /// reconstructing the builder map.
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
