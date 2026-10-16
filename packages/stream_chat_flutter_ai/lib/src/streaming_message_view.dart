import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' show MarkdownStyleSheet;
import 'package:stream_chat_flutter_ai/src/ai_markdown_body.dart';
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
/// {@endtemplate}
class StreamingMessageView extends StatefulWidget {
  /// {@macro streamingMessageView}
  const StreamingMessageView({
    super.key,
    required this.text,
    this.onTapLink,
    this.typingSpeed = const Duration(milliseconds: 10),
    this.onTypewriterStateChanged,
    this.expectMoreText = false,
    this.onFinished,
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
  ///
  /// [TypewriterState.idle] only means the typewriter has caught up with the
  /// text received so far, which also happens mid-stream whenever it overtakes
  /// the backend. To learn when a reply is completely on screen, use
  /// [onFinished].
  final ValueChanged<TypewriterState>? onTypewriterStateChanged;

  /// Whether more [text] for this message may still arrive, e.g. while the
  /// backend is generating the reply. [onFinished] waits until this is `false`.
  ///
  /// Defaults to `false`.
  final bool expectMoreText;

  /// Called once per reply, after the frame in which it is completely on
  /// screen: [expectMoreText] is `false` and every character of non-empty
  /// [text] has been revealed. Usually later than the end of generation, as
  /// the typewriter falls behind the backend.
  final VoidCallback? onFinished;

  @override
  State<StreamingMessageView> createState() => _StreamingMessageViewState();
}

class _StreamingMessageViewState extends State<StreamingMessageView> {
  late String _displayText;
  late final TypewriterController _controller;
  var _wasFinished = false;

  void _onTypewriterValueChanged() {
    final value = _controller.value;
    widget.onTypewriterStateChanged?.call(value.state);
    setState(() => _displayText = value.text);
    _scheduleFinishCheck();
  }

  bool get _isFinished =>
      !widget.expectMoreText &&
      widget.text.isNotEmpty &&
      _controller.value.state != TypewriterState.typing &&
      _controller.value.text == widget.text;

  /// Reports [StreamingMessageView.onFinished] when the reply goes from
  /// unfinished to finished.
  ///
  /// [_wasFinished] is tracked on every check, whether or not there is a
  /// callback, so a callback passed after the reply finished doesn't report it
  /// late. The report is deferred to after the current frame, since the check
  /// can run during a build (from [didUpdateWidget]).
  void _scheduleFinishCheck() {
    final isFinished = _isFinished;
    final justFinished = isFinished && !_wasFinished;
    _wasFinished = isFinished;
    if (!justFinished || widget.onFinished == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFinished?.call();
    });
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
    _scheduleFinishCheck();
  }

  @override
  void didUpdateWidget(covariant StreamingMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _controller.updateText(widget.text);
    }
    _scheduleFinishCheck();
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
