import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The user-facing strings the A2UI components draw themselves.
///
/// A reply's UI brings its own words. These are the few the components add,
/// such as the label a screen reader reads for a video's play button. Supply
/// one instance per locale with an [A2UITranslationsDelegate] on
/// `MaterialApp.localizationsDelegates`, or pin one over a subtree with an
/// [A2UITranslationsScope]. Supply neither and the components render
/// [DefaultA2UITranslations], in English.
///
/// The components' other words, such as the date a date input shows and the
/// label of a sheet's scrim, come from Flutter's `MaterialLocalizations`.
///
/// **Implement this class**, rather than extending [DefaultA2UITranslations]:
///
/// ```dart
/// class DutchA2UITranslations implements A2UITranslations {
///   const DutchA2UITranslations();
///
///   @override
///   String get playMedia => 'Afspelen';
///
///   // ...and every other string.
/// }
/// ```
///
/// That way a string this package adds later is a compile error that tells
/// you there is something new to translate, instead of English showing up in
/// your app. Adding a string is not considered a breaking change.
///
/// **Give your class a `const` constructor** and construct it as
/// `const DutchA2UITranslations()`. A scope compares instances to decide
/// whether to notify, so a fresh instance per `build` rebuilds every
/// dependent.
@immutable
abstract class A2UITranslations {
  /// Creates an [A2UITranslations].
  const A2UITranslations();

  /// The translations in force at [context].
  ///
  /// The first of these wins:
  ///
  /// 1. the nearest enclosing [A2UITranslationsScope];
  /// 2. what an [A2UITranslationsDelegate] loaded for the app's locale, read
  ///    through Flutter's [Localizations];
  /// 3. [DefaultA2UITranslations].
  ///
  /// A scope beats the delegate because it is placed by hand around specific
  /// widgets. Widgets that call this rebuild when the app's locale changes or
  /// the scope's translations change.
  static A2UITranslations of(BuildContext context) {
    if (A2UITranslationsScope.maybeOf(context) case final scoped?) return scoped;
    if (Localizations.of<A2UITranslations>(context, A2UITranslations) case final localized?) return localized;
    return const DefaultA2UITranslations();
  }

  /// Label of the button that plays a Video or an AudioPlayer.
  String get playMedia;

  /// Label of the button that pauses a Video or an AudioPlayer while it
  /// plays.
  String get pauseMedia;
}

/// The English strings the A2UI components ship, and what they render when
/// neither an [A2UITranslationsScope] nor an [A2UITranslationsDelegate]
/// supplies others.
///
/// Consider implementing [A2UITranslations] for other languages rather than
/// subclassing this, so a string added later is a compile error.
class DefaultA2UITranslations extends A2UITranslations {
  /// Creates a [DefaultA2UITranslations].
  const DefaultA2UITranslations();

  @override
  String get playMedia => 'Play';

  @override
  String get pauseMedia => 'Pause';
}

/// Provides [translations] to the A2UI components below it.
///
/// ```dart
/// A2UITranslationsScope(
///   translations: const DutchA2UITranslations(),
///   child: A2UIRenderer(...),
/// )
/// ```
///
/// Use this to pin strings over part of the tree, such as a screen that is
/// always in one language, a preview or a test. To translate the whole app by
/// locale, register an [A2UITranslationsDelegate] instead.
///
/// This is an [InheritedTheme], so a sheet a Modal opens carries it across the
/// [Navigator]. The sheet captures it when it opens, so a scope swapped while
/// the sheet is open reaches it only when it opens again.
class A2UITranslationsScope extends InheritedTheme {
  /// Creates an [A2UITranslationsScope].
  const A2UITranslationsScope({super.key, required this.translations, required super.child});

  /// The strings made available to the subtree.
  ///
  /// Should be a `const` instance. See [A2UITranslations] for why.
  final A2UITranslations translations;

  /// The nearest enclosing scope's [translations], or `null` when there is no
  /// scope above [context].
  ///
  /// This reads only the scope. To also fall back to the locale's delegate and
  /// then to the English defaults, consider [A2UITranslations.of].
  static A2UITranslations? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<A2UITranslationsScope>()?.translations;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return A2UITranslationsScope(translations: translations, child: child);
  }

  @override
  bool updateShouldNotify(A2UITranslationsScope oldWidget) => oldWidget.translations != translations;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<A2UITranslations>('translations', translations));
  }
}

