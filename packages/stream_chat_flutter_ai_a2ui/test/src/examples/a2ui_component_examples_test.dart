import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';
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
      // The page shows its own component.
      expect(_types(json), contains(_typeOf(name)), reason: name);
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

// The component types the example's messages use.
Set<String> _types(Map<String, Object?> json) {
  final types = <String>{};
  void walk(Object? value) {
    if (value case {'id': String _, 'component': final String type}) types.add(type);
    if (value is Map<String, Object?>) value.values.forEach(walk);
    if (value is List<Object?>) value.forEach(walk);
  }

  walk(json['messages']);
  return types;
}

// `audio_player` as `AudioPlayer`.
String _typeOf(String name) => A2UICatalog.basic.types.singleWhere((type) => _snake(type) == name);

String _snake(String type) {
  return type.replaceAllMapped(RegExp('(?<!^)[A-Z]'), (match) => '_${match[0]}').toLowerCase();
}

String _reported(A2UIError error) => error.message;

String _fileName(File file) => file.uri.pathSegments.last.replaceFirst('.json', '');
