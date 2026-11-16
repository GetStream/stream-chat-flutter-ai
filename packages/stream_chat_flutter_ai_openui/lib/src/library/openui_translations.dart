import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_number_format.dart';

/// The texts OpenUI components draw or read out that the agent didn't write.
///
/// Every such text resolves through an instance of this class: the labels
/// of pickers, tables, carousels and sources, what screen readers announce
/// for controls without a visible label, and the errors of a form's
/// `rules`. One is supplied per locale with an [OpenUITranslationsDelegate]
/// on `MaterialApp.localizationsDelegates`, or pinned over a subtree with an
/// [OpenUITranslationsScope]. Without either, the components fall back to
/// [DefaultOpenUITranslations], in English.
///
/// Numbers, such as a form rule's limit or a metric's trend, reach a
/// translation as numbers, and it formats them as its language needs, for
/// example with `intl`'s `NumberFormat`. [DefaultOpenUITranslations] writes
/// them as the program does, such as `1500` and `12.5`.
///
/// The texts of the components `stream_chat_flutter_ai` draws, such as a
/// code block's copy button, come from its `AITranslations`.
///
/// **Consider implementing this class**, rather than extending
/// [DefaultOpenUITranslations]:
///
/// ```dart
/// class DutchOpenUITranslations implements OpenUITranslations {
///   const DutchOpenUITranslations();
///
///   @override
///   String get sourcesTitle => 'Bronnen';
///
///   // ...and every other text.
/// }
/// ```
///
/// That way a text this package adds later is a compile error that points at
/// something new to translate, instead of English showing up in the app.
/// Adding a text is not considered a breaking change.
///
/// **Consider a `const` constructor**, with the class constructed as
/// `const DutchOpenUITranslations()`: a scope compares instances to decide
/// whether to notify, so a new instance on every build rebuilds every
/// component that reads it.
@immutable
abstract class OpenUITranslations {
  /// Creates an [OpenUITranslations].
  const OpenUITranslations();

  /// The translations in force at [context].
  ///
  /// The first of these wins:
  ///
  /// 1. the nearest enclosing [OpenUITranslationsScope];
  /// 2. what an [OpenUITranslationsDelegate] loaded for the app's locale, read
  ///    through Flutter's [Localizations];
  /// 3. [DefaultOpenUITranslations].
  ///
  /// A scope beats the delegate because it is placed by hand around specific
  /// widgets. Widgets that call this rebuild when the app's locale changes or
  /// the scope's translations change.
  static OpenUITranslations of(BuildContext context) {
    if (OpenUITranslationsScope.maybeOf(context) case final scoped?) return scoped;
    if (Localizations.of<OpenUITranslations>(context, OpenUITranslations) case final localized?) return localized;
    return const DefaultOpenUITranslations();
  }

  /// The title of a card's sources.
  String get sourcesTitle;

  /// What a source without a title is called.
  String get untitledSource;

  /// What closes an image gallery's full-screen preview.
  String get done;

  /// What a select shows before an option is chosen.
  String get selectPlaceholder;

  /// The label of the start of a date range.
  String get dateFrom;

  /// The label of the end of a date range.
  String get dateTo;

  /// The label of a single date.
  String get date;

  /// What picks a date that isn't set yet.
  String get chooseDate;

  /// What the lower thumb of the range slider labelled [label] reads as.
  String sliderLower(String label);

  /// What the upper thumb of the range slider labelled [label] reads as.
  String sliderUpper(String label);

  /// What shows the previous page of a table.
  String get previousPage;

  /// What shows the next page of a table.
  String get nextPage;

  /// The page [page] of [pages] of a table, as shown.
  String pagePosition(int page, int pages);

  /// The page [page] of [pages] of a table, as read out.
  String pagePositionLabel(int page, int pages);

  /// What a table whose rows are loading reads as.
  String get loading;

  /// What shows the previous slide of a carousel.
  String get previousSlide;

  /// What shows the next slide of a carousel.
  String get nextSlide;

  /// The slide [slide] of [slides] of a carousel, as read out.
  String slidePosition(int slide, int slides);

  /// What puts an editable table's cells back as they were.
  String get reset;

  /// What saves an editable table's changes. It is also the label of the
  /// action that saving runs.
  String get saveChanges;

  /// How many cells of an editable table changed.
  String changes(int count);

  /// The label of the action a `SnippetCardBlock`'s item [index] (counting
  /// from 1) runs when the item has no title.
  String snippetCardItem(int index);

  /// The label of the action an `OverviewCardBlock`'s item [index] (counting
  /// from 1) runs when the item has no title.
  String overviewCardItem(int index);

  /// The label of the action a `ContextCardBlock`'s item [index] (counting
  /// from 1) runs when the item has no title.
  String contextCardItem(int index);

  /// The label of the action a `CompositeCardBlock`'s item [index] (counting
  /// from 1) runs when the item has no title.
  String compositeCardItem(int index);

