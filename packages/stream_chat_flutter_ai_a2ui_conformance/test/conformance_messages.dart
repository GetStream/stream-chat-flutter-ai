part of 'a2ui_conformance.dart';

Future<void> _runProcessMessages(Map<String, Object?> testCase) async {
  final checks = _checksFor(testCase);
  final harness = _Harness(_catalogsFor(testCase), checks: checks);
  final steps = _steps(testCase);
  for (final (index, step) in steps.indexed) {
    final messages = _messagesOf(step);
    if (messages == null) continue;
    final isLast = index == steps.length - 1;
    final expectError = step['expectError'] ?? step['expect_error'] ?? (isLast ? testCase['expectError'] : null);
    if (expectError != null) {
      harness.errors.clear();
      harness.process(messages);
      await harness.resolveSurfaces();
      _assertErrorMatches(expectError, harness.errors);
    } else {
      harness.errors.clear();
      harness.process(messages);
      await harness.resolveSurfaces();
      expect(
        harness.errors.where((error) => !_isExpectedOf(error, checks: checks)),
        isEmpty,
        reason: 'A step that expects no error reported one.',
      );
      final expected = step['expect'] ?? (isLast ? testCase['expect'] : null);
      if (expected != null) await _assertSurfaces(harness, expected);
    }
  }
}

// A problem a step that expects none may still report: a function the case's
// catalog gives only a signature can't run when its call is resolved, and
// without graph checks an unknown component type is accepted, then reported
// when it is resolved.
bool _isExpectedOf(A2UIError error, {required A2UIDebugChecks? checks}) {
  if (error.message.contains('can be checked against but not run')) return true;
  return checks == null && error.code == A2UIErrorCode.unknownComponentType;
}

List<Map<String, Object?>> _steps(Map<String, Object?> testCase) => switch (testCase['steps']) {
  final List<Object?> steps => [
    for (final step in steps)
      if (step is Map<String, Object?>) step,
  ],
  _ => [testCase],
};

List<Object?>? _messagesOf(Map<String, Object?> step) {
  final raw = step['messages'] ?? step['payload'] ?? step['message'];
  if (raw == null) return null;
  if (raw is List<Object?>) return raw;
  return [raw];
}

// The checks of whole trees a case asks for: a `validate` case is strict unless
// it says otherwise, a `process_messages` case only when it says so.
A2UIDebugChecks? _checksFor(Map<String, Object?> testCase) {
  if (testCase['validationConfig'] case final Map<String, Object?> flags) {
    return A2UIDebugChecks(
      allowOrphans: flags['allowOrphanComponents'] == true,
      allowDangling: flags['allowDanglingReferences'] == true,
      allowMissingRoot: flags['allowMissingRoot'] == true,
    );
  }
  final strict = testCase['action'] == 'validate' ? testCase['strictMode'] != false : testCase['strictMode'] == true;
  if (!strict) return null;
  return const A2UIDebugChecks();
}

Future<void> _assertSurfaces(_Harness harness, Object? expected) async {
  final surfaces = (expected! as Map<String, Object?>)['surfaces'];
  if (surfaces is! Map<String, Object?>) return;
  for (final MapEntry(key: surfaceId, value: raw) in surfaces.entries) {
    if (raw is! Map<String, Object?>) continue;
    final surface = harness.processor.surface(surfaceId);
    if (raw['exists'] == false) {
      expect(surface, isNull, reason: 'Surface $surfaceId should not exist.');
      continue;
    }
    expect(surface, isNotNull, reason: 'Surface $surfaceId should exist.');
    surface!;
    if (raw['sendDataModel'] case final Object sendDataModel) expect(surface.sendDataModel, sendDataModel);
    if (raw.containsKey('dataModel')) {
      expect(_jsonEquals(raw['dataModel'], surface.read('/')), isTrue, reason: 'dataModel of $surfaceId');
    }
    if (raw.containsKey('metadata')) {
      expect(_jsonEquals(raw['metadata'], debugMetadata(surface)), isTrue, reason: 'metadata of $surfaceId');
    }
    final resolved = await _resolveComponents(surface);
    if (raw['components'] case final Object components) _assertComponents(surface, resolved, components);
    for (final field in _validationFields) {
      final byComponent = raw[field];
      if (byComponent is! Map<String, Object?>) continue;
      for (final MapEntry(key: componentId, value: value) in byComponent.entries) {
        final node = resolved[componentId];
        expect(node, isNotNull, reason: 'Component $componentId is missing from $surfaceId.');
        _assertContains(value, node!.properties[field], '$componentId.$field');
      }
    }
  }
}

const _validationFields = ['validationResult', 'validationResults', 'isValid', 'validationErrors'];

