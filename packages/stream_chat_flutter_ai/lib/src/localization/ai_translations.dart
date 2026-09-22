import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_semantics.dart';
// Here for the [ChartView] doc link below only; nothing in this file's code
// uses it.
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';

/// The user-facing strings the package renders itself.
///
/// Every string the widgets in this package draw — bar the ones a host passes
/// in, like `ChatComposer.hintText` or a `ChatOption`'s label — resolves
/// through an instance of this class. Supply one per locale with an
/// [AITranslationsDelegate] on `MaterialApp.localizationsDelegates`, or pin
/// one over a subtree with an [AITranslationsScope]. Supply neither and the
/// widgets fall back to [DefaultAITranslations] and render the English they
/// always have.
///
/// Most of these are `Tooltip` messages on icon-only buttons, which makes them
/// the only accessible label those buttons expose. Translating them is what
/// makes the composer legible to a screen reader in another locale.
///
/// **Subclass [DefaultAITranslations], not this class**, and override only the
/// strings you are changing:
///
/// ```dart
/// class DutchTranslations extends DefaultAITranslations {
///   const DutchTranslations();
///
///   @override
///   String get send => 'Verstuur';
///
///   @override
///   String clearOption(String option) => '$option wissen';
/// }
/// ```
///
/// Implementing [AITranslations] directly works, but then every string this
/// package later adds is a compile error rather than an untranslated default.
///
/// **Give your subclass a `const` constructor** and construct it as
/// `const DutchTranslations()`. A scope compares instances to decide whether
/// to notify, so a fresh instance per `build` rebuilds every dependent.
@immutable
abstract class AITranslations {
  /// Creates an [AITranslations].
  const AITranslations();

  /// The translations in force at [context] — the single lookup every widget
  /// in this package uses.
  ///
  /// Resolved in this order, first hit winning:
  ///
  /// 1. the nearest enclosing [AITranslationsScope], which is how a subtree
  ///    pins strings regardless of locale;
  /// 2. whatever an [AITranslationsDelegate] loaded for the app's current
  ///    locale, read through Flutter's [Localizations];
  /// 3. [DefaultAITranslations] — the English this package ships.
  ///
  /// A scope beats the delegates deliberately: it is placed by hand around
  /// specific widgets, so it is the more specific of the two. Nothing here
  /// throws, and every step registers [context] as a dependent, so a locale
  /// change or a swapped scope rebuilds the widgets that read it.
  static AITranslations of(BuildContext context) {
    return AITranslationsScope.maybeOf(context) ??
        Localizations.of<AITranslations>(context, AITranslations) ??
        const DefaultAITranslations();
  }

  /// Placeholder shown in the composer's empty text field.
  ///
  /// Only used when `ChatComposer.hintText` is `null` — an explicit
  /// `hintText` wins, since it is the more specific of the two.
  String get composerHint;

  /// Tooltip on the composer's send button, in both its enabled and its
  /// disabled state.
  String get send;

  /// Tooltip on the composer's stop button, shown while the AI is generating.
  String get stopGenerating;

  /// Tooltip on the dismiss button of a pending attachment's thumbnail.
  String get removeAttachment;

  /// Tooltip on the dismiss button of the selected chat option's chip, where
  /// `option` is that option's label.
  String clearOption(String option);

  /// Tooltip on the composer's leading attachment button.
  String get addPhotos;

  /// Heading of the attachment sheet's recent-photos row.
  String get photos;

  /// Label of the attachment sheet's button that opens the full photo library.
  String get allPhotos;

  /// Label of the attachment sheet's button that opens system settings, shown
  /// in place of the recent photos when photo access has been denied.
  String get allowPhotoAccess;

  /// Tooltip on the attachment sheet's camera tile.
  String get takePhoto;

  /// Tooltip on the voice-input button while it is idle.
  String get voiceInput;

  /// Tooltip on the voice-input button while a dictation session is running.
  String get stopRecording;

  /// Tooltip on a code block's copy button.
  String get copyCode;

  /// Tooltip on a code block's copy button for the two seconds after a copy,
  /// while it shows its confirmation.
  String get codeCopied;

