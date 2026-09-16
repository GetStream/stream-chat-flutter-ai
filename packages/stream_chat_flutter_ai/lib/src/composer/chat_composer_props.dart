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
// Doc links only.
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';

/// What every [ChatComposerFactory] slot receives.
///
/// Carries the composer's wiring — the [controller], the [focusNode], and the
/// [onSend]/[onStop] handlers — so that *any* slot can drive the composer, not
/// just the input one. A trailing send button, a leading button that refocuses
/// the field, and a custom input all need the same handful of values, and only
/// [ChatComposer] can supply them.
///
/// One subclass per slot. Three of them add nothing of their own and exist to
/// name the slot at the call site; [ChatComposerInputProps] adds the text-field
/// configuration, which has no meaning outside the input.
///
/// The three narrow subclasses each have a `.from` constructor: [ChatComposer]
/// builds [ChatComposerInputProps] — the widest set — once, and narrows that
/// per slot, so the shared values are named in one place.
abstract class ChatComposerSlotProps {
  /// Creates a [ChatComposerSlotProps].
  ///
  /// Abstract: every slot passes one of the subclasses below, and a bare
  /// `ChatComposerSlotProps` belongs to no slot.
  const ChatComposerSlotProps({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.onStop,
    this.allowSendWhileGenerating = false,
  });

  /// The composer's controller — input text, chat options, attachments, and
  /// generating state.
  ///
  /// The same object throughout the composer's lifetime, and the one a slot
  /// should read and mutate rather than keeping state of its own.
  final ChatComposerController controller;

  /// The composer's focus node for the text field.
  ///
  /// Either the one passed to [ChatComposer.focusNode] or, if that was `null`,
  /// the one the composer created and owns. A custom input should attach this
  /// node rather than create its own, or [onSend]'s refocus lands on a field
  /// that isn't on screen. Other slots can use it to move focus into the field
  /// — a leading button that dismisses a picker, say.
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
  /// across an async gap (a confirmation dialog, a debounce) after the composer
  /// has left the tree throws an [AssertionError] in debug, and returns without
  /// sending in release.
  ///
  /// A slot should call this rather than reimplement it —
  /// [ChatComposer.onSendPressed] is not otherwise reachable from a factory.
  final VoidCallback onSend;

  /// Stops the in-flight response, by calling [ChatComposer.onStopPressed].
  ///
  /// `null` when the host passed no `onStopPressed`, so a slot can hide or
  /// disable its stop affordance rather than offer one that does nothing. Only
  /// meaningful while [ChatComposerController.isGenerating] is `true`.
  ///
  /// Carries the same mounted caveat as [onSend].
  final VoidCallback? onStop;

  /// Whether [onSend] still sends while [ChatComposerController.isGenerating]
  /// is `true`.
  ///
  /// Mirrors [ChatComposer.allowSendWhileGenerating]; see it for what the
  /// choice means. Read [canSend] rather than combining this with the
  /// controller by hand.
  final bool allowSendWhileGenerating;

  /// Whether calling [onSend] right now would actually send.
  ///
  /// The condition a slot's send control should be enabled on:
  ///
  /// ```dart
  /// IconButton(
  ///   icon: const Icon(Icons.send),
  ///   onPressed: props.canSend ? props.onSend : null,
  /// )
  /// ```
  ///
  /// [onSend] is a no-op when this is `false`, so a control wired to it
  /// unconditionally looks enabled and does nothing — the dead-affordance
  /// problem [onStop] avoids by being `null`. `onSend` can't take that route:
  /// it flips with every keystroke, and a slot that captured it once would
  /// hold a stale `null`.
  bool get canSend => controller.hasContent && (allowSendWhileGenerating || !controller.isGenerating);
}

/// Props for [ChatComposerFactory.buildLeading].
class ChatComposerLeadingProps extends ChatComposerSlotProps {
  /// Creates a [ChatComposerLeadingProps].
  const ChatComposerLeadingProps({
    required super.controller,
    required super.focusNode,
    required super.onSend,
    super.onStop,
    super.allowSendWhileGenerating,
  });

