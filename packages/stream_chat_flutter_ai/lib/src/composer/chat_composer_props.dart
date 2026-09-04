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
class ChatComposerSlotProps {
  /// Creates a [ChatComposerSlotProps].
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
    required this.onStop,
    this.hintText,
    this.minLines = 1,
    this.maxLines = 8,
    this.textInputAction = TextInputAction.newline,
    this.enableSpeechToText = false,
    this.speechToTextConfig = const SpeechToTextConfig(),
  });

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
  /// A custom input built from [ChatComposerFactory.buildInput] should call
  /// this rather than reimplement it — [ChatComposer.onSendPressed] is not
  /// otherwise reachable from a factory.
  final VoidCallback onSend;

  /// Stops the in-flight response, by calling [ChatComposer.onStopPressed].
  ///
  /// A no-op if the host passed no `onStopPressed`. Only meaningful while
  /// [ChatComposerController.isGenerating] is `true`.
  final VoidCallback onStop;

  /// Placeholder text shown when the text field is empty.
  final String? hintText;

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
  final bool enableSpeechToText;

  /// Locale, timeouts and callbacks for voice input.
  ///
  /// Only consulted when [enableSpeechToText] is `true`.
  final SpeechToTextConfig speechToTextConfig;
}
