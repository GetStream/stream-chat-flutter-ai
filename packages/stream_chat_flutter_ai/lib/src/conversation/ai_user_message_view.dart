import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stream_chat_flutter_ai/src/components/ai_component_factory.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment_view.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/conversation_theme.dart';

/// A message the person sent: its attachments, then its text in a bubble, at
/// the trailing edge. A long press offers to copy the text, and to edit it given
/// [onEdit].
///
/// Attachments can be replaced through [AIComponentBuilders.messageAttachment].
class AIUserMessageView extends StatelessWidget {
  /// Creates an [AIUserMessageView].
  const AIUserMessageView({
    super.key,
    required this.text,
    this.attachments = const [],
    this.onEdit,
    this.onAttachmentTap,
  });

  /// What the person wrote.
  final String text;

  /// What they sent with it, such as images and files.
  final List<AIMessageAttachment> attachments;

  /// Edits the message, such as by putting its text back in the composer.
  final VoidCallback? onEdit;

  /// Opens one of the attachments.
  final ValueChanged<AIMessageAttachment>? onAttachmentTap;

  Future<void> _showMenu(BuildContext context, Offset position) async {
    final translations = AITranslations.of(context);
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final edit = onEdit;
    final choice = await showMenu<VoidCallback>(
      context: context,
      position: RelativeRect.fromRect(position & Size.zero, Offset.zero & overlay.size),
      items: [
        PopupMenuItem(
          value: () => Clipboard.setData(ClipboardData(text: text)),
          child: ListTile(leading: const Icon(Icons.content_copy), title: Text(translations.copyMessage)),
        ),
        if (edit != null)
          PopupMenuItem(
            value: edit,
            child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(translations.editMessage)),
          ),
      ],
    );
    choice?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ConversationTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final builders = AIComponentFactory.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 8,
        children: [
          for (final attachment in attachments)
            AIMessageAttachmentView.of(
              context,
              builders,
              AIMessageAttachmentProps(
                attachment: attachment,
                isFromUser: true,
                onTap: onAttachmentTap == null ? null : () => onAttachmentTap!(attachment),
              ),
            ),
          if (text.isNotEmpty)
            GestureDetector(
              onLongPressStart: (details) => _showMenu(context, details.globalPosition),
              onSecondaryTapUp: (details) => _showMenu(context, details.globalPosition),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.userMessageBackgroundColor ?? scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    text,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: scheme.onSurface).merge(theme.userMessageTextStyle),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
