@Tags(['conformance'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'a2ui_conformance.dart';

const _earlierVersions = 'Earlier versions of A2UI: this package reads A2UI 1.0.';
const _drawn = 'About drawn components, which this package does not draw yet.';

// The vendored suites this package doesn't run, each with the reason.
const _skipped = {
  'message_processor_v0_8': _earlierVersions,
  'message_processor_v0_9': _earlierVersions,
  'validator_v0_8': _earlierVersions,
  'validator_v0_9': _earlierVersions,
  'agent_to_renderer': 'Checks the published schema documents of the messages, not how a renderer behaves.',
  'common_types': 'Checks the published schema documents of the common types, not how a renderer behaves.',
  'catalog': 'Reads and writes catalog documents; this package builds its catalogs in code.',
  'multi_catalog': 'Picks a catalog per component and function call; this package names one catalog per surface.',
  'node_resolution': 'Its fixtures draw from the A2UI 0.9.1 basic catalog, which this package does not read.',
  'accessibility': _drawn,
  'adapter_conformance': _drawn,
  'message_processor_scaling': "Compares how long processing takes, and this package's tests don't measure time.",
};

void main() {
  for (final MapEntry(key: suite, value: reason) in _skipped.entries) {
    skipConformanceSuite(suite, reason: reason);
  }

  // Paths are relative to the package, where its tests run.
  test('every vendored suite is run or skipped', () {
    final run = {
      for (final file in Directory('test').listSync())
        if (file.path.endsWith('_conformance_test.dart'))
          file.uri.pathSegments.last.replaceAll('_conformance_test.dart', ''),
    }..remove('skipped_suites');
    final vendored = {
      for (final file in Directory('test/upstream/conformance/core').listSync())
        if (file.path.endsWith('.yaml')) file.uri.pathSegments.last.replaceAll('.yaml', ''),
    };
    expect(
      vendored.difference({...run, ..._skipped.keys}),
      isEmpty,
      reason: 'Vendored suites neither run nor skipped.',
    );
    expect(run.intersection(_skipped.keys.toSet()), isEmpty, reason: 'Suites both run and skipped.');
  });
}
