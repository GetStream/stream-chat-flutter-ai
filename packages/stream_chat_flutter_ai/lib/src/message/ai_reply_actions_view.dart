import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/reply_actions_theme.dart';

/// How the person rated a reply.
enum AIMessageRating {
  /// A good reply.
  positive,

  /// A bad reply.
  negative,
}

/// Shares a reply's [text] in place of the platform share sheet. [origin] is
/// the share button's rectangle in global coordinates, which a share sheet on
/// iPad anchors its popover to.
typedef AIReplyShareCallback = void Function(String text, Rect? origin);

/// What [AIReplyActionsView] offers besides copying and sharing a reply.
/// Regenerating and rating show only when their callback is set.
@immutable
class AIReplyActions {
  /// Creates an [AIReplyActions].
  const AIReplyActions({this.rating, this.onShare, this.onRegenerate, this.onRate});

  /// How the person rated the reply, or `null` when they didn't.
  final AIMessageRating? rating;

  /// Shares the reply in place of the platform share sheet, such as to record
  /// that it was shared. When `null`, the share button opens the share sheet.
  final AIReplyShareCallback? onShare;

  /// Asks the agent for a new reply in its place.
  final VoidCallback? onRegenerate;

  /// Rates the reply, or takes the rating back with `null`.
  final ValueChanged<AIMessageRating?>? onRate;
}

/// The buttons under a finished reply: copy and share, then regenerate and
/// rate when [actions] handles them.
///
/// Sharing opens the platform share sheet with [text], unless
/// [AIReplyActions.onShare] shares it instead.
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
    try {
      await Clipboard.setData(ClipboardData(text: widget.text));
    } on Object {
      // Such as on the web without clipboard permission: nothing was copied,
      // so there is nothing to confirm.
      return;
    }
    if (!mounted) return;
    setState(() => _copied = true);
    final translations = AITranslations.of(context);
    unawaited(
      SemanticsService.sendAnnouncement(View.of(context), translations.replyCopied, Directionality.of(context)),
    );
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _share(Rect? origin) async {
    try {
      await SharePlus.instance.share(ShareParams(text: widget.text, sharePositionOrigin: origin));
    } on Object {
      // Such as for an empty reply, or where the platform has no share sheet:
      // nothing was shared, and there is nothing to tell the person.
    }
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
    final color = theme.iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final selectedColor = theme.selectedIconColor ?? color;
    final size = theme.iconSize ?? 18;
    // A 32 dp button, padded to a 48 dp tap target where the theme asks for
    // one. Material 2 ignores `tapTargetSize`, so there the button is as
    // big as its target.
    final padded = Theme.of(context).materialTapTargetSize == MaterialTapTargetSize.padded;
    final extent = padded && !Theme.of(context).useMaterial3 ? kMinInteractiveDimension : 32.0;
    final actions = widget.actions;

    Widget button(IconData icon, String label, VoidCallback onPressed, {bool? selected}) {
      final glyph = Icon(icon, size: size, color: selected ?? false ? selectedColor : color);
      return IconButton(
        onPressed: onPressed,
        // Material 3 styles a toggle by it; the Semantics below reports the
        // state under Material 2 as well, which ignores it.
        isSelected: selected,
        icon: selected == null ? glyph : Semantics(selected: selected, child: glyph),
        tooltip: label,
        // Set on the button rather than in `style`, which Material 2 ignores.
        constraints: BoxConstraints.tightFor(width: extent, height: extent),
        padding: EdgeInsets.zero,
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
          _copied ? Icons.check : Icons.content_copy,
          _copied ? translations.replyCopied : translations.copyReply,
          _copy,
        ),
        Builder(
          builder: (context) => button(Icons.ios_share, translations.shareReply, () {
            final box = context.findRenderObject() as RenderBox?;
            final origin = box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
            if (onShare != null) {
              onShare(widget.text, origin);
            } else {
              unawaited(_share(origin));
            }
          }),
        ),
        if (onRegenerate != null) button(Icons.refresh, translations.regenerateReply, onRegenerate),
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
