import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import '../a2ui_test_app.dart';

// The examples published with A2UI's basic catalog build their surfaces, and
// show them without reporting anything.
void main() {
  final examples = Directory('test/fixtures/upstream_examples').listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('all 43 published examples are here', () {
    expect(examples, hasLength(43));
  });

  test('19 of them use only the components the catalog draws', () {
    expect(examples.where(_drawsWhole), hasLength(19));
  });

  for (final file in examples) {
    final name = file.uri.pathSegments.last;
    // testWidgets takes no reason for a skip.
    test('$name builds a root for each of its surfaces', () {
      final processor = A2UIProcessor(catalogs: A2UICatalogs());
      addTearDown(processor.dispose);

      processor.apply([for (final message in _messages(file)) jsonEncode(message)]);

      expect(processor.surfaceIds, isNotEmpty);
      expect([
        for (final surfaceId in processor.surfaceIds) processor.surface(surfaceId)!.root,
      ], everyElement(isNotNull));
    });

    if (_skips[name] case final reason?) {
      test('$name shows its surfaces without reporting anything', () {}, skip: reason);
      continue;
    }
    testWidgets('$name shows its surfaces without reporting anything', (tester) async {
      final errors = <A2UIError>[];
      final processor = A2UIProcessor(catalogs: A2UICatalogs(), onError: errors.add);
      addTearDown(processor.dispose);

      processor.apply([for (final message in _messages(file)) jsonEncode(message)]);
      for (final surfaceId in processor.surfaceIds) {
        await tester.pumpWidget(surfaceApp(processor.surface(surfaceId)!));
      }
      await tester.pump();

      expect(errors, isEmpty);
    });
  }

  for (final file in examples.where(_drawsWhole)) {
    final name = file.uri.pathSegments.last;
    testWidgets('$name draws every component', (tester) async {
      final processor = A2UIProcessor(catalogs: A2UICatalogs());
      addTearDown(processor.dispose);

      processor.apply([for (final message in _messages(file)) jsonEncode(message)]);
      await tester.pumpWidget(surfaceApp(processor.surface(processor.surfaceIds.single)!));

      expect(find.byType(AIUIEntrance), findsNWidgets(_shownComponents(processor)));
    });
  }
}

// Examples whose errors come from components this package doesn't draw yet.
const _skips = {
  '32_advanced-form-validator.json':
      "a2ui_core 0.4.0 rejects the arguments of the `and` in the example's Button check "
      '(EXPRESSION_ERROR); Button and its checks are not drawn yet.',
};

List<Object?> _messages(File file) =>
    (jsonDecode(file.readAsStringSync()) as Map<String, Object?>)['messages']! as List<Object?>;

// The component types [file] uses.
Set<String> _types(File file) {
  final types = <String>{};
  void walk(Object? value) {
    if (value case {'id': String _, 'component': final String type}) types.add(type);
    if (value is Map<String, Object?>) value.values.forEach(walk);
    if (value is List<Object?>) value.forEach(walk);
  }

  walk(_messages(file));
  return types;
}

bool _drawsWhole(File file) => A2UICatalog.basic.types.toSet().containsAll(_types(file));

// How many components the single surface of [processor] shows: one for each
// node from its root down.
int _shownComponents(A2UIProcessor processor) {
  final root = processor.surface(processor.surfaceIds.single)!.root;
  if (root == null) return 0;
  var count = 0;
  void walk(A2UINode node) {
    count += 1;
    for (final name in ['child', 'children']) {
      node.children(name).forEach(walk);
    }
    // Only the selected tab, the first, shows its child.
    if (node.property('tabs') case [{'child': final A2UINode child}, ...]) walk(child);
  }

  walk(root);
  return count;
}
