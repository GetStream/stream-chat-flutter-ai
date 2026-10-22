import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/components/ai_component_factory.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/conversation_theme.dart';
import 'package:stream_core_flutter/chat.dart';

/// One of a message's attachments: an image as a thumbnail, and any other kind
/// as a file card with its name, type and size.
///
/// Opening it is the app's: pass [onTap], such as to launch its URL.
class AIMessageAttachmentView extends StatelessWidget {
  /// Creates an [AIMessageAttachmentView].
  const AIMessageAttachmentView({super.key, required this.attachment, this.imageSize = 180, this.onTap});

  /// The view of [props]'s attachment: the `messageAttachment` builder of
  /// [streamAIComponentBuilders], or else an [AIMessageAttachmentView].
  static Widget of(BuildContext context, AIMessageAttachmentProps props) =>
      context.aiComponentBuilder<AIMessageAttachmentProps>()?.call(context, props) ??
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
    final colors = context.streamColorScheme;
    final textTheme = context.streamTextTheme;
    final radius = BorderRadius.all(context.streamRadius.xl);
    final translations = AITranslations.of(context);
    final background = theme.attachmentBackgroundColor ?? colors.backgroundSurface;
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
            borderRadius: radius,
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
                  child: Icon(context.streamIcons.image, color: colors.textSecondary),
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
        borderRadius: radius,
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
                  StreamFileTypeIcon.fromMimeType(mimeType: attachment.mimeType, size: .md),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyEmphasis
                              .copyWith(color: colors.textPrimary)
                              .merge(theme.attachmentTitleStyle),
                        ),
                        if (details != null)
                          Text(
                            details,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.captionDefault
                                .copyWith(color: colors.textSecondary)
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
