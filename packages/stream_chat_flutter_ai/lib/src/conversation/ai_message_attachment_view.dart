import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/components/ai_component_factory.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/conversation_theme.dart';

/// One of a message's attachments: an image as a thumbnail, and any other kind
/// as a file card with its name, type and size.
///
/// Opening it is the app's: pass [onTap], such as to launch its URL.
class AIMessageAttachmentView extends StatelessWidget {
  /// Creates an [AIMessageAttachmentView].
  const AIMessageAttachmentView({super.key, required this.attachment, this.imageSize = 180, this.onTap});

  /// The view of [props]'s attachment: [builders]'
  /// [AIComponentBuilders.messageAttachment], or else an
  /// [AIMessageAttachmentView].
  static Widget of(BuildContext context, AIComponentBuilders builders, AIMessageAttachmentProps props) =>
      builders.messageAttachment?.call(context, props) ??
      AIMessageAttachmentView(attachment: props.attachment, onTap: props.onTap);

  /// What to show.
  final AIMessageAttachment attachment;

  /// The width and height of an image.
  final double imageSize;

  /// Opens the attachment.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ConversationTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final translations = AITranslations.of(context);
    final background = theme.attachmentBackgroundColor ?? scheme.surfaceContainerHigh;
    final isImage = attachment.kind == AIMessageAttachmentKind.image;
    final url = attachment.url;
    final name = attachment.displayName ?? (isImage ? translations.attachmentImage : translations.attachmentFile);

    if (isImage && (attachment.image != null || url != null)) {
      final provider = attachment.image ?? NetworkImage(url.toString());
      return Semantics(
        image: true,
        label: name,
        button: onTap != null,
        child: GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox.square(
              dimension: imageSize,
              child: Image(
                image: provider,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                    frame == null && !wasSynchronouslyLoaded ? ColoredBox(color: background) : child,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: background,
                  child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final type = attachment.typeLabel;
    final size = attachment.size == null ? null : translations.fileSize(attachment.size!);
    final details = switch ((type, size)) {
      (final type?, final size?) => translations.attachmentDetails(type, size),
      (final type?, null) => type,
      (null, final size?) => size,
      (null, null) => null,
    };

    return Semantics(
      button: onTap != null,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 12,
                children: [
                  Icon(Icons.insert_drive_file_outlined, color: scheme.onSurfaceVariant),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500, color: scheme.onSurface)
                              .merge(theme.attachmentTitleStyle),
                        ),
                        if (details != null)
                          Text(
                            details,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant)
                                .merge(theme.attachmentDetailsStyle),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
