import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// The box a video or an audio clip shows in: [height] tall, as wide as it is
/// given, and [fallbackWidth] wide where nothing limits its width, such as in
/// a row that scrolls, with the corners of the theme's controls.
///
/// A row whose children don't fit can make it as narrow as it needs, down to
/// nothing. Its [color] fills it under [children], which are stacked to fill
/// it.
///
/// Internal to the package.
@internal
class A2UIMediaBox extends StatelessWidget {
  /// Creates an [A2UIMediaBox].
  const A2UIMediaBox({
    super.key,
    required this.height,
    required this.fallbackWidth,
    required this.color,
    required this.children,
  });

  /// The height of the box.
  final double height;

  /// The width of the box where nothing limits its width.
  final double fallbackWidth;

  /// The color under the box's [children].
  final Color color;

  /// What the box shows, stacked from the bottom up, each filling it unless
  /// it is positioned.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = A2UISurfaceScope.of(context).theme;
    return _MediaBoxSize(
      height: height,
      fallbackWidth: fallbackWidth,
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(theme.controlCornerRadius)),
        child: ColoredBox(
          color: color,
          child: Stack(fit: StackFit.expand, children: children),
        ),
      ),
    );
  }
}

// Sizes its child to the media box's size, which never depends on the child,
// so a row can measure the box without asking what it shows, such as a
// player that can't be measured that way.
class _MediaBoxSize extends SingleChildRenderObjectWidget {
  const _MediaBoxSize({required this.height, required this.fallbackWidth, super.child});

  final double height;
  final double fallbackWidth;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMediaBoxSize(height, fallbackWidth);

  @override
  void updateRenderObject(BuildContext context, _RenderMediaBoxSize renderObject) {
    renderObject
      ..height = height
      ..fallbackWidth = fallbackWidth;
  }
}

class _RenderMediaBoxSize extends RenderProxyBox {
  _RenderMediaBoxSize(this._height, this._fallbackWidth);

  double get height => _height;
  double _height;
  set height(double value) {
    if (_height == value) return;
    _height = value;
    markNeedsLayout();
  }

  double get fallbackWidth => _fallbackWidth;
  double _fallbackWidth;
  set fallbackWidth(double value) {
    if (_fallbackWidth == value) return;
    _fallbackWidth = value;
    markNeedsLayout();
  }

  Size _sizeFor(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : _fallbackWidth;
    return constraints.constrain(Size(width, _height));
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _fallbackWidth;

  @override
  double computeMinIntrinsicHeight(double width) => _height;

  @override
  double computeMaxIntrinsicHeight(double width) => _height;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => _sizeFor(constraints);

  // The box has no baseline of its own, and asking what it shows for one
  // would measure a player that can't be measured that way.
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => null;

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) => null;

  @override
  void performLayout() {
    size = _sizeFor(constraints);
    child?.layout(BoxConstraints.tight(size));
  }
}

/// A round button that plays media, or pauses it while [isPlaying], labeled
/// for assistive technologies.
///
/// It draws a circle [size] across in [color], over a shadow when
/// [hasShadow], and takes taps in at least a 48 by 48 square.
///
/// Internal to the package.
@internal
class A2UIPlayButton extends StatelessWidget {
  /// Creates an [A2UIPlayButton].
  const A2UIPlayButton({
    super.key,
    required this.isPlaying,
    required this.size,
    required this.color,
    this.hasShadow = false,
    required this.onPressed,
  });

  /// Whether the media plays, so the button pauses it.
  final bool isPlaying;

  /// The diameter of the button's circle.
  final double size;

  /// The color of the button's icon.
  final Color color;

  /// Whether the icon casts a shadow, so it shows over a picture.
  final bool hasShadow;

  /// Called when the person taps the button.
  final VoidCallback onPressed;

  // The least width and height a person can tap.
  static const _minTapSize = 48.0;

  // The blur and color of the icon's shadow: black at a third.
  static const _shadowBlur = 4.0;
  static const _shadowColor = Color(0x55000000);

  // The circle of the play and pause icons is 20 of their 24 units, so they
  // are drawn this much larger for the circle to be [size] across.
  static const _glyphScale = 24.0 / 20.0;

  @override
  Widget build(BuildContext context) {
    final translations = AITranslations.of(context);
    return Semantics(
      button: true,
      label: isPlaying ? translations.pauseMedia : translations.playMedia,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: math.max(size * _glyphScale, _minTapSize),
          child: Center(
            child: Icon(
              isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
              size: size * _glyphScale,
              color: color,
              shadows: hasShadow ? const [Shadow(color: _shadowColor, blurRadius: _shadowBlur)] : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin line along the bottom of a player that fills with the theme's
/// accent as the media plays, over a fill of what has loaded in the secondary
/// text color.
///
/// Assistive technologies skip it, and taps pass through it.
///
/// Internal to the package.
@internal
class A2UIMediaProgress extends StatelessWidget {
  /// Creates an [A2UIMediaProgress].
  const A2UIMediaProgress({super.key, required this.played, required this.loaded});

  /// The share of the media that has played, from 0 to 1.
  final double played;

  /// The share of the media that has loaded, from 0 to 1.
  final double loaded;

  // The thickness of the line.
  static const _height = 3.0;

  // How strongly the loaded part shows the secondary text color.
  static const _loadedOpacity = 0.4;

  @override
  Widget build(BuildContext context) {
    final theme = A2UISurfaceScope.of(context).theme;
    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: SizedBox(
            height: _height,
            child: ColoredBox(
              color: theme.border,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _bar(loaded, theme.secondaryText.withValues(alpha: _loadedOpacity)),
                  _bar(played, theme.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _bar(double share, Color color) {
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: share.isFinite ? share.clamp(0.0, 1.0) : 0.0,
      child: ColoredBox(color: color),
    );
  }
}

/// The sign that media can't play, in place of its play button: [icon] in the
/// secondary text color.
///
/// Internal to the package.
@internal
class A2UIMediaUnavailable extends StatelessWidget {
  /// Creates an [A2UIMediaUnavailable].
  const A2UIMediaUnavailable({super.key, required this.icon});

  /// The icon that stands for the media.
  final IconData icon;

  // The size of the icon, the size of the catalog's icons.
  static const _size = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = A2UISurfaceScope.of(context).theme;
    return Center(
      child: Icon(icon, size: _size, color: theme.secondaryText),
    );
  }
}

/// A small spinner in the secondary text color, shown while an image or a
/// player loads.
///
/// Internal to the package.
@internal
class A2UISpinner extends StatelessWidget {
  /// Creates an [A2UISpinner].
  const A2UISpinner({super.key});

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
