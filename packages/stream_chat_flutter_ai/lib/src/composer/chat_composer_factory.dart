import 'package:flutter/material.dart';
// Here for the [ChatComposer] doc links below only; nothing in this file's code
// uses it.
import 'package:stream_chat_flutter_ai/src/composer/chat_composer.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_controller.dart';
import 'package:stream_chat_flutter_ai/src/composer/composer_attachment_sheet.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';

/// Factory that produces the composable regions of [ChatComposer].
///
/// Subclass and override any method to swap out individual slots without
/// rebuilding the entire widget:
///
/// ```dart
/// class MyFactory extends ChatComposerFactory {
///   @override
///   Widget buildLeading(BuildContext context, ChatComposerController controller) {
///     return IconButton(
///       icon: const Icon(Icons.attach_file),
///       onPressed: () { /* pick attachments */ },
///     );
///   }
/// }
/// ```
class ChatComposerFactory {
  /// Creates a [ChatComposerFactory].
  const ChatComposerFactory();

  /// The widget placed to the left of the input container, or `null` for
  /// none.
  ///
  /// Defaults to an outlined circular "+" button that opens a
  /// [ComposerAttachmentSheet] — a combined photo picker and, if
  /// [ChatComposerController.chatOptions] is non-empty, chat-option list. The
  /// button is disabled while [ChatComposerController.isGenerating] is `true`.
  /// How many photos the sheet will accept is
  /// [ChatComposerController.maxAttachments].
  ///
  /// Override to replace it, or return `null` to hide it — [ChatComposer]
  /// only reserves layout space (and the gap to the input container) for a
  /// non-`null` result.
  Widget? buildLeading(BuildContext context, ChatComposerController controller) {
    return _AttachmentButton(controller: controller);
  }

  /// The widget placed to the right of the input container, or `null` for
  /// none.
  ///
  /// Returns `null` by default (no trailing widget). See [buildLeading] for
  /// how `null` affects layout.
  Widget? buildTrailing(BuildContext context, ChatComposerController controller) {
    return null;
  }
}

/// The default leading "+" attachment button — opens a
/// [ComposerAttachmentSheet] for [controller].
class _AttachmentButton extends StatelessWidget {
  const _AttachmentButton({required this.controller});

  final ChatComposerController controller;

  Future<void> _openAttachmentSheet(BuildContext context) {
    // Read here, from this button's context, and re-provide inside the sheet.
    // The sheet is pushed as its own route, so it sits under the Navigator
    // rather than under whatever wraps this button — a translations scope
    // placed directly above the composer would otherwise be invisible to it,
    // and the sheet's four strings would fall back to English while
    // everything around them was translated.
    final translations = AITranslations.of(context);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => AITranslationsScope(
        translations: translations,
        child: ComposerAttachmentSheet(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = !controller.isGenerating;
    final iconColor = enabled ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.3);

    return Tooltip(
      message: AITranslations.of(context).addPhotos,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          // Same fill/border tokens as the input pill (see
          // `_InputContainer` in chat_composer.dart) so the two read
          // as one connected surface rather than mismatched colors.
          color: colorScheme.surfaceContainerHigh,
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        // Above the fill, so the ink splash is actually visible.
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? () => _openAttachmentSheet(context) : null,
            child: Center(child: Icon(Icons.add, size: 22, color: iconColor)),
          ),
        ),
      ),
    );
  }
}
