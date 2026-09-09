import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';

/// Builds the highlighted span tree for a fenced code block.
///
/// [language] arrives verbatim: case folding and alias resolution (`js`, `py`,
/// …) are the highlighter's job. [baseStyle] is the block's monospace style —
/// override only what a token needs and Flutter merges the rest.
///
/// Return `null` for a language you don't cover, and the block renders [code]
/// as plain text. That is a normal outcome, not a failure.
///
/// This package ships no grammars — see [CodeBlockView.highlighter].
typedef CodeHighlighter = TextSpan? Function(String code, String language, TextStyle baseStyle);

/// The background [CodeBlockView] uses when none is given.
const kDefaultCodeBackgroundColor = Color(0xFF1E1E1E);

/// The code color [CodeBlockView] uses when none is given.
const kDefaultCodeForegroundColor = Color(0xFFD4D4D4);

/// How much of the foreground color the header chrome keeps.
const _kLabelOpacity = 0.6;

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

/// The font stack for code text.
///
/// `monospace` is a real family only on Android; elsewhere it silently resolves
/// to the default sans face, so the fallbacks name each platform's real one.
const _kMonoFontFamily = 'monospace';
const _kMonoFontFamilyFallback = ['Menlo', 'Consolas', 'Roboto Mono', 'DejaVu Sans Mono', 'Courier New'];

/// Renders a fenced code block with a dark background, monospace text, a
/// copy-to-clipboard button, and an optional language label.
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
    this.backgroundColor = kDefaultCodeBackgroundColor,
    this.foregroundColor = kDefaultCodeForegroundColor,
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
  /// and skipped past an internal length cap. One that throws, or returns
  /// spans whose text doesn't match [code], is reported through
  /// [FlutterError.onError] and falls back to plain text.
  final CodeHighlighter? highlighter;

  /// Fills the block. Defaults to [kDefaultCodeBackgroundColor].
  ///
  /// Deliberately independent of the ambient [Theme] — code reads as code.
  final Color backgroundColor;

  /// The code's color, which the header's label and copy button follow at
  /// reduced opacity. Defaults to [kDefaultCodeForegroundColor].
  ///
  /// Reaches a [highlighter] as its base style's color, so the two should come
  /// from the same palette.
  final Color foregroundColor;

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

  /// The language a failure was already reported for, so a still-streaming
  /// fence reports once rather than on every rebuild.
  String? _failureReportedFor;

  @override
  void initState() {
    super.initState();
    _highlight();
  }

  @override
  void didUpdateWidget(covariant CodeBlockView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Anything but more of the same code leaves no colored prefix to keep.
    // The highlighter compares by identity, so hosts should hoist it rather
    // than pass a fresh closure per build.
    if (widget.language != oldWidget.language ||
        widget.foregroundColor != oldWidget.foregroundColor ||
        widget.highlighter != oldWidget.highlighter ||
        !widget.code.startsWith(_highlightedCode)) {
      _highlight();
      return;
    }

    if (widget.code.length - _highlightedCode.length >= _kHighlightGrowthThreshold) {
      _highlight();
    } else if (widget.code.length != _highlightedCode.length) {
      // Too small a gain to pay for a pass; revisit once the fence settles.
      _settleTimer?.cancel();
      _settleTimer = Timer(_kHighlightSettleDelay, () {
        if (mounted) setState(_highlight);
      });
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
      final span = highlighter(widget.code, language, _codeTextStyle);
      // Null is the documented "I don't know this one", not a failure.
      if (span == null) return null;

      // ~1% of the tokenizing just done, guarding the only property here that
      // matters: colors are a nicety, the code is not. `re_highlight`, for
      // one, reports a mid-parse failure on its result rather than throwing,
      // handing back only the tokens it got to.
      if (span.toPlainText(includeSemanticsLabels: false, includePlaceholders: false) != widget.code) {
        _reportHighlightFailure(StateError('the highlighter altered the code text'), null, language);
        return null;
      }

      return span;
    } catch (error, stack) {
      // A code block must not take down a message list — but degrading
      // silently would look identical to a language never covered.
      _reportHighlightFailure(error, stack, language);
      return null;
    }
  }

  /// Hands a highlighting failure to the host's [FlutterError.onError] before
  /// the block falls back to plain text.
  void _reportHighlightFailure(Object error, StackTrace? stack, String language) {
    // A failing fence rebuilds every tick while streaming; report once.
    if (_failureReportedFor == language) return;
    _failureReportedFor = language;

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stream_chat_flutter_ai',
        context: ErrorDescription(
          'while syntax-highlighting a $language code block of '
          '${widget.code.length} characters; it will render as plain text',
        ),
      ),
    );
  }

  Color get _labelColor => widget.foregroundColor.withValues(alpha: _kLabelOpacity);

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
      style: _codeTextStyle,
      children: [
        span,
        TextSpan(text: pending),
      ],
    );
  }

  TextStyle get _codeTextStyle => TextStyle(
    fontFamily: _kMonoFontFamily,
    fontFamilyFallback: _kMonoFontFamilyFallback,
    fontSize: 13,
    color: widget.foregroundColor,
    height: 1.5,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    final span = _displaySpan;
    final style = _codeTextStyle;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(language: widget.language, code: widget.code, labelColor: _labelColor),
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
  const _Header({required this.language, required this.code, required this.labelColor});

  final String? code;
  final String? language;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          if (language != null && language!.isNotEmpty)
            Text(
              language!,
              style: TextStyle(
                fontFamily: _kMonoFontFamily,
                fontFamilyFallback: _kMonoFontFamilyFallback,
                fontSize: 12,
                color: labelColor,
              ),
            ),
          const Spacer(),
          _CopyButton(code: code ?? '', color: labelColor),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.code, required this.color});

  final String code;
  final Color color;

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
        color: _copied ? Colors.greenAccent : widget.color,
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
