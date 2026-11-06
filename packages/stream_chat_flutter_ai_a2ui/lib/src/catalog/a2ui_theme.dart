import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Overrides for the look of a reply's A2UI: the colors, fonts and corners its
/// components are drawn with.
///
/// Every field is nullable, and `null` means "use the default", which derives
/// from the app's Stream theme ([StreamTheme]) at build time, so one instance
/// covers light and dark mode. Without any overrides, A2UI looks like the rest
/// of the conversation.
///
/// ```dart
/// A2UITheme(
///   data: A2UIThemeData(accent: const Color(0xFFE65100), cornerRadius: 8),
///   child: child,
/// )
/// ```
///
/// [copyWith] cannot unset a field: a `null` argument keeps the current value.
@immutable
class A2UIThemeData with Diagnosticable {
  /// Creates an [A2UIThemeData].
  ///
  /// The [headings], when given, are the styles of headings from level 1
  /// down, at least one. The theme keeps its own copy of them.
  A2UIThemeData({
    this.accent,
    this.onAccent,
    this.text,
    this.secondaryText,
    this.surface,
    this.subtleSurface,
    this.border,
    this.error,
    this.warning,
    this.body,
    this.caption,
    this.label,
    List<TextStyle>? headings,
    this.cornerRadius,
    this.buttonCornerRadius,
    this.controlCornerRadius,
  }) : assert(headings == null || headings.isNotEmpty, 'An A2UIThemeData needs at least one heading style.'),
       headings = headings == null ? null : List.unmodifiable(headings);

  /// An [A2UIThemeData] that overrides nothing.
  const A2UIThemeData.empty()
    : accent = null,
      onAccent = null,
      text = null,
      secondaryText = null,
      surface = null,
      subtleSurface = null,
      border = null,
      error = null,
      warning = null,
      body = null,
      caption = null,
      label = null,
      headings = null,
      cornerRadius = null,
      buttonCornerRadius = null,
      controlCornerRadius = null;

  /// The color of primary buttons, selected options and the active parts of
  /// controls, such as the selected tab. Defaults to the Stream theme's
  /// `accentPrimary`.
  final Color? accent;

  /// The color of text and icons on [accent], such as a primary button's
  /// title. Defaults to `textOnAccent`.
  final Color? onAccent;

  /// The color of text and icons. Defaults to `textPrimary`.
  final Color? text;

  /// The color of captions, labels and other quieter text. Defaults to
  /// `textSecondary`.
  final Color? secondaryText;

  /// The background of cards. Defaults to `backgroundSurfaceCard`.
  final Color? surface;

  /// The background of buttons, fields and options, and of images while they
  /// load. Defaults to `backgroundSurface`.
  final Color? subtleSurface;

  /// The color of dividers and outlines. Defaults to `borderDefault`.
  final Color? border;

  /// The color of a field's errors. Defaults to `accentError`.
  final Color? error;

  /// The color of a field's warnings. Defaults to `accentWarning`.
  final Color? warning;

  /// The style of text. Defaults to `bodyDefault`, drawn in [text].
  final TextStyle? body;

  /// The style of A2UI's captions, such as text in the `caption` variant, and
  /// of a field's messages. Defaults to `metadataDefault`, drawn in
  /// [secondaryText].
  final TextStyle? caption;

  /// The style of labels, such as tab titles and a field's label. Defaults to
  /// `captionDefault`.
  final TextStyle? label;

  /// The styles of headings in text, from level 1 down. Defaults to the
  /// Stream theme's `headingLg`, `headingMd`, `headingSm` and `headingXs`.
  ///
  /// A level deeper than it has uses the last one.
  final List<TextStyle>? headings;

  /// The corner radius of cards. Defaults to the Stream theme's `xl` radius.
  final double? cornerRadius;

  /// The corner radius of buttons. Defaults to the Stream theme's `max`
  /// radius, which fully rounds them.
  final double? buttonCornerRadius;

  /// The corner radius of fields, images and players. Defaults to the Stream
  /// theme's `xl` radius.
  final double? controlCornerRadius;

