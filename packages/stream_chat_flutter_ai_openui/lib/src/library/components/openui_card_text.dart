import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_icon_map.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `Text`: its `value` as inline Markdown in the size its `size`
/// names (`xs`, `sm`, `lg`, or the medium size for any other), with its
/// `subtext` below it.
///
/// With the `variant` `number` the digits have one width. The `subtext` is
/// green when it starts with `+` and the `subtextVariant` is `metric`, red when
/// it starts with `-` or `−`.
///
/// Internal to the package.
@internal
Widget buildOpenUIText(BuildContext context, OpenUIComponentScope scope) => _text(context, scope, bold: false);

/// Builds a `BoldText`: a `Text` in a heavier weight and larger size.
///
/// Internal to the package.
@internal
Widget buildOpenUIBoldText(BuildContext context, OpenUIComponentScope scope) => _text(context, scope, bold: true);

Widget _text(BuildContext context, OpenUIComponentScope scope, {required bool bold}) {
  final theme = OpenUIViewScope.of(context).theme;
  final style = switch (scope.string('size')) {
    'xs' => theme.caption,
    'sm' => theme.bodySmall,
    'lg' => bold ? theme.title : theme.bodyLarge,
    _ => bold ? theme.heading : theme.body,
  };
  final subtext = scope.text('subtext') ?? '';
  final subtextColor = switch (scope.string('subtextVariant')) {
    'metric' when subtext.startsWith('+') => theme.success,
    'metric' when subtext.startsWith('-') || subtext.startsWith('−') => theme.error,
    _ => theme.secondaryText,
  };
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 2,
    children: [
      DefaultTextStyle.merge(
        style: TextStyle(
          fontFeatures: scope.string('variant') == 'number' ? const [FontFeature.tabularFigures()] : null,
        ),
        child: OpenUIMarkdownText(
          data: scope.text('value') ?? '',
          style: style.copyWith(fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
        ),
      ),
      if (subtext.isNotEmpty)
        Text(
          subtext,
          style: theme.caption.copyWith(
            color: subtextColor,
            fontFeatures: scope.string('subtextVariant') != 'text' ? const [FontFeature.tabularFigures()] : null,
          ),
        ),
    ],
  );
}

/// The title with its subtitle below it, as inline Markdown; the subtitle is
/// left out when empty.
///
/// Internal to the package.
@internal
class OpenUITitleSubtitle extends StatelessWidget {
  /// Creates the title block of [title] and [subtitle].
  const OpenUITitleSubtitle({super.key, required this.title, this.subtitle, this.bold = false});

  /// The title.
  final String title;

  /// The subtitle, or `null`.
  final String? subtitle;

  /// Whether the title is semibold, and medium weight otherwise.
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        OpenUIMarkdownText(
          data: title,
          style: theme.bodySmall.copyWith(fontWeight: bold ? FontWeight.w600 : FontWeight.w500),
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          OpenUIMarkdownText(data: subtitle!, style: theme.caption, color: theme.secondaryText),
      ],
    );
  }
}

/// Builds an `IconText`: its `icon` in a rounded badge of its `iconVariant`
/// and `iconSize`, beside (or, with the `layout` `vertical`, above) its
/// `title` and `subtitle`.
///
/// Internal to the package.
@internal
Widget buildOpenUIIconText(BuildContext context, OpenUIComponentScope scope) {
  final icon = scope.elements('icon').firstOrNull;
  final iconScope = icon == null ? null : scope.scopeOf(icon);
  final badge = _IconBadge(
    icon: iconScope == null
        ? null
        : openUIIconOf(context.streamIcons, iconScope.string('name') ?? '', iconScope.string('category')),
    variant: scope.string('iconVariant'),
    size: scope.string('iconSize'),
  );
  return _withLeading(
    context,
    scope,
    leading: badge,
    title: OpenUITitleSubtitle(
      title: scope.text('title') ?? '',
      subtitle: scope.text('subtitle'),
      bold: scope.boolean('bold') ?? false,
    ),
  );
}

/// Builds an `ImageText`: its `src` as a square of its `imageSize` (8 to 200,
/// 40 when it isn't a number) beside (or, with the `layout` `vertical`,
/// above) its `title` and `subtitle`.
///
/// Internal to the package.
@internal
Widget buildOpenUIImageText(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUIViewScope.of(context).theme;
  final requested = scope.number('imageSize');
  final size = requested == null || !requested.isFinite ? 40.0 : requested.clamp(8.0, 200.0);
  return _withLeading(
    context,
    scope,
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(theme.smallCornerRadius),
      // A picture has no text to size it, so its side is its own.
      child: SizedBox.square(
        dimension: size,
        child: OpenUIRemoteImage(source: scope.string('src'), alt: scope.text('alt')),
      ),
    ),
    title: OpenUITitleSubtitle(
      title: scope.text('title') ?? '',
      subtitle: scope.text('subtitle'),
      bold: scope.boolean('bold') ?? false,
    ),
  );
}

Widget _withLeading(
  BuildContext context,
  OpenUIComponentScope scope, {
  required Widget leading,
  required Widget title,
}) {
  final spacing = OpenUIViewScope.of(context).theme;
  if (scope.string('layout') == 'vertical') {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.sSpacing,
      children: [leading, title],
    );
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    spacing: spacing.mSpacing,
    children: [
      leading,
      Flexible(child: title),
    ],
  );
}

/// Builds an `ImageTextLarge`: its `src` across the space it is given, with
/// its `title` and `subtitle` below.
///
/// Internal to the package.
@internal
Widget buildOpenUIImageTextLarge(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUIViewScope.of(context).theme;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: theme.sSpacing,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(theme.mediumCornerRadius),
        // A picture has no text to size it, so its height is its own.
        child: SizedBox(
          height: 140,
          child: OpenUIRemoteImage(source: scope.string('src'), alt: scope.text('alt')),
        ),
      ),
      OpenUITitleSubtitle(title: scope.text('title') ?? '', subtitle: scope.text('subtitle'), bold: true),
    ],
  );
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.variant, required this.size});

  final IconData? icon;
  final String? variant;
  final String? size;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    final (foreground, background) = switch (variant) {
      'inverted' => (theme.onAccent, theme.text),
      'filled' => (theme.onAccent, theme.accent),
      'info' || 'success' || 'warning' || 'danger' => (
        openUIVariantColor(theme, variant),
        openUIVariantColor(theme, variant).withValues(alpha: 0.14),
      ),
      'soft' => (theme.accent, theme.accent.withValues(alpha: 0.12)),
      _ => (theme.text, theme.sunkenSurface),
    };
    final dimension = openUIScaled(context, switch (size) {
      'xs' => 24.0,
      's' || 'sm' => 30.0,
      'l' || 'lg' => 44.0,
      'xl' => 52.0,
      _ => 36.0,
    });
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: dimension,
        child: DecoratedBox(
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(dimension * 0.28)),
          child: icon == null
              ? null
              : Center(
                  child: Icon(icon, size: dimension * 0.45, color: foreground),
                ),
        ),
      ),
    );
  }
}
