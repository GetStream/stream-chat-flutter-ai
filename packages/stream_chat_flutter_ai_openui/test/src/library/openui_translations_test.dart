import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_translations.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view.dart';

import '../openui_test_app.dart';

// German-like texts for the few the tests read; the rest stay English.
class _German extends DefaultOpenUITranslations {
  const _German();

  @override
  String get validationRequired => 'Pflichtfeld';

  @override
  String validationMinLength(String min) => 'Mindestens $min Zeichen';

  @override
  String get nextPage => 'Nächste Seite';

  @override
  String get decimalSeparator => ',';

  @override
  String get groupSeparator => '.';

  @override
  String percent(String number) => '$number %';

  @override
  String trendUp(String number) => 'Plus $number Prozent';
}

class _Dutch extends DefaultOpenUITranslations {
  const _Dutch();

  @override
  String get validationRequired => 'Verplicht';
}

const _form = '''
root = Card([Form("f", Buttons([Button("Go", @ToAssistant("go"), "primary")]), [FormControl("Name", Input("name", "", "text", {required: true})), FormControl("Code", Input("code", "", "text", {minLength: 3}))])])
''';

Future<void> _pumpIn(WidgetTester tester, String program, OpenUITranslations? translations) async {
  final runtime = testRuntime();
  addTearDown(runtime.dispose);
  await pumpOpenUI(tester, runtime, program: program);
  await tester.pump();
  if (translations == null) return;
  await tester.pumpWidget(
    testApp(
      OpenUITranslationsScope(
        translations: translations,
        child: OpenUIView(runtime: runtime, library: OpenUILibrary.chat),
      ),
    ),
  );
  await tester.pump();
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

  testWidgets("a trend's percentage uses the translations' separators", (tester) async {
    await _pumpIn(
      tester,
      'root = Card([MetricIndicatorInline("1", "", {direction: "up", value: 1234.567})])',
      const _German(),
    );

    expect(find.text('1.234,57 %'), findsOneWidget);
    expect(find.bySemanticsLabel('Plus 1.234,567 Prozent'), findsOneWidget);
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

  test('a delegate rejects a key that is not a locale', () {
    expect(() => const OpenUITranslationsDelegate({'nl-NL': _Dutch()}).resolve(const Locale('nl')), throwsFlutterError);
  });
}
