/// Fetching a program's queries and running its mutations.
///
/// Internal to the package.
@internal
library;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/tool_provider.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

/// Starts a timer that calls `callback` once after `duration`.
typedef OpenUITimerFactory = Timer Function(Duration duration, void Function() callback);

/// A `Query(…)` statement, evaluated.
@immutable
final class QueryNode {
  /// Creates the query [statementId] of the tool [toolName].
  const QueryNode({
    required this.statementId,
    required this.toolName,
    this.args,
    this.defaults,
    this.deps,
    this.refreshSeconds,
  });

  /// The statement's name.
  final String statementId;

  /// The tool it runs.
  final String toolName;

  /// The arguments it runs the tool with.
  final OpenUIValue? args;

  /// What it reads before its first result.
  final OpenUIValue? defaults;

  /// The values of the `$variables` written in its args, which fetch again
  /// when they change.
  final OpenUIValue? deps;

  /// How often it fetches again, in seconds; never when `null` or not above
  /// zero.
  final double? refreshSeconds;
}

/// Fetches queries and runs mutations, as OpenUI's `queryManager.ts` does,
/// with the timing of StreamChatOpenUI and the Android SDK.
///
/// A query fetches when it first appears and when its arguments change —
/// once they have stayed the same for [argumentDebounce] — and again every
/// refresh interval, never more often than [minimumRefresh]. While it
/// fetches it reads its previous data, or its defaults before any; a result
/// for arguments it no longer has is dropped.
final class QueryManager {
  /// Creates a manager that runs tools with [tools]; with none, nothing
  /// fetches and every mutation fails.
  QueryManager({
    this.tools,
    OpenUITimerFactory? timer,
    this.argumentDebounce = const Duration(milliseconds: 300),
    this.minimumRefresh = const Duration(seconds: 5),
  }) : _timer = timer ?? Timer.new;

  /// Runs the tools.
  final OpenUIToolProvider? tools;

  /// How long a query waits after its arguments change before it fetches.
  final Duration argumentDebounce;

  /// The shortest time between two refreshes of a query.
  final Duration minimumRefresh;

  final OpenUITimerFactory _timer;

  /// Called after the data, loading state or errors change.
  void Function()? onChange;

  final _queries = <String, _Query>{};
  final _mutations = <String, _Mutation>{};
  final _cache = <String, _CacheEntry>{};
  bool _disposed = false;
  bool _paused = false;
  int _generation = 0;
  QuerySnapshot _snapshot = QuerySnapshot.empty;

  /// The queries' and mutations' current values, loading state and errors.
  QuerySnapshot get snapshot => _snapshot;

  /// The cache key of a query: its tool, its arguments and its
  /// dependencies, written as JSON with sorted keys.
  static String cacheKey(String toolName, OpenUIValue? args, OpenUIValue? deps) {
    final depsKey = JS.isNullish(deps) ? '' : '::${stableJson(deps)}';
    return '$toolName::${stableJson(args)}$depsKey';
  }

