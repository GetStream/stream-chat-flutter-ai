import 'package:meta/meta.dart';

/// The texts the components draw that the agent didn't write.
///
/// Internal to the package; English only until the package is localized.
@internal
abstract final class OpenUIStrings {
  /// The title of a card's sources.
  static const sourcesTitle = 'Sources';

  /// What a source without a title is called.
  static const untitledSource = 'Untitled';

  /// What closes the gallery's preview.
  static const done = 'Done';

  /// What a rising [value] reads as.
  static String trendUp(String value) => 'Up $value';

  /// What a falling [value] reads as.
  static String trendDown(String value) => 'Down $value';
}
