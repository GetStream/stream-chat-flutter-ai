import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' show MarkdownStyleSheet;
import 'package:stream_chat_flutter_ai/src/ai_markdown_body.dart';
// Imported for the doc links below too.
import 'package:stream_chat_flutter_ai/src/ai_typing_indicator_view.dart';
import 'package:stream_chat_flutter_ai/src/code_block_view.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/code_block_theme.dart';
import 'package:stream_chat_flutter_ai/src/typewriter_builder.dart';

bool get _isDesktopDeviceOrWeb =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

/// {@template streamingMessageView}
/// A widget that displays a message in a streaming fashion. The message is
/// displayed as if it is being typed out by a typewriter.
///
/// Markdown in the message is fully rendered, including:
/// - Fenced code blocks (with a copy-to-clipboard button and language label,
///   syntax-highlighted when a [codeHighlighter] is supplied), which appear as
///   soon as the opening fence arrives rather than waiting for the block to
///   close.
/// - JSON / chart blocks rendered as interactive charts.
/// - LaTeX, when a [mathBuilder] is supplied.
///
/// **Accessibility.** With reduced motion on
/// ([MediaQueryData.disableAnimations]) there is no typewriter: each new [text]
/// is shown in full at once, and [onTypewriterStateChanged] reports
/// [TypewriterState.idle] for it. Turning reduced motion on mid-reveal
/// finishes the reveal.
///
/// The view is deliberately *not* a live region. A streamed reply changes
/// many times a second, and announcing every chunk would bury the user in
/// half-sentences; a screen reader reads the finished message when the user
/// moves to it. Pair it with an [AITypingIndicatorView], whose live region
/// announces the AI's state while the reply is being produced.
/// {@endtemplate}
class StreamingMessageView extends StatefulWidget {
  /// {@macro streamingMessageView}
  const StreamingMessageView({
    super.key,
    required this.text,
    this.onTapLink,
    this.typingSpeed = const Duration(milliseconds: 10),
    this.onTypewriterStateChanged,
    this.styleSheet,
    this.mathBuilder,
    this.useDollarDelimitersForMath = false,
    this.codeHighlighter,
    this.codeBlockTheme,
  });

  /// The text to display in the widget.
  final String text;

  /// Style overrides for the rendered markdown. See
  /// [AIMarkdownBody.styleSheet].
  final MarkdownStyleSheet? styleSheet;

  /// Renders LaTeX expressions. See [AIMarkdownBody.mathBuilder].
  final MathBuilder? mathBuilder;

  /// Whether `$…$` is also treated as a LaTeX delimiter. See
  /// [AIMarkdownBody.useDollarDelimitersForMath].
  final bool useDollarDelimitersForMath;

  /// Syntax-highlights code fences. See [AIMarkdownBody.codeHighlighter].
  final CodeHighlighter? codeHighlighter;

  /// Overrides for how code fences are framed. See
  /// [AIMarkdownBody.codeBlockTheme] and [CodeBlockView.theme].
  final CodeBlockThemeData? codeBlockTheme;

  /// The speed at which the text is typed out.
  ///
  /// Defaults to 10 milliseconds per character.
  final Duration typingSpeed;

  /// Called when the user taps a hyperlink in the rendered markdown.
  ///
  /// If not provided, links are silently ignored.
  final MarkdownTapLinkCallback? onTapLink;

  /// A callback that is called whenever the typewriter state changes.
  final ValueChanged<TypewriterState>? onTypewriterStateChanged;

  @override
  State<StreamingMessageView> createState() => _StreamingMessageViewState();
}

class _StreamingMessageViewState extends State<StreamingMessageView> {
  late String _displayText;
  late final TypewriterController _controller;

  void _onTypewriterValueChanged() {
    final value = _controller.value;
    widget.onTypewriterStateChanged?.call(value.state);
    setState(() => _displayText = value.text);
  }

  @override
  void initState() {
    super.initState();
    _controller = TypewriterController(
      text: widget.text,
      typingSpeed: widget.typingSpeed,
    )..addListener(_onTypewriterValueChanged);

    _displayText = _controller.value.text;

    // Report the initial state once, after the first frame.
    //
    // A view constructed with its complete text is already fully revealed and
    // never transitions, so the controller emits nothing and a host waiting to
    // hear `idle` (to flip a "generating" flag back off, say) would wait
    // forever. Deferred to post-frame so that host is free to rebuild in
    // response without doing so during this build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onTypewriterStateChanged?.call(_controller.value.state);
    });
  }

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion switched on mid-reveal: show what has arrived rather than
    // carrying on animating it.
    if (_reduceMotion && _controller.value.state == TypewriterState.typing) {
      _controller.finishTyping();
    }
  }

  @override
  void didUpdateWidget(covariant StreamingMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      if (_reduceMotion) {
        // Reveals the whole text at once and reports `idle`, with no timer.
        _controller.text = widget.text;
      } else {
        _controller.updateText(widget.text);
      }
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTypewriterValueChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AIMarkdownBody(
      data: _displayText,
      selectable: _isDesktopDeviceOrWeb,
      onTapLink: widget.onTapLink,
      styleSheet: widget.styleSheet,
      mathBuilder: widget.mathBuilder,
      useDollarDelimitersForMath: widget.useDollarDelimitersForMath,
      codeHighlighter: widget.codeHighlighter,
      codeBlockTheme: widget.codeBlockTheme,
    );
  }
}
