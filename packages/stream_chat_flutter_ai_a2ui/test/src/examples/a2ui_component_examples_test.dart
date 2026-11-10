import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import '../a2ui_test_app.dart';

// The gallery's component examples, `example/assets/components/<name>.json`
// (every component has one: see `a2ui_docs_test.dart`), build their surfaces and show them. A few of them show an edge case on
// purpose, so what they report is listed here: nothing else may be reported.
void main() {
  final files = Directory('example/assets/components').listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final name = _fileName(file);

    testWidgets('$name shows its surfaces and reports only what it shows on purpose', (tester) async {
      final errors = <A2UIError>[];
      final processor = A2UIProcessor(catalogs: A2UICatalogs(), onError: errors.add);
      addTearDown(processor.dispose);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

      expect(json['name'], isA<String>());
      expect(json['description'], isA<String>());
      processor.apply([for (final message in json['messages']! as List<Object?>) jsonEncode(message)]);

      expect(processor.surfaceIds, isNotEmpty);
      for (final surfaceId in processor.surfaceIds) {
        expect(processor.surface(surfaceId)!.root, isNotNull, reason: surfaceId);
        await tester.pumpWidget(surfaceApp(processor.surface(surfaceId)!));
        await tester.pump();
      }
      await tester.pump();

      expect([for (final error in errors) _reported(error)], unorderedEquals(_expectedReports[name] ?? const []));
    });
  }
}

// What an example reports because it shows an edge case on purpose: the
// component and the problem.
const _expectedReports = <String, List<String>>{
  'check_box': ["Component 'c' of type 'CheckBox': Its 'value' isn't bound to the data model, so it can't be changed."],
  'slider': ["Component 's' of type 'Slider': Its 'value' isn't bound to the data model, so it can't be changed."],
  'text_field': [
    "Component 'u' of type 'TextField': Its 'value' isn't bound to the data model, so it can't be changed.",
  ],
};

String _reported(A2UIError error) => error.message;

String _fileName(File file) => file.uri.pathSegments.last.replaceFirst('.json', '');