  /// The label of the action a `VisualCardBlock`'s item [index] (counting
  /// from 1) runs when the item has no title.
  String visualCardItem(int index);

  /// A metric's change of [percent] percent as its trend badge shows it,
  /// such as `12.5%` for `12.5`.
  String trendPercent(num percent);

  /// What a metric that rose by [percent] percent reads as, such as
  /// `12.5`.
  String trendUp(num percent);

  /// What a metric that fell by [percent] percent reads as, such as `12.5`.
  String trendDown(num percent);

  /// The error of a field with the `required` rule that has no value.
  String get validationRequired;

  /// The error of a group of checkboxes with the `required` rule where none
  /// is ticked.
  String get validationRequiredOption;

  /// The error of a field with the `email` rule whose value isn't an email
  /// address.
  String get validationEmail;

  /// The error of a field with the `url` rule whose value isn't a URL.
  String get validationUrl;

  /// The error of a field with the `numeric` rule whose value isn't a number.
  String get validationNumeric;

  /// The error of a field whose value is below its `min` rule's [min].
  String validationMin(num min);

  /// The error of a field whose value is above its `max` rule's [max].
  String validationMax(num max);

  /// The error of a field whose value is shorter than its `minLength` rule's
  /// [min] characters.
  String validationMinLength(int min);

  /// The error of a field whose value is longer than its `maxLength` rule's
  /// [max] characters.
  String validationMaxLength(int max);
}

/// The English texts the OpenUI components ship, and what they draw when
/// neither an [OpenUITranslationsScope] nor an [OpenUITranslationsDelegate]
/// supplies others.
///
/// Consider implementing [OpenUITranslations] for other languages rather than
/// subclassing this, so a string added later is a compile error.
class DefaultOpenUITranslations extends OpenUITranslations {
  /// Creates the English translations.
  const DefaultOpenUITranslations();

  @override
  String get sourcesTitle => 'Sources';

  @override
  String get untitledSource => 'Source';

  @override
  String get done => 'Done';

  @override
  String get selectPlaceholder => 'Select...';

  @override
  String get dateFrom => 'From';

  @override
  String get dateTo => 'To';

  @override
  String get date => 'Date';

  @override
  String get chooseDate => 'Choose';

  @override
  String sliderLower(String label) => '$label, minimum';

  @override
  String sliderUpper(String label) => '$label, maximum';

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String pagePosition(int page, int pages) => '$page / $pages';

  @override
  String pagePositionLabel(int page, int pages) => 'Page $page of $pages';

  @override
  String get loading => 'Loading';

  @override
  String get previousSlide => 'Previous slide';

  @override
  String get nextSlide => 'Next slide';

  @override
  String slidePosition(int slide, int slides) => 'Slide $slide of $slides';

  @override
  String get reset => 'Reset';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String changes(int count) => count == 1 ? '1 change' : '$count changes';

  @override
  String snippetCardItem(int index) => 'Snippet card $index';

  @override
  String overviewCardItem(int index) => 'Overview card $index';

  @override
  String contextCardItem(int index) => 'Context card $index';

  @override
  String compositeCardItem(int index) => 'Composite card $index';

  @override
  String visualCardItem(int index) => 'Visual card $index';

  @override
  String trendPercent(num percent) => '${openUIPlainNumber(percent, maxDecimals: 2)}%';

  @override
  String trendUp(num percent) => 'Up ${openUIPlainNumber(percent, maxDecimals: 2)} percent';

  @override
  String trendDown(num percent) => 'Down ${openUIPlainNumber(percent, maxDecimals: 2)} percent';

  @override
  String get validationRequired => 'This field is required';

  @override
  String get validationRequiredOption => 'At least one option is required';

  @override
  String get validationEmail => 'Please enter a valid email';

  @override
  String get validationUrl => 'Please enter a valid URL';

  @override
  String get validationNumeric => 'Must be a number';

  @override
  String validationMin(num min) => 'Must be at least ${openUIPlainNumber(min)}';

  @override
  String validationMax(num max) => 'Must be no more than ${openUIPlainNumber(max)}';

  @override
  String validationMinLength(int min) => 'Must be at least $min characters';

  @override
  String validationMaxLength(int max) => 'Must be no more than $max characters';
}

/// Pins [translations] for the OpenUI components below it, whatever the
/// locale.
///
/// ```dart
/// OpenUITranslationsScope(
///   translations: const DutchOpenUITranslations(),
///   child: OpenUIView(...),
/// )
/// ```
///
/// Translating by locale is the job of an [OpenUITranslationsDelegate]
/// instead. A scope outranks the delegate. It is an [InheritedTheme], so a route the
/// components push, such as a modal's sheet, carries it as it does a `Theme`.
class OpenUITranslationsScope extends InheritedTheme {
  /// Creates an [OpenUITranslationsScope].
  const OpenUITranslationsScope({super.key, required this.translations, required super.child});

  /// The translations for the subtree; a `const` instance, see
  /// [OpenUITranslations].
  final OpenUITranslations translations;