  /// The name to use for a chart series the data didn't name. Reaches the
  /// screen as a heatmap's row label, and is read out by
  /// [chartSemanticsLabel].
  String get unnamedChartSeries;

  /// The screen-reader summary of a chart.
  ///
  /// [ChartView] paints to a canvas, so this is the only thing a reader has to
  /// go on; [ChartSemantics] carries the facts, already formatted.
  ///
  /// One method rather than a dozen phrase-sized ones, because a sentence's
  /// word order varies far more between languages than a tooltip's. Switch on
  /// [ChartSemantics.kind] and drop any clause whose fact is absent, the way
  /// [DefaultAITranslations] does.
  String chartSemanticsLabel(ChartSemantics chart);
}

/// The English strings this package ships, and what every widget renders when
/// no [AITranslationsScope] is in the tree.
///
/// Subclass to override individual strings — see [AITranslations] for the
/// idiom and for why the subclass wants a `const` constructor.
class DefaultAITranslations extends AITranslations {
  /// Creates a [DefaultAITranslations].
  const DefaultAITranslations();

  @override
  String get composerHint => 'Ask anything…';

  @override
  String get send => 'Send';

  @override
  String get stopGenerating => 'Stop generating';

  @override
  String get removeAttachment => 'Remove attachment';

  @override
  String clearOption(String option) => 'Clear $option';

  @override
  String get addPhotos => 'Add photos';

  @override
  String get photos => 'Photos';

  @override
  String get allPhotos => 'All Photos';

  @override
  String get allowPhotoAccess => 'Allow photo access';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get voiceInput => 'Voice input';

  @override
  String get stopRecording => 'Stop recording';

  @override
  String get copyCode => 'Copy code';

  @override
  String get codeCopied => 'Copied!';

  @override
  String get unnamedChartSeries => 'Series';

  @override
  String chartSemanticsLabel(ChartSemantics chart) {
    final parts = <String>[
      switch (chart.kind) {
        USpecKind.line => 'Line chart',
        USpecKind.area => 'Area chart',
        USpecKind.bar => 'Bar chart',
        USpecKind.pie => 'Pie chart',
        USpecKind.scatter => 'Scatter chart',
        USpecKind.bubble => 'Bubble chart',
        USpecKind.heatmap => 'Heatmap',
        USpecKind.histogram => 'Histogram',
      },
      if (chart.title case final title?) title,
    ];

    if (chart.isEmpty) return [...parts, 'no data'].join(', ');

    // A pie has one series and no axes, and a histogram's x axis is the buckets
    // it derived rather than anything the data named.
    if (chart.kind != USpecKind.pie && chart.kind != USpecKind.histogram) {
      if (chart.xLabel case final label?) parts.add('$label on the x axis');
      if (chart.yLabel case final label?) parts.add('$label on the y axis');
      // Skipped for one series, whose name almost always repeats the title or
      // the y label, and for a heatmap, whose series *are* its rows and are
      // named as such below.
      if (chart.seriesNames.length > 1 && chart.kind != USpecKind.heatmap) {
        parts.add('${chart.seriesNames.length} series: ${chart.seriesNames.join(', ')}');
      }
    }

    switch (chart.kind) {
      case USpecKind.pie:
        parts.add(_count(chart.pointCount, 'slice'));
        if (chart.largestSliceLabel case final label? when chart.largestSlicePercent != null) {
          parts.add('largest $label at ${chart.largestSlicePercent} percent');
        }
      case USpecKind.bar:
        parts
          ..add(_count(chart.categoryCount, 'category', plural: 'categories'))
          ..add(_range(chart));
      case USpecKind.histogram:
        parts
          ..add(_count(chart.pointCount, 'sample'))
          ..add(_range(chart));
      case USpecKind.heatmap:
        // A heatmap rarely names its axes, and the painted row and column
        // labels are excluded from the tree — so naming them here is the only
        // way a reader learns the rows are Mon and Tue, not just that there
        // are two.
        parts
          ..add('${_count(chart.rowCount, 'row')} by ${_count(chart.columnCount, 'column')}')
          ..add('rows: ${chart.seriesNames.join(', ')}')
          ..add('columns: ${chart.columnLabels.join(', ')}')
          ..add(_range(chart));
      case USpecKind.line || USpecKind.area || USpecKind.scatter || USpecKind.bubble:
        parts
          ..add(_count(chart.pointCount, 'point'))
          ..add(_range(chart));
        // Null for everything but a bubble — see [ChartSemantics.sizeMin].
        if (chart.sizeMin case final min?) parts.add('sizes $min to ${chart.sizeMax}');
    }

    return parts.join(', ');
  }

