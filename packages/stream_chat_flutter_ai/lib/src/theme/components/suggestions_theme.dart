import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Imported for the doc links below only; nothing in this file's code uses it.
import 'package:stream_chat_flutter_ai/src/composer/suggestions_view.dart';
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/composer_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';

/// Overrides for how [AISuggestionsView] draws its chips.
///
/// Every field is nullable, and `null` means "derive it from the ambient
/// [ThemeData]" — so a host overrides what it cares about and the rest keeps
/// following the app.
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       AITheme(suggestionsTheme: SuggestionsThemeData(backgroundColor: brandMint)),
///     ],
///   ),
/// )
/// ```
///
/// The defaults are deliberately the same tokens [ComposerThemeData] uses for
/// the input pill, since a suggestion row is normally docked directly above the
/// composer and the two should read as one surface. Override both together if
/// you are recoloring that surface.
///
/// Narrow it to a subtree with [SuggestionsTheme]. [copyWith] cannot unset a
/// field — a `null` argument keeps the current value.
@immutable
class SuggestionsThemeData {
  /// Creates a [SuggestionsThemeData].
  const SuggestionsThemeData({this.backgroundColor, this.borderColor, this.textStyle});

  /// The fill behind a chip. Falls back to [ColorScheme.surfaceContainerHigh],
  /// matching [ComposerThemeData.fillColor]'s default.
  final Color? backgroundColor;

  /// The hairline around a chip. Falls back to [ColorScheme.outlineVariant],
  /// matching [ComposerThemeData.borderColor]'s default.
  final Color? borderColor;

  /// The style of a chip's text. Falls back to the ambient [DefaultTextStyle]
  /// in [ColorScheme.onSurface].
  ///
  /// Chips are measured before they are laid out — each one shrinks to fit its
  /// own two lines — so this style is what that measurement uses. A style that
  /// changes the metrics (size, weight, font) resizes the chips accordingly
  /// rather than overflowing them.
  final TextStyle? textStyle;

  /// Returns a copy with the given fields replaced. A `null` argument keeps the
  /// current value.
  SuggestionsThemeData copyWith({Color? backgroundColor, Color? borderColor, TextStyle? textStyle}) {
    return SuggestionsThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      textStyle: textStyle ?? this.textStyle,
    );
  }

  /// Returns this theme with [other]'s set fields layered on top — what makes a
  /// partial override partial.
  SuggestionsThemeData merge(SuggestionsThemeData? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      backgroundColor: other.backgroundColor,
      borderColor: other.borderColor,
      textStyle: other.textStyle,
    );
  }

  /// Linearly interpolates between two [SuggestionsThemeData]s. Runs on every
  /// theme animation, including a light/dark switch.
  static SuggestionsThemeData lerp(SuggestionsThemeData a, SuggestionsThemeData b, double t) {
    if (identical(a, b)) return a;
    return SuggestionsThemeData(
      backgroundColor: lerpColorOrSwap(a.backgroundColor, b.backgroundColor, t),
      borderColor: lerpColorOrSwap(a.borderColor, b.borderColor, t),
      textStyle: lerpTextStyleOrSwap(a.textStyle, b.textStyle, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SuggestionsThemeData &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.textStyle == textStyle;
  }

  @override
  int get hashCode => Object.hash(backgroundColor, borderColor, textStyle);
}

/// Overrides the suggestions theme for the widgets below it.
///
/// Layers [data] over the ambient [AITheme], so a scope setting only a fill
/// leaves everything else alone:
///
/// ```dart
/// SuggestionsTheme(
///   data: const SuggestionsThemeData(backgroundColor: Colors.teal),
///   child: AISuggestionsView(suggestions: prompts, onSuggestionSelected: send),
/// )
/// ```
///
/// Nesting one inside another replaces rather than layers, the way [IconTheme]
/// does; use [SuggestionsTheme.merge] to add to an enclosing scope instead.
class SuggestionsTheme extends InheritedTheme {
  /// Creates a [SuggestionsTheme].
  const SuggestionsTheme({super.key, required this.data, required super.child});

  /// A scope layering [data] over the enclosing [SuggestionsTheme] rather than
  /// replacing it. Use it wherever a scope may already be above you.
  static Widget merge({Key? key, required SuggestionsThemeData data, required Widget child}) => Builder(
    builder: (context) {
      // The enclosing scope, not [of]'s result, which would make `data` a full
      // snapshot of [AITheme] instead of the overrides it documents.
      final outer = context.dependOnInheritedWidgetOfExactType<SuggestionsTheme>()?.data;
      return SuggestionsTheme(key: key, data: outer?.merge(data) ?? data, child: child);
    },
  );

  /// The overrides applied to the subtree.
  final SuggestionsThemeData data;

  /// The suggestions theme at [context]: the nearest [SuggestionsTheme] layered
  /// over [AITheme]'s.
  ///
  /// Depends on both, so the chips repaint when either changes. Never `null`;
  /// with neither present every field derives from the ambient [ThemeData].
  static SuggestionsThemeData of(BuildContext context) {
    final local = context.dependOnInheritedWidgetOfExactType<SuggestionsTheme>();
    return AITheme.of(context).suggestionsTheme.merge(local?.data);
  }

  @override
  Widget wrap(BuildContext context, Widget child) => SuggestionsTheme(data: data, child: child);

  @override
  bool updateShouldNotify(SuggestionsTheme oldWidget) => oldWidget.data != data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<SuggestionsThemeData>('data', data));
  }
}