  /// The nearest enclosing scope's [translations], or `null` when there is no
  /// scope above [context].
  ///
  /// This reads only the scope. To also fall back to the locale's delegate and
  /// then to the English defaults, consider [OpenUITranslations.of].
  static OpenUITranslations? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<OpenUITranslationsScope>()?.translations;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return OpenUITranslationsScope(translations: translations, child: child);
  }

  @override
  bool updateShouldNotify(OpenUITranslationsScope oldWidget) => oldWidget.translations != translations;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<OpenUITranslations>('translations', translations));
  }
}

/// Supplies [OpenUITranslations] per locale through Flutter's localizations.
///
/// It is registered on `MaterialApp.localizationsDelegates`, with the locales
/// listed in `supportedLocales`:
///
/// ```dart
/// MaterialApp(
///   localizationsDelegates: const [
///     OpenUITranslationsDelegate({'nl': DutchOpenUITranslations()}),
///     GlobalMaterialLocalizations.delegate,
///     GlobalWidgetsLocalizations.delegate,
///   ],
///   supportedLocales: const [Locale('en'), Locale('nl')],
///   home: ...,
/// )
/// ```
///
/// A locale without an entry gets [DefaultOpenUITranslations].
class OpenUITranslationsDelegate extends LocalizationsDelegate<OpenUITranslations> {
  /// Creates an [OpenUITranslationsDelegate] serving [translations].
  const OpenUITranslationsDelegate(this.translations);

  /// The translations to serve, keyed by locale.
  ///
  /// A key equals `Locale.toString()` of an entry of the app's
  /// `supportedLocales`, such as `'pt_BR'`, or that entry's bare language
  /// code, such as `'pt'`. A locale with a script takes the script in its key
  /// too, as `Locale.toString()` writes it: `'zh_Hant_TW'`. The hyphenated
  /// BCP-47 form, such as `'pt-BR'`, never matches, and neither does a key
  /// in another case, as [Locale] matches its subtags verbatim. A debug-only
  /// check rejects such a key rather than leaving it to fall back to English
  /// unexplained.
  final Map<String, OpenUITranslations> translations;

  /// The entry for [locale], or `null`: the exact match if [translations] has
  /// one, otherwise the entry for its language and script, then for its
  /// language and country, then for its language alone.
  ///
  /// So a single `'pt'` entry serves `pt_BR` and `pt_PT`, a `'pt_BR'` entry
  /// serves only Brazilian Portuguese, and a `'zh_Hant'` entry serves
  /// `zh_Hant_TW` too. [load] turns the `null` case into
  /// [DefaultOpenUITranslations], so `null` here means "nothing registered",
  /// never "no texts available".
  ///
  /// Throws a [FlutterError] in debug mode if [translations] holds a key that
  /// is not a locale key. That is a different failure from `null`: a
  /// malformed key can never match any locale, so returning `null` for it
  /// would report a locale as not translated when it was, under a key with a
  /// typo in it.
  OpenUITranslations? resolve(Locale locale) {
    assert(() {
      for (final key in translations.keys) {
        if (!_localeKey.hasMatch(key)) {
          throw FlutterError(
            "OpenUITranslationsDelegate was given the key '$key', which is not a locale key.\n"
            "Keys take Locale.toString()'s form, such as 'nl', 'pt_BR' and 'zh_Hant_TW'.",
          );
        }
      }
      return true;
    }(), 'OpenUITranslationsDelegate keys must be locale keys.');
    if (translations[locale.toString()] case final exact?) return exact;
    if (locale.scriptCode case final script?) {
      if (translations['${locale.languageCode}_$script'] case final scripted?) return scripted;
    }
    if (locale.countryCode case final country?) {
      if (translations['${locale.languageCode}_$country'] case final regional?) return regional;
    }
    return translations[locale.languageCode];
  }

  /// Always `true`: a locale without an entry gets the English defaults.
  ///
  /// Claiming every locale is deliberate. `WidgetsApp` warns in debug when
  /// any `supportedLocales` entry is unsupported by any one delegate, so
  /// reporting honestly here would put a warning in the console of every app
  /// that supports more locales than it has translated this package into.
  /// [resolve] tells what is actually registered.
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<OpenUITranslations> load(Locale locale) {
    // Synchronous, so the first frame after a locale change has its texts.
    return SynchronousFuture<OpenUITranslations>(resolve(locale) ?? const DefaultOpenUITranslations());
  }

  @override
  bool shouldReload(OpenUITranslationsDelegate old) => !mapEquals(old.translations, translations);

  @override
  String toString() => 'OpenUITranslationsDelegate(${translations.keys.join(', ')})';
}

// The shape [OpenUITranslationsDelegate.translations]'s keys take: `nl`,
// `pt_BR`, `zh_Hant`, `zh_Hant_TW`, `es_419`. Case counts, since [Locale]
// never normalizes it.
final _localeKey = RegExp(r'^[a-z]{2,8}(_[A-Z][a-z]{3})?(_([A-Z]{2}|\d{3}))?$');
