import 'package:flutter/material.dart';
// The [ChatComposer], [ChatComposerFactory], [ChatComposerInput], [ChatOption]
// and [SpeechToTextButton] references below are doc links only; nothing in this
// file's code uses them.
import 'package:stream_chat_flutter_ai/src/composer/chat_composer.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_controller.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_factory.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_input.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_option.dart';
import 'package:stream_chat_flutter_ai/src/composer/speech_to_text_button.dart';
import 'package:stream_chat_flutter_ai/src/composer/speech_to_text_controller.dart';

/// What every [ChatComposerFactory] slot receives.
///
/// One subclass per slot, so a slot that needs more than the controller can
/// grow its own fields without disturbing the others — see
/// [ChatComposerInputProps], which carries the input field's configuration and
/// the composer's send/stop wiring.
abstract class ChatComposerSlotProps {
  /// Creates a [ChatComposerSlotProps].
  ///
  /// Abstract: every slot passes one of the subclasses below, and a bare
  /// `ChatComposerSlotProps` belongs to no slot.
  const ChatComposerSlotProps({required this.controller});

  /// The composer's controller — input text, chat options, attachments, and
  /// generating state.
  ///
  /// The same object throughout the composer's lifetime, and the one a slot
  /// should read and mutate rather than keeping state of its own.
  final ChatComposerController controller;
}

/// Props for [ChatComposerFactory.buildLeading].
class ChatComposerLeadingProps extends ChatComposerSlotProps {
  /// Creates a [ChatComposerLeadingProps].
  const ChatComposerLeadingProps({required super.controller});
}

/// Props for [ChatComposerFactory.buildTrailing].
class ChatComposerTrailingProps extends ChatComposerSlotProps {
  /// Creates a [ChatComposerTrailingProps].
  const ChatComposerTrailingProps({required super.controller});
}

/// Props for [ChatComposerFactory.buildAttachmentSheet].
///
/// The sheet is built inside a modal route, so — unlike the other three slots
/// — it is not rebuilt by the composer. A sheet that renders [controller]
/// state has to listen to it itself.
class ChatComposerAttachmentSheetProps extends ChatComposerSlotProps {
  /// Creates a [ChatComposerAttachmentSheetProps].
  const ChatComposerAttachmentSheetProps({required super.controller});
}

/// Props for [ChatComposerFactory.buildInput].
///
/// Everything [ChatComposerInput] renders from. Beyond the shared
/// [controller], this carries the values [ChatComposer] owns and a slot has no
/// other way to reach: the composer's [focusNode], its [onSend]/[onStop]
/// handlers, and the text-field configuration passed to the [ChatComposer]
/// constructor.
class ChatComposerInputProps extends ChatComposerSlotProps {
  /// Creates a [ChatComposerInputProps].
  const ChatComposerInputProps({
    required super.controller,
    required this.focusNode,
    required this.onSend,
    this.onStop,
    this.hintText = defaultHintText,
    this.minLines = 1,
    this.maxLines = 8,
    this.textInputAction = TextInputAction.newline,
    this.enableSpeechToText = false,
    this.speechToTextConfig = const SpeechToTextConfig(),
  }) : assert(minLines >= 1, 'minLines must be at least 1'),
       // Checked here rather than left to TextField's own assert, which trips
       // several frames deep with no mention of the composer.
       assert(maxLines >= minLines, "maxLines can't be less than minLines");

  /// The placeholder [hintText] falls back to, and [ChatComposer]'s own
  /// default when [ChatComposer.hintText] is `null`.
  ///
  /// Lives here, not in [ChatComposerInput], so a custom input forwarding
  /// `props.hintText` renders the same placeholder the default one does
  /// instead of no placeholder at all.
  static const defaultHintText = 'Ask anything…';

  /// The composer's focus node for the text field.
  ///
  /// Either the one passed to [ChatComposer.focusNode] or, if that was `null`,
  /// the one the composer created and owns. A custom input should attach this
  /// node rather than create its own, or [onSend]'s refocus lands on a field
  /// that isn't on screen.
  final FocusNode focusNode;

