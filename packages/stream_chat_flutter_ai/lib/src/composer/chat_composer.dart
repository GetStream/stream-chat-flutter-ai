import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_controller.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_factory.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_input.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_props.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_option.dart';
// Here for the [SpeechToTextButton] doc link on `enableSpeechToText` only;
// nothing in this file's code uses it.
import 'package:stream_chat_flutter_ai/src/composer/speech_to_text_button.dart';
import 'package:stream_chat_flutter_ai/src/composer/speech_to_text_controller.dart';

/// Callback fired when the user taps the send button.
///
/// [text] is the current message text. [selectedOption] is the active
/// [ChatOption], or `null` if the user did not select one. [attachments] is
/// the list of images the user picked via the composer's attachment button.
///
/// Returning a [Future] is supported and expected — a send is usually a
/// network call. The composer does not wait for it before clearing the field
/// (see [ChatComposerInputProps.onSend]), but it does watch it: a rejected
/// future is reported through [FlutterError.onError] instead of being
/// swallowed as an unhandled asynchronous error.
typedef ChatComposerSendCallback =
    FutureOr<void> Function(
      String text,
      ChatOption? selectedOption,
      List<XFile> attachments,
    );

/// Marks the 8px gaps the composer inserts between a rendered leading or
/// trailing slot and the input container.
///
/// Keyed only so the gap-handling regression tests can identify exactly these
/// spacers, and which side each belongs to. Matching on width alone also
/// catches the attachment thumbnails' own 8px separator, which would quietly
/// turn those tests into a measurement of something else the first time one
/// rendered an attachment. Two keys rather than one because siblings in a
/// single [Row] may not share a key.
const _leadingGapKey = Key('stream_chat_flutter_ai.composer.slot_gap.leading');
const _trailingGapKey = Key('stream_chat_flutter_ai.composer.slot_gap.trailing');

/// An AI-aware message composer.
///
/// Renders a text input with:
/// - An inline selected-option chip (with dismiss button) inside the input
///   box once a [ChatOption] is selected — see `ComposerAttachmentSheet`,
///   which lists [ChatComposerController.chatOptions] alongside the photo
///   picker, opened from the composer's leading "+" button by default.
/// - A row of image thumbnails inside the input box, above the text field,
///   once the user has picked attachments — through the leading "+" button by
///   default (see [ChatComposerFactory.buildLeading]).
/// - A single circular trailing control that morphs between voice input
///   (empty field), send (field has content), and stop (while
///   [ChatComposerController.isGenerating] is `true`).
///
/// The chip, the thumbnails and the trailing control all live in
/// [ChatComposerInput], the default occupant of the input slot.
///
/// All four regions are customisable via [ChatComposerFactory].
///
/// Example:
/// ```dart
/// ChatComposer(
///   controller: controller,
///   onSendPressed: (text, option, attachments) async {
///     await myBackend.sendMessage(text, attachments);
///   },
///   onStopPressed: () => myBackend.stopGenerating(),
/// );
/// ```
class ChatComposer extends StatefulWidget {
  /// Creates a [ChatComposer].
  const ChatComposer({
    super.key,
    this.controller,
    required this.onSendPressed,
    this.onStopPressed,
    this.factory = const ChatComposerFactory(),
    this.focusNode,
    this.hintText,
    this.minLines = 1,
    this.maxLines = 8,
    this.textInputAction = TextInputAction.newline,
    this.enableSpeechToText = false,
    this.speechToTextConfig = const SpeechToTextConfig(),
  }) : assert(minLines >= 1, 'minLines must be at least 1'),
       assert(maxLines >= minLines, "maxLines can't be less than minLines");

  /// The controller that manages input text, chat options, attachments, and
  /// generating state.
  ///
  /// If not provided, an internal controller is created and disposed
  /// automatically.
  final ChatComposerController? controller;

  /// Called when the user taps the send button.
  final ChatComposerSendCallback onSendPressed;

  /// Called when the user taps the stop button while the AI is generating.
  final VoidCallback? onStopPressed;

  /// Factory used to build the composer's slots — leading, trailing, the
  /// input field, and the attachment sheet the default leading button opens.
  final ChatComposerFactory factory;

  /// Focus node for the text field.
  final FocusNode? focusNode;

  /// Placeholder text shown when the text field is empty.
  final String? hintText;

  /// Minimum number of lines in the text field.
  final int minLines;

  /// Maximum number of lines the text field may grow to before scrolling.
  final int maxLines;

  /// The action shown on the keyboard's action button.
  final TextInputAction textInputAction;

  /// Whether to show a voice-input button in place of the send button when
  /// the text field is empty.
  ///
  /// When `true`, the composer's single trailing control shows a mic while
  /// the field is empty and the AI isn't generating a response, and morphs
  /// into the send button as soon as the user types (or the stop button
  /// while generating). Requires the platform permissions documented on
  /// [SpeechToTextButton]. Defaults to `false`.
  ///
  /// The one exception to that morph is an in-flight dictation: the mic stays
  /// put, showing its stop state, until the session ends. Otherwise the first
  /// recognised word — which is content — would replace the control the user
  /// needs in order to stop talking.
  final bool enableSpeechToText;

  /// Locale, timeouts and callbacks for voice input.
  ///
  /// Only consulted when [enableSpeechToText] is `true`.
  final SpeechToTextConfig speechToTextConfig;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late ChatComposerController _controller;
  late FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;

