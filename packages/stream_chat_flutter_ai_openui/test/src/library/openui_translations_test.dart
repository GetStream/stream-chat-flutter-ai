import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/form_validation.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_translations.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_actions.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view.dart';
import 'package:stream_core_flutter/core.dart';

import '../openui_test_app.dart';

// German-like texts for the few the tests read; the rest stay English. It
// writes numbers itself, as a translation does.
class _German extends DefaultOpenUITranslations {
  const _German();

  @override
  String get validationRequired => 'Pflichtfeld';

  @override
  String validationMinLength(int min) => 'Mindestens $min Zeichen';

  @override
  String get nextPage => 'Nächste Seite';

  @override
  String get selectPlaceholder => 'Wählen...';

  @override
  String get done => 'Fertig';

  @override
  String galleryImage(int index, int count) => 'Bild $index von $count';

  @override
  String trendPercent(num percent) => '${_german(percent)} %';

  @override
  String trendUp(num percent) => 'Plus ${_german(percent)} Prozent';

  @override
  String validationMin(num min) => 'Mindestens ${_german(min)}';

  @override
  String snippetCardItem(int index) => 'Karte $index';
}

// [value] with German separators, as `intl` would write it.
String _german(num value) {
  final whole = value.truncate();
  final grouped = whole.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  final fraction = value == whole ? '' : value.toString().split('.').last;
  return fraction.isEmpty ? grouped : '$grouped,$fraction';
}

// A text of its own for every form error, to tell each apart from English.
class _Marked extends DefaultOpenUITranslations {
  const _Marked();

  @override
  String get validationRequired => '#required';

  @override
  String get validationRequiredOption => '#requiredOption';

  @override
  String get validationEmail => '#email';

  @override
  String get validationUrl => '#url';

  @override
  String get validationNumeric => '#numeric';

  @override
  String validationMin(num min) => '#min $min';

  @override
  String validationMax(num max) => '#max $max';

  @override
  String validationMinLength(int min) => '#minLength $min';

  @override
  String validationMaxLength(int max) => '#maxLength $max';

  @override
  String get validationPattern => '#pattern';
}

class _Dutch extends DefaultOpenUITranslations {
  const _Dutch();

  @override
  String get validationRequired => 'Verplicht';
}

const _form = '''
root = Card([Form("f", Buttons([Button("Go", @ToAssistant("go"), "primary")]), [FormControl("Name", Input("name", "", "text", {required: true})), FormControl("Code", Input("code", "", "text", {minLength: 3}))])])
''';

// Pumps the view of [program] read with [library], under [translations] when
// given; returns the actions it runs.
Future<List<OpenUIActionEvent>> _pumpIn(
  WidgetTester tester,
  String program,
  OpenUITranslations? translations, {
  OpenUILibrary? library,
}) async {
  final lib = library ?? OpenUILibrary.chat;
  final runtime = testRuntime(library: lib);
  addTearDown(runtime.dispose);
  final events = <OpenUIActionEvent>[];
  runtime.actions.listen(events.add);
  runtime.update(program, isStreaming: false);
  Widget view = OpenUIView(runtime: runtime, library: lib);
  if (translations != null) view = OpenUITranslationsScope(translations: translations, child: view);
  await tester.pumpWidget(testApp(view));
  await tester.pump();
  return events;
}

