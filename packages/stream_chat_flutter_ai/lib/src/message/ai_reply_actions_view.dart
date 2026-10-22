import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/reply_actions_theme.dart';
import 'package:stream_core_flutter/chat.dart';

/// How the person rated a reply.
enum AIMessageRating {
  /// A good reply.
  positive,

  /// A bad reply.
  negative,
}

/// Shares a reply's [text]. [origin] is the share button's rectangle in global
/// coordinates, which a share sheet on iPad anchors its popover to.
typedef AIReplyShareCallback = void Function(String text, Rect? origin);

/// What [AIReplyActionsView] offers besides copying a reply. Each action shows
/// only when its callback is set.
@immutable
class AIReplyActions {
  /// Creates an [AIReplyActions].
  const AIReplyActions({this.rating, this.onShare, this.onRegenerate, this.onRate});

  /// How the person rated the reply, or `null` when they didn't.
  final AIMessageRating? rating;

  /// Shares the reply, such as with `share_plus`.
  final AIReplyShareCallback? onShare;

  /// Asks the agent for a new reply in its place.
  final VoidCallback? onRegenerate;

  /// Rates the reply, or takes the rating back with `null`.
  final ValueChanged<AIMessageRating?>? onRate;
}

/// The buttons under a finished reply: copy, then share, regenerate and rate
/// when [actions] handles them.
///
/// ```dart
/// AIReplyActionsView(
///   text: reply.text,
///   actions: AIReplyActions(
///     rating: ratings[reply.id],
///     onRate: (rating) => setState(() => ratings[reply.id] = rating),
///   ),
/// )
/// ```
class AIReplyActionsView extends StatefulWidget {
  /// Creates an [AIReplyActionsView].
  const AIReplyActionsView({super.key, required this.text, this.actions = const AIReplyActions()});

  /// The reply's text, which copying and sharing hand on.
  final String text;

  /// What else the person can do with the reply.
  final AIReplyActions actions;

  @override
  State<AIReplyActionsView> createState() => _AIReplyActionsViewState();
}

class _AIReplyActionsViewState extends State<AIReplyActionsView> {
  bool _copied = false;
  Timer? _resetTimer;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () => setState(() => _copied = false));
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final translations = AITranslations.of(context);
    final theme = ReplyActionsTheme.of(context);
    final color = theme.iconColor ?? context.streamColorScheme.textSecondary;
    final icons = context.streamIcons;
    final selectedColor = theme.selectedIconColor ?? color;
    final size = theme.iconSize ?? 18;
    final actions = widget.actions;

    Widget button(IconData icon, String label, VoidCallback onPressed, {bool? selected}) {
      final glyph = Icon(icon, size: size, color: selected ?? false ? selectedColor : color);
      return StreamButton.icon(
        onPressed: onPressed,
        style: .secondary,
        type: .ghost,
        size: .small,
        isSelected: selected,
        icon: glyph,
        tooltip: label,
        themeStyle: const StreamButtonThemeStyle(tapTargetSize: .shrinkWrap),
      );
    }

    final onShare = actions.onShare;
    final onRegenerate = actions.onRegenerate;
    final onRate = actions.onRate;
    final positive = actions.rating == AIMessageRating.positive;
    final negative = actions.rating == AIMessageRating.negative;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(
          _copied ? icons.checkmark : icons.copy,
          _copied ? translations.replyCopied : translations.copyReply,
          _copy,
        ),
        if (onShare != null)
          Builder(
            builder: (context) => button(icons.share, translations.shareReply, () {
              final box = context.findRenderObject() as RenderBox?;
              final origin = box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
              onShare(widget.text, origin);
            }),
          ),
        if (onRegenerate != null) button(icons.refresh, translations.regenerateReply, onRegenerate),
        if (onRate != null) ...[
          button(
            positive ? Icons.thumb_up : Icons.thumb_up_outlined,
            translations.rateReplyPositive,
            () => onRate(positive ? null : AIMessageRating.positive),
            selected: positive,
          ),
          button(
            negative ? Icons.thumb_down : Icons.thumb_down_outlined,
            translations.rateReplyNegative,
            () => onRate(negative ? null : AIMessageRating.negative),
            selected: negative,
          ),
        ],
      ],
    );
  }
}
