/// What a program's statements resolved to, kept between the passes of one
/// stream.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// A statement looked up by name while resolving, with the version it had,
/// or a `null` version when nothing defined it.
typedef StatementRead = ({String name, int? version});

/// What a cached result is kept under: the statement, whether it was resolved
/// as an expression rather than a value, and whether the program was cut
/// short.
typedef CacheKey = ({String name, bool asExpression, bool partial});

/// Where resolving a statement started in the logs and counters of its pass.
typedef ResolveStart = ({
  int reads,
  int errors,
  int unresolved,
  int reached,
  int nodes,
  int cycles,
  int truncations,
  int depth,
  int deepest,
});

/// What each statement resolved to while one program streams in, kept so the
/// next pass can reuse it.
///
/// Each statement has a version that changes whenever its text may have, and
/// each result is kept with the versions of the statements it read. A result
/// stands as long as all of those are unchanged.
final class MaterializationCache {
  /// The version of each statement of the current pass.
  Map<String, int> versions = const {};

  /// The results kept, by statement and how it was resolved.
  final Map<CacheKey, CacheEntry> entries = {};

  /// The `$variables` each statement uses, with the version they were read
  /// from.
  final Map<String, ({int version, List<String> names})> stateReferences = {};

  /// How many nodes were resolved afresh, not reused, over all passes.
  ///
  /// Only the tests read it.
  int debugResolvedNodes = 0;

  /// Whether every statement in `reads` still has the version it was read
  /// with.
  bool isCurrent(List<StatementRead> reads) {
    for (final read in reads) {
      if (versions[read.name] != read.version) return false;
    }
    return true;
  }
}

/// A statement's kept result, with what resolving it read, reported and
/// reached, so that reusing it reports the same.
@immutable
final class CacheEntry {
  /// Creates the kept [result] of a statement of [version].
  const CacheEntry({
    required this.result,
    required this.version,
    required this.reads,
    required this.errors,
    required this.unresolved,
    required this.reached,
    required this.nodes,
    required this.height,
  });

  /// What the statement resolved to.
  final OpenUIValue result;

  /// The statement's version when it was resolved.
  final int? version;

  /// The statements it read, each once, with their versions.
  final List<StatementRead> reads;

  /// The problems it reported.
  final List<ValidationError> errors;

  /// The references it couldn't resolve, once per use.
  final List<String> unresolved;

  /// The statements it reached, each once.
  final List<String> reached;

  /// How many nodes it counted against the node budget.
  final int nodes;

  /// How many levels deep below the statement resolving went.
  final int height;
}
