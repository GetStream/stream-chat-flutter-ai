import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/query_manager.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/tool_provider.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

import 'fake_timers.dart';
import 'fake_tools.dart';

OpenUIValue _v(Object? json) => OpenUIValue.fromJson(json);

QueryNode _query(Object? args, {double? refresh, Object? defaults}) => QueryNode(
  statementId: 'q',
  toolName: 'list',
  args: _v(args),
  defaults: _v(defaults),
  refreshSeconds: refresh,
);

void main() {
  late FakeTimers timers;
  late FakeTools tools;
  late QueryManager manager;

  setUp(() {
    timers = FakeTimers();
    tools = FakeTools();
    manager = QueryManager(tools: tools, timer: timers.call);
  });

  group('cacheKey', () {
    test('sorts the keys of the args at every level', () {
      expect(
        QueryManager.cacheKey(
          't',
          _v({
            'b': 1,
            'a': {'d': 2, 'c': 3},
          }),
          null,
        ),
        QueryManager.cacheKey(
          't',
          _v({
            'a': {'c': 3, 'd': 2},
            'b': 1,
          }),
          null,
        ),
      );
      expect(QueryManager.cacheKey('t', _v({'a': 1}), null), 't::{"a":1}');
    });

    test('adds the dependencies when there are any', () {
      expect(QueryManager.cacheKey('t', _v({}), _v({r'$s': 'x'})), r't::{}::{"$s":"x"}');
      expect(QueryManager.cacheKey('t', _v({}), _v(null)), 't::{}');
    });

    test('names what JSON has no text for', () {
      expect(QueryManager.stableJson(null), '"__undefined__"');
      expect(QueryManager.stableJson(const OpenUINumber(double.nan)), '"__NaN__"');
      expect(QueryManager.stableJson(const OpenUINumber(double.negativeInfinity)), '"__-Inf__"');
    });
  });

  test('a query reads its defaults, then its result', () async {
    manager.updateQueries([
      _query({}, defaults: {'rows': <Object?>[]}),
    ]);

    expect(manager.result('q'), _v({'rows': <Object?>[]}));
    expect(manager.snapshot.loading, ['q']);
    tools.calls.single.answer.complete(
      _v({
        'rows': [1],
      }),
    );
    await pumpMicrotasks();

    expect(
      manager.result('q'),
      _v({
        'rows': [1],
      }),
    );
    expect(manager.snapshot.loading, isEmpty);
    expect(tools.calls.single.userInitiated, isFalse);
  });

  test('changed args fetch once they stay the same for 300 ms, keeping the data shown', () async {
    tools.results['list'] = _v('first');
    manager.updateQueries([
      _query({'s': 'a'}),
    ]);
    await pumpMicrotasks();
    tools.results.remove('list');

    manager.updateQueries([
      _query({'s': 'ab'}),
    ]);
    await timers.elapse(const Duration(milliseconds: 200));
    manager.updateQueries([
      _query({'s': 'abc'}),
    ]);
    await timers.elapse(const Duration(milliseconds: 299));

    expect(tools.calls, hasLength(1));
    expect(manager.result('q'), _v('first'));
    expect(manager.snapshot.refetching, ['q']);
    await timers.elapse(const Duration(milliseconds: 1));
    expect(tools.calls, hasLength(2));
    expect(tools.calls.last.args, {'s': _v('abc')});
  });

  test('a result for args the query no longer has is dropped', () async {
    manager
      ..updateQueries([
        _query({'s': 'a'}),
      ])
      ..updateQueries([
        _query({'s': 'b'}),
      ]);
    tools.calls.first.answer.complete(_v('stale'));
    await pumpMicrotasks();

    expect(manager.result('q'), _v(null));
    expect(manager.snapshot.loading, ['q']);
    await timers.elapse(const Duration(milliseconds: 300));
    tools.calls.last.answer.complete(_v('fresh'));
    await pumpMicrotasks();
    expect(manager.result('q'), _v('fresh'));
  });

  test('coming back to args whose fetch is in flight uses that fetch', () async {
    manager.updateQueries([
      _query({'s': 'a'}),
    ]);
    tools.calls.single.answer.complete(_v('a'));
    await pumpMicrotasks();
    manager.updateQueries([
      _query({'s': 'b'}),
    ]);
    await timers.elapse(const Duration(milliseconds: 300));
    manager
      ..updateQueries([
        _query({'s': 'c'}),
      ])
      ..updateQueries([
        _query({'s': 'b'}),
      ]);
    tools.calls.last.answer.complete(_v('b'));
    await pumpMicrotasks();

    expect(manager.result('q'), _v('b'));
    expect(manager.snapshot.loading, isEmpty);
    expect(tools.calls, hasLength(2));
  });

  test('a provider that throws instead of failing its future fails the fetch', () async {
    final throwing = QueryManager(tools: _ThrowingTools(), timer: timers.call)
      ..updateQueries([_query({}, defaults: 'd')]);
    await pumpMicrotasks();

    expect(throwing.snapshot.errors.single.code, OpenUIErrorCode.toolError);
    expect(throwing.snapshot.loading, isEmpty);
  });

  test('invalidating a query in flight fetches it once more when it is done', () async {
    manager
      ..updateQueries([_query({})])
      ..invalidate(['q'])
      ..invalidate(['q']);

    expect(tools.calls, hasLength(1));
    tools.calls.single.answer.complete(_v(1));
    await pumpMicrotasks();
    expect(tools.calls, hasLength(2));
  });

  group('refresh', () {
    test('never runs more often than every 5 seconds', () async {
      tools.results['list'] = _v(1);
      manager.updateQueries([_query({}, refresh: 1)]);
      await pumpMicrotasks();
      await timers.elapse(const Duration(milliseconds: 4999));

      expect(tools.calls, hasLength(1));
      await timers.elapse(const Duration(milliseconds: 1));
      expect(tools.calls, hasLength(2));
      await timers.elapse(const Duration(seconds: 5));
      expect(tools.calls, hasLength(3));
    });

    test('periods are clamped to a millisecond and 2^31 - 1 milliseconds', () {
      final unlimited = QueryManager(minimumRefresh: Duration.zero);

      expect(unlimited.refreshPeriod(0.0000001), const Duration(milliseconds: 1));
      expect(unlimited.refreshPeriod(1000000000000), const Duration(milliseconds: 2147483647));
      expect(manager.refreshPeriod(double.nan), const Duration(seconds: 5));
      expect(manager.refreshPeriod(30), const Duration(seconds: 30));
    });

    test('pausing stops the timers and resuming starts them again', () async {
      tools.results['list'] = _v(1);
      manager.updateQueries([_query({}, refresh: 5)]);
      await pumpMicrotasks();
      manager.pause();
      await timers.elapse(const Duration(seconds: 20));

      expect(tools.calls, hasLength(1));
      manager.resume();
      await timers.elapse(const Duration(seconds: 5));
      expect(tools.calls, hasLength(2));
    });
  });

  test('a failed fetch reports the error its kind gives', () async {
    manager.updateQueries([_query({})]);
    tools.calls.single.answer.completeError(const ToolNotFoundException('list', availableTools: ['other']));
    await pumpMicrotasks();

    final error = manager.snapshot.errors.single;
    expect(error.code, OpenUIErrorCode.toolNotFound);
    expect(error.hint, 'Available tools: other');
    expect(
      QueryManager.queryError(const McpToolException('x'), OpenUIErrorSource.query, 'q', 'list').code,
      OpenUIErrorCode.mcpError,
    );
    expect(
      QueryManager.queryError(StateError('x'), OpenUIErrorSource.mutation, 'm', 't').code,
      OpenUIErrorCode.toolError,
    );
  });

  group('mutations', () {
    setUp(() => manager.updateMutations({'m': 'save'}));

    test('are idle, then loading, then succeed', () async {
      expect(manager.result('m'), _v({'status': 'idle', 'data': null, 'error': null}));
      final run = manager.runMutation('m', {'a': _v(1)});

      expect((manager.result('m')! as OpenUIObject).fields['status'], _v('loading'));
      tools.calls.single.answer.complete(_v('ok'));

      expect(await run, isTrue);
      expect(manager.result('m'), _v({'status': 'success', 'data': 'ok', 'error': null}));
      expect(tools.calls.single.userInitiated, isTrue);
    });

    test('a second run while one is loading is rejected', () async {
      final first = manager.runMutation('m', const {});

      expect(await manager.runMutation('m', const {}), isFalse);
      expect(tools.calls, hasLength(1));
      tools.calls.single.answer.complete(_v(1));
      expect(await first, isTrue);
    });

    test('a failure is an error result', () async {
      final run = manager.runMutation('m', const {});
      tools.calls.single.answer.completeError(StateError('boom'));

      expect(await run, isFalse);
      expect((manager.result('m')! as OpenUIObject).fields['status'], _v('error'));
      expect(manager.snapshot.errors.single.code, OpenUIErrorCode.toolError);
    });

    test('disposing during a run puts it back to idle and drops its result', () async {
      final run = manager.runMutation('m', const {});
      manager.dispose();
      tools.calls.single.answer.complete(_v('late'));

      expect(await run, isFalse);
      expect(manager.result('m'), _v({'status': 'idle', 'data': null, 'error': null}));
    });
  });

  test('a fetch answered after dispose changes nothing', () async {
    var changes = 0;
    manager
      ..updateQueries([_query({}, defaults: 'd')])
      ..onChange = () {
        changes += 1;
      }
      ..dispose();
    tools.calls.single.answer.complete(_v('late'));
    await pumpMicrotasks();

    expect(manager.result('q'), _v('d'));
    expect(changes, 0);
  });

  group('a failed query', () {
    QueryNode failing({Object? deps, double? refresh}) => QueryNode(
      statementId: 'q',
      toolName: 'list',
      args: _v({}),
      deps: deps == null ? null : _v(deps),
      refreshSeconds: refresh,
    );

    Future<void> fail(int call) async {
      tools.calls[call].answer.completeError(const ToolNotFoundException('list', availableTools: []));
      await pumpMicrotasks();
    }

    test('is not fetched again when other values change', () async {
      manager.updateQueries([failing()]);
      await fail(0);
      // Evaluating again, as every keystroke in another field does.
      for (var i = 0; i < 3; i += 1) {
        manager.updateQueries([failing()]);
        await timers.elapse(const Duration(milliseconds: 300));
      }

      expect(tools.calls, hasLength(1));
      expect(manager.snapshot.errors, hasLength(1));
      expect(manager.snapshot.loading, isEmpty);
    });

    test('is fetched again when its own dependency changes, and not again once it failed on that', () async {
      manager.updateQueries([
        failing(deps: {r'$a': 1}),
      ]);
      await fail(0);
      manager.updateQueries([
        failing(deps: {r'$a': 2}),
      ]);
      await timers.elapse(const Duration(milliseconds: 300));
      expect(tools.calls, hasLength(2));
      await fail(1);

      manager.updateQueries([
        failing(deps: {r'$a': 2}),
      ]);
      await timers.elapse(const Duration(milliseconds: 300));
      expect(tools.calls, hasLength(2));
    });

    test('is fetched again on returning to its args after other args, even when those failed too', () async {
      for (final otherOk in [true, false]) {
        tools.calls.clear();
        final m = QueryManager(tools: tools, timer: timers.call)
          ..updateQueries([
            failing(deps: {r'$a': 'A'}),
          ]);
        tools.calls[0].answer.completeError(Exception('x'));
        await pumpMicrotasks();
        m.updateQueries([
          failing(deps: {r'$a': 'B'}),
        ]);
        await timers.elapse(const Duration(milliseconds: 300));
        if (otherOk) {
          tools.calls[1].answer.complete(_v('ok'));
        } else {
          tools.calls[1].answer.completeError(Exception('y'));
        }
        await pumpMicrotasks();
        m.updateQueries([
          failing(deps: {r'$a': 'A'}),
        ]);
        await timers.elapse(const Duration(milliseconds: 300));

        expect(tools.calls, hasLength(3), reason: 'other args ok: $otherOk');
        m.dispose();
      }
    });

    test('stays settled for a query still on its key when another query leaves it', () async {
      QueryNode on(String id, Object? deps) => QueryNode(
        statementId: id,
        toolName: 'list',
        args: _v({}),
        deps: _v(deps),
      );
      manager.updateQueries([
        on('a', {'k': 1}),
        on('b', {'k': 1}),
      ]);
      await fail(0);
      manager.updateQueries([
        on('a', {'k': 2}),
        on('b', {'k': 1}),
      ]);
      await timers.elapse(const Duration(milliseconds: 300));
      // Only `a`, on its new args, fetched; `b` stays settled on its failure.
      expect(tools.calls, hasLength(2));
      manager.updateQueries([
        on('a', {'k': 2}),
        on('b', {'k': 1}),
      ]);
      await timers.elapse(const Duration(milliseconds: 300));

      expect(tools.calls, hasLength(2));
    });

    test('is fetched again by invalidate', () async {
      manager.updateQueries([failing()]);
      await fail(0);
      manager.invalidate(['q']);

      expect(tools.calls, hasLength(2));
      await fail(1);
      manager.updateQueries([failing()]);
      expect(tools.calls, hasLength(2));
    });

    test('is fetched again by invalidate while it was already fetching', () async {
      manager
        ..updateQueries([failing()])
        ..invalidate(['q']);
      await fail(0);

      expect(tools.calls, hasLength(2));
    });

    test('has its error cleared by a later success', () async {
      manager.updateQueries([failing()]);
      await fail(0);
      manager.invalidate(['q']);
      tools.calls[1].answer.complete(_v('ok'));
      await pumpMicrotasks();

      expect(manager.snapshot.errors, isEmpty);
      expect(manager.result('q'), _v('ok'));
      manager.updateQueries([failing()]);
      await timers.elapse(const Duration(milliseconds: 300));
      expect(tools.calls, hasLength(2));
    });

    test('is retried by its refresh timer, which keeps running', () async {
      manager.updateQueries([failing(refresh: 5)]);
      await fail(0);
      await timers.elapse(const Duration(seconds: 5));
      expect(tools.calls, hasLength(2));
      await fail(1);
      await timers.elapse(const Duration(seconds: 5));

      expect(tools.calls, hasLength(3));
    });

    test('is not retried while paused, and is again once resumed', () async {
      manager.updateQueries([failing(refresh: 5)]);
      await fail(0);
      manager.pause();
      await timers.elapse(const Duration(seconds: 30));
      expect(tools.calls, hasLength(1));
      manager.resume();
      await timers.elapse(const Duration(seconds: 5));

      expect(tools.calls, hasLength(2));
    });

    test('is not fetched by a second query that reaches its key while the debounce runs', () async {
      QueryNode on(String id, Object? deps) => QueryNode(
        statementId: id,
        toolName: 'list',
        args: _v({}),
        deps: _v(deps),
      );
      manager.updateQueries([
        on('a', {'k': 1}),
        on('b', {'k': 1}),
      ]);
      for (final call in tools.calls) {
        call.answer.complete(_v('ok'));
      }
      await pumpMicrotasks();
      tools.calls.clear();

      manager.updateQueries([
        on('a', {'k': 2}),
        on('b', {'k': 1}),
      ]);
      await timers.elapse(const Duration(milliseconds: 200));
      manager.updateQueries([
        on('a', {'k': 2}),
        on('b', {'k': 2}),
      ]);
      await timers.elapse(const Duration(milliseconds: 100));
      expect(tools.calls, hasLength(1));
      await fail(0);
      await timers.elapse(const Duration(milliseconds: 300));

      expect(tools.calls, hasLength(1));
    });

    test('a first success is not fetched again', () async {
      manager.updateQueries([failing()]);
      tools.calls.single.answer.complete(_v('ok'));
      await pumpMicrotasks();
      manager.updateQueries([failing()]);
      await timers.elapse(const Duration(milliseconds: 300));

      expect(tools.calls, hasLength(1));
    });
  });

  test('without tools nothing fetches and mutations fail', () async {
    final none = QueryManager()
      ..updateQueries([_query({}, defaults: 1)])
      ..updateMutations({'m': 'save'});

    expect(none.result('q'), _v(1));
    expect(await none.runMutation('m', const {}), isFalse);
  });

  test('the snapshot is written with the reserved keys', () {
    manager.updateQueries([_query({})]);

    expect(manager.snapshot.toJson(), containsPair('__openui_loading', ['q']));
    expect(manager.snapshot.toJson().keys, containsAll(['q', '__openui_refetching', '__openui_errors']));
  });
}

final class _ThrowingTools implements OpenUIToolProvider {
  @override
  Future<OpenUIValue> callTool(String name, Map<String, OpenUIValue> args, {required bool userInitiated}) =>
      throw StateError('sync');
}