  /// What the composer rebuilds on.
  ///
  /// Held in state rather than merged inside `build`: `Listenable.merge`
  /// returns a fresh object every call and doesn't define `==`, so building it
  /// there made `ListenableBuilder` detach from and re-attach to both sources
  /// on every parent rebuild.
  late Listenable _listenable;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _controller = ChatComposerController();
      _ownsController = true;
    } else {
      _controller = widget.controller!;
    }
    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    } else {
      _focusNode = widget.focusNode!;
    }
    _rebuildListenable();
  }

  /// The speech controller is merged in so the trailing control can hold its
  /// stop state for the length of a dictation — that state lives there, not in
  /// `_controller`.
  void _rebuildListenable() {
    _listenable = widget.enableSpeechToText
        ? Listenable.merge([_controller, SpeechToTextController.instance])
        : _controller;
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _controller.dispose();
        _ownsController = false;
      }
      if (widget.controller == null) {
        _controller = ChatComposerController();
        _ownsController = true;
      } else {
        _controller = widget.controller!;
      }
    }
    if (widget.focusNode != oldWidget.focusNode) {
      if (_ownsFocusNode) {
        _focusNode.dispose();
        _ownsFocusNode = false;
      }
      if (widget.focusNode == null) {
        _focusNode = FocusNode();
        _ownsFocusNode = true;
      } else {
        _focusNode = widget.focusNode!;
      }
    }
    if (widget.controller != oldWidget.controller || widget.enableSpeechToText != oldWidget.enableSpeechToText) {
      _rebuildListenable();
    }
  }

  @override
  void dispose() {
    // The recognition session outlives the mic button by design, but not the
    // composer that offered it — nothing would be left to stop it.
    //
    // Not gated on `enableSpeechToText`: a host can place a [SpeechToTextButton]
    // itself through a [ChatComposerFactory] and leave that flag false, which is
    // exactly the arrangement [SpeechToTextButton]'s own documentation
    // recommends. Skipping the cancel there left a live session writing into the
    // controller disposed on the next line.
    unawaited(SpeechToTextController.instance.cancel());
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onSend() {
    // Handed to arbitrary host code through `ChatComposerInputProps.onSend`,
    // which a custom input may call across an async gap (a confirm dialog, a
    // debounce) long after the composer left the tree. Clearing a disposed
    // controller only asserts in debug, so without this the same call sends a
    // message from a screen the user has already navigated away from and then
    // fails silently in release.
    if (!mounted) {
      assert(
        false,
        'ChatComposerInputProps.onSend was called after the ChatComposer was '
        'disposed. A custom buildInput must not call it across an async gap '
        'without checking that its own State is still mounted.',
      );
      return;
    }
    if (!_controller.hasContent) return;
    final send = widget.onSendPressed(
      _controller.text,
      _controller.selectedChatOption,
      _controller.attachments,
    );
    // Optimistic, and documented as such on `ChatComposerInputProps.onSend`:
    // the field empties on invocation, not on completion. Awaiting first would
    // leave the composer looking unresponsive for the length of a round trip.
    _controller.clear();
    _focusNode.requestFocus();
    if (send is Future<void>) unawaited(_reportSendFailure(send));
  }

  /// Surfaces a rejected [ChatComposer.onSendPressed] future.
  ///
  /// Reported rather than rethrown: the message has already been handed off
  /// and the composer has no way to recover it. Without this the rejection
  /// reaches the enclosing [Zone] as an unhandled asynchronous error — one
  /// console line in debug, nothing at all in release.
  Future<void> _reportSendFailure(Future<void> send) async {
    try {
      await send;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'stream_chat_flutter_ai',
          context: ErrorDescription('while sending a composer message'),
        ),
      );
    }
  }

  void _onStop() {
    if (!mounted) {
      assert(
        false,
        'ChatComposerInputProps.onStop was called after the ChatComposer was '
        'disposed.',
      );
      return;
    }
    widget.onStopPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _listenable,
      builder: (context, _) {
        final leading = widget.factory.buildLeading(
          context,
          ChatComposerLeadingProps(controller: _controller),
        );
        final trailing = widget.factory.buildTrailing(
          context,
          ChatComposerTrailingProps(controller: _controller),
        );
        final input = widget.factory.buildInput(
          context,
          ChatComposerInputProps(
            controller: _controller,
            focusNode: _focusNode,
            hintText: widget.hintText ?? ChatComposerInputProps.defaultHintText,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            textInputAction: widget.textInputAction,
            enableSpeechToText: widget.enableSpeechToText,
            speechToTextConfig: widget.speechToTextConfig,
            onSend: _onSend,
            // `null`, not a callback that quietly does nothing, so a custom
            // input can tell that stopping is unsupported and hide its own
            // stop affordance.
            onStop: widget.onStopPressed == null ? null : _onStop,
          ),
        );

        // The layout contract `buildInput`'s dartdoc states, enforced: an
        // `Expanded` returned here lands inside the one below, which throws
        // from a debug-only `ParentDataWidget` assert and mis-applies parent
        // data in release.
        assert(
          input is! Expanded && input is! Flexible,
          'ChatComposerFactory.buildInput must not return an Expanded or '
          'Flexible — ChatComposer already wraps the result in one.',
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                // Centered, not `.end` — the pill is taller than the fixed-size
                // leading/trailing circles (its height grows with multi-line
                // text), and bottom-aligning them dumps 100% of that extra
                // height above the circles as a lopsided gap. Centering keeps
                // the circles evenly inset, matching the reference Android
                // layout, where both the "+" and mic sit centered within the
                // pill's height rather than flush to its bottom edge.
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) ...[leading, const SizedBox(key: _leadingGapKey, width: 8)],
                  Expanded(child: input),
                  if (trailing != null) ...[const SizedBox(key: _trailingGapKey, width: 8), trailing],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
