import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

void main() {
  test('the default translations are in English', () {
    const translations = DefaultA2UITranslations();

    expect(translations.playMedia, 'Play');
    expect(translations.pauseMedia, 'Pause');
  });

  testWidgets('without a scope or a delegate the defaults are read', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Reader()));

    expect(_read(tester), isA<DefaultA2UITranslations>());
  });

  testWidgets('a scope supplies the translations below it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: A2UITranslationsScope(translations: _DutchTranslations(), child: _Reader()),
      ),
    );

    expect(_read(tester).playMedia, 'Afspelen');
  });

  testWidgets("a delegate supplies the translations of the app's locale", (tester) async {
    await tester.pumpWidget(_localizedApp(const Locale('nl'), child: const _Reader()));

    expect(_read(tester).pauseMedia, 'Pauzeren');
  });

  testWidgets('a delegate serves the defaults for a locale it has no entry for', (tester) async {
    await tester.pumpWidget(_localizedApp(const Locale('de'), child: const _Reader()));

    expect(_read(tester), isA<DefaultA2UITranslations>());
  });

  testWidgets("a scope wins over the locale's delegate", (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        const Locale('nl'),
        child: const A2UITranslationsScope(translations: _ShoutingTranslations(), child: _Reader()),
      ),
    );

    expect(_read(tester).playMedia, 'PLAY');
  });

  test('a delegate serves a language entry for each country of it', () {
    const delegate = A2UITranslationsDelegate({'nl': _DutchTranslations()});

    expect(delegate.resolve(const Locale('nl', 'BE')), isA<_DutchTranslations>());
  });

  test('a delegate serves a country entry before the entry of its language', () {
    const delegate = A2UITranslationsDelegate({'pt': DefaultA2UITranslations(), 'pt_BR': _DutchTranslations()});

    expect(delegate.resolve(const Locale('pt', 'BR')), isA<_DutchTranslations>());
  });

  test('a delegate serves the language entry to a country without an entry of its own', () {
    const delegate = A2UITranslationsDelegate({'pt': DefaultA2UITranslations(), 'pt_BR': _DutchTranslations()});

    expect(delegate.resolve(const Locale('pt', 'PT')), isA<DefaultA2UITranslations>());
  });

  test('a delegate serves a script entry to a locale with that script and a country', () {
    const delegate = A2UITranslationsDelegate({'zh': DefaultA2UITranslations(), 'zh_Hant': _DutchTranslations()});

    expect(
      delegate.resolve(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')),
      isA<_DutchTranslations>(),
    );
  });

  test('a delegate serves a country entry to a locale with a script it has no entry for', () {
    const delegate = A2UITranslationsDelegate({'zh': DefaultA2UITranslations(), 'zh_TW': _DutchTranslations()});

    expect(
      delegate.resolve(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')),
      isA<_DutchTranslations>(),
    );
  });

  test('a delegate rejects a key that is not a locale key', () {
    const delegate = A2UITranslationsDelegate({'nl-NL': _DutchTranslations()});

    expect(() => delegate.resolve(const Locale('nl')), throwsFlutterError);
  });

  test('a delegate accepts every key shape Locale.toString() produces', () {
    const delegate = A2UITranslationsDelegate({
      'nl': _DutchTranslations(),
      'pt_BR': _DutchTranslations(),
      'zh_Hant': _DutchTranslations(),
      'zh_Hant_TW': _DutchTranslations(),
      'es_419': _DutchTranslations(),
    });

    expect(
      delegate.resolve(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')),
      isA<_DutchTranslations>(),
    );
    expect(delegate.resolve(const Locale('es', '419')), isA<_DutchTranslations>());
  });

  test('a delegate loads its strings synchronously', () {
    const delegate = A2UITranslationsDelegate({'nl': _DutchTranslations()});

    expect(delegate.load(const Locale('nl')), isA<SynchronousFuture<A2UITranslations>>());
  });

  test('a delegate does not reload for equal translations', () {
    const delegate = A2UITranslationsDelegate({'nl': _DutchTranslations()});

    expect(delegate.shouldReload(const A2UITranslationsDelegate({'nl': _DutchTranslations()})), isFalse);
  });

  test('a delegate reloads when its translations change', () {
    const delegate = A2UITranslationsDelegate({'nl': _DutchTranslations()});

    expect(delegate.shouldReload(const A2UITranslationsDelegate({'nl': _ShoutingTranslations()})), isTrue);
  });

  test('a delegate names the locales it serves', () {
    final translations = {'nl': const _DutchTranslations(), 'pt_BR': const _ShoutingTranslations()};

    expect(A2UITranslationsDelegate(translations).toString(), 'A2UITranslationsDelegate(nl, pt_BR)');
  });

  test('a scope lists its translations in its diagnostics', () {
    final builder = DiagnosticPropertiesBuilder();
    const A2UITranslationsScope(translations: _DutchTranslations(), child: SizedBox()).debugFillProperties(builder);

    expect(builder.properties.map((property) => property.name), contains('translations'));
  });

  testWidgets('a scope does not rebuild its dependents for the same translations', (tester) async {
    var builds = 0;
    final counter = _BuildCounter(onBuild: () => builds++);
    Widget app(A2UITranslations translations) => MaterialApp(
      home: A2UITranslationsScope(translations: translations, child: counter),
    );

    await tester.pumpWidget(app(const _DutchTranslations()));
    await tester.pumpWidget(app(const _DutchTranslations()));

    expect(builds, 1);
  });

  testWidgets('a scope rebuilds its dependents when its translations change', (tester) async {
    var builds = 0;
    final counter = _BuildCounter(onBuild: () => builds++);
    Widget app(A2UITranslations translations) => MaterialApp(
      home: A2UITranslationsScope(translations: translations, child: counter),
    );

    await tester.pumpWidget(app(const _DutchTranslations()));
    await tester.pumpWidget(app(const _ShoutingTranslations()));

    expect(builds, 2);
  });

  testWidgets('a scope carries its translations into a route pushed with captured themes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: A2UITranslationsScope(
          translations: const _DutchTranslations(),
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                final navigator = Navigator.of(context);
                final themes = InheritedTheme.capture(from: context, to: navigator.context);
                navigator.push(MaterialPageRoute<void>(builder: (_) => themes.wrap(const _Reader())));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(_read(tester).playMedia, 'Afspelen');
  });
}

Widget _localizedApp(Locale locale, {required Widget child}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('nl'), Locale('de')],
    localizationsDelegates: const [
      A2UITranslationsDelegate({'nl': _DutchTranslations()}),
      _AnyLocaleDelegate<MaterialLocalizations>(DefaultMaterialLocalizations()),
      _AnyLocaleDelegate<CupertinoLocalizations>(DefaultCupertinoLocalizations()),
    ],
    home: child,
  );
}

A2UITranslations _read(WidgetTester tester) => A2UITranslations.of(tester.element(find.byType(_Reader)));

class _Reader extends StatelessWidget {
  const _Reader();

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// Reads the translations and reports each build to [onBuild].
class _BuildCounter extends StatelessWidget {
  const _BuildCounter({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    A2UITranslations.of(context);
    onBuild();
    return const SizedBox();
  }
}

// Serves [value] for any locale, so an app can run in a locale Flutter's own
// localizations don't carry.
class _AnyLocaleDelegate<T> extends LocalizationsDelegate<T> {
  const _AnyLocaleDelegate(this.value);

  final T value;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) => SynchronousFuture<T>(value);

  @override
  bool shouldReload(_AnyLocaleDelegate<T> old) => false;
}

class _DutchTranslations implements A2UITranslations {
  const _DutchTranslations();

  @override
  String get playMedia => 'Afspelen';

  @override
  String get pauseMedia => 'Pauzeren';
}

class _ShoutingTranslations implements A2UITranslations {
  const _ShoutingTranslations();

  @override
  String get playMedia => 'PLAY';

  @override
  String get pauseMedia => 'PAUSE';
}
