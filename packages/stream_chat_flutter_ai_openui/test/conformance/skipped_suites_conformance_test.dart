@Tags(['conformance'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'openui_conformance.dart';
import 'openui_conformance_skips.dart';

// The vendored fixtures this package doesn't run yet, each with the reason.
void main() {
  skipConformanceSuite(
    'parser streaming (`chunks`, `checkpoints`, `streamResults`, `completeResult` of parser-conformance.json)',
    reason: 'Reading a program as it streams in is not part of the package yet.',
  );
  skipConformanceSuite(
    'evaluator-conformance.json',
    reason: 'Evaluating programs is not part of the package yet.',
  );
  skipConformanceSuite(
    'spec-interactions.json',
    reason: "Running a program's state, forms and actions is not part of the package yet.",
  );
  skipConformanceSuite(
    'library specs (upstream-chat-library.spec.json, upstream-playground-library.spec.json)',
    reason: "The package doesn't define the chat and standard libraries yet; it reads their specs to parse.",
  );
  skipConformanceSuite('prompt-goldens.json', reason: 'Generating system prompts is not part of the package yet.');
  for (final MapEntry(key: area, value: reason) in specAreasSkipped.entries) {
    skipConformanceSuite('specification $area', reason: reason);
  }
}
