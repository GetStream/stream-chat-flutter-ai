import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_resolved_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_stream_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// How opaque the accent is where it highlights something, such as a chosen
/// chip, a slider's overlay or a list's marker.
///
/// Internal to the package.
@internal
const double openUIHighlightAlpha = 0.12;

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

/// [child] on the surface of [variant]: `clear` is no surface, `sunk` a sunken
/// one, and anything else, `card` among it, a bordered card surface.
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
      'clear' => (null, null),
      'sunk' => (theme.sunkenSurface, null),
      _ => (theme.surface, Border.all(color: theme.border, width: 0.5)),
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

/// [text] with each Markdown image, `![alt](url)` or `![alt][ref]`, turned
/// into a link, `[alt](url)`, that shows its alt text and loads nothing.
///
/// An escaped `\![` stays as it is, and so does a `![` in a code span or a
/// fenced code block. Where a code span or fence is unclear, the `!` is
/// dropped anyway: at worst a `!` goes missing, and never does an image load.
///
/// Internal to the package.
@internal
String openUIImagesAsLinks(String text) {
  if (!text.contains('![')) return text;
  final out = StringBuffer();
  String? fence;
  // Whether a backtick run in this paragraph had no closing run on its line,
  // so Markdown might close it on another line: code spans aren't trusted
  // until a blank line.
  var spansUnclear = false;
  for (final (index, line) in text.split('\n').indexed) {
    if (index > 0) out.write('\n');
    if (fence != null) {
      // Closed by any line that starts with the fence, even one Markdown
      // wouldn't close on: what follows is then read as text.
      if (line.trimLeft().startsWith(fence) && line.length - line.trimLeft().length <= 3) fence = null;
      out.write(line);
      continue;
    }
    // Only a fence at the start of a line, which nothing else can contain.
    final opening = _fenceOpening.firstMatch(line);
    if (opening != null && !(opening[1]!.startsWith('`') && opening[2]!.contains('`'))) {
      fence = opening[1];
      out.write(line);
      continue;
    }
    if (line.trim().isEmpty) spansUnclear = false;
    // A `<` may start an HTML tag or autolink, which a backtick in it doesn't
    // open a code span in.
    final spans = !spansUnclear && !line.contains('<');
    var position = 0;
    while (position < line.length) {
      final char = line[position];
      if (char == r'\') {
        out.write(line.substring(position, (position + 2).clamp(0, line.length)));
        position += 2;
      } else if (char == '`') {
        var end = position;
        while (end < line.length && line[end] == '`') {
          end++;
        }
        final close = spans ? _closingRun(line, end, end - position) : -1;
        if (close == -1) {
          if (!spans || _closingRun(line, end, end - position) == -1) spansUnclear = true;
          out.write(line.substring(position, end));
          position = end;
        } else {
          out.write(line.substring(position, close));
          position = close;
        }
      } else if (char == '!' && position + 1 < line.length && line[position + 1] == '[') {
        position++;
      } else {
        out.write(char);
        position++;
      }
    }
  }
  return out.toString();
}

// A fence at the start of a line: its marker, then its info string.
final _fenceOpening = RegExp(r'^(`{3,}|~{3,})(.*)$');

// The end of the run of exactly [length] backticks after [from] in [line],
// or -1 when there is none.
int _closingRun(String line, int from, int length) {
  var position = from;
  while (position < line.length) {
    if (line[position] != '`') {
      position++;
      continue;
    }
    var end = position;
    while (end < line.length && line[end] == '`') {
      end++;
    }
    if (end - position == length) return end;
    position = end;
  }
  return -1;
}

/// Markdown in [style] and [color], as the design system draws it, with links
/// opening through the view. An image in it is drawn as a link of its alt
/// text, never loaded; see [openUIImagesAsLinks].
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
        data: openUIImagesAsLinks(inline ? openUIEscapeBlockMarkers(data) : data),
        onTapLink: (text, href, title) => openOpenUILink(context, href),
      ),
    );
  }
}

/// The image of [source], filling the width it is given.
///
/// It loads only a web link that the reply's program wrote out or one of its
/// tools gave, and through the view's media function. While it loads, or
/// when it can't, it shows a sunken box with [alt] in it. With an
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
    final view = OpenUIViewScope.of(context);
    final source = this.source;
    // Only a link the program wrote out or a tool gave loads, so an image
    // can't send what the person types to a server, however it is built.
    final uri = source == null || !view.runtime.allowsImageLink(source) ? null : Uri.tryParse(source.trim());
    final url = uri == null || !((uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty)
        ? null
        : view.mediaUrl(uri);
    final label = alt ?? '';
    final child = url == null
        ? _Placeholder(alt: label)
        : StreamNetworkImage(
            url.toString(),
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: openUIDecodeWidth(context, extent: extent, fit: fit),
            placeholderBuilder: (context) => _Placeholder(alt: label, loading: true),
            errorBuilder: (context, error, retry) => _Placeholder(alt: label),
          );
    if (label.isEmpty) return ExcludeSemantics(child: child);
    return Semantics(image: true, label: label, excludeSemantics: true, child: child);
  }
}

/// The widest an image is decoded, in device pixels.
const _maxDecodeWidth = 2048;

/// The width to decode an image at, in device pixels: [extent], the longer side
/// of the box it is drawn in (or the screen's width when `null`), in logical
/// pixels. Only the width is set, so the image keeps its proportions.
///
/// An image that has to cover or fill the box, or fit its height, may need
/// more than the box's width, so it gets twice that. No image is decoded wider
/// than 2048 pixels, and one shown at its own size ([BoxFit.none]) gets that.
///
/// Internal to the package.
@internal
int openUIDecodeWidth(BuildContext context, {required double? extent, required BoxFit fit}) {
  if (fit == BoxFit.none) return _maxDecodeWidth;
  final factor = switch (fit) {
    BoxFit.cover || BoxFit.fill || BoxFit.fitHeight => 2,
    _ => 1,
  };
  final logical = extent ?? MediaQuery.sizeOf(context).width;
  final width = (logical * MediaQuery.devicePixelRatioOf(context) * factor).ceil();
  return width < _maxDecodeWidth ? width : _maxDecodeWidth;
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
    num() when value.isFinite && value == value.truncateToDouble() && value.abs() < 1e21 => value.toStringAsFixed(0),
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
