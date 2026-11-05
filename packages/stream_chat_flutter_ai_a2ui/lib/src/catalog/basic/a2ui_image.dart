import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_debug_log.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_fill.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_media.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds an `Image`: the image at its `url`, in a box whose size its
/// `variant` sets and that the image never changes, scaled into it as its
/// `fit` says.
///
/// The image is drawn with the Stream design system's [StreamNetworkImage], so
/// the builder an app registers for network images through
/// [StreamComponentFactory] loads and draws it instead. It is decoded at a
/// width its box needs rather than at its own size, unless its `fit` is
/// `none`, which shows it at its own size.
///
/// The box shows the subtle surface color, with a spinner while the image
/// loads. An image that can't load, whose URL has no scheme, or whose URL the
/// surface's media function refuses, leaves the box empty. Its `description`
/// is its accessibility label; when the agent writes neither a description
/// nor an accessibility label, or writes them empty, assistive technologies
/// skip it.
///
/// Internal to the package.
@internal
Widget buildA2UIImage(BuildContext context, A2UIComponentScope scope) {
  final description = scope.string('description');
  final accessibility = a2uiWrittenProperty(scope, 'accessibility');
  return A2UIImageView(
    url: scope.string('url'),
    description: description == null || description.isEmpty ? null : description,
    // A description or label that is bound but not read yet still counts, so
    // the image isn't skipped before its data arrives.
    isDecorative:
        !_isWritten(a2uiWrittenProperty(scope, 'description')) &&
        !_isWritten(accessibility is Map<String, Object?> ? accessibility['label'] : null),
    fit: _fitOf(scope.hint('fit')),
    footprint: A2UIImageFootprint.of(scope.hint('variant')),
  );
}

bool _isWritten(Object? text) => text != null && text != '';

// The scaling of a `fit`, which follows CSS's `object-fit`: `fill`, the
// default, stretches the image to the box.
BoxFit _fitOf(String? fit) {
  return switch (fit) {
    'contain' => BoxFit.contain,
    'cover' => BoxFit.cover,
    'none' => BoxFit.none,
    'scaleDown' => BoxFit.scaleDown,
    _ => BoxFit.fill,
  };
}

/// The size of an `Image`'s box for its `variant`, which doesn't depend on
/// the image, so an image never changes the layout around it.
///
/// Internal to the package.
@internal
@immutable
final class A2UIImageFootprint {
  const A2UIImageFootprint._({this.width, required this.height, this.isCircle = false});

  /// The footprint of [variant]; an unknown or missing variant is a medium
  /// feature.
  factory A2UIImageFootprint.of(String? variant) {
    return switch (variant) {
      'icon' => const A2UIImageFootprint._(width: 24, height: 24),
      'avatar' => const A2UIImageFootprint._(width: 48, height: 48, isCircle: true),
      'smallFeature' => const A2UIImageFootprint._(width: 72, height: 72),
      'largeFeature' => const A2UIImageFootprint._(width: 240, height: 240),
      'header' => const A2UIImageFootprint._(height: 200),
      _ => const A2UIImageFootprint._(width: 160, height: 160),
    };
  }

  /// The width of the box, or `null` for the full width it is given.
  final double? width;

  /// The height of the box.
  final double height;

  /// Whether the box is a circle rather than a rounded rectangle.
  final bool isCircle;
}

/// The image at [url] in a box of [footprint], scaled by [fit].
///
/// Internal to the package.
@internal
class A2UIImageView extends StatelessWidget {
  /// Creates an [A2UIImageView].
  const A2UIImageView({
    super.key,
    required this.url,
    required this.description,
    required this.isDecorative,
    required this.fit,
    required this.footprint,
  });

  /// The URL the agent wrote, or `null` when it wrote none.
  final String? url;

  /// The accessibility label of the image.
  final String? description;

  /// Whether assistive technologies skip the image.
  final bool isDecorative;

  /// How the image is scaled into its box.
  final BoxFit fit;

  /// The size and shape of the box.
  final A2UIImageFootprint footprint;

  @override
  Widget build(BuildContext context) {
    final scope = A2UISurfaceScope.of(context);
    final theme = scope.theme;
    final source = _sourceOf(url, scope.mediaUrl);
    final sized = SizedBox(
      width: footprint.width,
      height: footprint.height,
      child: ColoredBox(
        color: theme.subtleSurface,
        child: source == null ? null : _image(context, source),
      ),
    );
    final box = footprint.width == null ? A2UIFill(axis: Axis.horizontal, child: sized) : sized;
    final clipped = footprint.isCircle
        ? ClipOval(child: box)
        : ClipRRect(borderRadius: BorderRadius.all(Radius.circular(theme.controlCornerRadius)), child: box);
    if (isDecorative) return ExcludeSemantics(child: clipped);
    return Semantics(image: true, label: description, excludeSemantics: true, child: clipped);
  }

  // The URL to load the image from (see [a2uiMediaSourceOf]). A URL that
  // loads nothing is logged in debug builds.
  static Uri? _sourceOf(String? url, A2UIMediaUrl mediaUrl) {
    final source = a2uiMediaSourceOf(url, mediaUrl);
    if (source != null || url == null || url.isEmpty) return source;
    if (Uri.tryParse(url) case final uri? when uri.hasScheme) {
      a2uiDebugLogOnce("The Image URL '$url' is not loaded: the surface's media URL function refused it.");
    } else {
      a2uiDebugLogOnce("The Image URL '$url' is not loaded: it is not a URL with a scheme.");
    }
    return source;
  }

  Widget _image(BuildContext context, Uri source) {
    return StreamNetworkImage(
      source.toString(),
      width: footprint.width,
      height: footprint.height,
      cacheWidth: a2uiDecodeWidth(context, width: footprint.width, height: footprint.height, fit: fit),
      fit: fit,
      excludeFromSemantics: true,
      placeholderBuilder: (context) => const A2UISpinner(),
      errorBuilder: (context, error, retry) {
        a2uiDebugLogOnce("The Image '$source' failed to load: $error");
        return const SizedBox.shrink();
      },
    );
  }
}

/// The width, in pixels, an image shown with [fit] in a box [height] tall and
/// [width] wide is decoded at, or `null` to decode it at its own size.
///
/// A box with no [width] is taken to be as wide as the screen.
///
/// The image keeps its proportions. An image that only has to fit in the box
/// needs no more pixels than the box's longest side; one that covers or fills
/// the box needs more when it is wider than the box, so it gets twice that,
/// which keeps images up to twice as wide as tall sharp. With [BoxFit.none]
/// it is shown at its own size, so it is decoded at its own size.
///
/// Internal to the package.
@internal
int? a2uiDecodeWidth(BuildContext context, {required double? width, required double height, required BoxFit fit}) {
  final factor = switch (fit) {
    BoxFit.none => null,
    BoxFit.contain || BoxFit.scaleDown => 1,
    BoxFit.cover || BoxFit.fill || BoxFit.fitWidth || BoxFit.fitHeight => 2,
  };
  if (factor == null) return null;
  // A box without a width is at most as wide as the screen.
  final boxWidth = width ?? MediaQuery.sizeOf(context).width;
  final longestSide = boxWidth > height ? boxWidth : height;
  return (longestSide * MediaQuery.devicePixelRatioOf(context) * factor).ceil();
}