  /// Returns a copy with the given fields replaced. A `null` argument keeps the
  /// current value.
  A2UIThemeData copyWith({
    Color? accent,
    Color? onAccent,
    Color? text,
    Color? secondaryText,
    Color? surface,
    Color? subtleSurface,
    Color? border,
    Color? error,
    Color? warning,
    TextStyle? body,
    TextStyle? caption,
    TextStyle? label,
    List<TextStyle>? headings,
    double? cornerRadius,
    double? buttonCornerRadius,
    double? controlCornerRadius,
  }) {
    return A2UIThemeData(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      text: text ?? this.text,
      secondaryText: secondaryText ?? this.secondaryText,
      surface: surface ?? this.surface,
      subtleSurface: subtleSurface ?? this.subtleSurface,
      border: border ?? this.border,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      body: body ?? this.body,
      caption: caption ?? this.caption,
      label: label ?? this.label,
      headings: headings ?? this.headings,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      buttonCornerRadius: buttonCornerRadius ?? this.buttonCornerRadius,
      controlCornerRadius: controlCornerRadius ?? this.controlCornerRadius,
    );
  }

  /// Returns this theme with [other]'s set fields layered on top. Like every
  /// other field, a set text style replaces this one's rather than merging
  /// into it.
  A2UIThemeData merge(A2UIThemeData? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      accent: other.accent,
      onAccent: other.onAccent,
      text: other.text,
      secondaryText: other.secondaryText,
      surface: other.surface,
      subtleSurface: other.subtleSurface,
      border: other.border,
      error: other.error,
      warning: other.warning,
      body: other.body,
      caption: other.caption,
      label: other.label,
      headings: other.headings,
      cornerRadius: other.cornerRadius,
      buttonCornerRadius: other.buttonCornerRadius,
      controlCornerRadius: other.controlCornerRadius,
    );
  }

  /// Linearly interpolates between two [A2UIThemeData]s.
  ///
  /// A field only one side sets switches at the midpoint, since `null` means
  /// "use the default" rather than zero or transparent. Heading lists of the
  /// same length are interpolated style by style; others switch too.
  static A2UIThemeData lerp(A2UIThemeData a, A2UIThemeData b, double t) {
    if (identical(a, b)) return a;
    return A2UIThemeData(
      accent: _lerpColor(a.accent, b.accent, t),
      onAccent: _lerpColor(a.onAccent, b.onAccent, t),
      text: _lerpColor(a.text, b.text, t),
      secondaryText: _lerpColor(a.secondaryText, b.secondaryText, t),
      surface: _lerpColor(a.surface, b.surface, t),
      subtleSurface: _lerpColor(a.subtleSurface, b.subtleSurface, t),
      border: _lerpColor(a.border, b.border, t),
      error: _lerpColor(a.error, b.error, t),
      warning: _lerpColor(a.warning, b.warning, t),
      body: _lerpStyle(a.body, b.body, t),
      caption: _lerpStyle(a.caption, b.caption, t),
      label: _lerpStyle(a.label, b.label, t),
      headings: _lerpHeadings(a.headings, b.headings, t),
      cornerRadius: _lerpDouble(a.cornerRadius, b.cornerRadius, t),
      buttonCornerRadius: _lerpDouble(a.buttonCornerRadius, b.buttonCornerRadius, t),
      controlCornerRadius: _lerpDouble(a.controlCornerRadius, b.controlCornerRadius, t),
    );
  }

  static T? _swap<T>(T? a, T? b, double t) => t < 0.5 ? a : b;

  static Color? _lerpColor(Color? a, Color? b, double t) =>
      a != null && b != null ? Color.lerp(a, b, t) : _swap(a, b, t);

  static TextStyle? _lerpStyle(TextStyle? a, TextStyle? b, double t) =>
      a != null && b != null ? TextStyle.lerp(a, b, t) : _swap(a, b, t);

  static double? _lerpDouble(double? a, double? b, double t) =>
      a != null && b != null ? lerpDouble(a, b, t) : _swap(a, b, t);

  static List<TextStyle>? _lerpHeadings(List<TextStyle>? a, List<TextStyle>? b, double t) {
    if (a == null || b == null || a.length != b.length) return _swap(a, b, t);
    return [for (var i = 0; i < a.length; i++) TextStyle.lerp(a[i], b[i], t)!];
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('accent', accent, defaultValue: null))
      ..add(ColorProperty('onAccent', onAccent, defaultValue: null))
      ..add(ColorProperty('text', text, defaultValue: null))
      ..add(ColorProperty('secondaryText', secondaryText, defaultValue: null))
      ..add(ColorProperty('surface', surface, defaultValue: null))
      ..add(ColorProperty('subtleSurface', subtleSurface, defaultValue: null))
      ..add(ColorProperty('border', border, defaultValue: null))
      ..add(ColorProperty('error', error, defaultValue: null))
      ..add(ColorProperty('warning', warning, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('body', body, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('caption', caption, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('label', label, defaultValue: null))
      ..add(IterableProperty<TextStyle>('headings', headings, defaultValue: null))
      ..add(DoubleProperty('cornerRadius', cornerRadius, defaultValue: null))
      ..add(DoubleProperty('buttonCornerRadius', buttonCornerRadius, defaultValue: null))
      ..add(DoubleProperty('controlCornerRadius', controlCornerRadius, defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is A2UIThemeData &&
        other.accent == accent &&
        other.onAccent == onAccent &&
        other.text == text &&
        other.secondaryText == secondaryText &&
        other.surface == surface &&
        other.subtleSurface == subtleSurface &&
        other.border == border &&
        other.error == error &&
        other.warning == warning &&
        other.body == body &&
        other.caption == caption &&
        other.label == label &&
        listEquals(other.headings, headings) &&
        other.cornerRadius == cornerRadius &&
        other.buttonCornerRadius == buttonCornerRadius &&
        other.controlCornerRadius == controlCornerRadius;
  }

  @override
  int get hashCode => Object.hash(
    accent,
    onAccent,
    text,
    secondaryText,
    surface,
    subtleSurface,
    border,
    error,
    warning,
    body,
    caption,
    label,
    headings == null ? null : Object.hashAll(headings!),
    cornerRadius,
    buttonCornerRadius,
    controlCornerRadius,
  );
}

/// Overrides the A2UI theme for the widgets below it.
///
/// A reply's A2UI reads its look from the nearest [A2UITheme], and takes each
/// value it doesn't set from the app's Stream theme:
///
/// ```dart
/// A2UITheme(
///   data: A2UIThemeData(cornerRadius: 8),
///   child: child,
/// )
/// ```
///
/// Nesting one inside another replaces rather than layers, the way [IconTheme]
/// does; use [A2UITheme.merge] to add to an enclosing scope instead.
class A2UITheme extends InheritedTheme {
  /// Creates an [A2UITheme].
  const A2UITheme({super.key, required this.data, required super.child});

  /// A scope layering [data] over the enclosing [A2UITheme] rather than
  /// replacing it.
  static Widget merge({Key? key, required A2UIThemeData data, required Widget child}) => Builder(
    builder: (context) {
      final outer = context.dependOnInheritedWidgetOfExactType<A2UITheme>()?.data;
      return A2UITheme(key: key, data: outer?.merge(data) ?? data, child: child);
    },
  );

  /// The overrides applied to the subtree.
  final A2UIThemeData data;

  /// The A2UI theme at [context]: the overrides of the nearest [A2UITheme].
  ///
  /// Never `null`; with no [A2UITheme] above, every field is `null` and takes
  /// its default. A builder of a surface's catalog reads the theme the surface
  /// is drawn with, and resolves the fields it leaves unset from the Stream
  /// theme, as the basic components do:
  ///
  /// ```dart
  /// final border = A2UITheme.of(context).border ?? context.streamColorScheme.borderDefault;
  /// ```
  static A2UIThemeData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<A2UITheme>()?.data ?? const A2UIThemeData.empty();
  }

  @override
  Widget wrap(BuildContext context, Widget child) => A2UITheme(data: data, child: child);

  @override
  bool updateShouldNotify(A2UITheme oldWidget) => oldWidget.data != data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<A2UIThemeData>('data', data));
  }
}