void _assertComponents(A2UISurface surface, Map<String, _Resolved> resolved, Object expected) {
  final components = debugComponents(surface);
  final entries = switch (expected) {
    final Map<String, Object?> map => map.entries.toList(),
    final List<Object?> list => [
      for (final item in list)
        if (item is Map<String, Object?>) MapEntry(item['id']! as String, item),
    ],
    _ => <MapEntry<String, Object?>>[],
  };
  for (final MapEntry(key: id, value: raw) in entries) {
    final component = components[id];
    final node = resolved[id];
    expect(component != null || node != null, isTrue, reason: 'Component $id is missing.');
    if (raw is! Map<String, Object?>) continue;
    if (raw['component'] case final String type) expect(component?.type ?? node?.type, type, reason: 'type of $id');
    if (raw.containsKey('metadata')) {
      expect(_jsonEquals(raw['metadata'], component?.metadata), isTrue, reason: 'metadata of $id');
    }
    if (node == null) continue;
    for (final MapEntry(:key, :value) in raw.entries) {
      if (key == 'id' || key == 'component' || key == 'metadata') continue;
      _assertContains(value, node.properties[key], '$id.$key');
    }
  }
  if (expected is List<Object?> && entries.every((entry) => components.containsKey(entry.key))) {
    expect(components, hasLength(entries.length), reason: 'component count');
  }
}

// A component of a surface as a case sees it: its type, and its properties
// resolved, except child references, checks and actions, which stay as written.
typedef _Resolved = ({String type, Map<String, Object?> properties});

// Every component reachable from the root, keyed by id, and each item a
// template repeats, keyed by `<id>_<index>`, as the reference harnesses key
// them.
Future<Map<String, _Resolved>> _resolveComponents(A2UISurface surface) async {
  final resolved = <String, _Resolved>{};
  final raw = debugComponents(surface);
  // A component inside a template's item is keyed by the item's index too.
  void visit(A2UINode node, String key, {int? item}) {
    if (resolved.containsKey(key)) return;
    final written = raw[node.id]?.properties ?? const <String, Object?>{};
    final properties = <String, Object?>{};
    for (final MapEntry(key: name, value: value) in written.entries) {
      // A component the catalog can't resolve has only what the agent wrote.
      if (!node.isResolved || name == 'checks' || name == 'action' || node.children(name).isNotEmpty) {
        properties[name] = value;
      } else {
        properties[name] = _caseValue(node.property(name));
      }
    }
    for (final field in ['isValid', 'validationErrors', 'validationResults', 'validationResult']) {
      if (node.property(field) case final Object value) properties[field] = _caseValue(value);
    }
    resolved[key] = (type: node.type, properties: properties);
    for (final name in written.keys) {
      final children = node.children(name);
      final isTemplate = written[name] is Map<String, Object?>;
      for (final (index, child) in children.indexed) {
        if (isTemplate) {
          visit(child, '${child.id}_$index', item: index);
        } else {
          visit(child, item == null ? child.id : '${child.id}_$item', item: item);
        }
      }
      for (final child in _nodesIn(node.property(name))) {
        visit(child, item == null ? child.id : '${child.id}_$item', item: item);
      }
    }
  }

  final root = surface.root;
  if (root != null) visit(root, root.id);
  // Problems in components are reported in microtasks after they are
  // resolved; this lets them run.
  await pumpEventQueue();
  return resolved;
}

Iterable<A2UINode> _nodesIn(Object? value) sync* {
  switch (value) {
    case final A2UINode node:
      yield node;
    case final Map<Object?, Object?> map:
      for (final item in map.values) {
        yield* _nodesIn(item);
      }
    case final List<Object?> list:
      for (final item in list) {
        yield* _nodesIn(item);
      }
  }
}

// The value with the nodes inside it written as the ids of their components.
Object? _caseValue(Object? value) => switch (value) {
  final A2UINode node => node.id,
  final Map<Object?, Object?> map => {for (final MapEntry(:key, :value) in map.entries) '$key': _caseValue(value)},
  final List<Object?> list => [for (final item in list) _caseValue(item)],
  _ => value,
};

Future<void> _runRendererDataModel(Map<String, Object?> testCase) async {
  final harness = _Harness(_catalogsFor(testCase));
  for (final step in _steps(testCase)) {
    final messages = _messagesOf(step);
    if (messages != null) harness.process(messages);
  }
  final args = testCase['args'] as Map<String, Object?>?;
  final actual = debugRendererDataModel(harness.processor, version: args?['version'] as String?);
  if (testCase['expect'] == null) {
    expect(actual, isNull);
    return;
  }
  _assertContains(testCase['expect'], actual);
}