  /// `value` as JSON with the keys of every object sorted, and `undefined`,
  /// `NaN` and the infinities written as named strings.
  static String stableJson(OpenUIValue? value) {
    return switch (value) {
      null => '"__undefined__"',
      OpenUINumber(:final value) when value.isNaN => '"__NaN__"',
      OpenUINumber(:final value) when value.isInfinite => value > 0 ? '"__Inf__"' : '"__-Inf__"',
      OpenUIArray(:final items) => '[${items.map(stableJson).join(',')}]',
      OpenUIObject(:final fields) =>
        '{${[
          for (final key in fields.keys.toList()..sort()) '${JS.jsonStringify(OpenUIString(key))}:${stableJson(fields[key])}',
        ].join(',')}}',
      _ => JS.jsonStringify(value) ?? 'null',
    };
  }

  /// The data `statementId` reads: its result, its previous result while it
  /// fetches again, or its defaults; a mutation's `{status, data, error}`;
  /// absent for neither.
  OpenUIValue? result(String statementId) {
    if (_mutations[statementId] case final mutation?) return mutation.result;
    final query = _queries[statementId];
    if (query == null) return null;
    return _cache[query.key]?.data ?? _cache[query.previousKey]?.data ?? query.defaults;
  }

  /// Brings the queries in line with `nodes`: drops the ones gone, fetches
  /// the new and changed ones, and sets their refresh timers.
  void updateQueries(List<QueryNode> nodes) {
    if (_disposed) return;
    final ids = {for (final node in nodes) node.statementId};
    for (final id in [..._queries.keys]) {
      if (ids.contains(id)) continue;
      final query = _queries.remove(id)!..cancelTimers();
      _cleanUp(query.key);
      _cleanUp(query.previousKey);
    }
    for (final node in nodes) {
      final key = cacheKey(node.toolName, node.args, node.deps);
      var query = _queries[node.statementId];
      var argsChanged = false;
      if (query == null) {
        query = _queries[node.statementId] = _Query(key);
      } else if (query.key != key) {
        // The data shown while it fetches: the last args' data, or, when
        // those never got any, the data shown before them.
        final abandoned = query.key;
        if (_cache[abandoned]?.data != null || query.previousKey == null) {
          final dropped = query.previousKey;
          query.previousKey = abandoned;
          _cleanUp(dropped);
        }
        query.key = key;
        // A failure only settles the key a query is on: once it moves away,
        // coming back fetches again, as for any key that has no data.
        if (_queriesOn(abandoned).isEmpty) _cache[abandoned]?.failed = false;
        _cleanUp(abandoned);
        argsChanged = true;
      }
      query
        ..toolName = node.toolName
        ..args = node.args
        ..defaults = node.defaults;
      final entry = _cache[key];
      final settled = _isSettled(entry);
      if (settled) {
        query.pending?.cancel();
        query.pending = null;
        if (query.loading) {
          // Back on args whose data is cached while a fetch for other args
          // was in flight: that fetch no longer keeps it loading.
          query.loading = false;
          _dropPrevious(query);
        }
      } else if (tools != null && !(entry?.inFlight ?? false)) {
        if (argsChanged) {
          _scheduleFetch(node.statementId, query);
        } else if (query.pending == null) {
          _startFetch(key);
        }
      } else if (entry?.inFlight ?? false) {
        query.loading = true;
      }
      final interval = node.refreshSeconds ?? 0;
      if (interval != query.refreshSeconds) {
        query.refresh?.cancel();
        query
          ..refresh = null
          ..refreshSeconds = interval;
        if (interval > 0 && !_paused) _armRefresh(query);
      }
    }
    _publish();
  }

  /// The time between two refreshes of a query written to refresh every
  /// `seconds`: at least [minimumRefresh], and, like a browser's timers, at
  /// least a millisecond and at most 2^31 - 1 milliseconds.
  Duration refreshPeriod(double seconds) {
    const longest = 2147483647;
    final shortest = minimumRefresh.inMicroseconds / 1000;
    final milliseconds = seconds.isNaN ? shortest : seconds * 1000;
    final clamped = milliseconds < shortest ? shortest : milliseconds;
    return Duration(microseconds: (clamped.clamp(1, longest) * 1000).round());
  }

  void _armRefresh(_Query query) {
    query.refresh = _timer(refreshPeriod(query.refreshSeconds), () {
      if (_disposed || !_queries.values.contains(query)) return;
      if (!(_cache[query.key]?.inFlight ?? false)) _startFetch(query.key);
      _armRefresh(query);
    });
  }

  // Fetches once the args have stayed the same for [argumentDebounce], as a
  // query bound to a field changes with every keystroke. It shows as
  // fetching while it waits, with the data it had.
  void _scheduleFetch(String statementId, _Query query) {
    query.pending?.cancel();
    final key = query.key;
    query
      ..loading = true
      ..pending = _timer(argumentDebounce, () {
        query.pending = null;
        if (_disposed || !identical(_queries[statementId], query) || query.key != key) return;
        final entry = _cache[key];
        if (_isSettled(entry) || (entry?.inFlight ?? false)) {
          query.loading = entry?.inFlight ?? false;
          _publish();
          return;
        }
        _startFetch(key);
      });
  }

  // A query is settled on a cache key once a fetch for it has ended, with data
  // or with an error, and it is not fetching again.
  //
  // Deliberately unlike OpenUI's `queryManager.ts`, which fetches a failed
  // query again on every evaluation: that would call a tool that keeps failing
  // on every keystroke in an unrelated field. A failure counts as settled until
  // `invalidate` (what `@Run(query)` calls), a refresh timer, or a change of the
  // cache key (its args or dependencies) asks for another fetch; the fetch that
  // follows sets the flag again or clears it.
  static bool _isSettled(_CacheEntry? entry) =>
      entry != null && !entry.inFlight && (entry.data != null || entry.failed);

  // Marks `key` as fetching, then runs the tool of the queries on it.
  void _startFetch(String key) {
    final tools = this.tools;
    final query = _queries.values.where((query) => query.key == key).firstOrNull;
    if (tools == null || query == null) return;
    final entry = _cache.putIfAbsent(key, _CacheEntry.new)..inFlight = true;
    for (final waiting in _queriesOn(key)) {
      waiting.loading = true;
    }
    _publish();
    final toolName = query.toolName;
    final args = switch (query.args) {
      OpenUIObject(:final fields) => fields,
      _ => const <String, OpenUIValue>{},
    };
    final generation = _generation;
    // A provider that throws instead of failing its future fails the fetch.
    Future.sync(() => tools.callTool(toolName, args, userInitiated: false)).then(
      (data) => _finishFetch(key, entry, generation, toolName, data: data),
      onError: (Object error) => _finishFetch(key, entry, generation, toolName, error: error),
    );
  }

  void _finishFetch(
    String key,
    _CacheEntry entry,
    int generation,
    String toolName, {
    OpenUIValue? data,
    Object? error,
  }) {
    entry.inFlight = false;
    if (_disposed || generation != _generation) return;
    final waiting = _queriesOn(key);
    if (waiting.isEmpty) {
      // Every query moved on to other args, or left: the result is stale.
      _cleanUp(key);
      _publish();
      return;
    }
    if (error == null) {
      entry
        ..data = data
        ..failed = false;
    } else {
      entry.failed = true;
    }
    var refetch = false;
    for (final query in waiting) {
      query.loading = false;
      if (error == null) {
        query
          ..everFetched = true
          ..error = null;
        _dropPrevious(query);
      } else {
        query.error = queryError(error, OpenUIErrorSource.query, _idOf(query), toolName);
      }
      refetch |= query.needsRefetch;
      query.needsRefetch = false;
    }
    _publish();
    if (refetch) _startFetch(key);
  }

  List<_Query> _queriesOn(String key) => [
    for (final query in _queries.values)
      if (query.key == key) query,
  ];

  String _idOf(_Query query) => _queries.entries.firstWhere((entry) => identical(entry.value, query)).key;

  void _dropPrevious(_Query query) {
    final previous = query.previousKey;
    if (previous == null || previous == query.key) return;
    query.previousKey = null;
    _cleanUp(previous);
  }

  // Removes the cache entry of `key` when no query reads it and no fetch is
  // filling it: a query can come back to args whose fetch is in flight.
  void _cleanUp(String? key) {
    if (key == null || (_cache[key]?.inFlight ?? false)) return;
    if (_queries.values.any((query) => query.key == key || query.previousKey == key)) return;
    _cache.remove(key);
  }

  /// Fetches the queries `statementIds` again, or every query when empty; one
  /// already fetching fetches again once it is done.
  void invalidate([List<String> statementIds = const []]) {
    if (_disposed || tools == null) return;
    final targets = statementIds.isEmpty ? [..._queries.keys] : statementIds;
    for (final id in targets) {
      final query = _queries[id];
      if (query == null) continue;
      if (_cache[query.key]?.inFlight ?? false) {
        query.needsRefetch = true;
      } else {
        _startFetch(query.key);
      }
    }
  }

  /// Brings the mutations in line with `tools`, their tool names by
  /// statement; a mutation whose tool changes is idle again.
  void updateMutations(Map<String, String> tools) {
    _mutations.removeWhere((id, _) => !tools.containsKey(id));
    for (final MapEntry(key: id, value: toolName) in tools.entries) {
      final mutation = _mutations[id];
      if (mutation == null) {
        _mutations[id] = _Mutation(toolName);
      } else if (mutation.toolName != toolName) {
        mutation
          ..toolName = toolName
          ..result = _Mutation.idle
          ..error = null;
      }
    }
    _publish();
  }

  /// Runs the mutation `statementId` with `args`; whether it succeeded.
  ///
  /// A mutation already running is rejected, and so is one with no tool
  /// provider. One still running when the manager is disposed goes back to
  /// idle, and its result is dropped.
  Future<bool> runMutation(String statementId, Map<String, OpenUIValue> args) async {
    final tools = this.tools;
    final mutation = _mutations[statementId];
    if (_disposed || tools == null || mutation == null) return false;
    if (mutation.isLoading) return false;
    final generation = _generation;
    mutation.result = OpenUIValue.fromJson(const {'status': 'loading', 'data': null, 'error': null});
    _publish();
    try {
      final data = await tools.callTool(mutation.toolName, args, userInitiated: true);
      if (_disposed || generation != _generation) return false;
      mutation
        ..result = OpenUIObject({
          'status': const OpenUIString('success'),
          'data': data,
          'error': OpenUINull.instance,
        })
        ..error = null;
      _publish();
      return true;
    } on Object catch (error) {
      if (_disposed || generation != _generation) return false;
      mutation
        ..result = OpenUIObject({
          'status': const OpenUIString('error'),
          'data': OpenUINull.instance,
          'error': OpenUIString(_message(error)),
        })
        ..error = queryError(error, OpenUIErrorSource.mutation, statementId, mutation.toolName);
      _publish();
      return false;
    }
  }

  /// Stops the refresh timers, keeping the queries and their data.
  void pause() {
    _paused = true;
    for (final query in _queries.values) {
      query.refresh?.cancel();
      query.refresh = null;
    }
  }

  /// Starts the refresh timers [pause] stopped.
  void resume() {
    if (!_paused || _disposed) return;
    _paused = false;
    for (final query in _queries.values) {
      if (query.refreshSeconds > 0 && query.refresh == null) _armRefresh(query);
    }
  }

  /// Stops every timer and drops the results of calls still running; a
  /// mutation still running goes back to idle. Nothing fetches afterwards.
  void dispose() {
    _disposed = true;
    _generation += 1;
    onChange = null;
    for (final query in _queries.values) {
      query
        ..cancelTimers()
        ..loading = false
        ..needsRefetch = false;
    }
    for (final mutation in _mutations.values) {
      if (mutation.isLoading) mutation.result = _Mutation.idle;
    }
  }

  void _publish() {
    final values = <String, OpenUIValue>{};
    final loading = <String>[];
    final refetching = <String>[];
    final errors = <OpenUIError>[];
    for (final MapEntry(key: id, value: query) in _queries.entries) {
      values[id] = result(id) ?? OpenUINull.instance;
      if (query.loading) {
        loading.add(id);
        if (query.everFetched) refetching.add(id);
      }
      if (query.error case final error?) errors.add(error);
    }
    for (final MapEntry(key: id, value: mutation) in _mutations.entries) {
      values[id] = mutation.result;
      if (mutation.error case final error?) errors.add(error);
    }
    final next = QuerySnapshot(values: values, loading: loading, refetching: refetching, errors: errors);
    if (next == _snapshot) return;
    _snapshot = next;
    onChange?.call();
  }

  static String _message(Object error) => '$error';

  /// The error a failed call reports: `tool-not-found`, `mcp-error` or
  /// `tool-error`.
  static OpenUIError queryError(Object error, OpenUIErrorSource source, String statementId, String toolName) {
    final kind = source == OpenUIErrorSource.query ? 'Query' : 'Mutation';
    return switch (error) {
      ToolNotFoundException(:final availableTools) => OpenUIError(
        source: source,
        code: OpenUIErrorCode.toolNotFound,
        message: '$kind tool "$toolName" not found',
        statementId: statementId,
        component: kind,
        toolName: toolName,
        hint: availableTools.isEmpty ? null : 'Available tools: ${availableTools.join(', ')}',
      ),
      McpToolException(:final text) => OpenUIError(
        source: source,
        code: OpenUIErrorCode.mcpError,
        message: '$kind "$toolName" returned an error: $text',
        statementId: statementId,
        component: kind,
        toolName: toolName,
      ),
      _ => OpenUIError(
        source: source,
        code: OpenUIErrorCode.toolError,
        message: '$kind "$toolName" failed: ${_message(error)}',
        statementId: statementId,
        component: kind,
        toolName: toolName,
      ),
    };
  }
}

