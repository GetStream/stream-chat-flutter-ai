import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_resolved_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_stream_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// The color the variant [name] draws with: `success`, `warning`, `danger` or
/// `error`, `info`, or the neutral color for any other.
///
/// Internal to the package.
@internal
Color openUIVariantColor(OpenUIResolvedTheme theme, String? name) {
  return switch (name) {
    'success' => theme.success,
    'warning' => theme.warning,
    'danger' || 'error' => theme.error,
    'info' => theme.info,
    _ => theme.neutral,
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
    final theme = OpenUIViewScope.of(context).theme;
    final (color, border) = switch (variant) {
      'card' => (theme.surface, Border.all(color: theme.border, width: 0.5)),
      'sunk' => (theme.sunkenSurface, null),
      _ => (null, null),
    };
    if (color == null) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: border,
        borderRadius: BorderRadius.circular(theme.mediumCornerRadius),
      ),
      child: Padding(padding: EdgeInsets.all(theme.mSpacing), child: child),
    );
  }
}

/// [text] with the marker that starts a block at the start of each of its
/// lines escaped, so Markdown reads it as inline text: `# of orders` stays
/// that, and `1. Paris` isn't a list.
///
/// Lines lose their indentation, which would make them code.
///
/// Internal to the package.
@internal
String openUIEscapeBlockMarkers(String text) => text.split('\n').map(_escapeLine).join('\n');

final _headingMarker = RegExp(r'^#{1,6}(?=\s|$)');
final _orderedMarker = RegExp(r'^\d{1,9}(?=[.)](\s|$))');
final _bulletMarker = RegExp(r'^[-+*](?=\s|$)');
final _ruleLine = RegExp(r'^(?:=+|-+|(?:[-*_][ \t]*){3,})[ \t]*$');
final _fence = RegExp('^(?:`{3,}|~{3,})');

String _escapeLine(String line) {
  final text = line.trimLeft();
  if (text.startsWith('>') || _headingMarker.hasMatch(text) || _fence.hasMatch(text) || _ruleLine.hasMatch(text)) {
    return '\\$text';
  }
  if (_bulletMarker.hasMatch(text)) return '\\$text';
  final ordered = _orderedMarker.firstMatch(text);
  if (ordered != null) return '${ordered[0]}\\${text.substring(ordered.end)}';
  return text;
}

/// Markdown in [style] and [color], as the design system draws it, with links
/// opening through the view.
///
/// With [inline], [data] is read as inline Markdown: the markers that would
/// start a block, such as `#` or `1.`, are drawn as the text they are.
///
/// Internal to the package.
@internal
class OpenUIMarkdownText extends StatelessWidget {
  /// Creates the Markdown of [data].
  const OpenUIMarkdownText({super.key, required this.data, this.style, this.color, this.inline = false});

  /// The Markdown.
  final String data;

  /// The body style, or `null` for the theme's.
  final TextStyle? style;

  /// The text color, or `null` for the theme's primary color.
  final Color? color;

  /// Whether [data] is inline Markdown only.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    return OpenUIStreamTheme(
      theme: theme.copyWith(body: style, text: color),
      child: AIMarkdownBody(
        data: inline ? openUIEscapeBlockMarkers(data) : data,
        onTapLink: (text, href, title) => openOpenUILink(context, href),
      ),
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
  const OpenUIRemoteImage({super.key, required this.source, this.alt, this.fit = BoxFit.cover, this.extent});

  /// The image's address, or `null` for none.
  final String? source;

  /// What the image shows, in words.
  final String? alt;

  /// How the image fills its space.
  final BoxFit fit;

  /// The longer side of the box the image is drawn in, in logical pixels, or
  /// `null` for the width of the screen. The image is decoded no larger than
  /// that, as it would fill the memory of a long reply otherwise.
  final double? extent;

  @override
  Widget build(BuildContext context) {
    final uri = source == null ? null : Uri.tryParse(source!.trim());
    final url = uri == null || !((uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty)
        ? null
        : OpenUIViewScope.of(context).mediaUrl(uri);
    final label = alt ?? '';
    final child = url == null
        ? _Placeholder(alt: label)
        : StreamNetworkImage(
            url.toString(),
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: _decodeWidth(context, extent),
            placeholderBuilder: (context) => _Placeholder(alt: label, loading: true),
            errorBuilder: (context, error, retry) => _Placeholder(alt: label),
          );
    if (label.isEmpty) return ExcludeSemantics(child: child);
    return Semantics(image: true, label: label, excludeSemantics: true, child: child);
  }
}

// The width to decode an image at: [extent], the longer side of the box it is
// drawn in, or the screen's width when that isn't known, in device pixels. Only
// the width is set, so the image keeps its proportions.
int _decodeWidth(BuildContext context, double? extent) {
  final logical = extent ?? MediaQuery.sizeOf(context).width;
  return (logical * MediaQuery.devicePixelRatioOf(context)).ceil();
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.alt, this.loading = false});

  final String alt;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    return ColoredBox(
      color: theme.sunkenSurface,
      // Scaled down to fit when the box is small, as the picture of a thumbnail.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(theme.sSpacing),
          child: loading
              ? StreamLoadingSpinner()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: theme.xsSpacing,
                  children: [
                    Icon(context.streamIcons.image, color: theme.tertiaryText),
                    if (alt.isNotEmpty)
                      Text(
                        alt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.caption.copyWith(color: theme.tertiaryText),
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
    final theme = OpenUIViewScope.of(context).theme;
    final neutral = variant == null || variant == 'neutral';
    final color = neutral ? theme.secondaryText : openUIVariantColor(theme, variant);
    final (horizontal, vertical, iconSize, style) = switch (size) {
      'lg' => (theme.mSpacing, theme.sSpacing, 16.0, theme.bodySmall),
      'md' => (theme.mSpacing, theme.xsSpacing, 14.0, theme.caption),
      _ => (theme.sSpacing, theme.xsSpacing, 12.0, theme.caption),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: neutral ? theme.subtleFill : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(theme.pillCornerRadius),
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
