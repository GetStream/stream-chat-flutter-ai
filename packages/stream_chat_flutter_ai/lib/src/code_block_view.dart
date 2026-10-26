import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/resolved_code_block_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/code_block_theme.dart';

/// Builds the highlighted span tree for a fenced code block.
///
/// Return `null` for a language you don't cover, and the block renders the code
/// as plain text. That is a normal outcome, not a failure.
///
/// **Contrast.** The token colors are yours; the frame they land on is the
/// block's [CodeBlockThemeData]. A palette made for a dark background is
/// unreadable on a light one, so choose it from
/// [CodeHighlightRequest.brightness] — the block's pinned
/// [CodeBlockThemeData.brightness], or else its background's — rather than
/// from the app's own [ThemeData.brightness]:
///
/// ```dart
/// TextSpan? highlightCode(CodeHighlightRequest request) {
///   final palette = request.brightness == Brightness.dark ? darkPalette : lightPalette;
///   return myTokenizer(request.code, request.language, request.baseStyle, palette);
/// }
/// ```
///
/// This package ships no grammars — see [CodeBlockView.highlighter].
typedef CodeHighlighter = TextSpan? Function(CodeHighlightRequest request);

/// What a [CodeHighlighter] is asked to highlight, and the frame it will be
/// drawn on.
///
/// New fields may be added in later releases without that being a breaking
/// change, which is why the highlighter receives one object rather than
/// positional arguments.
///
/// [baseStyle] and [brightness] are derived from [theme] rather than stored,
/// so a request can't describe a frame other than the one it carries.
@immutable
final class CodeHighlightRequest {
  /// Creates a [CodeHighlightRequest]. Public so a host can unit-test its
  /// highlighter; the package builds these itself.
  ///
  /// [language] must be non-empty, and [theme] must set at least
  /// [CodeBlockThemeData.backgroundColor] and
  /// [CodeBlockThemeData.codeTextStyle].
  CodeHighlightRequest({required this.code, required this.language, required this.theme})
    : assert(language.isNotEmpty, 'a request is only made for a fence with a language'),
      assert(theme.backgroundColor != null, 'the theme must be resolved: backgroundColor is unset'),
      assert(theme.codeTextStyle != null, 'the theme must be resolved: codeTextStyle is unset');

  /// The raw code text, without the surrounding fences.
  final String code;

  /// The language from the opening fence, verbatim: case folding and alias
  /// resolution (`js`, `py`, …) are the highlighter's job. Never empty.
  final String language;

  /// The block's resolved theme, with every field set.
  final CodeBlockThemeData theme;

  /// The block's monospace style: [theme]'s [CodeBlockThemeData.codeTextStyle].
  /// Override only what a token needs and Flutter merges the rest.
  TextStyle get baseStyle => theme.codeTextStyle!;

  /// Whether the block is a dark or a light surface. Pick the token palette
  /// from this.
  ///
  /// [theme]'s [CodeBlockThemeData.brightness] — which the package always
  /// sets, to the host's pinned value or else the background's estimated
  /// brightness. A hand-built request without one falls back to
  /// [ThemeData.estimateBrightnessForColor] on its background.
  Brightness get brightness => theme.brightness ?? ThemeData.estimateBrightnessForColor(theme.backgroundColor!);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    // baseStyle and brightness derive from theme, so comparing it covers them.
    return other is CodeHighlightRequest && other.code == code && other.language == language && other.theme == theme;
  }

  @override
  int get hashCode => Object.hash(code, language, theme);

  @override
  String toString() =>
      'CodeHighlightRequest(language: $language, ${code.length} characters, brightness: ${brightness.name})';
}

/// How a newly resolved theme differs from the one the current span was built
/// with, which decides how soon the block re-highlights.
enum _ThemeChange {
  /// Equal; nothing to do.
  none,

  /// Only colors moved, as on every frame of a theme animation. The frame
  /// repaints at once; the re-highlight is debounced through the settle timer.
  colorsOnly,

  /// The brightness flipped, or the base style's metrics changed — the
  /// highlighter may pick a different palette, or the old spans would lay out
  /// wrongly. Re-highlight at once.
  structural,
}

