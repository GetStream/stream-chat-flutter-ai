import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';

/// The package's overrides on the ambient Material theme, registered as a
/// [ThemeExtension].
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [AITheme(chartTheme: ChartThemeData(seriesColors: brandPalette))],
///   ),
/// )
/// ```
///
/// Overrides, not a design system: no brightness, color scheme or typography of
/// its own, so one instance covers light and dark. Note [ThemeData.copyWith]
/// replaces the whole extension set, so an app with other extensions has to
/// re-list them.
///
/// See also:
///
///  * [ChartThemeData], the only component theme so far, and [ChartTheme] for
///    overriding it in one subtree.
@immutable
class AITheme extends ThemeExtension<AITheme> {
  /// Creates an [AITheme].
  const AITheme({ChartThemeData? chartTheme}) : chartTheme = chartTheme ?? const ChartThemeData();

  /// How charts are drawn. Defaults to `const ChartThemeData()`, which derives
  /// every field from the ambient [ThemeData].
  final ChartThemeData chartTheme;

  /// The [AITheme] on the ambient [ThemeData], or a default one.
  ///
  /// Never null and never throws — registering no extension gets the appearance
  /// the package always had, which is what makes theming opt-in.
  static AITheme of(BuildContext context) => Theme.of(context).extension<AITheme>() ?? const AITheme();

  @override
  AITheme copyWith({ChartThemeData? chartTheme}) => AITheme(chartTheme: chartTheme ?? this.chartTheme);

  @override
  AITheme lerp(covariant AITheme? other, double t) {
    if (other == null || identical(this, other)) return this;
    return AITheme(chartTheme: ChartThemeData.lerp(chartTheme, other.chartTheme, t));
  }

  // Load-bearing: ThemeData.== compares extensions with mapEquals, so without
  // this every rebuild of an identical ThemeData compares unequal and restarts
  // the theme interpolation.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AITheme && other.chartTheme == chartTheme;
  }

  @override
  int get hashCode => chartTheme.hashCode;
}
