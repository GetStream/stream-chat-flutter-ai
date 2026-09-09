import 'package:flutter/material.dart';
// Here for the doc link on [of] only; nothing in this file's code uses it.
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/chart_theme.dart';

/// The package's overrides on the ambient Material theme, registered as a
/// [ThemeExtension].
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     colorSchemeSeed: brandBlue,
///     extensions: const [AITheme(chartTheme: ChartThemeData(seriesColors: brandPalette))],
///   ),
///   ...
/// )
/// ```
///
/// **[ThemeData.copyWith] replaces the whole extension set**, so an app that
/// already registers other extensions has to re-list them:
/// `theme.copyWith(extensions: [...theme.extensions.values, const AITheme()])`.
///
/// **This is a set of overrides, not a design system.** It carries no
/// brightness, no color scheme and no typography of its own: every widget in
/// this package already resolves its colors from the ambient [ColorScheme], and
/// a second brightness here would be a second source of truth able to disagree
/// with [Theme.of]. So there is nothing to construct for light versus dark —
/// one instance covers both, and anything it leaves unset follows the app.
///
/// See also:
///
///  * [ChartThemeData], the only component theme so far, and [ChartTheme] for
///    overriding it in one subtree.
@immutable
class AITheme extends ThemeExtension<AITheme> {
  /// Creates an [AITheme].
  const AITheme({ChartThemeData? chartTheme}) : chartTheme = chartTheme ?? const ChartThemeData();

  /// How charts are drawn. Defaults to `const ChartThemeData()`, every field of
  /// which derives from the ambient [ThemeData].
  final ChartThemeData chartTheme;

  /// The [AITheme] registered on the ambient [ThemeData], or a default one.
  ///
  /// Registers [context] as a dependent of the [Theme]. Never returns `null`
  /// and never throws — a host that registers no extension gets the same
  /// appearance the package always had, which is what makes the whole thing
  /// opt-in. [AITranslations.of] takes the same line.
  static AITheme of(BuildContext context) => Theme.of(context).extension<AITheme>() ?? const AITheme();

  @override
  AITheme copyWith({ChartThemeData? chartTheme}) => AITheme(chartTheme: chartTheme ?? this.chartTheme);

  @override
  AITheme lerp(covariant AITheme? other, double t) {
    if (other == null || identical(this, other)) return this;
    return AITheme(chartTheme: ChartThemeData.lerp(chartTheme, other.chartTheme, t));
  }

  // Not ceremony: ThemeData.== compares its extensions with mapEquals, so
  // without this every rebuild of an otherwise identical ThemeData would
  // compare unequal and start a fresh interpolation.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AITheme && other.chartTheme == chartTheme;
  }

  @override
  int get hashCode => chartTheme.hashCode;
}