/// The queries' and mutations' values, which are fetching, and their
/// errors.
@immutable
final class QuerySnapshot {
  /// Creates a snapshot.
  const QuerySnapshot({
    required this.values,
    required this.loading,
    required this.refetching,
    required this.errors,
  });

  /// The snapshot of no queries and no mutations.
  static const empty = QuerySnapshot(values: {}, loading: [], refetching: [], errors: []);

  /// What each query and mutation reads, by statement.
  final Map<String, OpenUIValue> values;

  /// The queries fetching.
  final List<String> loading;

  /// The queries fetching again, having had a result.
  final List<String> refetching;

  /// The errors of the last calls.
  final List<OpenUIError> errors;

  /// The snapshot as OpenUI writes it for the host: the values, with the
  /// reserved keys `__openui_loading`, `__openui_refetching` and
  /// `__openui_errors`.
  Map<String, Object?> toJson() => {
    ...values,
    '__openui_loading': loading,
    '__openui_refetching': refetching,
    '__openui_errors': errors,
  };

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is QuerySnapshot &&
        _mapEquals(other.values, values) &&
        _listEquals(other.loading, loading) &&
        _listEquals(other.refetching, refetching) &&
        _listEquals(other.errors, errors);
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(values.keys), Object.hashAll(loading), errors.length);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i += 1) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapEquals(Map<String, OpenUIValue> a, Map<String, OpenUIValue> b) {
    if (a.length != b.length) return false;
    for (final MapEntry(:key, :value) in a.entries) {
      if (b[key] != value) return false;
    }
    return true;
  }
}

final class _Query {
  _Query(this.key);

  String key;
  String? previousKey;
  String toolName = '';
  OpenUIValue? args;
  OpenUIValue? defaults;
  bool loading = false;
  bool everFetched = false;
  bool needsRefetch = false;
  double refreshSeconds = 0;
  Timer? refresh;
  Timer? pending;
  OpenUIError? error;

  void cancelTimers() {
    refresh?.cancel();
    pending?.cancel();
    refresh = null;
    pending = null;
  }
}

final class _Mutation {
  _Mutation(this.toolName);

  static final idle = OpenUIValue.fromJson(const {'status': 'idle', 'data': null, 'error': null});

  String toolName;
  OpenUIValue result = idle;
  OpenUIError? error;

  bool get isLoading =>
      result is OpenUIObject && (result as OpenUIObject).fields['status'] == const OpenUIString('loading');
}

final class _CacheEntry {
  // `null` until a result arrives, which may itself be JSON `null`.
  OpenUIValue? data;
  bool inFlight = false;

  // Whether the last fetch failed; a success clears it.
  bool failed = false;
}