  /// Sends the current message.
  ///
  /// A no-op unless [ChatComposerController.hasContent]; otherwise it fires
  /// [ChatComposer.onSendPressed] with the text, the selected [ChatOption] and
  /// the attachments, then clears [controller] and returns focus to
  /// [focusNode].
  ///
  /// The clear is **optimistic**: it happens as soon as
  /// [ChatComposer.onSendPressed] is invoked, not when the future it returns
  /// completes. A host whose send can fail owns surfacing that failure and
  /// re-seeding the composer — though a rejected future is at least reported
  /// through [FlutterError.onError] rather than swallowed.
  ///
  /// Only safe to call while the [ChatComposer] is still mounted. Calling it
  /// across an async gap (a confirmation dialog, a debounce) after the
  /// composer has left the tree asserts in debug and returns without sending.
  ///
  /// A custom input built from [ChatComposerFactory.buildInput] should call
  /// this rather than reimplement it — [ChatComposer.onSendPressed] is not
  /// otherwise reachable from a factory.
  final VoidCallback onSend;

  /// Stops the in-flight response, by calling [ChatComposer.onStopPressed].
  ///
  /// `null` when the host passed no `onStopPressed`, so a custom input can
  /// hide or disable its stop affordance rather than offer one that does
  /// nothing. Only meaningful while [ChatComposerController.isGenerating] is
  /// `true`.
  ///
  /// Carries the same mounted caveat as [onSend].
  final VoidCallback? onStop;

  /// Placeholder text shown when the text field is empty.
  ///
  /// Defaults to [defaultHintText].
  final String hintText;

  /// Minimum number of lines in the text field.
  final int minLines;

  /// Maximum number of lines the text field may grow to before scrolling.
  final int maxLines;

  /// The action shown on the keyboard's action button.
  final TextInputAction textInputAction;

  /// Whether to show a voice-input button in place of the send button when the
  /// text field is empty.
  ///
  /// See [ChatComposer.enableSpeechToText], which this mirrors, for the morph
  /// behaviour and the platform permissions [SpeechToTextButton] needs.
  ///
  /// A custom input that renders its own mic state should read
  /// [SpeechToTextController.instance] and rebuild on it — the listening flag
  /// lives on that process-wide controller, not here. [ChatComposerInput]
  /// already does.
  final bool enableSpeechToText;

  /// Locale, timeouts and callbacks for voice input.
  ///
  /// Only consulted when [enableSpeechToText] is `true`.
  final SpeechToTextConfig speechToTextConfig;

  /// A copy of these props with the given fields replaced.
  ///
  /// The way to tweak one value while keeping the rest of what [ChatComposer]
  /// passed down — hand-listing all ten fields instead silently reverts any
  /// you forget to a constructor default, discarding the host's own
  /// configuration.
  ///
  /// Passing `null` for [onStop] leaves the existing callback in place; use
  /// `clearOnStop: true` to drop it.
  ChatComposerInputProps copyWith({
    ChatComposerController? controller,
    FocusNode? focusNode,
    VoidCallback? onSend,
    VoidCallback? onStop,
    bool clearOnStop = false,
    String? hintText,
    int? minLines,
    int? maxLines,
    TextInputAction? textInputAction,
    bool? enableSpeechToText,
    SpeechToTextConfig? speechToTextConfig,
  }) {
    return ChatComposerInputProps(
      controller: controller ?? this.controller,
      focusNode: focusNode ?? this.focusNode,
      onSend: onSend ?? this.onSend,
      onStop: clearOnStop ? null : (onStop ?? this.onStop),
      hintText: hintText ?? this.hintText,
      minLines: minLines ?? this.minLines,
      maxLines: maxLines ?? this.maxLines,
      textInputAction: textInputAction ?? this.textInputAction,
      enableSpeechToText: enableSpeechToText ?? this.enableSpeechToText,
      speechToTextConfig: speechToTextConfig ?? this.speechToTextConfig,
    );
  }
}
