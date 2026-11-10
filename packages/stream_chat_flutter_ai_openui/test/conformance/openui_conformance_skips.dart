// The conformance cases and keys this package doesn't run yet, each with the
// reason. iOS and Android run every case of the parser fixtures and have no
// skip list; this package runs all of those too. The skips below are of the
// specification's own fixtures, which the platforms reach only through the
// parser fixtures' `v1-spec/*` cases, and of the one evaluator case whose
// result needs the locale's collation.

/// The areas of the specification's fixtures this package runs.
const specAreasRun = ['grammar', 'entry', 'errors', 'streaming', 'evaluation', 'actions', 'state', 'editing'];

const _needsPatternMatcher =
    "A `pattern` rule needs a regular expression matcher that can't freeze the app, which the package doesn't have yet.";

/// Why the validation case with [rules] isn't run, or `null` when it is.
String? specValidationSkipReason(Object? rules) =>
    rules is Map<String, Object?> && rules.containsKey('pattern') ? _needsPatternMatcher : null;

const _needsCollation =
    "@Sort orders text with the locale's collation, which puts accented letters next to their base letter; "
    "the package doesn't collate by locale yet.";

/// The specification's cases whose rendered tree isn't compared, by name,
/// with the reason.
const _rootSkips = {'evaluation/008-builtin-sort-locale': _needsCollation};

/// Why the rendered tree of the specification's case [name] isn't compared,
/// or `null` when it is.
String? specRootSkipReason(String name) => _rootSkips[name];

/// Why the evaluator case [name] isn't run, or `null` when it is.
String? evaluatorCaseSkipReason(String name) =>
    name == 'corpus-v1-spec/evaluation/008-builtin-sort-locale' ? _needsCollation : null;

/// Why the second half of the specification's case [name], serializing the
/// tree and reading it back, isn't run, or `null` when the case has none.
String? specRoundtripSkipReason(String name) {
  if (!name.contains('-roundtrip-')) return null;
  return 'Writing a tree back as OpenUI Lang is not part of this package; the tree itself is compared.';
}
