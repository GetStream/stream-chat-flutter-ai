import 'package:flutter/cupertino.dart' show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  group('AITranslations.of', () {
    testWidgets('falls back to the English defaults with no scope in the tree', (tester) async {
      late AITranslations resolved;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              resolved = AITranslations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, isA<DefaultAITranslations>());
      expect(resolved.send, 'Send');
      expect(resolved.composerHint, 'Ask anything…');
      expect(resolved.clearOption('Weather'), 'Clear Weather');
    });

    testWidgets('finds an enclosing scope', (tester) async {
      late AITranslations resolved;

      await tester.pumpWidget(
        _wrap(
          AITranslationsScope(
            translations: const _TestTranslations(),
            child: Builder(
              builder: (context) {
                resolved = AITranslations.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(resolved, isA<_TestTranslations>());
      expect(resolved.send, 'VERSTUUR');
    });

    testWidgets('resolves to the nearest of two nested scopes', (tester) async {
      late AITranslations resolved;

      await tester.pumpWidget(
        _wrap(
          AITranslationsScope(
            translations: const DefaultAITranslations(),
            child: AITranslationsScope(
              translations: const _TestTranslations(),
              child: Builder(
                builder: (context) {
                  resolved = AITranslations.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(resolved.send, 'VERSTUUR');
    });
  });

  group('AITranslationsScope', () {
    test('updateShouldNotify tracks the instance', () {
      const child = SizedBox.shrink();
      const a = AITranslationsScope(translations: DefaultAITranslations(), child: child);
      const b = AITranslationsScope(translations: DefaultAITranslations(), child: child);
      const c = AITranslationsScope(translations: _TestTranslations(), child: child);

      // `const` instances of the same class are canonicalized to one object —
      // the property the docs lean on when they ask for a `const` subclass.
      expect(a.updateShouldNotify(b), isFalse);
      expect(a.updateShouldNotify(c), isTrue);
    });

    testWidgets('a dependent rebuilds when the translations change, and not when they do not', (tester) async {
      var builds = 0;
      final strings = ValueNotifier<AITranslations>(const DefaultAITranslations());
      addTearDown(strings.dispose);

      await tester.pumpWidget(
        _wrap(
          ValueListenableBuilder<AITranslations>(
            valueListenable: strings,
            builder: (context, value, _) => AITranslationsScope(
              translations: value,
              child: Builder(
                builder: (context) {
                  builds++;
                  return Text(AITranslations.of(context).send);
                },
              ),
            ),
          ),
        ),
      );

      expect(builds, 1);
      expect(find.text('Send'), findsOneWidget);

      // Same const instance: the scope widget is replaced, the dependent is not
      // rebuilt.
      strings.value = const DefaultAITranslations();
      await tester.pump();
      expect(builds, 1);

      strings.value = const _TestTranslations();
      await tester.pump();
      expect(builds, 2);
      expect(find.text('VERSTUUR'), findsOneWidget);
    });
  });

  group('AITranslationsScope crosses a route', () {
    // The scope is an InheritedTheme, so anything that captures themes on the
    // way to the Navigator carries it. Asserted through showDialog rather than
    // the attachment sheet to pin the general mechanism, not one caller: the
    // package owes translated strings to whatever it shows in a route of its
    // own, however that route is pushed.
    testWidgets('a dialog pushed from inside the scope keeps it', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AITranslationsScope(
            translations: const _TestTranslations(),
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => Text(AITranslations.of(context).send),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('VERSTUUR'), findsOneWidget);
    });

    testWidgets('without the scope the same dialog falls back to English', (tester) async {
      // The control for the test above — otherwise it would pass just as well
      // if the dialog were somehow reading the defaults.
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => Text(AITranslations.of(context).send),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Send'), findsOneWidget);
    });
  });

  group('AITranslationsDelegate', () {
    // Everything here goes through a real MaterialApp rather than calling the
    // delegate directly: the point of the delegate is that Flutter's own
    // locale resolution drives it.
    Widget app({required Locale locale, Widget? home}) => MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AITranslationsDelegate({
          'nl': _TestTranslations(),
          'pt_BR': _BrazilianTranslations(),
        }),
        ..._anyLocaleMaterialDelegates,
      ],
      supportedLocales: const [Locale('en'), Locale('nl'), Locale('pt', 'BR')],
      home: Scaffold(body: home ?? const _Probe()),
    );

    testWidgets('serves the entry for the app locale', (tester) async {
      await tester.pumpWidget(app(locale: const Locale('nl')));

      expect(find.text('VERSTUUR'), findsOneWidget);
    });

    testWidgets('a locale it does not carry falls back to English', (tester) async {
      await tester.pumpWidget(app(locale: const Locale('en')));

      expect(find.text('Send'), findsOneWidget);
    });

    testWidgets('changing the app locale changes the strings', (tester) async {
      await tester.pumpWidget(app(locale: const Locale('en')));
      expect(find.text('Send'), findsOneWidget);

      await tester.pumpWidget(app(locale: const Locale('nl')));
      await tester.pump();

      expect(find.text('VERSTUUR'), findsOneWidget);
      expect(find.text('Send'), findsNothing);
    });

    testWidgets('a country entry serves only that country', (tester) async {
      await tester.pumpWidget(app(locale: const Locale('pt', 'BR')));

      expect(find.text('MANDA VER'), findsOneWidget);
    });

    testWidgets('a bare language entry serves its country variants', (tester) async {
      // `Locale('nl')` is registered, the app is running nl_BE.
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('nl', 'BE'),
          localizationsDelegates: [
            AITranslationsDelegate({'nl': _TestTranslations()}),
            ..._anyLocaleMaterialDelegates,
          ],
          supportedLocales: [Locale('nl', 'BE')],
          home: Scaffold(body: _Probe()),
        ),
      );

      expect(find.text('VERSTUUR'), findsOneWidget);
    });

    testWidgets('an enclosing scope outranks the delegate', (tester) async {
      // The scope is placed by hand around specific widgets; the delegate
      // covers the app. The narrower one wins.
      await tester.pumpWidget(
        app(
          locale: const Locale('nl'),
          home: const AITranslationsScope(
            translations: _BrazilianTranslations(),
            child: _Probe(),
          ),
        ),
      );

      expect(find.text('MANDA VER'), findsOneWidget);
      expect(find.text('VERSTUUR'), findsNothing);
    });

    testWidgets('reaches a pushed route, which is where Localizations sits', (tester) async {
      await tester.pumpWidget(
        app(
          locale: const Locale('nl'),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => Text(AITranslations.of(context).send),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('VERSTUUR'), findsOneWidget);
    });

    test('resolve matches country first, then bare language', () {
      const delegate = AITranslationsDelegate({
        'nl': _TestTranslations(),
        'pt_BR': _BrazilianTranslations(),
      });

      expect(delegate.resolve(const Locale('nl')), isA<_TestTranslations>());
      expect(delegate.resolve(const Locale('nl', 'BE')), isA<_TestTranslations>());
      expect(delegate.resolve(const Locale('pt', 'BR')), isA<_BrazilianTranslations>());
      // Registered for BR only, so plain `pt` matches nothing.
      expect(delegate.resolve(const Locale('pt')), isNull);
      expect(delegate.resolve(const Locale('en')), isNull);
    });

    test('isSupported claims every locale, so WidgetsApp does not warn', () {
      // The English fallback happens in `load`, not by refusing the locale —
      // see the note on `isSupported`. A test app declaring a supported locale
      // this delegate had refused would fail on that warning.
      const delegate = AITranslationsDelegate({'nl': _TestTranslations()});

      expect(delegate.isSupported(const Locale('nl')), isTrue);
      expect(delegate.isSupported(const Locale('en')), isTrue);
      expect(delegate.isSupported(const Locale('ja')), isTrue);
    });

    testWidgets('load serves the English defaults for an unregistered locale', (tester) async {
      const delegate = AITranslationsDelegate({'nl': _TestTranslations()});

      await expectLater(delegate.load(const Locale('ja')), completion(isA<DefaultAITranslations>()));
    });

    test('a key that is not a locale key is rejected in debug', () {
      // 'nl-BE' is the BCP-47 form; Locale.toString() uses an underscore, so
      // this key could never match and every widget would quietly render
      // English. Both entry points report it, because the check sits in
      // `resolve`, which `load` goes through — a malformed key must not read
      // as the `null` that means "this locale isn't translated".
      const delegate = AITranslationsDelegate({'nl-BE': _TestTranslations()});
      final complains = throwsA(isA<FlutterError>().having((e) => e.message, 'message', contains('nl-BE')));

      expect(() => delegate.resolve(const Locale('nl')), complains);
      expect(() => delegate.load(const Locale('nl')), complains);
    });

    test('a mis-cased key is rejected in debug', () {
      // The same failure as a malformed key, and the easier one to write by
      // accident: Locale compares its subtags verbatim and never normalizes
      // case, so 'NL' matches no locale at all and 'pt_br' matches neither
      // `pt_BR` nor `pt`.
      for (final key in const ['NL', 'pt_br', 'PT_BR', 'zh_hant_TW']) {
        const supported = Locale('nl');
        final delegate = AITranslationsDelegate({key: const _TestTranslations()});

        expect(
          () => delegate.resolve(supported),
          throwsA(isA<FlutterError>().having((e) => e.message, 'message', contains(key))),
          reason: "'$key' is not a shape Locale.toString() can produce",
        );
      }
    });

    test('every shape Locale.toString() produces is accepted', () {
      // The guard against over-tightening the check: a key in canonical form
      // has to survive it, script and numeric region subtags included.
      const delegate = AITranslationsDelegate({
        'nl': _TestTranslations(),
        'pt_BR': _TestTranslations(),
        'zh_Hant': _TestTranslations(),
        'zh_Hant_TW': _TestTranslations(),
        'es_419': _TestTranslations(),
        // An 8-letter language subtag, the longest ISO 639 allows.
        'nordicmt': _TestTranslations(),
      });

      expect(delegate.resolve(const Locale('nl')), isA<_TestTranslations>());
      expect(
        delegate.resolve(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')),
        isA<_TestTranslations>(),
      );
      expect(delegate.resolve(const Locale('es', '419')), isA<_TestTranslations>());
    });

    test('shouldReload tracks the map, not the delegate instance', () {
      const a = AITranslationsDelegate({'nl': _TestTranslations()});
      const b = AITranslationsDelegate({'nl': _TestTranslations()});
      const c = AITranslationsDelegate({'nl': _BrazilianTranslations()});

      expect(a.shouldReload(b), isFalse);
      expect(a.shouldReload(c), isTrue);
    });
  });

  group('DefaultAITranslations', () {
    test('a subclass overriding one string keeps the rest', () {
      const translations = _TestTranslations();

      expect(translations.send, 'VERSTUUR');
      expect(translations.stopGenerating, 'Stop generating');
      expect(translations.copyCode, 'Copy code');
    });
  });
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Stands in for `flutter_localizations` in the tests that declare non-English
/// `supportedLocales`.
///
/// `MaterialApp` warns — and a widget test fails on that warning — when a
/// declared locale is unsupported by *any* delegate, and Flutter's built-in
/// Material and Cupertino delegates cover English only. These serve the
/// English defaults for every locale, which is fine: nothing here asserts on a
/// Material string. The alternative is a `flutter_localizations`
/// dev-dependency for two classes the package itself never touches.
const _anyLocaleMaterialDelegates = <LocalizationsDelegate<dynamic>>[
  _AnyLocaleDelegate<MaterialLocalizations>(DefaultMaterialLocalizations()),
  _AnyLocaleDelegate<CupertinoLocalizations>(DefaultCupertinoLocalizations()),
];

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

/// Reads the one string these tests assert on, from its own context.
class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => Text(AITranslations.of(context).send);
}

/// Overrides exactly one string, to prove the rest still come from the default.
class _TestTranslations extends DefaultAITranslations {
  const _TestTranslations();

  @override
  String get send => 'VERSTUUR';
}

/// A second override, to tell two registered locales apart.
class _BrazilianTranslations extends DefaultAITranslations {
  const _BrazilianTranslations();

  @override
  String get send => 'MANDA VER';
}