  static String _range(ChartSemantics chart) => 'values ${chart.valueMin} to ${chart.valueMax}';

  /// `'1 row'`, `'4 columns'`. English pluralization, which a subclass replaces
  /// along with the rest of the sentence.
  static String _count(int count, String singular, {String? plural}) =>
      '$count ${count == 1 ? singular : plural ?? '${singular}s'}';
}

/// Provides [translations] to the widgets below it.
///
/// ```dart
/// AITranslationsScope(
///   translations: const DutchTranslations(),
///   child: ChatComposer(onSendPressed: ...),
/// )
/// ```
///
/// Use this to pin strings over part of the tree — a screen that is always in
/// one language, a preview, a test. To translate the whole app by locale,
/// register an [AITranslationsDelegate] instead and leave the scope out.
///
/// Widgets read it through [AITranslations.of], where a scope outranks the
/// locale's delegate, and neither is required: without either, the English
/// defaults render.
///
/// **Where to put it.** Anywhere above the widgets whose strings it should
/// cover — a single scope above the app's `MaterialApp` covers the lot.
/// Placed lower, directly above a `ChatComposer` say, it still reaches the
/// attachment sheet and anything else the package shows in a route of its own:
/// this is an [InheritedTheme], so `showModalBottomSheet`, `showDialog` and
/// `showMenu` carry it across the [Navigator] for you, as they do a `Theme`. The
/// one thing to know is that they *capture* it at push time, so a scope
/// swapped while such a route is already open does not reach it until the
/// route is reopened.
class AITranslationsScope extends InheritedTheme {
  /// Creates an [AITranslationsScope].
  const AITranslationsScope({super.key, required this.translations, required super.child});

  /// The strings made available to the subtree.
  ///
  /// Should be a `const` instance — see [AITranslations] for why.
  final AITranslations translations;

  /// The nearest enclosing scope's [translations], or `null` when there is no
  /// scope above [context].
  ///
  /// This consults *only* the scope. Widgets want [AITranslations.of], which
  /// falls through to the locale's delegate and then to the English defaults.
  ///
  /// Registers [context] as a dependent where a scope is found, so it rebuilds
  /// when that scope's value changes. Where none is found there is nothing to
  /// depend on — but inserting one later rebuilds the subtree anyway, so a
  /// `null` here is not an answer that can go stale.
  static AITranslations? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AITranslationsScope>()?.translations;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return AITranslationsScope(translations: translations, child: child);
  }

  @override
  bool updateShouldNotify(AITranslationsScope oldWidget) => oldWidget.translations != translations;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AITranslations>('translations', translations));
  }
}

/// Supplies [AITranslations] per locale, through Flutter's own localization
/// machinery.
///
/// Register it on `MaterialApp.localizationsDelegates` alongside the Flutter
/// ones and list the locales in `supportedLocales`; Flutter then resolves the
/// app's locale and hands every widget in this package the matching instance,
/// including inside routes it pushes, and reacts to a locale change on its
/// own:
///
/// ```dart
/// MaterialApp(
///   localizationsDelegates: const [
///     AITranslationsDelegate({
///       'nl': DutchTranslations(),
///       'de': GermanTranslations(),
///     }),
///     GlobalMaterialLocalizations.delegate,
///     GlobalWidgetsLocalizations.delegate,
///   ],
///   supportedLocales: const [Locale('en'), Locale('nl'), Locale('de')],
///   home: ...,
/// )
/// ```
///
/// English needs no entry: a locale this delegate does not carry renders
/// [DefaultAITranslations], so registering it is safe long before a
/// translation exists for every locale the app supports.
///
/// This adds no dependency — [LocalizationsDelegate] is part of
/// `package:flutter/widgets.dart`. `GlobalMaterialLocalizations` above comes
/// from `flutter_localizations`, which a host translating the rest of its app
/// will already have.
class AITranslationsDelegate extends LocalizationsDelegate<AITranslations> {
  /// Creates an [AITranslationsDelegate] serving [translations].
  const AITranslationsDelegate(this.translations);

