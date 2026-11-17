// The conformance cases and keys this package doesn't run yet, each with the
// reason. iOS and Android run every case of the parser fixtures and have no
// skip list; this package runs all of those too. The skips below are of the
// specification's own fixtures, which the platforms reach only through the
// parser fixtures' `v1-spec/*` cases.

/// The areas of the specification's fixtures this package runs.
const specAreasRun = ['grammar', 'entry', 'errors'];

/// The areas of the specification's fixtures this package doesn't run yet,
/// each with the reason.
const specAreasSkipped = {
  'actions': _needsRuntime,
  'state': _needsRuntime,
  'evaluation': 'Evaluating programs is not part of the package yet.',
  'streaming': 'Reading a program as it streams in is not part of the package yet.',
  'editing': "Merging an edit into an earlier program isn't part of the package.",
};

const _needsRuntime = "Running a program's state, forms and actions is not part of the package yet.";

const _needsEvaluating =
    "The tree's values come from evaluating it (operators, member reads, a ternary entry, a library function), "
    'which the evaluator does.';

const _rootNeedsEvaluating = {
  'grammar/006-lex-minus-and-skip',
  'grammar/008-expr-precedence-and-keys',
  'grammar/009-member-digits-field',
  'entry/006-ternary-root-multiline',
  'errors/002-unknown-function-null',
  'errors/014-function-literal-args',
};

/// The names of the specification's cases whose rendered tree isn't compared
/// yet.
Set<String> get specRootSkips => _rootNeedsEvaluating;

/// Why the rendered tree of the specification's case [name] isn't compared,
/// or `null` when it is.
String? specRootSkipReason(String name) => _rootNeedsEvaluating.contains(name) ? _needsEvaluating : null;

/// Why the second half of the specification's case [name], serializing the
/// tree and reading it back, isn't run, or `null` when the case has none.
String? specRoundtripSkipReason(String name) {
  if (!name.contains('-roundtrip-')) return null;
  return 'Writing a tree back as OpenUI Lang is not part of this package; the tree itself is compared.';
}
