import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_actions.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `ListBlock`: its `items` in rows, each numbered or, when its
/// `variant` is `image`, led by its item's `image`, with the item's `title`
/// and `subtitle`; `size` `small` draws it smaller.
///
/// An item with an `action` can be tapped, unless the reply is still
/// streaming: it runs the action labelled with its `title`, with its
/// `actionLabel` and an arrow at the row's end.
///
/// Internal to the package.
@internal
Widget buildOpenUIListBlock(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUIViewScope.of(context).theme;
  final colors = theme;
  final styles = theme;
  final items = scope.elements('items');
  final small = scope.string('size') == 'small';
  final images = scope.string('variant') == 'image';
  final hasSubtitle = items.any((item) => scope.scopeOf(item).text('subtitle') != null);
  Widget row(int index, OpenUIComponentScope item) {
    final title = item.text('title') ?? '';
    final subtitle = item.text('subtitle');
    final action = item.prop('action');
    final hasAction = action != null && action is! OpenUINull;
    final image = item.value('image');
    final Widget leading;
    if (images && image is Map<String, Object?>) {
      final side = openUIScaled(context, small ? 36 : 48);
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(theme.smallCornerRadius),
        child: SizedBox.square(
          dimension: side,
          child: OpenUIRemoteImage(source: image['src'] as String?, alt: image['alt'] as String?),
        ),
      );
    } else {
      final side = openUIScaled(context, small ? 20 : 24);
      leading = Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: openUIHighlightAlpha),
          shape: BoxShape.circle,
        ),
        child: Text(
          '${index + 1}',
          textScaler: TextScaler.noScaling,
          style: styles.caption.copyWith(fontWeight: FontWeight.w600, color: colors.accent),
        ),
      );
    }
    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: (small ? theme.xsSpacing : theme.sSpacing) + 2),
      child: Row(
        crossAxisAlignment: hasSubtitle ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        spacing: theme.mSpacing,
        children: [
          leading,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 2,
              children: [
                OpenUIMarkdownText(
                  data: title,
                  style: (small ? styles.caption : styles.bodySmall).copyWith(fontWeight: FontWeight.w500),
                ),
                if (subtitle != null)
                  OpenUIMarkdownText(data: subtitle, style: styles.caption, color: colors.secondaryText),
              ],
            ),
          ),
          if (hasAction)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                if (item.text('actionLabel') case final label?)
                  Text(
                    label,
                    style: styles.caption.copyWith(fontWeight: FontWeight.w500, color: colors.secondaryText),
                  ),
                ExcludeSemantics(
                  child: Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? context.streamIcons.chevronLeft
                        : context.streamIcons.chevronRight,
                    size: openUIScaled(context, 14),
                    color: colors.secondaryText,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    if (!hasAction) return content;
    return Builder(
      builder: (context) => OpenUIPressable(
        onTap: scope.isStreaming
            ? null
            : () => triggerOpenUIAction(context, scope, label: title, action: action, inForm: false),
        child: content,
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, node) in items.indexed) ...[
        if (index > 0)
          Padding(
            padding: EdgeInsetsDirectional.only(start: images ? (small ? 48 : 60) : 36),
            child: SizedBox(height: 0.5, child: ColoredBox(color: colors.border)),
          ),
        row(index, scope.scopeOf(node)),
      ],
    ],
  );
}

/// Builds a `FollowUpBlock`: its `items`, suggestions the person can tap,
/// unless the reply is still streaming, to send an item's `text` as their
/// next message.
///
/// Internal to the package.
@internal
Widget buildOpenUIFollowUpBlock(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUIViewScope.of(context).theme;
  final colors = theme;
  final items = scope.elements('items');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, node) in items.indexed) ...[
        if (index > 0)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 26),
            child: SizedBox(height: 0.5, child: ColoredBox(color: colors.border)),
          ),
        Builder(
          builder: (context) {
            final text = scope.scopeOf(node).text('text') ?? '';
            return OpenUIPressable(
              onTap: scope.isStreaming ? null : () => triggerOpenUIAction(context, scope, label: text, inForm: false),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: theme.sSpacing + 2),
                child: Row(
                  spacing: theme.sSpacing,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? context.streamIcons.arrowLeft
                            : context.streamIcons.arrowRight,
                        size: openUIScaled(context, 16),
                        color: colors.accent,
                      ),
                    ),
                    Expanded(
                      child: Text(text, style: theme.bodySmall.copyWith(color: colors.text)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ],
  );
}
