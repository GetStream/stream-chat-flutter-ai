import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_fill.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// Builds an `Image`: the image at its `url`, in a box whose size its
/// `variant` sets and that the image never changes, scaled into it as its
/// `fit` says.
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

  // The longest side an image is decoded at, whatever size it was sent at.
  static const _maxPixels = 1200;

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

  // The URL to load the image from: the agent's, when it has a scheme, as
  // [mediaUrl] gives it. A name without a scheme loads nothing.
  static Uri? _sourceOf(String? url, A2UIMediaUrl mediaUrl) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    return mediaUrl(uri);
  }

  Widget _image(BuildContext context, Uri source) {
    return Image(
      image: ResizeImage(
        CachedNetworkImageProvider(source.toString()),
        width: _maxPixels,
        height: _maxPixels,
        policy: ResizeImagePolicy.fit,
        allowUpscaling: false,
      ),
      fit: fit,
      width: footprint.width,
      height: footprint.height,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame == null && !wasSynchronouslyLoaded) return const _Loading();
        return child;
      },
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

// A small spinner in the secondary text color.
class _Loading extends StatelessWidget {
  const _Loading();

  static const _size = 20.0;
  static const _stroke = 2.0;

  @override
  Widget build(BuildContext context) {
    final theme = A2UISurfaceScope.of(context).theme;
    return Center(
      child: SizedBox.square(
        dimension: _size,
        child: CircularProgressIndicator(strokeWidth: _stroke, color: theme.secondaryText),
      ),
    );
  }
}
