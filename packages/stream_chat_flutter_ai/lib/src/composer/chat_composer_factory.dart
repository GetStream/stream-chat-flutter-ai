import 'package:flutter/material.dart';
// Here for the [ChatComposer] doc links below only; nothing in this file's code
// uses it.
import 'package:stream_chat_flutter_ai/src/composer/chat_composer.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_controller.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_input.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_props.dart';
import 'package:stream_chat_flutter_ai/src/composer/composer_attachment_sheet.dart';

/// Factory that produces the composable regions of [ChatComposer].
///
/// Four slots: [buildLeading] and [buildTrailing] flank the input row,
/// [buildInput] is the input field between them, and [buildAttachmentSheet]
/// supplies the contents of the sheet the default leading button opens.
/// Subclass and override any of them to swap out individual slots without
/// rebuilding the entire widget:
///
/// ```dart
/// class MyFactory extends ChatComposerFactory {
///   @override
///   Widget? buildLeading(BuildContext context, ChatComposerLeadingProps props) {
///     return IconButton(
///       icon: const Icon(Icons.attach_file),
///       onPressed: () { /* pick attachments */ },
///     );
///   }
/// }
/// ```
///
/// Each slot receives a [ChatComposerSlotProps] subclass rather than a bare
/// [ChatComposerController], so a slot can be handed values [ChatComposer]
/// owns — see [ChatComposerInputProps.onSend], which is the only way to reach
/// [ChatComposer.onSendPressed] from here.
class ChatComposerFactory {
  /// Creates a [ChatComposerFactory].
  const ChatComposerFactory();

  /// The widget placed to the left of the input container, or `null` for
  /// none.
  ///
  /// Defaults to an outlined circular "+" button that opens the sheet from
  /// [buildAttachmentSheet] — a combined photo picker and, if
  /// [ChatComposerController.chatOptions] is non-empty, chat-option list. The
  /// button is disabled while [ChatComposerController.isGenerating] is `true`.
  /// How many photos the sheet will accept is
  /// [ChatComposerController.maxAttachments].
  ///
  /// Override to replace it, or return `null` to hide it — [ChatComposer]
  /// only reserves layout space (and the gap to the input container) for a
  /// non-`null` result.
  Widget? buildLeading(BuildContext context, ChatComposerLeadingProps props) {
    // `this`, not `const ChatComposerFactory()`: the button reads the sheet
    // back off the factory, so a subclass overriding only
    // `buildAttachmentSheet` still gets its sheet.
    return _AttachmentButton(controller: props.controller, factory: this);
  }

  /// The widget placed to the right of the input container, or `null` for
  /// none.
  ///
  /// Returns `null` by default (no trailing widget). See [buildLeading] for
  /// how `null` affects layout.
  Widget? buildTrailing(BuildContext context, ChatComposerTrailingProps props) {
    return null;
  }

  /// The input field, placed between the leading and trailing slots.
  ///
  /// Defaults to [ChatComposerInput] — the outlined pill holding the text
  /// field, the inline selected-option chip, the attachment thumbnails and the
  /// morphing mic/send/stop control. Wrap it by returning
  /// `ChatComposerInput(props: props)` inside your own widget, or ignore it
  /// entirely and build a field from scratch.
  ///
  /// For a full replacement, [props] is the seam that keeps the composer
  /// working: [ChatComposerInputProps.onSend] and
  /// [ChatComposerInputProps.onStop] are the only route to
  /// [ChatComposer.onSendPressed] / [ChatComposer.onStopPressed] (plus the
  /// clear-and-refocus that follows a send), and
  /// [ChatComposerInputProps.focusNode] is the node that refocus targets.
  ///
  /// Unlike [buildLeading] and [buildTrailing] this is non-nullable: the
  /// result goes into an [Expanded], and there is no layout for "no input".
  /// Return `const SizedBox.shrink()` if you really want an empty one — safe
  /// here, unlike in the nullable slots, because nothing compares this result
  /// against an empty-widget sentinel.
  ///
  /// Whatever is returned must not be an [Expanded] itself — [ChatComposer]
  /// already supplies one.
  Widget buildInput(BuildContext context, ChatComposerInputProps props) {
    return ChatComposerInput(props: props);
  }

  /// The contents of the modal sheet [buildLeading]'s default "+" button
  /// opens.
  ///
  /// Defaults to [ComposerAttachmentSheet]. Only the sheet's *body* comes from
  /// here — the default button presents it with [showModalBottomSheet]
  /// (`isScrollControlled: true`, `showDragHandle: true`), so a replacement
  /// should not draw a drag handle of its own. Override [buildLeading] to
  /// change how, or whether, a picker is presented at all.
  ///
  /// Non-nullable: this is only called once the button has decided to open a
  /// sheet, and an empty sheet is worse than no sheet.
  ///
  /// Unlike [buildInput], the result is **not** rebuilt by the composer: this
  /// runs inside a pushed modal route, outside the [ListenableBuilder] that
  /// drives the composer's own subtree. A sheet that renders controller state
  /// — a selection count, tiles disabled at
  /// [ChatComposerController.maxAttachments] — must listen to
  /// [ChatComposerAttachmentSheetProps.controller] itself, as
  /// [ComposerAttachmentSheet] does, or it will freeze at its open-time state.
  ///
  /// A replacement also inherits none of [ComposerAttachmentSheet]'s photo
  /// permission handling or its error reporting; see that widget for what
  /// those cover.
  Widget buildAttachmentSheet(BuildContext context, ChatComposerAttachmentSheetProps props) {
    return ComposerAttachmentSheet(controller: props.controller);
  }
}

/// The default leading "+" attachment button — opens [factory]'s attachment
/// sheet for [controller].
class _AttachmentButton extends StatelessWidget {
  const _AttachmentButton({required this.controller, required this.factory});

  final ChatComposerController controller;

  /// The factory that supplies the sheet's contents — `this` from
  /// [ChatComposerFactory.buildLeading], i.e. the instance the composer is
  /// actually using, so a subclass overriding only
  /// [ChatComposerFactory.buildAttachmentSheet] still has its override
  /// honoured.
  final ChatComposerFactory factory;

  Future<void> _openAttachmentSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => factory.buildAttachmentSheet(
        context,
        ChatComposerAttachmentSheetProps(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = !controller.isGenerating;
    final iconColor = enabled ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.3);

    return Tooltip(
      message: 'Add photos',
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          // Same fill/border tokens as the input pill (see
          // `ChatComposerInput` in chat_composer_input.dart) so the two read
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
