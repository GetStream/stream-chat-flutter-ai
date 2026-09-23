import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/composer_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/suggestions_theme.dart';

/// The package's overrides on the ambient Material theme, registered as a
/// [ThemeExtension].
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       AITheme(
///         chartTheme: ChartThemeData(seriesColors: brandPalette),
///         composerTheme: ComposerThemeData(sendButtonColor: brandBlue),
///       ),
///     ],
///   ),
/// )
/// ```
///
/// Overrides, not a design system: no brightness, color scheme or typography of
/// its own, so one instance covers light and dark. Note [ThemeData.copyWith]
/// replaces the whole extension set, so an app with other extensions has to
/// re-list them.
///
/// Every component theme defaults to an all-null instance, which derives each
/// field from the ambient [ThemeData] — registering no extension at all gets
/// the appearance the package always had.
///
/// See also:
///
///  * [ChartThemeData] and [ChartTheme], for charts.
///  * [ComposerThemeData] and [ComposerTheme], for the composer and its
///    attachment sheet.
///  * [SuggestionsThemeData] and [SuggestionsTheme], for the suggestion chips.
@immutable
class AITheme extends ThemeExtension<AITheme> {
  /// Creates an [AITheme].
  const AITheme({
    ChartThemeData? chartTheme,
    ComposerThemeData? composerTheme,
    SuggestionsThemeData? suggestionsTheme,
  }) : chartTheme = chartTheme ?? const ChartThemeData(),
       composerTheme = composerTheme ?? const ComposerThemeData(),
       suggestionsTheme = suggestionsTheme ?? const SuggestionsThemeData();

  /// How charts are drawn. Defaults to `const ChartThemeData()`, which derives
  /// every field from the ambient [ThemeData].
  final ChartThemeData chartTheme;

  /// How the composer and its attachment sheet are drawn. Defaults to
  /// `const ComposerThemeData()`, which derives every field from the ambient
  /// [ThemeData].
  final ComposerThemeData composerTheme;

  /// How suggestion chips are drawn. Defaults to
  /// `const SuggestionsThemeData()`, which derives every field from the ambient
  /// [ThemeData].
  final SuggestionsThemeData suggestionsTheme;

  /// The [AITheme] on the ambient [ThemeData], or a default one.
  ///
  /// Never null and never throws — registering no extension gets the appearance
  /// the package always had, which is what makes theming opt-in.
  static AITheme of(BuildContext context) => Theme.of(context).extension<AITheme>() ?? const AITheme();

  @override
  AITheme copyWith({
    ChartThemeData? chartTheme,
    ComposerThemeData? composerTheme,
    SuggestionsThemeData? suggestionsTheme,
  }) => AITheme(
    chartTheme: chartTheme ?? this.chartTheme,
    composerTheme: composerTheme ?? this.composerTheme,
    suggestionsTheme: suggestionsTheme ?? this.suggestionsTheme,
  );

  @override
  AITheme lerp(covariant AITheme? other, double t) {
    if (other == null || identical(this, other)) return this;
    return AITheme(
      chartTheme: ChartThemeData.lerp(chartTheme, other.chartTheme, t),
      composerTheme: ComposerThemeData.lerp(composerTheme, other.composerTheme, t),
      suggestionsTheme: SuggestionsThemeData.lerp(suggestionsTheme, other.suggestionsTheme, t),
    );
  }

  // Load-bearing: ThemeData.== compares extensions with mapEquals, so without
  // this every rebuild of an identical ThemeData compares unequal and restarts
  // the theme interpolation.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AITheme &&
        other.chartTheme == chartTheme &&
        other.composerTheme == composerTheme &&
        other.suggestionsTheme == suggestionsTheme;
  }

  @override
  int get hashCode => Object.hash(chartTheme, composerTheme, suggestionsTheme);
}
