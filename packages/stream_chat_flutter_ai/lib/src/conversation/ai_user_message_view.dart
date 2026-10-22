import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stream_chat_flutter_ai/src/components/ai_component_factory.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment_view.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/conversation_theme.dart';
import 'package:stream_core_flutter/chat.dart';

/// A message the person sent: its attachments, then its text in a bubble, at
/// the trailing edge. A long press offers to copy the text, and to edit it given
/// [onEdit].
///
/// Attachments can be replaced through the `messageAttachment` builder of [streamAIComponentBuilders].
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
    final icons = context.streamIcons;
    final edit = onEdit;
    final choice = await showGeneralDialog<VoidCallback>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0x00000000),
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => CustomSingleChildLayout(
        delegate: _MenuLayout(position),
        child: StreamContextMenu(
          children: [
            StreamContextMenuAction<VoidCallback>(
              value: () => Clipboard.setData(ClipboardData(text: text)),
              label: Text(translations.copyMessage),
              leading: Icon(icons.copy),
            ),
            if (edit != null)
              StreamContextMenuAction<VoidCallback>(
                value: edit,
                label: Text(translations.editMessage),
                leading: Icon(icons.edit),
              ),
          ],
        ),
      ),
    );
    choice?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ConversationTheme.of(context);
    final colors = context.streamColorScheme;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 8,
        children: [
          for (final attachment in attachments)
            AIMessageAttachmentView.of(
              context,
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
                  color: theme.userMessageBackgroundColor ?? colors.backgroundSurface,
                  borderRadius: BorderRadius.all(context.streamRadius.xxl),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    text,
                    style: context.streamTextTheme.bodyDefault
                        .copyWith(color: colors.textPrimary)
                        .merge(theme.userMessageTextStyle),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Places the menu at the press, kept on screen.
class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout(this.position);

  final Offset position;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    position.dx.clamp(0, math.max(0, size.width - childSize.width)),
    position.dy.clamp(0, math.max(0, size.height - childSize.height)),
  );

  @override
  bool shouldRelayout(_MenuLayout oldDelegate) => position != oldDelegate.position;
}