void main() {
  testWidgets('without translations the components draw English', (tester) async {
    await _pumpIn(tester, _form, null);
    await tester.enterText(find.byType(EditableText).last, 'ab');
    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(find.text('This field is required'), findsOneWidget);
    expect(find.text('Must be at least 3 characters'), findsOneWidget);
  });

  testWidgets("a form's errors come from the translations in scope", (tester) async {
    await _pumpIn(tester, _form, const _German());
    await tester.enterText(find.byType(EditableText).last, 'ab');
    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(find.text('Pflichtfeld'), findsOneWidget);
    expect(find.text('Mindestens 3 Zeichen'), findsOneWidget);
  });

  testWidgets("a form rule's limit reaches the translation as a number, which it formats", (tester) async {
    await _pumpIn(
      tester,
      'root = Card([Form("f", Buttons([Button("Go", @ToAssistant("go"), "primary")]), [FormControl("A", Input("a", "", "number", {min: 1500})), FormControl("B", Input("b", "", "number", {min: 0.5}))])])',
      const _German(),
    );
    await tester.enterText(find.byType(EditableText).first, '1');
    await tester.enterText(find.byType(EditableText).last, '0');
    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(find.text('Mindestens 1.500'), findsOneWidget);
    expect(find.text('Mindestens 0,5'), findsOneWidget);
  });

  for (final (error, message) in [
    (const FormValidationError(FormValidationErrorCode.required), '#required'),
    (const FormValidationError(FormValidationErrorCode.requiredOption), '#requiredOption'),
    (const FormValidationError(FormValidationErrorCode.email), '#email'),
    (const FormValidationError(FormValidationErrorCode.url), '#url'),
    (const FormValidationError(FormValidationErrorCode.numeric), '#numeric'),
    (const FormValidationError(FormValidationErrorCode.min, 1000), '#min 1000'),
    (const FormValidationError(FormValidationErrorCode.max, 2.5), '#max 2.5'),
    (const FormValidationError(FormValidationErrorCode.minLength, 3), '#minLength 3'),
    (const FormValidationError(FormValidationErrorCode.maxLength, 4), '#maxLength 4'),
    (const FormValidationError(FormValidationErrorCode.pattern), '#pattern'),
  ]) {
    test('the ${error.code.name} error comes from its translation', () {
      expect(openUIValidationMessage(const _Marked(), error), message);
    });
  }

  // The texts of the errors the other tests don't read in English.
  for (final (error, message) in [
    (const FormValidationError(FormValidationErrorCode.requiredOption), 'At least one option is required'),
    (const FormValidationError(FormValidationErrorCode.email), 'Please enter a valid email'),
    (const FormValidationError(FormValidationErrorCode.url), 'Please enter a valid URL'),
    (const FormValidationError(FormValidationErrorCode.numeric), 'Must be a number'),
    (const FormValidationError(FormValidationErrorCode.maxLength, 4), 'Must be no more than 4 characters'),
    (const FormValidationError(FormValidationErrorCode.pattern), 'Invalid format'),
  ]) {
    test('the English text of the ${error.code.name} error is "$message"', () {
      expect(openUIValidationMessage(const DefaultOpenUITranslations(), error), message);
    });
  }

  testWidgets("a card item without a title runs its action with the translations' label", (tester) async {
    final events = await _pumpIn(
      tester,
      'root = Card([SnippetCardBlock([SnippetCardItem(null, Text("text", "42"))], null, null, {type: "pick"})])',
      const _German(),
    );

    await tester.tap(find.text('42'));
    await tester.pump();

    expect(events.single.label, 'Karte 1');
  });

  // Each block's item shows nothing its action's label could be named by.
  for (final (kind, program) in [
    ('Snippet', 'SnippetCardBlock([SnippetCardItem(null, Text("text", "42"))], null, null, {type: "pick"})'),
    ('Overview', 'OverviewCardBlock([OverviewCardItem(null, Image("a"))], null, null, {type: "pick"})'),
    ('Context', 'ContextCardBlock([ContextCardItem(null, "")], null, null, {type: "pick"})'),
    (
      'Composite',
      'CompositeCardBlock([CompositeCardItem(null, null, [Text("text", "x")])], null, null, {type: "pick"})',
    ),
    ('Visual', 'VisualCardBlock([VisualCardItem(Image("a"), null)], null, null, {type: "pick"})'),
  ]) {
    testWidgets('a $kind card item that shows no title runs its action labeled in English', (tester) async {
      final events = await _pumpIn(tester, 'root = Card([$program])', null);

      await tester.tap(find.byType(OpenUIPressable));
      await tester.pump();

      expect(events.single.label, '$kind card 1');
    });
  }

  testWidgets("a trend's percentage reaches the translation as a number, which it formats", (tester) async {
    await _pumpIn(
      tester,
      'root = Card([MetricIndicatorInline("1", "", {direction: "up", value: 1234.567})])',
      const _German(),
    );

    expect(find.bySemanticsLabel('Plus 1.234,567 Prozent'), findsOneWidget);
  });

  testWidgets("a trend's percentage shows as the translation writes it", (tester) async {
    await _pumpIn(
      tester,
      'root = Card([MetricIndicatorInline("1", "", {direction: "up", value: 1234.567})])',
      const _German(),
    );

    expect(find.text('1.234,567 %'), findsOneWidget);
  });

  group('the English texts write numbers as the program does', () {
    const english = DefaultOpenUITranslations();

    test('a whole limit without a fraction', () {
      expect(english.validationMin(1500.0), 'Must be at least 1500');
    });

    test('a limit with a fraction', () {
      expect(english.validationMax(0.5), 'Must be no more than 0.5');
    });

    test('a trend percentage with at most 2 decimals', () {
      expect(english.trendPercent(1234.567), '1234.57%');
    });

    test('a whole trend percentage past the integer range in full', () {
      expect(english.trendPercent(1e20), '100000000000000000000%');
    });

    test('a gallery image by its place', () {
      expect(english.galleryImage(2, 5), 'Image 2 of 5');
    });

    test('a rise with at most 2 decimals', () {
      expect(english.trendUp(1234.567), 'Up 1234.57 percent');
    });

    test('a fall with at most 2 decimals', () {
      expect(english.trendDown(1234.567), 'Down 1234.57 percent');
    });
  });

  testWidgets("a table's controls read in the translations' words", (tester) async {
    final rows = [for (var i = 0; i < 12; i++) '{n: $i}'].join(', ');
    await _pumpIn(tester, 'root = Card([Table([Col("N", [$rows])])])', const _German());

    expect(find.bySemanticsLabel('Nächste Seite'), findsOneWidget);
  });

  testWidgets("a delegate supplies the translations of the app's locale", (tester) async {
    late OpenUITranslations found;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('nl'),
        delegates: const [
          OpenUITranslationsDelegate({'nl': _Dutch()}),
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            found = OpenUITranslations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();

    expect(found, const _Dutch());
  });

  test('a delegate serves the defaults for a locale it has no entry for', () async {
    const delegate = OpenUITranslationsDelegate({'nl': _Dutch()});

    expect(await delegate.load(const Locale('fr')), const DefaultOpenUITranslations());
  });

  test('a delegate serves a language entry for each country of it', () {
    const delegate = OpenUITranslationsDelegate({'nl': _Dutch()});

    expect(delegate.resolve(const Locale('nl', 'BE')), const _Dutch());
  });

  test('a delegate serves a country entry before the entry of its language', () {
    const delegate = OpenUITranslationsDelegate({'pt': DefaultOpenUITranslations(), 'pt_BR': _Dutch()});

    expect(delegate.resolve(const Locale('pt', 'BR')), const _Dutch());
  });

  test('a delegate serves the language entry to a country without an entry of its own', () {
    const delegate = OpenUITranslationsDelegate({'pt': DefaultOpenUITranslations(), 'pt_BR': _Dutch()});

    expect(delegate.resolve(const Locale('pt', 'PT')), const DefaultOpenUITranslations());
  });

  test('a delegate serves a script entry to a locale with that script and a country', () {
    const delegate = OpenUITranslationsDelegate({'zh': DefaultOpenUITranslations(), 'zh_Hant': _Dutch()});

    expect(
      delegate.resolve(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')),
      const _Dutch(),
    );
  });

  test('a delegate serves a country entry to a locale with a script it has no entry for', () {
    const delegate = OpenUITranslationsDelegate({'zh': DefaultOpenUITranslations(), 'zh_TW': _Dutch()});

    expect(
      delegate.resolve(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')),
      const _Dutch(),
    );
  });

  test('a delegate rejects a key that is not a locale key', () {
    const delegate = OpenUITranslationsDelegate({'nl-NL': _Dutch()});

    expect(() => delegate.resolve(const Locale('nl')), throwsFlutterError);
  });

  test('a delegate accepts every key shape Locale.toString() produces', () {
    const delegate = OpenUITranslationsDelegate({
      'nl': _Dutch(),
      'pt_BR': _Dutch(),
      'zh_Hant': _Dutch(),
      'zh_Hant_TW': _Dutch(),
      'es_419': _Dutch(),
    });

    expect(
      delegate.resolve(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')),
      const _Dutch(),
    );
    expect(delegate.resolve(const Locale('es', '419')), const _Dutch());
  });

  test('a delegate loads its texts synchronously', () {
    const delegate = OpenUITranslationsDelegate({'nl': _Dutch()});

    expect(delegate.load(const Locale('nl')), isA<SynchronousFuture<OpenUITranslations>>());
  });

  test('a delegate does not reload for equal translations', () {
    const delegate = OpenUITranslationsDelegate({'nl': _Dutch()});

    expect(delegate.shouldReload(const OpenUITranslationsDelegate({'nl': _Dutch()})), isFalse);
  });

  test('a delegate reloads when its translations change', () {
    const delegate = OpenUITranslationsDelegate({'nl': _Dutch()});

    expect(delegate.shouldReload(const OpenUITranslationsDelegate({'nl': _German()})), isTrue);
  });

  test('a delegate names the locales it serves', () {
    final translations = {'nl': const _Dutch(), 'pt_BR': const _German()};

    expect(OpenUITranslationsDelegate(translations).toString(), 'OpenUITranslationsDelegate(nl, pt_BR)');
  });

  testWidgets('a scope outranks the delegate', (tester) async {
    late OpenUITranslations found;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('nl'),
        delegates: const [
          OpenUITranslationsDelegate({'nl': _Dutch()}),
          DefaultWidgetsLocalizations.delegate,
        ],
        child: OpenUITranslationsScope(
          translations: const _German(),
          child: Builder(
            builder: (context) {
              found = OpenUITranslations.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(found, const _German());
  });

  test('a scope lists its translations in its diagnostics', () {
    final builder = DiagnosticPropertiesBuilder();
    const OpenUITranslationsScope(translations: _Dutch(), child: SizedBox()).debugFillProperties(builder);

    expect(builder.properties.map((property) => property.name), contains('translations'));
  });

  testWidgets('a scope does not rebuild its dependents for the same translations', (tester) async {
    var builds = 0;
    final counter = _BuildCounter(onBuild: () => builds++);
    Widget app(OpenUITranslations translations) => MaterialApp(
      home: OpenUITranslationsScope(translations: translations, child: counter),
    );

    await tester.pumpWidget(app(const _Dutch()));
    await tester.pumpWidget(app(const _Dutch()));

    expect(builds, 1);
  });

  testWidgets('a scope rebuilds its dependents when its translations change', (tester) async {
    var builds = 0;
    final counter = _BuildCounter(onBuild: () => builds++);
    Widget app(OpenUITranslations translations) => MaterialApp(
      home: OpenUITranslationsScope(translations: translations, child: counter),
    );

    await tester.pumpWidget(app(const _Dutch()));
    await tester.pumpWidget(app(const _German()));

    expect(builds, 2);
  });

  testWidgets("a scope's translations reach the sheet a Modal opens", (tester) async {
    await _pumpIn(
      tester,
      'root = Stack([Modal("Pick", true, [Select("s", [SelectItem("a", "A")])])])',
      const _German(),
      library: OpenUILibrary.standard,
    );
    await tester.pumpAndSettle();

    expect(find.text('Wählen...'), findsOneWidget);
  });

  testWidgets("a scope's translations reach the viewer an ImageGallery opens", (tester) async {
    await _pumpIn(tester, 'root = Card([ImageGallery([{src: "https://a.dev/1.png", alt: "One"}])])', const _German());
    await tester.tap(find.byType(StreamNetworkImage));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Fertig'), findsOneWidget);
  });

  testWidgets("an ImageGallery's tile without alt text is named in the translations' words", (tester) async {
    await _pumpIn(
      tester,
      'root = Card([ImageGallery([{src: "https://a.dev/1.png"}, {src: "https://a.dev/2.png"}])])',
      const _German(),
    );

    expect(find.bySemanticsLabel('Bild 2 von 2'), findsOneWidget);
  });

  testWidgets("the scrim of an ImageGallery's viewer is labelled as a dismissal", (tester) async {
    await _pumpIn(tester, 'root = Card([ImageGallery([{src: "https://a.dev/1.png", alt: "One"}])])', null);
    await tester.tap(find.byType(StreamNetworkImage));
    await tester.pumpAndSettle();

    final barriers = tester
        .widgetList<ModalBarrier>(find.byType(ModalBarrier))
        .map((barrier) => barrier.semanticsLabel);
    expect(barriers, contains('Dismiss'));
  });
}

// Reads the translations in force and counts its builds through [onBuild].
class _BuildCounter extends StatelessWidget {
  const _BuildCounter({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    OpenUITranslations.of(context);
    onBuild();
    return const SizedBox();
  }
}