/// Above this many characters [CodeBlockView.highlighter] is not called at all.
const _kMaxHighlightChars = 20000;

/// How many characters a growing fence must gain before it is re-highlighted.
///
/// A streaming fence hands over a longer prefix every tick, so highlighting
/// each one costs O(n²) in the block's length. Also the longest uncolored tail
/// a reader can see, since the gap renders plain until the next pass.
const _kHighlightGrowthThreshold = 64;

/// How long a fence must go unchanged before a pending tail is highlighted.
///
/// Without it, a stream stopping mid-threshold stays partly colored for good.
const _kHighlightSettleDelay = Duration(milliseconds: 120);

/// The rounding of the block's corners.
const _kCornerRadius = Radius.circular(8);
const _kBorderRadius = BorderRadius.all(_kCornerRadius);

/// Renders a fenced code block with a framed background, monospace text, a
/// copy-to-clipboard button, and an optional language label.
///
/// The frame is themed through [CodeBlockThemeData]: [theme], then the nearest
/// [CodeBlockTheme], then [AITheme.codeBlockTheme]. By default it is dark in
/// light and dark mode alike.
///
/// Syntax highlighting is opt-in through [highlighter]. Without one — or for a
/// fence with no language, or one the highlighter doesn't recognise — the code
/// renders as plain monospace text. It stays selectable and horizontally
/// scrollable either way.
class CodeBlockView extends StatefulWidget {
  /// Creates a [CodeBlockView].
  const CodeBlockView({
    super.key,
    required this.code,
    this.language,
    this.highlighter,
    this.theme,
  });

  /// The raw code text (without the surrounding fences).
  final String code;

  /// The language identifier from the opening fence, e.g. `dart`, `python`.
  ///
  /// Shown as the block's label, and handed to [highlighter] verbatim. A value
  /// no highlighter recognises is not an error — the code renders unhighlighted.
  final String? language;

  /// Tokenizes and colors the code. When null, code renders as plain text.
  ///
  /// Grammars dwarf this package — `re_highlight`'s are ~2.7 MB of Dart source
  /// that nothing tree-shakes — so a host injects one instead, the same trade
  /// `AIMarkdownBody.mathBuilder` makes. Copy
  /// `example/lib/code_highlighter.dart` to get one.
  ///
  /// Called only for a fence with a [language], throttled while one streams,
  /// and skipped past an internal length cap. Called again whenever the
  /// resolved theme changes, since [CodeHighlightRequest.brightness] and
  /// [CodeHighlightRequest.baseStyle] come from it. One that throws, or
  /// returns spans whose text doesn't match [code], is reported through
  /// [FlutterError.onError] and falls back to plain text.
  final CodeHighlighter? highlighter;

  /// Overrides for this block's frame, layered over the nearest
  /// [CodeBlockTheme] and [AITheme.codeBlockTheme].
  ///
  /// See [CodeBlockThemeData] for the contrast this has to keep with the
  /// [highlighter]'s token colors.
  final CodeBlockThemeData? theme;