/// Supplies [A2UITranslations] per locale, through Flutter's localization.
///
/// Register it on `MaterialApp.localizationsDelegates` next to the others,
/// and list the locales in `supportedLocales`:
///
/// ```dart
/// MaterialApp(
///   localizationsDelegates: const [
///     AITranslationsDelegate({'nl': DutchTranslations()}),
///     A2UITranslationsDelegate({'nl': DutchA2UITranslations()}),
///     GlobalMaterialLocalizations.delegate,
///     GlobalWidgetsLocalizations.delegate,
///   ],
///   supportedLocales: const [Locale('en'), Locale('nl')],
///   home: ...,
/// )
/// ```
///
/// English needs no entry: a locale this delegate has no entry for renders
/// [DefaultA2UITranslations].
class A2UITranslationsDelegate extends LocalizationsDelegate<A2UITranslations> {
  /// Creates an [A2UITranslationsDelegate] serving [translations].
  const A2UITranslationsDelegate(this.translations);

  /// The translations to serve, keyed by the locale each is written for.
  ///
  /// Keys take `Locale.toString()`'s form: a language code (`'nl'`), or a
  /// language and country joined by an underscore (`'pt_BR'`), not the
  /// hyphenated BCP-47 form. Case counts: lowercase language, uppercase
  /// country. A debug-only check rejects any other key, which could never
  /// match a locale.
  final Map<String, A2UITranslations> translations;

  /// The entry for [locale], or `null`: the exact match if [translations] has
  /// one, otherwise the entry for its language and script, then for its
  /// language and country, then for its language alone.
  ///
  /// So a single `'pt'` entry serves `pt_BR` and `pt_PT`, a `'pt_BR'` entry
  /// serves only Brazilian Portuguese, and a `'zh_Hant'` entry serves
  /// `zh_Hant_TW` too.
  ///
  /// Throws a [FlutterError] in debug mode if [translations] holds a key that
  /// is not a locale key.
  A2UITranslations? resolve(Locale locale) {
    assert(() {
      for (final key in translations.keys) {
        if (!_localeKey.hasMatch(key)) {
          throw FlutterError(
            "A2UITranslationsDelegate was given the key '$key', which is not a locale key.\n"
            "Keys take Locale.toString()'s form: a lowercase language code such as 'nl', "
            "optionally followed by a script and an uppercase country, as in 'pt_BR' and "
            "'zh_Hant_TW'. A key in any other shape can never match a locale.",
          );
        }
      }
      return true;
    }(), 'A2UITranslationsDelegate keys must be locale keys.');

    if (translations[locale.toString()] case final exact?) return exact;
    if (locale.scriptCode case final script?) {
      if (translations['${locale.languageCode}_$script'] case final scripted?) return scripted;
    }
    if (locale.countryCode case final country?) {
      if (translations['${locale.languageCode}_$country'] case final regional?) return regional;
    }
    return translations[locale.languageCode];
  }

  /// Always `true`: a locale [translations] has no entry for is served the
  /// English defaults rather than refused, so that apps supporting more
  /// locales than they have translated get no warning. Use [resolve] to ask
  /// what is registered.
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<A2UITranslations> load(Locale locale) {
    // Synchronous, so the first frame after a locale change already has the
    // new locale's strings.
    return SynchronousFuture<A2UITranslations>(resolve(locale) ?? const DefaultA2UITranslations());
  }

  @override
  bool shouldReload(A2UITranslationsDelegate old) => !mapEquals(old.translations, translations);

  @override
  String toString() => 'A2UITranslationsDelegate(${translations.keys.join(', ')})';
}

// The shape [A2UITranslationsDelegate.translations]'s keys take: `nl`,
// `pt_BR`, `zh_Hant`, `zh_Hant_TW`, `es_419`. Case counts, since [Locale]
// never normalizes it.
final _localeKey = RegExp(r'^[a-z]{2,8}(_[A-Z][a-z]{3})?(_([A-Z]{2}|\d{3}))?$');
