import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/form_validation.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_translations.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_actions.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view.dart';

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
}

class _Dutch extends DefaultOpenUITranslations {
  const _Dutch();

  @override
  String get validationRequired => 'Verplicht';
}

const _form = '''
root = Card([Form("f", Buttons([Button("Go", @ToAssistant("go"), "primary")]), [FormControl("Name", Input("name", "", "text", {required: true})), FormControl("Code", Input("code", "", "text", {minLength: 3}))])])
''';

Future<List<OpenUIActionEvent>> _pumpIn(WidgetTester tester, String program, OpenUITranslations? translations) async {
  final runtime = testRuntime();
  addTearDown(runtime.dispose);
  final events = <OpenUIActionEvent>[];
  runtime.actions.listen(events.add);
  await pumpOpenUI(tester, runtime, program: program);
  await tester.pump();
  if (translations == null) return events;
  await tester.pumpWidget(
    testApp(
      OpenUITranslationsScope(
        translations: translations,
        child: OpenUIView(runtime: runtime, library: OpenUILibrary.chat),
      ),
    ),
  );
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
  ]) {
    test('the ${error.code.name} error comes from its translation', () {
      expect(openUIValidationMessage(const _Marked(), error), message);
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

  testWidgets("a trend's percentage reaches the translation as a number, which it formats", (tester) async {
    await _pumpIn(
      tester,
      'root = Card([MetricIndicatorInline("1", "", {direction: "up", value: 1234.567})])',
      const _German(),
    );

    expect(find.bySemanticsLabel('Plus 1.234,567 Prozent'), findsOneWidget);
  });

  group('the English texts write numbers as the program does', () {
    const english = DefaultOpenUITranslations();

    test('a whole limit without a fraction', () {
      expect(english.validationMin(1500.0), 'Must be at least 1500');
    });

    test('a limit with a fraction', () {
      expect(english.validationMax(0.5), 'Must be no more than 0.5');
    });

    test('a trend with at most 2 decimals', () {
      expect(english.trendUp(12.5), 'Up 12.5 percent');
      expect(english.trendDown(1234.567), 'Down 1234.57 percent');
    });
  });

  testWidgets("a table's controls read in the translations' words", (tester) async {
    final rows = [for (var i = 0; i < 12; i++) '{n: $i}'].join(', ');
    await _pumpIn(tester, 'root = Card([Table([Col("N", [$rows])])])', const _German());

    expect(find.bySemanticsLabel('Nächste Seite'), findsOneWidget);
  });

  testWidgets('a delegate serves the translations of the locale, and English for another', (tester) async {
    const delegate = OpenUITranslationsDelegate({'nl': _Dutch()});

    expect(delegate.resolve(const Locale('nl', 'BE')), const _Dutch());
    expect(delegate.resolve(const Locale('fr')), isNull);
    expect(await delegate.load(const Locale('fr')), const DefaultOpenUITranslations());

    late OpenUITranslations found;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('nl'),
        delegates: const [delegate, DefaultWidgetsLocalizations.delegate],
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

  test('a scope notifies when its translations change', () {
    const child = SizedBox.shrink();
    const a = OpenUITranslationsScope(translations: DefaultOpenUITranslations(), child: child);
    const b = OpenUITranslationsScope(translations: DefaultOpenUITranslations(), child: child);
    const c = OpenUITranslationsScope(translations: _Dutch(), child: child);

    expect(a.updateShouldNotify(b), isFalse);
    expect(a.updateShouldNotify(c), isTrue);
  });

  test('a delegate reloads when its map changes, not when it is a new instance', () {
    const a = OpenUITranslationsDelegate({'nl': _Dutch()});
    const b = OpenUITranslationsDelegate({'nl': _Dutch()});
    const c = OpenUITranslationsDelegate({'nl': _German()});

    expect(a.shouldReload(b), isFalse);
    expect(a.shouldReload(c), isTrue);
  });

  test('a delegate rejects a key that is not a locale', () {
    expect(() => const OpenUITranslationsDelegate({'nl-NL': _Dutch()}).resolve(const Locale('nl')), throwsFlutterError);
  });
}
