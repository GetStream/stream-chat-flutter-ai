part of 'openui_conformance.dart';

/// Registers a test for each case of the area named `area` of the OpenUI Lang
/// specification's fixtures, `upstream/spec/fixtures/1.0/<area>/`, and one
/// that checks the area has cases.
///
/// A case's program is read with the specification's test library, and what
/// reading gives is compared with its `expected.json` by the specification's
/// rules: errors as a multiset of their codes and statements, unresolved
/// names and orphans as sets, `incomplete`, the state's defaults when listed,
/// the listed fields of the error objects, and the rendered tree, summarized.
void runSpecConformanceArea(String area) {
  final cases = _specCases(area);

  test('the $area area has cases', () {
    expect(cases, isNotEmpty);
  });

  for (final directory in cases) {
    final name = '$area/${directory.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty)}';
    final input = File('${directory.path}/input.oui').readAsStringSync();
    final expected = jsonDecode(File('${directory.path}/expected.json').readAsStringSync()) as Map<String, Object?>;
    final schema = conformanceLibraries()['spec']!;

    test('$name: errors', () {
      final actual = debugParse(schema, input);

      expect(_unmatchedErrors(_errors(actual), expected['errors']! as List<Object?>), isEmpty);
    });

    test('$name: unresolved', () {
      final actual = debugParse(schema, input);

      expect(
        (actual['meta']! as Map<String, Object?>)['unresolved'],
        unorderedEquals(expected['unresolved']! as List<Object?>),
      );
    });

    test('$name: orphans', () {
      final actual = debugParse(schema, input);

      expect(
        (actual['meta']! as Map<String, Object?>)['orphaned'],
        unorderedEquals(expected['orphans']! as List<Object?>),
      );
    });

    test('$name: incomplete', () {
      final actual = debugParse(schema, input);

      expect((actual['meta']! as Map<String, Object?>)['incomplete'], expected['incomplete']);
    });

    if (expected['state'] case final Map<String, Object?> state) {
      test('$name: state', () {
        final actual = debugParse(schema, input);

        expect(firstDifference(actual['stateDeclarations'], state), isNull);
      });
    }

    if (expected['errorObjects'] case final List<Object?> errorObjects) {
      test('$name: error objects', () {
        final errors = debugParseErrors(schema, input);
        final actual = [
          for (final error in errors)
            {
              'source': error.source as String,
              'code': error.code as String,
              'statementId': error.statementId,
              'component': error.component,
              'path': error.path,
            },
        ];

        expect(_unmatchedObjects(actual, errorObjects), isEmpty);
      });
    }

    test('$name: root', () {
      final actual = debugParse(schema, input);

      expect(firstDifference(canonicalTree(actual['root']), expected['root']), isNull);
    }, skip: specRootSkipReason(name));

    if (specRoundtripSkipReason(name) case final reason?) {
      test('$name: the serialized tree parses back', () {}, skip: reason);
    }
  }
}

/// Whether reading the case [name] of the specification gives a tree that
/// holds an expression, or an entry that picks its component only when
/// evaluated: either only evaluating can summarize.
bool specRootNeedsEvaluating(String name) {
  final directory = '$_specRoot/$name';
  final input = File('$directory/input.oui').readAsStringSync();
  final result = debugParse(conformanceLibraries()['spec']!, input);
  return result.containsKey('rootExpression') || _holdsExpression(result['root']);
}

/// The names of the specification's cases in [area], such as
/// `grammar/003-fence-multiple-joined`.
List<String> specCaseNames(String area) {
  return [
    for (final directory in _specCases(area)) '$area/${directory.uri.pathSegments.lastWhere((s) => s.isNotEmpty)}',
  ];
}

const _specRoot = 'test/conformance/upstream/spec/fixtures/1.0';

List<Directory> _specCases(String area) {
  final directories = Directory('$_specRoot/$area').listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return directories;
}

/// The tree [value] gives, summarized as the specification's fixtures write
/// it: a component as `{type, props}` without its `null` props, and values as
/// they are.
Object? canonicalTree(Object? value) {
  if (value is List<Object?>) return [for (final item in value) canonicalTree(item)];
  if (value is! Map<String, Object?>) return value;
  if (value['type'] == 'element') {
    final props = value['props']! as Map<String, Object?>;
    return {
      'type': value['typeName'],
      'props': {
        for (final MapEntry(:key, :value) in props.entries)
          if (value != null) key: canonicalTree(value),
      },
    };
  }
  return {for (final MapEntry(:key, :value) in value.entries) key: canonicalTree(value)};
}

const _astKinds = {
  'Comp', 'Str', 'Num', 'Bool', 'Null', 'Arr', 'Obj', 'Ref', 'Ph', //
  'StateRef', 'RuntimeRef', 'BinOp', 'UnaryOp', 'Ternary', 'Member', 'Index', 'Assign',
};

bool _holdsExpression(Object? value) {
  if (value is List<Object?>) return value.any(_holdsExpression);
  if (value is! Map<String, Object?>) return false;
  if (value['type'] != 'element' && _astKinds.contains(value['k'])) return true;
  return value.values.any(_holdsExpression);
}

List<Map<String, Object?>> _errors(Map<String, Object?> result) {
  final meta = result['meta']! as Map<String, Object?>;
  return (meta['errors']! as List<Object?>).cast<Map<String, Object?>>();
}

// The expected errors no reported error matches, each matched once. An
// expected error without a statement matches any statement; every reported
// error must be matched too.
List<Object?> _unmatchedErrors(List<Map<String, Object?>> actual, List<Object?> expected) {
  final remaining = [...actual];
  final unmatched = <Object?>[];
  for (final entry in expected.cast<Map<String, Object?>>()) {
    final index = remaining.indexWhere((error) {
      if (error['code'] != entry['code']) return false;
      return !entry.containsKey('statementId') || error['statementId'] == entry['statementId'];
    });
    if (index == -1) {
      unmatched.add(entry);
    } else {
      remaining.removeAt(index);
    }
  }
  return [...unmatched, for (final error in remaining) 'unexpected ${error['code']} in ${error['statementId']}'];
}

// The expected error objects no reported one matches on the keys they list,
// each matched once.
List<Object?> _unmatchedObjects(List<Map<String, Object?>> actual, List<Object?> expected) {
  final remaining = [...actual];
  final unmatched = <Object?>[];
  for (final entry in expected.cast<Map<String, Object?>>()) {
    final index = remaining.indexWhere((error) => entry.entries.every((field) => error[field.key] == field.value));
    if (index == -1) {
      unmatched.add(entry);
    } else {
      remaining.removeAt(index);
    }
  }
  return unmatched;
}
