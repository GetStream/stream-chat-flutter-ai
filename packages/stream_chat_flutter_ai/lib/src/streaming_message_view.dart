import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' show MarkdownStyleSheet;
import 'package:stream_chat_flutter_ai/src/ai_markdown_body.dart';
import 'package:stream_chat_flutter_ai/src/code_block_view.dart';
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
    this.codeBackgroundColor = kDefaultCodeBackgroundColor,
    this.codeForegroundColor = kDefaultCodeForegroundColor,
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

  /// Fills code fences. See [CodeBlockView.backgroundColor].
  final Color codeBackgroundColor;

  /// Colors the text in code fences. See [CodeBlockView.foregroundColor].
  final Color codeForegroundColor;

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
  /// backend is generating the reply.
  ///
  /// The view can't tell a finished reply from a pause in the stream by its
  /// [text] alone, so [onFinished] waits until this is `false`. Typically
  /// driven by the backend's AI state, or a "generating" flag on the message.
  ///
  /// Defaults to `false`.
  final bool expectMoreText;

  /// Called once the reply is completely on screen: [expectMoreText] is `false`
  /// and the typewriter has revealed every character of [text].
  ///
  /// The backend usually finishes well before the typewriter does, so this
  /// fires later than the end of generation. It is called after the frame in
  /// which the reply finished, so the host is free to rebuild in response.
  ///
  /// Fires once per reply, and again only if the text grows or [expectMoreText]
  /// turns back to `true` and then `false`. A view built with its complete
  /// text and `expectMoreText: false`, such as a message from history, reports
  /// it after its first frame.
  final VoidCallback? onFinished;

  @override
  State<StreamingMessageView> createState() => _StreamingMessageViewState();
}

class _StreamingMessageViewState extends State<StreamingMessageView> {
  late String _displayText;
  late final TypewriterController _controller;
  var _finishReported = false;

  void _onTypewriterValueChanged() {
    final value = _controller.value;
    widget.onTypewriterStateChanged?.call(value.state);
    if (value.state == TypewriterState.typing) _finishReported = false;
    setState(() => _displayText = value.text);
    _scheduleFinishCheck();
  }

  bool get _isFinished =>
      !widget.expectMoreText &&
      _controller.value.state != TypewriterState.typing &&
      _controller.value.text == widget.text;

  /// Reports [StreamingMessageView.onFinished] after the current frame, since
  /// the check can run during a build (from [didUpdateWidget]).
  void _scheduleFinishCheck() {
    if (_finishReported || widget.onFinished == null || !_isFinished) return;
    _finishReported = true;
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
    if (widget.expectMoreText && !oldWidget.expectMoreText) _finishReported = false;
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
      codeBackgroundColor: widget.codeBackgroundColor,
      codeForegroundColor: widget.codeForegroundColor,
    );
  }
}
