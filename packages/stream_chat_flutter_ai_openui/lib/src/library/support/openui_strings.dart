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

  /// What a select shows before an option is chosen.
  static const selectPlaceholder = 'Select...';

  /// The labels of a date range's rows and of a single date's row.
  static const dateFrom = 'From';

  /// See [dateFrom].
  static const dateTo = 'To';

  /// See [dateFrom].
  static const date = 'Date';

  /// What picks a date that isn't set yet.
  static const chooseDate = 'Choose';

  /// What the lower thumb of the range slider labelled [label] reads as.
  static String sliderLower(String label) => '$label, minimum';

  /// What the upper thumb of the range slider labelled [label] reads as.
  static String sliderUpper(String label) => '$label, maximum';

  /// What an open section reads as.
  static const expanded = 'Expanded';

  /// What a closed section reads as.
  static const collapsed = 'Collapsed';

  /// What shows the previous page of a table.
  static const previousPage = 'Previous page';

  /// What shows the next page of a table.
  static const nextPage = 'Next page';

  /// The page [page] of [pages] of a table, as shown.
  static String pagePosition(int page, int pages) => '$page / $pages';

  /// The page [page] of [pages] of a table, as read.
  static String pagePositionLabel(int page, int pages) => 'Page $page of $pages';

  /// What shows the previous slide of a carousel.
  static const previousSlide = 'Previous slide';

  /// What shows the next slide of a carousel.
  static const nextSlide = 'Next slide';

  /// The slide [slide] of [slides] of a carousel, as read.
  static String slidePosition(int slide, int slides) => 'Slide $slide of $slides';

  /// What a table whose rows are loading reads as.
  static const loading = 'Loading';

  /// What puts an editable table's cells back as they were.
  static const reset = 'Reset';

  /// What saves an editable table's changes, and the label of the action it
  /// runs.
  static const saveChanges = 'Save Changes';

  /// How many cells of an editable table changed.
  static String changes(int count) => count == 1 ? '1 change' : '$count changes';

  /// What a card block's item [index] (from 1) of the kind [kind], such as
  /// `Snippet`, is sent as when it has no title.
  static String cardItem(String kind, int index) => '$kind card $index';
}
