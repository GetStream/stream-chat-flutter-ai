import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Builds the highlighted span tree for a fenced code block.
///
/// [code] is the fence body and [language] its opening-line label, passed
/// through verbatim — matching it case-insensitively, and resolving aliases like
/// `js` or `py`, is the highlighter's job. [baseStyle] is the monospace style
/// the block has already settled on, including its color; return spans that
/// override only what a token needs, and Flutter merges the rest.
///
/// Returning `null` means "not highlighted" — an unknown language, or a body
/// this highlighter would rather not touch — and the block renders [code] as
/// plain monospace text instead. That is a normal outcome, not a failure.
///
/// Tokenizing code needs a grammar set, and this package deliberately ships
/// without one — see [CodeBlockView.highlighter].
typedef CodeHighlighter = TextSpan? Function(String code, String language, TextStyle baseStyle);

/// The background [CodeBlockView] uses when none is given.
const kDefaultCodeBackgroundColor = Color(0xFF1E1E1E);

/// The code color [CodeBlockView] uses when none is given.
const kDefaultCodeForegroundColor = Color(0xFFD4D4D4);

/// How much of the foreground color the header chrome keeps.
const _kLabelOpacity = 0.6;

/// Above this many characters [CodeBlockView.highlighter] is not called.
///
/// Highlighting is typically a single linear pass, but it runs again on every
/// frame a growing fence produces while a message streams, which makes the
/// total cost quadratic in the block's length. Past a few hundred lines that is
/// felt, and nobody is reading token colors that far down a wall of generated
/// code anyway.
const _kMaxHighlightChars = 20000;

/// The font stack for code text.
///
/// `monospace` is a real family only on Android. Everywhere else it silently
/// resolves to the default sans face, which is why code blocks used to render
/// proportionally on iOS, macOS and Windows. The fallbacks name each platform's
/// actual monospace font.
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
  /// A grammar set is the single largest thing a highlighter brings with it —
  /// `re_highlight`'s 194 grammars are ~2.7 MB of Dart source, and because each
  /// is a top-level `final` holding a tree of constructor calls, nothing
  /// tree-shakes the unused ones back out of a host app. This package stays
  /// standalone and lets the host inject one instead — the same trade
  /// `AIMarkdownBody.mathBuilder` makes. `example/lib/code_highlighter.dart` is
  /// a complete implementation over `re_highlight`, ready to copy.
  ///
  /// Only called for a fence that has a [language], and not for bodies past an
  /// internal length cap, since a streaming fence re-highlights as it grows.
  /// A highlighter that throws, or that returns spans whose text doesn't match
  /// [code], is reported through [FlutterError.onError] and the block falls back
  /// to plain text — highlighting never costs the reader the code.
  final CodeHighlighter? highlighter;

  /// Fills the block. Defaults to [kDefaultCodeBackgroundColor].
  ///
  /// Deliberately independent of the ambient [Theme] — code reads as code.
  final Color backgroundColor;

  /// The code's color, which the header's label and copy button then follow at
  /// reduced opacity. Defaults to [kDefaultCodeForegroundColor].
  ///
  /// A [highlighter] receives this as the base style's color and paints token
  /// colors over it, so the two should come from the same palette.
  final Color foregroundColor;

  @override
  State<CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends State<CodeBlockView> {
  /// The highlighted code, or null when it is rendered as plain text.
  ///
  /// Computed off the widget's fields rather than in `build`, because those
  /// fields are what it depends on and a code block is rebuilt far more often
  /// than it changes — every typewriter tick, for one, while the text after it
  /// is still arriving.
  TextSpan? _span;

  /// The language a highlighting failure has already been reported for, so a
  /// still-streaming fence reports once rather than on every rebuild.
  String? _failureReportedFor;

  @override
  void initState() {
    super.initState();
    _span = _buildSpan();
  }

  @override
  void didUpdateWidget(covariant CodeBlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.code != oldWidget.code ||
        widget.language != oldWidget.language ||
        widget.foregroundColor != oldWidget.foregroundColor ||
        // Hosts pass an inline closure, so this differs on almost every build
        // of theirs. It costs nothing in the case that matters — a streaming
        // fence re-highlights anyway, because its `code` grew — and
        // `AIMarkdownBody` hands back an identical cached widget for an
        // unchanged fence, so a host rebuilding for unrelated reasons doesn't
        // reach this at all.
        widget.highlighter != oldWidget.highlighter) {
      _span = _buildSpan();
    }
  }

  TextSpan? _buildSpan() {
    final highlighter = widget.highlighter;
    if (highlighter == null) return null;

    final language = widget.language;
    if (language == null || language.isEmpty) return null;
    if (widget.code.length > _kMaxHighlightChars) return null;

    try {
      final span = highlighter(widget.code, language, _codeTextStyle);
      // A null return is the documented "I don't know this one" answer, not a
      // failure, so it degrades without a word.
      if (span == null) return null;

      // One linear pass next to the tokenizing just done, guarding the only
      // property of this widget that actually matters: token colors are a
      // nicety, the user's code is not. Highlighters drop text more often than
      // you would hope — `re_highlight`, for one, reports a mid-parse grammar
      // failure on its result rather than throwing, and hands back only the
      // tokens it managed to produce.
      if (span.toPlainText(includeSemanticsLabels: false, includePlaceholders: false) != widget.code) {
        _reportHighlightFailure(StateError('the highlighter altered the code text'), null, language);
        return null;
      }

      return span;
    } catch (error, stack) {
      // Third-party code, called once per fence per tick. Degrading to plain
      // text is right — a code block must not take down a message list — but
      // silently would leave the host unable to tell a broken highlighter from
      // a language it never covered.
      _reportHighlightFailure(error, stack, language);
      return null;
    }
  }

  /// Hands a highlighting failure to the host's [FlutterError.onError] before
  /// the block falls back to plain text.
  ///
  /// Degrading silently would be indistinguishable from the documented
  /// "unrecognised language" path, so a host would have no way to tell a broken
  /// highlighter from a language it never covered — and nobody files that bug.
  void _reportHighlightFailure(Object error, StackTrace? stack, String language) {
    // A fence that fails while it is still streaming rebuilds on every
    // typewriter tick. Report the first failure, not a few hundred copies of
    // it.
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
    final span = _span;
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
    return IconButton(
      onPressed: _onTap,
      icon: Icon(
        _copied ? Icons.check : Icons.content_copy,
        size: 16,
        color: _copied ? Colors.greenAccent : widget.color,
      ),
      tooltip: _copied ? 'Copied!' : 'Copy code',
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
