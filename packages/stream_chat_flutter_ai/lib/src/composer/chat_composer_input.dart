import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// The [ChatComposer] and [ChatComposerFactory] references in the doc comments
// below are doc links only; nothing in this file's code uses them.
import 'package:stream_chat_flutter_ai/src/composer/chat_composer.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_controller.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_factory.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_props.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_option.dart';
import 'package:stream_chat_flutter_ai/src/composer/composer_action_button.dart';
import 'package:stream_chat_flutter_ai/src/composer/speech_to_text_button.dart';
import 'package:stream_chat_flutter_ai/src/composer/speech_to_text_controller.dart';

/// The composer's input pill — [ChatComposer]'s default input slot.
///
/// A rounded, outlined surface containing, top to bottom: the inline selected
/// [ChatOption] chip, a row of attachment thumbnails, and the text field with
/// the morphing mic/send/stop control at its right edge. Everything it renders
/// comes out of [props].
///
/// This is what [ChatComposerFactory.buildInput] returns by default. Construct
/// it with the props that slot hands you to keep the default input while
/// decorating around it:
///
/// ```dart
/// class MyFactory extends ChatComposerFactory {
///   @override
///   Widget buildInput(BuildContext context, ChatComposerInputProps props) {
///     return Padding(
///       padding: const EdgeInsets.only(bottom: 4),
///       child: ChatComposerInput(props: props),
///     );
///   }
/// }
/// ```
class ChatComposerInput extends StatelessWidget {
  /// Creates a [ChatComposerInput].
  const ChatComposerInput({super.key, required this.props});

  /// The controller, focus node, send/stop wiring and text-field configuration
  /// this input renders from.
  final ChatComposerInputProps props;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outlineVariant;
    final controller = props.controller;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.selectedChatOption != null)
            _SelectedOptionChip(
              option: controller.selectedChatOption!,
              onDismiss: controller.clearSelectedChatOption,
            ),
          if (controller.attachments.isNotEmpty)
            _AttachmentThumbnails(
              attachments: controller.attachments,
              onRemove: controller.removeAttachment,
            ),
          Row(
            // Centered so the trailing mic/send/stop circle sits evenly
            // inset within the pill instead of flush to one edge — see the
            // comment on the outer Row in `_ChatComposerState.build`, in
            // chat_composer.dart.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: controller.textEditingController,
                  focusNode: props.focusNode,
                  minLines: props.minLines,
                  maxLines: props.maxLines,
                  textInputAction: props.textInputAction,
                  decoration: InputDecoration(
                    hintText: props.hintText ?? 'Ask anything…',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  ),
                  onSubmitted: (_) {
                    if (props.textInputAction == TextInputAction.send) props.onSend();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                  child: _TrailingControl(
                    key: ValueKey(
                      _trailingState(controller, props.enableSpeechToText),
                    ),
                    controller: controller,
                    onSend: props.onSend,
                    onStop: props.onStop,
                    enableSpeechToText: props.enableSpeechToText,
                    speechToTextConfig: props.speechToTextConfig,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Identifies which of the trailing control's states is currently active, so
/// [AnimatedSwitcher] can key on it and animate transitions between them.
String _trailingState(
  ChatComposerController controller,
  bool enableSpeechToText,
) {
  if (controller.isGenerating) return 'stop';
  // Ahead of the content check: dictation puts its first recognised word in the
  // field, and morphing to send there took away the only control that could
  // stop the session.
  if (enableSpeechToText && SpeechToTextController.instance.isListening) return 'mic';
  if (controller.hasContent) return 'send';
  if (enableSpeechToText) return 'mic';
  return 'send-disabled';
}

// ---------------------------------------------------------------------------
// Trailing control (mic / send / stop — one morphing button)
// ---------------------------------------------------------------------------

class _TrailingControl extends StatelessWidget {
  const _TrailingControl({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onStop,
    required this.enableSpeechToText,
    required this.speechToTextConfig,
  });

  final ChatComposerController controller;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final bool enableSpeechToText;
  final SpeechToTextConfig speechToTextConfig;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (controller.isGenerating) {
      return ComposerActionButton(
        icon: Icons.stop_rounded,
        onPressed: onStop,
        tooltip: 'Stop generating',
        color: colorScheme.error,
      );
    }

    // Checked before `hasContent` — see `_trailingState`, which keys the
    // AnimatedSwitcher on the same ordering.
    if (enableSpeechToText && (SpeechToTextController.instance.isListening || !controller.hasContent)) {
      return SpeechToTextButton(controller: controller, config: speechToTextConfig);
    }

    if (controller.hasContent) {
      return ComposerActionButton(
        icon: Icons.arrow_upward_rounded,
        onPressed: onSend,
        tooltip: 'Send',
        color: colorScheme.primary,
      );
    }

    return ComposerActionButton(
      icon: Icons.arrow_upward_rounded,
      onPressed: null,
      tooltip: 'Send',
      color: colorScheme.primary,
    );
  }
}

// ---------------------------------------------------------------------------
// Attachment thumbnails
// ---------------------------------------------------------------------------

class _AttachmentThumbnails extends StatelessWidget {
  const _AttachmentThumbnails({
    required this.attachments,
    required this.onRemove,
  });

  final List<XFile> attachments;
  final ValueChanged<XFile> onRemove;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: SizedBox(
        height: _size,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: attachments.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final file = attachments[index];
            return _AttachmentThumbnail(
              key: ValueKey(file.path),
              file: file,
              onRemove: () => onRemove(file),
            );
          },
        ),
      ),
    );
  }
}

class _AttachmentThumbnail extends StatefulWidget {
  const _AttachmentThumbnail({
    super.key,
    required this.file,
    required this.onRemove,
  });

  final XFile file;
  final VoidCallback onRemove;

  @override
  State<_AttachmentThumbnail> createState() => _AttachmentThumbnailState();
}

class _AttachmentThumbnailState extends State<_AttachmentThumbnail> {
  static const double _size = 64;

  /// Held in state rather than started inside `build`.
  ///
  /// The controller notifies on every keystroke, so a future created in `build`
  /// meant re-reading every attachment off disk in full — and re-decoding it —
  /// for each character the user typed.
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.file.readAsBytes();
  }

  @override
  void didUpdateWidget(covariant _AttachmentThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file.path != oldWidget.file.path) _bytes = widget.file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Decode at thumbnail resolution instead of full camera resolution.
    final cacheWidth = (_size * MediaQuery.devicePixelRatioOf(context)).round();

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: _size,
              height: _size,
              child: FutureBuilder<Uint8List>(
                future: _bytes,
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null) {
                    return ColoredBox(color: colorScheme.surface);
                  }
                  return Image.memory(bytes, fit: BoxFit.cover, cacheWidth: cacheWidth);
                },
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              // The Material sits *above* the fill so the ink splash is
              // visible — an InkWell wrapped around an opaque decoration
              // paints its ripple behind it, leaving the tap with no feedback.
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onRemove,
                  child: Tooltip(
                    message: 'Remove attachment',
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selected option chip (inline in input box)
// ---------------------------------------------------------------------------

class _SelectedOptionChip extends StatelessWidget {
  const _SelectedOptionChip({required this.option, required this.onDismiss});

  final ChatOption option;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 18, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: 6),
                ],
                Text(
                  option.text,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  type: MaterialType.transparency,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onDismiss,
                    child: Tooltip(
                      message: 'Clear ${option.text}',
                      child: Icon(Icons.close, size: 18, color: colorScheme.onPrimaryContainer),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