  @override
  State<CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends State<CodeBlockView> {
  /// The highlighted code, or null when it is rendered as plain text.
  ///
  /// Held in state rather than computed in `build`, which runs far more often
  /// than its inputs change — every typewriter tick, while text still arrives.
  TextSpan? _span;

  /// The exact code [_span] was built from; [CodeBlockView.code] grows past it
  /// while a fence streams.
  ///
  /// Only [_highlight] writes this, and only ever to the whole of
  /// [CodeBlockView.code] — so the one place a shortfall can arise is
  /// [didUpdateWidget]'s throttle branch, which arms [_settleTimer] to clear
  /// it. [_displaySpan] asserts the two stay in step.
  String _highlightedCode = '';

  /// Fires the pass that picks up a tail too short to have triggered one.
  Timer? _settleTimer;

  /// The inputs a failure was already reported for, so a still-streaming fence
  /// reports once rather than on every rebuild — but a failure under a new
  /// kind of highlighter or palette (after a theme change) is reported afresh.
  ({String language, Type highlighterType, Brightness brightness})? _failureReportedFor;

  /// The frame this block draws, and what the highlighter is told about it.
  ///
  /// Resolved outside `build` — in [didChangeDependencies] and
  /// [didUpdateWidget] — because a change to it has to invalidate [_span]:
  /// the highlighter was handed its brightness and base style.
  ResolvedCodeBlockTheme? _theme;

  ResolvedCodeBlockTheme get _resolvedTheme => _theme!;

  /// Re-resolves [_theme], and returns how it changed.
  _ThemeChange _resolveTheme() {
    final previous = _theme;
    final theme = ResolvedCodeBlockTheme.resolve(context, override: widget.theme);
    if (theme == previous) return _ThemeChange.none;
    _theme = theme;
    if (previous == null || theme.brightness != previous.brightness) return _ThemeChange.structural;
    // Compared with the colors masked out: a font, size or height change has to
    // re-lay-out the spans, which carry the old base style.
    const mask = Color(0x00000000);
    final metricsChanged =
        theme.codeTextStyle.copyWith(color: mask, backgroundColor: mask) !=
        previous.codeTextStyle.copyWith(color: mask, backgroundColor: mask);
    return metricsChanged ? _ThemeChange.structural : _ThemeChange.colorsOnly;
  }

  /// (Re)arms the settle pass, which highlights once the inputs stop moving.
  void _scheduleSettlePass() {
    _settleTimer?.cancel();
    _settleTimer = Timer(_kHighlightSettleDelay, () {
      if (mounted) setState(_highlight);
    });
  }

  // There is no `initState` override: the theme is inherited, so it can't be
  // read before this first call, which is where the first highlight pass runs.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    switch (_resolveTheme()) {
      case _ThemeChange.none:
        break;
      case _ThemeChange.colorsOnly:
        // Spans carrying the old base style keep its color until the settle
        // pass, which each animation frame re-arms — so plain tokens hold the
        // old color for the whole animation and catch up 120 ms after it ends.
        _scheduleSettlePass();
      case _ThemeChange.structural:
        _highlight();
    }
  }

  @override
  void didUpdateWidget(covariant CodeBlockView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Anything but more of the same code leaves no colored prefix to keep.
    // The highlighter compares by identity, so hosts should hoist it rather
    // than pass a fresh closure per build.
    final themeChange = _resolveTheme();
    if (widget.language != oldWidget.language ||
        themeChange == _ThemeChange.structural ||
        widget.highlighter != oldWidget.highlighter ||
        !widget.code.startsWith(_highlightedCode)) {
      _highlight();
      return;
    }

    if (widget.code.length - _highlightedCode.length >= _kHighlightGrowthThreshold) {
      _highlight();
    } else if (widget.code.length != _highlightedCode.length || themeChange == _ThemeChange.colorsOnly) {
      // Too small a gain to pay for a pass, or a color-only theme step (one per
      // frame while a theme animates); revisit once things settle.
      _scheduleSettlePass();
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  /// Re-runs the highlighter over the whole of [CodeBlockView.code].
  void _highlight() {
    _settleTimer?.cancel();
    _settleTimer = null;
    _span = _buildSpan();
    _highlightedCode = widget.code;
  }

  TextSpan? _buildSpan() {
    final highlighter = widget.highlighter;
    if (highlighter == null) return null;

    final language = widget.language;
    if (language == null || language.isEmpty) return null;
    if (widget.code.length > _kMaxHighlightChars) return null;

    try {
      final span = highlighter(
        CodeHighlightRequest(code: widget.code, language: language, theme: _resolvedTheme.toData()),
      );
      // Null is the documented "I don't know this one", not a failure.
      if (span == null) return null;

      // ~1% of the tokenizing just done, guarding the only property here that
      // matters: colors are a nicety, the code is not. `re_highlight`, for
      // one, reports a mid-parse failure on its result rather than throwing,
      // handing back only the tokens it got to.
      final text = span.toPlainText(includeSemanticsLabels: false, includePlaceholders: false);
      if (text != widget.code) {
        _reportHighlightFailure(_alteredTextError(widget.code, text), null, language, highlighter);
        return null;
      }

      return span;
    } catch (error, stack) {
      // A code block must not take down a message list — but degrading
      // silently would look identical to a language never covered.
      _reportHighlightFailure(error, stack, language, highlighter);
      return null;
    }
  }

  /// Hands a highlighting failure to the host's [FlutterError.onError] before
  /// the block falls back to plain text.
  void _reportHighlightFailure(Object error, StackTrace? stack, String language, CodeHighlighter highlighter) {
    // A failing fence rebuilds every tick while streaming; report once per
    // highlighter type, language and palette rather than once per pass. By
    // type, not identity: a host building its highlighter inline hands over a
    // new closure on every rebuild.
    final brightness = _resolvedTheme.brightness;
    final key = (language: language, highlighterType: highlighter.runtimeType, brightness: brightness);
    if (_failureReportedFor == key) return;
    _failureReportedFor = key;

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stream_chat_flutter_ai',
        context: ErrorDescription(
          'while syntax-highlighting a $language code block of ${widget.code.length} characters on a '
          '${brightness.name} background with ${highlighter.runtimeType}; it will render as plain text',
        ),
      ),
    );
  }

  /// Describes how a highlighter's output text differs from the code it was
  /// given, so the report points at the spot rather than just saying so.
  static StateError _alteredTextError(String expected, String actual) {
    final shorter = expected.length < actual.length ? expected.length : actual.length;
    var index = 0;
    while (index < shorter && expected.codeUnitAt(index) == actual.codeUnitAt(index)) {
      index++;
    }
    return StateError(
      'the highlighter altered the code text: expected ${expected.length} characters, got '
      '${actual.length}; first difference at index $index',
    );
  }

  /// [_span] extended with whatever arrived after it, unhighlighted.
  ///
  /// [_span] covers only [_highlightedCode], so rendering it alone mid-stream
  /// would show a truncated block. One plain run keeps the code whole.
  TextSpan? get _displaySpan {
    final span = _span;
    if (span == null) return null;

    final pending = widget.code.substring(_highlightedCode.length);
    if (pending.isEmpty) return span;

    // A tail with no pass coming would stay plain for the block's whole life,
    // and look exactly like a highlighter that declined the language.
    assert(_settleTimer != null, 'a pending tail must have a settle pass armed');

    return TextSpan(
      style: _resolvedTheme.codeTextStyle,
      children: [
        span,
        TextSpan(text: pending),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final span = _displaySpan;
    final theme = _resolvedTheme;
    final style = theme.codeTextStyle;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: _kBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(language: widget.language, code: widget.code, theme: theme),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: span == null
                ? SelectableText(widget.code, style: style)
                // Passed as the base style too, so a highlighter that only
                // sets colors per token still gets this font: Flutter merges a
                // child span's style over its ancestors'.
                : SelectableText.rich(span, style: style),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.language, required this.code, required this.theme});

  final String code;
  final String? language;
  final ResolvedCodeBlockTheme theme;

  @override
  Widget build(BuildContext context) {
    final language = this.language;
    Widget header = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          if (language != null && language.isNotEmpty) Text(language, style: theme.languageLabelStyle),
          const Spacer(),
          _CopyButton(code: code, color: theme.copyIconColor, copiedColor: theme.copiedIconColor),
        ],
      ),
    );

    // Painted only when it differs, so the default single-surface frame draws
    // exactly as it always has.
    if (theme.headerBackgroundColor != theme.backgroundColor) {
      header = DecoratedBox(
        decoration: BoxDecoration(
          color: theme.headerBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: _kCornerRadius),
        ),
        child: header,
      );
    }

    return header;
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.code, required this.color, required this.copiedColor});

  final String code;
  final Color color;
  final Color copiedColor;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  Timer? _resetTimer;

  Future<void> _onTap() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    // The clipboard write is a platform round-trip, so the block may have been
    // scrolled out of the list (or the message replaced) before it completes.
    if (!mounted) return;

    setState(() => _copied = true);
    // A single restartable timer, rather than a `Future.delayed` per tap: two
    // overlapping delays would race, and the first to resolve would clear the
    // confirmation while the later tap still expected it shown.
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final translations = AITranslations.of(context);

    return IconButton(
      onPressed: _onTap,
      icon: Icon(
        _copied ? Icons.check : Icons.content_copy,
        size: 16,
        color: _copied ? widget.copiedColor : widget.color,
      ),
      tooltip: _copied ? translations.codeCopied : translations.copyCode,
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