  /// The translations to serve, keyed by the locale each is written for.
  ///
  /// Keys are `Locale.toString()`'s form: a language code (`'nl'`), or a
  /// language and country joined by an underscore (`'pt_BR'`) — not the
  /// hyphenated BCP-47 form. Case included: lowercase language, uppercase
  /// country, as [Locale] matches its subtags verbatim. A debug-only check
  /// rejects anything else rather than leaving it to fall back to English
  /// unexplained.
  ///
  /// Keyed by `String` rather than by [Locale] so the map, and with it the
  /// whole delegate, can be `const`: [Locale] overrides `==`, and Dart does
  /// not allow such a type as a `const` map key. `const` instances matter here
  /// for the reason given on [AITranslations].
  final Map<String, AITranslations> translations;

  /// The entry for [locale]: the exact `language_COUNTRY` match if
  /// [translations] has one, otherwise the entry for the bare language code,
  /// otherwise `null`.
  ///
  /// So a single `'pt'` entry serves `pt_BR` and `pt_PT`, while a `'pt_BR'`
  /// entry serves only Brazilian Portuguese. [load] turns the `null` case into
  /// [DefaultAITranslations], so `null` here means "nothing registered", never
  /// "no strings available".
  ///
  /// Throws in debug if [translations] holds a key that is not a locale key.
  /// That is a different failure from `null`: a malformed key can never match
  /// any locale, so returning `null` for it would report "you did not
  /// translate this locale" for a locale that *was* translated, under a key
  /// with a typo in it.
  AITranslations? resolve(Locale locale) {
    assert(() {
      for (final key in translations.keys) {
        if (!_localeKey.hasMatch(key)) {
          throw FlutterError(
            "AITranslationsDelegate was given the key '$key', which is not a locale key.\n"
            "Keys take Locale.toString()'s form — a lowercase language code such as 'nl', "
            "optionally followed by a script and an uppercase country, as in 'pt_BR' and "
            "'zh_Hant_TW'. Case counts: 'NL' is a different string from 'nl', and Locale never "
            'normalizes it. A key in any other shape can never match a locale, so those widgets '
            'would silently render English.',
          );
        }
      }
      return true;
    }(), 'AITranslationsDelegate keys must be locale keys.');

    return translations[locale.toString()] ?? translations[locale.languageCode];
  }

  /// Always `true`: a locale [translations] has no entry for is served the
  /// English defaults rather than refused.
  ///
  /// Claiming every locale is deliberate. `WidgetsApp` warns, loudly and in
  /// debug, when any `supportedLocales` entry is unsupported by any one
  /// delegate — so reporting honestly here would put a warning in the console
  /// of every app that supports more locales than it has translated this
  /// package into, which is every app that adds this delegate first and
  /// translates later. Use [resolve] to ask what is actually registered.
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AITranslations> load(Locale locale) {
    // Synchronous: the strings are already in memory, and an asynchronous
    // future here would leave the first frame after a locale change rendering
    // the previous locale's strings.
    return SynchronousFuture<AITranslations>(resolve(locale) ?? const DefaultAITranslations());
  }

  @override
  bool shouldReload(AITranslationsDelegate old) => !mapEquals(old.translations, translations);

  @override
  String toString() => 'AITranslationsDelegate(${translations.keys.join(', ')})';
}

/// The shape [AITranslationsDelegate.translations]'s keys have to take:
/// `nl`, `pt_BR`, `zh_Hant`, `zh_Hant_TW`, `es_419`.
///
/// Mirrors what `Locale.toString()` can produce — a language, then an optional
/// script, then an optional region. Case is part of the shape: [Locale] never
/// normalizes it, so `'NL'` is as unmatchable a key as `'nl-NL'` is.
final _localeKey = RegExp(r'^[a-z]{2,8}(_[A-Z][a-z]{3})?(_([A-Z]{2}|\d{3}))?$');
