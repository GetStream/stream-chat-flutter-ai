import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Imported for the doc links below only; nothing in this file's code uses it.
import 'package:stream_chat_flutter_ai/src/ai_typing_indicator_view.dart';
// Not doc-only: [TypingIndicatorTheme.of] reads it.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';
// Imported for the doc links below only.
import 'package:stream_core_flutter/chat.dart';

/// Overrides for how [AITypingIndicatorView] is drawn: the caption's style and
/// the dots' color, size and spacing.
///
/// Every field is nullable, and `null` means "use the default", which derives
/// from the Stream theme ([StreamTheme], which falls back to Stream's defaults for
/// the app's brightness when the app sets none) — so one instance covers light and dark
/// mode.
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       AITheme(typingIndicatorTheme: TypingIndicatorThemeData(dotColor: brandBlue)),
///     ],
///   ),
/// )
/// ```
///
/// Narrow it to a subtree with [TypingIndicatorTheme]. [copyWith] cannot unset
/// a field — a `null` argument keeps the current value.
@immutable
class TypingIndicatorThemeData with Diagnosticable {
  /// Creates a [TypingIndicatorThemeData].
  const TypingIndicatorThemeData({
    this.textStyle,
    this.dotColor,
    this.dotSize,
    this.dotSpacing,
  }) : assert(dotSize == null || dotSize >= 0, 'dotSize must not be negative'),
       assert(dotSpacing == null || dotSpacing >= 0, 'dotSpacing must not be negative');

  /// The caption's style, merged over the Stream theme's `bodyDefault` in
  /// `textSecondary`.
  final TextStyle? textStyle;

  /// The dots' color. Defaults to the resolved [textStyle]'s color, so the dots
  /// always match the caption.
  final Color? dotColor;

  /// The diameter of each dot. Defaults to [StreamTypingIndicatorDots]'.
  final double? dotSize;

  /// The gap between two dots. Defaults to [StreamTypingIndicatorDots]'.
  final double? dotSpacing;

  /// Returns a copy with the given fields replaced. A `null` argument keeps the
  /// current value.
  TypingIndicatorThemeData copyWith({
    TextStyle? textStyle,
    Color? dotColor,
    double? dotSize,
    double? dotSpacing,
  }) {
    return TypingIndicatorThemeData(
      textStyle: textStyle ?? this.textStyle,
      dotColor: dotColor ?? this.dotColor,
      dotSize: dotSize ?? this.dotSize,
      dotSpacing: dotSpacing ?? this.dotSpacing,
    );
  }

  /// Returns this theme with [other]'s set fields layered on top — what makes a
  /// partial override partial. Like every other field, a set [textStyle]
  /// replaces this one's rather than merging into it.
  TypingIndicatorThemeData merge(TypingIndicatorThemeData? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      textStyle: other.textStyle,
      dotColor: other.dotColor,
      dotSize: other.dotSize,
      dotSpacing: other.dotSpacing,
    );
  }

  /// Linearly interpolates between two [TypingIndicatorThemeData]s. Runs on
  /// every theme animation, including a light/dark switch.
  static TypingIndicatorThemeData lerp(TypingIndicatorThemeData a, TypingIndicatorThemeData b, double t) {
    if (identical(a, b)) return a;
    return TypingIndicatorThemeData(
      textStyle: lerpTextStyleOrSwap(a.textStyle, b.textStyle, t),
      dotColor: lerpColorOrSwap(a.dotColor, b.dotColor, t),
      dotSize: lerpDoubleOrSwap(a.dotSize, b.dotSize, t),
      dotSpacing: lerpDoubleOrSwap(a.dotSpacing, b.dotSpacing, t),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<TextStyle>('textStyle', textStyle, defaultValue: null))
      ..add(ColorProperty('dotColor', dotColor, defaultValue: null))
      ..add(DoubleProperty('dotSize', dotSize, defaultValue: null))
      ..add(DoubleProperty('dotSpacing', dotSpacing, defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TypingIndicatorThemeData &&
        other.textStyle == textStyle &&
        other.dotColor == dotColor &&
        other.dotSize == dotSize &&
        other.dotSpacing == dotSpacing;
  }

  @override
  int get hashCode => Object.hash(textStyle, dotColor, dotSize, dotSpacing);
}

/// Overrides the typing indicator theme for the widgets below it.
///
/// Layers [data] over the ambient [AITheme], so a scope setting only a color
/// leaves everything else alone:
///
/// ```dart
/// TypingIndicatorTheme(
///   data: const TypingIndicatorThemeData(dotColor: Colors.teal),
///   child: const AITypingIndicatorView(text: 'Thinking'),
/// )
/// ```
///
/// Nesting one inside another replaces rather than layers, the way [IconTheme]
/// does; use [TypingIndicatorTheme.merge] to add to an enclosing scope instead.
class TypingIndicatorTheme extends InheritedTheme {
  /// Creates a [TypingIndicatorTheme].
  const TypingIndicatorTheme({super.key, required this.data, required super.child});

  /// A scope layering [data] over the enclosing [TypingIndicatorTheme] rather
  /// than replacing it. Use it wherever a scope may already be above you.
  static Widget merge({Key? key, required TypingIndicatorThemeData data, required Widget child}) => Builder(
    builder: (context) {
      // The enclosing scope, not [of]'s result, which would make `data` a full
      // snapshot of [AITheme] instead of the overrides it documents.
      final outer = context.dependOnInheritedWidgetOfExactType<TypingIndicatorTheme>()?.data;
      return TypingIndicatorTheme(key: key, data: outer?.merge(data) ?? data, child: child);
    },
  );

  /// The overrides applied to the subtree.
  final TypingIndicatorThemeData data;

  /// The typing indicator theme at [context]: the nearest
  /// [TypingIndicatorTheme] layered over [AITheme]'s.
  ///
  /// Depends on both, so indicators rebuild when either changes. Never `null`;
  /// with neither present every field is `null` and takes its default.
  static TypingIndicatorThemeData of(BuildContext context) {
    final local = context.dependOnInheritedWidgetOfExactType<TypingIndicatorTheme>();
    return AITheme.of(context).typingIndicatorTheme.merge(local?.data);
  }

  @override
  Widget wrap(BuildContext context, Widget child) => TypingIndicatorTheme(data: data, child: child);

  @override
  bool updateShouldNotify(TypingIndicatorTheme oldWidget) => oldWidget.data != data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TypingIndicatorThemeData>('data', data));
  }
}