  /// Creates a [ChatComposerLeadingProps] carrying another slot's wiring.
  ///
  /// How [ChatComposer] derives this slot's props: it builds the widest set
  /// once and narrows it per slot, so the shared values are named in one place
  /// rather than re-listed four times.
  ChatComposerLeadingProps.from(ChatComposerSlotProps props)
    : this(
        controller: props.controller,
        focusNode: props.focusNode,
        onSend: props.onSend,
        onStop: props.onStop,
        allowSendWhileGenerating: props.allowSendWhileGenerating,
      );
}

/// Props for [ChatComposerFactory.buildTrailing].
class ChatComposerTrailingProps extends ChatComposerSlotProps {
  /// Creates a [ChatComposerTrailingProps].
  const ChatComposerTrailingProps({
    required super.controller,
    required super.focusNode,
    required super.onSend,
    super.onStop,
    super.allowSendWhileGenerating,
  });

  /// Creates a [ChatComposerTrailingProps] carrying another slot's wiring.
  ///
  /// See [ChatComposerLeadingProps.from].
  ChatComposerTrailingProps.from(ChatComposerSlotProps props)
    : this(
        controller: props.controller,
        focusNode: props.focusNode,
        onSend: props.onSend,
        onStop: props.onStop,
        allowSendWhileGenerating: props.allowSendWhileGenerating,
      );
}

/// Props for [ChatComposerFactory.buildAttachmentSheet].
///
/// The sheet is built inside a modal route, so — unlike the other three slots
/// — it is not rebuilt by the composer. A sheet that renders [controller]
/// state has to listen to it itself.
class ChatComposerAttachmentSheetProps extends ChatComposerSlotProps {
  /// Creates a [ChatComposerAttachmentSheetProps].
  const ChatComposerAttachmentSheetProps({
    required super.controller,
    required super.focusNode,
    required super.onSend,
    super.onStop,
    super.allowSendWhileGenerating,
  });

  /// Creates a [ChatComposerAttachmentSheetProps] carrying another slot's
  /// wiring.
  ///
  /// See [ChatComposerLeadingProps.from].
  ChatComposerAttachmentSheetProps.from(ChatComposerSlotProps props)
    : this(
        controller: props.controller,
        focusNode: props.focusNode,
        onSend: props.onSend,
        onStop: props.onStop,
        allowSendWhileGenerating: props.allowSendWhileGenerating,
      );
}

/// Props for [ChatComposerFactory.buildInput].
///
/// Everything [ChatComposerInput] renders from: the wiring every slot gets
/// from [ChatComposerSlotProps], plus the text-field configuration passed to
/// the [ChatComposer] constructor, which no other slot has a use for.
class ChatComposerInputProps extends ChatComposerSlotProps {
  /// Creates a [ChatComposerInputProps].
  const ChatComposerInputProps({
    required super.controller,
    required super.focusNode,
    required super.onSend,
    super.onStop,
    super.allowSendWhileGenerating,
    this.hintText,
    this.minLines = 1,
    this.maxLines = 8,
    this.textInputAction = TextInputAction.newline,
    this.enableSpeechToText = false,
    this.speechToTextConfig = const SpeechToTextConfig(),
  }) : assert(minLines >= 1, 'minLines must be at least 1'),
       // Checked here rather than left to TextField's own assert, which trips
       // several frames deep with no mention of the composer.
       assert(maxLines >= minLines, "maxLines can't be less than minLines");

  /// Placeholder text shown when the text field is empty.
  ///
  /// `null` when the host passed no [ChatComposer.hintText], and it is left
  /// that way: the slot rendering the field decides what an absent hint means.
  /// [ChatComposerInput] falls back to [AITranslations.composerHint]; a custom
  /// input that wants the same does `props.hintText ?? AITranslations.of(context).composerHint`,
  /// and one with a placeholder of its own simply ignores this.
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
  /// passed down — hand-listing all eleven fields instead silently reverts any
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
    bool? allowSendWhileGenerating,
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
      allowSendWhileGenerating: allowSendWhileGenerating ?? this.allowSendWhileGenerating,
      hintText: hintText ?? this.hintText,
      minLines: minLines ?? this.minLines,
      maxLines: maxLines ?? this.maxLines,
      textInputAction: textInputAction ?? this.textInputAction,
      enableSpeechToText: enableSpeechToText ?? this.enableSpeechToText,
      speechToTextConfig: speechToTextConfig ?? this.speechToTextConfig,
    );
  }
}
