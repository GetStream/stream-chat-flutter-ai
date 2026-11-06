import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_stream_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// The color the variant [name] draws with: `success`, `warning`, `danger` or
/// `error`, `info`, or the neutral color for any other.
///
/// Internal to the package.
@internal
Color openUIVariantColor(OpenUIColors colors, String? name) {
  return switch (name) {
    'success' => colors.success!,
    'warning' => colors.warning!,
    'danger' || 'error' => colors.danger!,
    'info' => colors.info!,
    _ => colors.neutral!,
  };
}

/// [child] on the surface of [variant]: `card` is a bordered card surface,
/// `sunk` a sunken one, and anything else, `clear`, no surface.
///
/// Internal to the package.
@internal
class OpenUISurface extends StatelessWidget {
  /// Creates the surface of [variant] around [child].
  const OpenUISurface({super.key, required this.variant, required this.child});

  /// The surface's name.
  final String variant;

  /// The widget on the surface.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUITheme.of(context);
    final colors = theme.colors!;
    final (color, border) = switch (variant) {
      'card' => (colors.surface!, Border.all(color: colors.border!, width: 0.5)),
      'sunk' => (colors.sunkenSurface!, null),
      _ => (null, null),
    };
    if (color == null) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: border,
        borderRadius: BorderRadius.circular(theme.radius!.medium!),
      ),
      child: Padding(padding: EdgeInsets.all(theme.spacing!.m!), child: child),
    );
  }
}

/// Markdown in [style] and [color], as the design system draws it, with links
/// opening through the view.
///
/// Internal to the package.
@internal
class OpenUIMarkdownText extends StatelessWidget {
  /// Creates the Markdown of [data].
  const OpenUIMarkdownText({super.key, required this.data, this.style, this.color});

  /// The Markdown.
  final String data;

  /// The body style, or `null` for the theme's.
  final TextStyle? style;

  /// The text color, or `null` for the theme's primary color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUITheme.of(context);
    final styles = theme.textStyles!;
    return OpenUIStreamTheme(
      theme: theme.copyWith(
        textStyles: style == null ? styles : styles.copyWith(body: style),
        colors: color == null ? theme.colors : theme.colors!.copyWith(textPrimary: color),
      ),
      child: AIMarkdownBody(data: data, onTapLink: (text, href, title) => openOpenUILink(context, href)),
    );
  }
}

/// The image of [source], filling the width it is given.
///
/// It loads web links only, and through the view's media function. While it
/// loads, or when it can't, it shows a sunken box with [alt] in it. With an
/// [alt] it reads as an image with that description; without one it is left
/// out of the semantics.
///
/// Internal to the package.
@internal
class OpenUIRemoteImage extends StatelessWidget {
  /// Creates the image of [source] described by [alt].
  const OpenUIRemoteImage({super.key, required this.source, this.alt, this.fit = BoxFit.cover});

  /// The image's address, or `null` for none.
  final String? source;

  /// What the image shows, in words.
  final String? alt;

  /// How the image fills its space.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final uri = source == null ? null : Uri.tryParse(source!.trim());
    final url = uri == null || !((uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty)
        ? null
        : OpenUIViewScope.of(context).mediaUrl(uri);
    final label = alt ?? '';
    final Widget child = url == null
        ? _Placeholder(alt: label)
        : StreamNetworkImage(
            url.toString(),
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            placeholderBuilder: (context) => _Placeholder(alt: label, loading: true),
            errorBuilder: (context, error, retry) => _Placeholder(alt: label),
          );
    if (label.isEmpty) return ExcludeSemantics(child: child);
    return Semantics(image: true, label: label, excludeSemantics: true, child: child);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.alt, this.loading = false});

  final String alt;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUITheme.of(context);
    final colors = theme.colors!;
    return ColoredBox(
      color: colors.sunkenSurface!,
      // Scaled down to fit when the box is small, as the picture of a thumbnail.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(theme.spacing!.s!),
          child: loading
              ? StreamLoadingSpinner()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: theme.spacing!.xs!,
                  children: [
                    Icon(context.streamIcons.image, color: colors.textTertiary),
                    if (alt.isNotEmpty)
                      Text(
                        alt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textStyles!.caption!.copyWith(color: colors.textTertiary),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// [size] scaled with the person's text size.
///
/// Internal to the package.
@internal
double openUIScaled(BuildContext context, double size) => MediaQuery.textScalerOf(context).scale(size);

/// [value], a prop's JSON value, as the text it reads as: a string as it is, a
/// whole number without a decimal point, and `''` for `null` and for what has
/// no text.
///
/// Internal to the package.
@internal
String openUIJsonText(Object? value) {
  return switch (value) {
    String() => value,
    num() when value.isFinite && value == value.truncateToDouble() => value.toInt().toString(),
    num() || bool() => '$value',
    _ => '',
  };
}

/// [value], a prop's JSON value, as a list: a list as it is, none for `null`,
/// and a one-item list for anything else.
///
/// Internal to the package.
@internal
List<Object?> openUIJsonList(Object? value) {
  return switch (value) {
    final List<Object?> list => list,
    null => const [],
    _ => [value],
  };
}

/// The tag with [text] in the size [size] (`lg`, `md`, or the smallest for
/// any other) and the variant [variant], with [icon] before the text.
///
/// Internal to the package.
@internal
class OpenUITagPill extends StatelessWidget {
  /// Creates the tag of [text].
  const OpenUITagPill({super.key, required this.text, this.icon, this.size, this.variant});

  /// What the tag says.
  final String text;

  /// The icon before the text, or `null`.
  final IconData? icon;

  /// The tag's size name.
  final String? size;

  /// The tag's variant name.
  final String? variant;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUITheme.of(context);
    final colors = theme.colors!;
    final neutral = variant == null || variant == 'neutral';
    final color = neutral ? colors.textSecondary! : openUIVariantColor(colors, variant);
    final (horizontal, vertical, iconSize, style) = switch (size) {
      'lg' => (12.0, 6.0, 16.0, theme.textStyles!.bodySmall!),
      'md' => (10.0, 4.0, 14.0, theme.textStyles!.caption!.copyWith(fontSize: 13)),
      _ => (8.0, 3.0, 12.0, theme.textStyles!.caption!),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: neutral ? colors.subtleFill : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(theme.radius!.pill!),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            if (icon != null)
              ExcludeSemantics(
                child: Icon(icon, size: openUIScaled(context, iconSize), color: color),
              ),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(fontWeight: FontWeight.w500, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
