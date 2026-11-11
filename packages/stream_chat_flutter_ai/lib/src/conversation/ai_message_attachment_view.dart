import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/components/stream_ai_component_builders.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/notice.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/conversation_theme.dart';
import 'package:stream_core_flutter/core.dart';
import 'package:url_launcher/url_launcher.dart';

/// One of a message's attachments: an image as a thumbnail, and any other kind
/// as a file card with its name, type and size.
///
/// To show a kind of your own, such as an artifact or a file in an agent's
/// sandbox, register a `messageAttachment` builder with
/// [streamAIComponentBuilders], read its raw fields from
/// [AIMessageAttachment.extraData], and return this view for the kinds you
/// don't handle.
///
/// A file card with a URL opens it when tapped: a web link in the browser, and
/// any other URL is handed to the platform. When nothing opens it, a notice
/// says so. An app that shows a local file itself, such as in a preview,
/// handles the tap with [onTap]. An image has no default action.
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

  /// Opens the attachment, in place of what a tap does by default.
  ///
  /// Without it, an image does nothing when tapped, and a file card with a URL
  /// opens that URL as the class documents. A file card without one is not
  /// tappable.
  final VoidCallback? onTap;

  Future<void> _open(BuildContext context, Uri url) async {
    final mode = url.scheme == 'http' || url.scheme == 'https'
        ? LaunchMode.externalApplication
        : LaunchMode.platformDefault;
    var opened = false;
    try {
      opened = await launchUrl(url, mode: mode);
      if (!opened) reportPartIssue(() => 'No app could open the attachment at $url.');
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stream_chat_flutter_ai',
          context: ErrorDescription('while opening a file attachment'),
        ),
      );
    }
    if (opened || !context.mounted) return;
    showErrorSnackbar(context, message: AITranslations.of(context).cannotOpenAttachment);
  }

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

    final tap = onTap ?? (url == null ? null : () => unawaited(_open(context, url)));

    return Semantics(
      button: tap != null,
      onTapHint: onTap == null && tap != null ? translations.openAttachment : null,
      child: Material(
        color: background,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tap,
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
