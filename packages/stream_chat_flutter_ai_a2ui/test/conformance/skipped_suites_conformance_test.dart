@Tags(['conformance'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'a2ui_conformance.dart';

// The vendored suites this package doesn't run, each with the reason.
void main() {
  for (final suite in ['message_processor_v0_8', 'message_processor_v0_9', 'validator_v0_8', 'validator_v0_9']) {
    skipConformanceSuite(suite, reason: 'Earlier versions of A2UI: this package reads A2UI 1.0.');
  }
  skipConformanceSuite(
    'agent_to_renderer',
    reason: 'Checks the published schema documents of the messages, not how a renderer behaves.',
  );
  skipConformanceSuite(
    'common_types',
    reason: 'Checks the published schema documents of the common types, not how a renderer behaves.',
  );
  skipConformanceSuite(
    'catalog',
    reason: 'Reads and writes catalog documents; this package builds its catalogs in code.',
  );
  skipConformanceSuite(
    'multi_catalog',
    reason: 'Picks a catalog per component and function call; this package names one catalog per surface.',
  );
  skipConformanceSuite(
    'node_resolution',
    reason: 'Its fixtures draw from the A2UI 0.9.1 basic catalog, which this package does not read.',
  );
  skipConformanceSuite('accessibility', reason: 'About drawn components, which this package does not draw yet.');
  skipConformanceSuite(
    'adapter_conformance',
    reason: 'About drawn components, which this package does not draw yet.',
  );
  skipConformanceSuite(
    'message_processor_scaling',
    reason: "Compares how long processing takes, and this package's tests don't measure time.",
  );
}
