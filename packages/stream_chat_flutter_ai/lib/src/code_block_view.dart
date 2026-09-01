import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/vs2015.dart';
import 'package:stream_chat_flutter_ai/src/highlight/code_languages.dart';

/// Token colors used by [CodeBlockView] when no other theme is given.
///
/// VS Code's Dark+ palette. Its `root` entry — `#1E1E1E` on `#DCDCDC` — is what
/// supplies the block's background, so highlighting changed the token colors
/// without changing the box the code sits in.
const kDefaultCodeBlockTheme = vs2015Theme;

/// Background used when a theme carries no `root` entry.
const _kBgColor = Color(0xFF1E1E1E);

/// Foreground used when a theme carries no `root` entry.
const _kFgColor = Color(0xFFD4D4D4);

/// How much of the foreground color the header chrome keeps.
const _kLabelOpacity = 0.6;

/// Above this many characters the code is rendered unhighlighted.
///
/// Highlighting is a single linear pass, but it runs again on every frame a
/// growing fence produces while a message streams, which makes the total cost
/// quadratic in the block's length. Past a few hundred lines that is felt, and
/// nobody is reading token colors that far down a wall of generated code
/// anyway.
const _kMaxHighlightChars = 20000;

/// The font stack for code text.
///
/// `monospace` is a real family only on Android — and, because Flutter hands
/// family names straight to the browser, on web. Everywhere else it silently
/// resolves to the default sans face, which is why code blocks used to render
/// proportionally on iOS, macOS and Windows. The fallbacks name each platform's
/// actual monospace font.
const _kMonoFontFamily = 'monospace';
const _kMonoFontFamilyFallback = ['Menlo', 'Consolas', 'Roboto Mono', 'DejaVu Sans Mono', 'Courier New'];

/// Renders a fenced code block with a dark background, syntax-highlighted
/// monospace text, a copy-to-clipboard button, and an optional language label.
///
/// Highlighting covers the languages LLMs commonly emit (and their usual
/// aliases — `js`, `py`, `sh`, `yml`, …). A fence with no language, or one
/// outside that set, renders as plain monospace text; it stays selectable and
/// horizontally scrollable either way.
class CodeBlockView extends StatefulWidget {
  /// Creates a [CodeBlockView].
  const CodeBlockView({
    super.key,
    required this.code,
    this.language,
    this.theme = kDefaultCodeBlockTheme,
  });

  /// The raw code text (without the surrounding fences).
  final String code;

  /// The language identifier from the opening fence, e.g. `dart`, `python`.
  ///
  /// Matched case-insensitively, aliases included. An unrecognised value is not
  /// an error — the code renders unhighlighted.
  final String? language;

  /// Token colors, keyed by highlight.js scope name (`keyword`, `string`,
  /// `comment`, `title.function_`, …), defaulting to [kDefaultCodeBlockTheme].
  ///
  /// The `root` entry is read directly rather than applied to a token: its
  /// `backgroundColor` fills the block and its `color` is the default text
  /// color, which the header's label and copy button then follow at reduced
  /// opacity. Any of `re_highlight`'s `styles/*.dart` maps works here, as does a
  /// hand-written one; scopes the map doesn't mention simply keep the default
  /// color.
  ///
  /// Deliberately kept dark regardless of the ambient [Theme] — code reads as
  /// code. Pass a `const` or otherwise hoisted map: `AIMarkdownBody` memoizes
  /// built fences by theme identity, so a map rebuilt on every frame costs that
  /// reuse.
  final Map<String, TextStyle> theme;

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
        // By contents, not identity: comparing a few dozen entries is far
        // cheaper than re-tokenizing the block, so a host handing over an
        // equal-but-fresh map every build costs nothing here.
        !mapEquals(widget.theme, oldWidget.theme)) {
      _span = _buildSpan();
    }
  }

  TextSpan? _buildSpan() {
    final language = widget.language;
    if (language == null || language.isEmpty) return null;
    if (widget.code.length > _kMaxHighlightChars) return null;
    // `highlight` throws on a language it doesn't know rather than degrading,
    // and an LLM will happily label a fence `pseudocode`.
    if (kCodeHighlight.getLanguage(language) == null) return null;

    try {
      final result = kCodeHighlight.highlight(code: widget.code, language: language);
      final renderer = TextSpanRenderer(_codeTextStyle, widget.theme);
      result.render(renderer);
      return renderer.span;
    } on Object {
      // A grammar that trips over its input must not cost the user the code.
      // `ignoreIllegals` defaults to true, so this is the belt to that braces.
      return null;
    }
  }

  Color get _foreground => widget.theme['root']?.color ?? _kFgColor;

  Color get _background => widget.theme['root']?.backgroundColor ?? _kBgColor;

  Color get _labelColor => _foreground.withValues(alpha: _kLabelOpacity);

  TextStyle get _codeTextStyle => TextStyle(
    fontFamily: _kMonoFontFamily,
    fontFamilyFallback: _kMonoFontFamilyFallback,
    fontSize: 13,
    color: _foreground,
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
        color: _background,
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
                // The renderer stamps the base style at every nesting level and
                // Flutter merges a child span's style over its ancestors', so
                // the theme contributes color on top of this font rather than
                // replacing it.
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
