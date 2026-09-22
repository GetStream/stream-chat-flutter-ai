import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_tool_definition.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_tool_invocation.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_tool_registry.dart';

/// A tool that records what it was asked to do, and appends to [log] when its
/// actions actually run.
class _RecordingTool implements AIClientTool {
  _RecordingTool({
    required this.log,
    this.name = 'greetUser',
    this.actionCount = 1,
    this.onHandle,
    this.actionBody,
    this.syncActions = false,
  });

  final List<String> log;
  final String name;
  final int actionCount;

  /// Runs instead of returning actions, so a test can make handling fail.
  final void Function()? onHandle;

  /// Runs in place of the default logging body, so a test can make an action
  /// fail.
  final FutureOr<void> Function(int index)? actionBody;

  /// Whether the returned actions are plain synchronous closures.
  ///
  /// [AIToolAction] is `FutureOr<void> Function()`, so a tool may legitimately
  /// return a closure that is not `async` at all. A throw from one of those
  /// leaves the action synchronously rather than as a rejected future, which is
  /// a different path out of [AIToolRegistry.dispatch].
  final bool syncActions;

  final invocations = <AIToolInvocation>[];

  @override
  AIToolDefinition get definition => AIToolDefinition(name: name, description: 'Records invocations');

  @override
  List<AIToolAction> handleInvocation(AIToolInvocation invocation) {
    invocations.add(invocation);
    onHandle?.call();
    return List.generate(actionCount, (index) {
      if (syncActions) {
        return () {
          if (actionBody case final body?) return body(index);
          log.add('$name#$index');
        };
      }
      return () async {
        if (actionBody case final body?) return body(index);
        log.add('$name#$index');
      };
    });
  }
}

/// A tool whose `definition` getter answers differently on every call.
///
/// Stands in for the realistic versions — a name read from a mutable field, a
/// locale, or a feature flag.
class _DriftingTool implements AIClientTool {
  int _calls = 0;

  @override
  AIToolDefinition get definition => AIToolDefinition(name: 'drift${_calls++}', description: 'Drifts');

  @override
  List<AIToolAction> handleInvocation(AIToolInvocation invocation) => const [];
}

/// Runs [body] with [FlutterError.onError] collecting instead of failing, and
/// returns what it collected.
///
/// The override is lifted before returning, deliberately: left in place for the
/// rest of the test it would also intercept the test framework's own failure
/// reporting, turning a failed expectation below into a ten-minute hang.
Future<List<FlutterErrorDetails>> _collectingErrors(Future<void> Function() body) async {
  final reported = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = reported.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previousOnError;
  }
  return reported;
}

AIToolInvocation _invocationOf(String name) => AIToolInvocation(tool: AIInvokedTool(name: name));

void main() {
  group('AIToolRegistry', () {
    group('registration', () {
      test('has no payloads until something is registered', () {
        expect(AIToolRegistry().registrationPayloads(), isEmpty);
        expect(AIToolRegistry().toolNames, isEmpty);
      });

      test('produces one payload per tool, in first-registration order', () {
        final log = <String>[];
        final registry = AIToolRegistry()
          ..register(_RecordingTool(log: log, name: 'second'))
          ..register(_RecordingTool(log: log, name: 'first'));

        expect(registry.registrationPayloads().map((payload) => payload['name']), ['second', 'first']);
        expect(registry.toolNames, ['second', 'first']);
      });

      test('lets the last registration under a name win, without duplicating it', () {
        final log = <String>[];
        final replacement = _RecordingTool(log: log, name: 'greetUser');
        final registry = AIToolRegistry()
          ..register(_RecordingTool(log: log, name: 'greetUser'))
          ..register(replacement);

        expect(registry.registrationPayloads(), hasLength(1));
        registry.resolve(_invocationOf('greetUser'));
        expect(replacement.invocations, hasLength(1));
      });

      test('keeps a re-registered tool in its original position', () {
        // Re-registering is blessed as normal — a State.initState that runs
        // again, a hot reload — so it must not quietly reorder the payloads.
        final log = <String>[];
        final registry = AIToolRegistry()
          ..register(_RecordingTool(log: log, name: 'first'))
          ..register(_RecordingTool(log: log, name: 'second'))
          ..register(_RecordingTool(log: log, name: 'first'));

        expect(registry.toolNames, ['first', 'second']);
      });

      test('keys a tool under the name it had when it was registered', () {
        // The registry announces one name to the backend and matches
        // invocations against another if it re-reads a getter that has since
        // changed its answer.
        final registry = AIToolRegistry()..register(_DriftingTool());

        expect(registry.registrationPayloads().map((payload) => payload['name']), registry.toolNames);
      });

      test('rejects an empty tool name in debug', () {
        // The definition's own assert is compile-time for const definitions;
        // this is the net for a name derived at runtime.
        expect(() => AIToolRegistry().register(_RecordingTool(log: [], name: '')), throwsAssertionError);
      });

      test('unregisters a registered tool, and reports whether there was one', () {
        final registry = AIToolRegistry()..register(_RecordingTool(log: [], name: 'greetUser'));

        expect(registry.unregister('greetUser'), isTrue);
        expect(registry.unregister('greetUser'), isFalse);
        expect(registry.registrationPayloads(), isEmpty);
      });
    });

    group('resolve', () {
      test('returns the tool actions without running any of them', () {
        // The whole reason a tool returns actions rather than performing them:
        // the host decides when, and where, they run.
        final log = <String>[];
        final registry = AIToolRegistry()..register(_RecordingTool(log: log, actionCount: 2));

        final actions = registry.resolve(_invocationOf('greetUser'));

        expect(actions, hasLength(2));
        expect(log, isEmpty);
      });

      test('hands the invocation to the tool unchanged', () {
        final log = <String>[];
        final tool = _RecordingTool(log: log);
        final registry = AIToolRegistry()..register(tool);
        final invocation = AIToolInvocation.tryParse({
          'tool': {'name': 'greetUser'},
          'cid': 'messaging:general',
          'args': {'name': 'Ada'},
        })!;

        registry.resolve(invocation);

        expect(tool.invocations.single, same(invocation));
      });

      test('returns null for a name no tool is registered under', () {
        expect(AIToolRegistry().resolve(_invocationOf('greetUser')), isNull);
      });

      test('lets a tool that throws while handling throw through', () {
        // Unlike dispatch: this is a lookup, and a caller reaching for the
        // actions themselves decides what a failure means. Wrapping this in a
        // guard "for symmetry" would turn a crashing tool into a null, which is
        // the one thing null must not mean.
        final registry = AIToolRegistry()
          ..register(
            _RecordingTool(log: [], onHandle: () => throw StateError('no navigator')),
          );

        expect(() => registry.resolve(_invocationOf('greetUser')), throwsStateError);
      });

      test('returns an empty list for a tool that produced no actions', () {
        // Distinct from null: this tool exists and decided there was nothing to
        // do, which is not the same as an invocation nobody claims.
        final registry = AIToolRegistry()..register(_RecordingTool(log: [], actionCount: 0));

        expect(registry.resolve(_invocationOf('greetUser')), isEmpty);
      });
    });

    group('dispatch', () {
      test('runs a registered tool action and reports that it was handled', () async {
        // The end-to-end path a host takes, minus the network: the documented
        // event payload, parsed, routed, run.
        final log = <String>[];
        final tool = _RecordingTool(log: log);
        final registry = AIToolRegistry()..register(tool);
        final invocation = AIToolInvocation.tryParse({
          'type': kClientToolInvocationEventType,
          'cid': 'messaging:general',
          'message_id': '8f3c',
          'tool': {'name': 'greetUser'},
          'args': {'name': 'Ada'},
        })!;

        expect(await registry.dispatch(invocation), isTrue);
        expect(log, ['greetUser#0']);
        expect(tool.invocations.single.args, {'name': 'Ada'});
      });

      test('runs multiple actions in order', () async {
        final log = <String>[];
        final registry = AIToolRegistry()..register(_RecordingTool(log: log, actionCount: 3));

        await registry.dispatch(_invocationOf('greetUser'));

        expect(log, ['greetUser#0', 'greetUser#1', 'greetUser#2']);
      });

      test('waits for an async action before starting the next', () async {
        final log = <String>[];
        final registry = AIToolRegistry()
          ..register(
            _RecordingTool(
              log: log,
              actionCount: 2,
              actionBody: (index) async {
                log.add('start $index');
                await Future<void>.delayed(Duration.zero);
                log.add('end $index');
              },
            ),
          );

        await registry.dispatch(_invocationOf('greetUser'));

        expect(log, ['start 0', 'end 0', 'start 1', 'end 1']);
      });

      test('reports that a tool produced no actions as handled', () {
        final registry = AIToolRegistry()..register(_RecordingTool(log: [], actionCount: 0));

        expect(registry.dispatch(_invocationOf('greetUser')), completion(isTrue));
      });

      test('reports an unregistered name as unhandled, and says nothing to FlutterError', () async {
        // Registrations persist on the server and are re-applied when the agent
        // restarts, so a build that dropped a tool still receives invocations
        // for it. That is expected, and outside the app's control, so routing it
        // to a host's crash reporter would be noise. A debug-only console line
        // names it instead.
        final reported = await _collectingErrors(() async {
          expect(await AIToolRegistry().dispatch(_invocationOf('greetUser')), isFalse);
        });

        expect(reported, isEmpty);
      });

      group('failures', () {
        test('reports a tool that throws while handling, and still says it was handled', () async {
          // The bool means coverage, not success: a crashing tool must not read
          // as "some older build registered this".
          final registry = AIToolRegistry()
            ..register(
              _RecordingTool(log: [], onHandle: () => throw StateError('no navigator')),
            );

          final reported = await _collectingErrors(() async {
            expect(await registry.dispatch(_invocationOf('greetUser')), isTrue);
          });

          expect(reported, hasLength(1));
          expect(reported.single.library, 'stream_chat_flutter_ai');
          expect(reported.single.exception, isStateError);
        });

        test('reports an action that throws, and still runs the ones after it', () async {
          // Stopping partway through would leave the UI half-updated.
          final log = <String>[];
          final registry = AIToolRegistry()
            ..register(
              _RecordingTool(
                log: log,
                actionCount: 3,
                actionBody: (index) async {
                  if (index == 0) throw StateError('first action failed');
                  log.add('ran $index');
                },
              ),
            );

          final reported = await _collectingErrors(() async {
            expect(await registry.dispatch(_invocationOf('greetUser')), isTrue);
          });

          expect(log, ['ran 1', 'ran 2']);
          expect(reported, hasLength(1));
          expect(reported.single.library, 'stream_chat_flutter_ai');
        });

        test('reports an action that fails after an await', () async {
          // What FutureOr<void> buys over VoidCallback: with a plain void return
          // this throw escapes to the zone — a console line in debug, silence in
          // release — and never reaches the host at all.
          final registry = AIToolRegistry()
            ..register(
              _RecordingTool(
                log: [],
                actionBody: (_) async {
                  await Future<void>.delayed(Duration.zero);
                  throw StateError('failed after awaiting');
                },
              ),
            );

          final reported = await _collectingErrors(() async {
            await registry.dispatch(_invocationOf('greetUser'));
          });

          expect(reported, hasLength(1));
          expect(reported.single.exception, isStateError);
        });

        test('reports each failing action separately', () async {
          // No report-once guard here, unlike CodeBlockView's: an invocation is
          // handled once, so there is no rebuild loop to flood.
          final registry = AIToolRegistry()
            ..register(
              _RecordingTool(
                log: [],
                actionCount: 3,
                actionBody: (index) async => throw StateError('action $index failed'),
              ),
            );

          final reported = await _collectingErrors(() async {
            await registry.dispatch(_invocationOf('greetUser'));
          });

          expect(reported, hasLength(3));
        });

        test('catches a synchronous throw from an action that is not async', () async {
          // AIToolAction is FutureOr<void> Function(), so a tool may return a
          // plain closure. Hoisting the call out of the guard would let this
          // escape uncaught while every async-action test still passed.
          final log = <String>[];
          final registry = AIToolRegistry()
            ..register(
              _RecordingTool(
                log: log,
                actionCount: 2,
                syncActions: true,
                actionBody: (index) {
                  if (index == 0) throw StateError('sync failure');
                  log.add('ran $index');
                },
              ),
            );

          final reported = await _collectingErrors(() async {
            expect(await registry.dispatch(_invocationOf('greetUser')), isTrue);
          });

          expect(log, ['ran 1']);
          expect(reported, hasLength(1));
          expect(reported.single.exception, isStateError);
        });

        test('runs a synchronous action that does not throw', () async {
          final log = <String>[];
          final registry = AIToolRegistry()..register(_RecordingTool(log: log, syncActions: true));

          expect(await registry.dispatch(_invocationOf('greetUser')), isTrue);
          expect(log, ['greetUser#0']);
        });

        test('names the failing action, and the tool, in the report context', () async {
          // The context is the only thing that makes a report actionable in a
          // crash reporter, and the 1-based index is exactly the detail that
          // rots unnoticed.
          final registry = AIToolRegistry()
            ..register(
              _RecordingTool(
                log: [],
                actionCount: 3,
                actionBody: (index) async => throw StateError('action $index failed'),
              ),
            );

          final reported = await _collectingErrors(() async {
            await registry.dispatch(_invocationOf('greetUser'));
          });

          expect(
            reported.map((details) => details.context.toString()),
            [
              contains('action 1 of 3'),
              contains('action 2 of 3'),
              contains('action 3 of 3'),
            ],
          );
          expect(reported.every((details) => details.context.toString().contains('greetUser')), isTrue);
          expect(reported.every((details) => details.stack != null), isTrue);
        });

        test('names the handling phase, not an action, when handling throws', () async {
          final registry = AIToolRegistry()
            ..register(
              _RecordingTool(log: [], onHandle: () => throw StateError('no navigator')),
            );

          final reported = await _collectingErrors(() async {
            await registry.dispatch(_invocationOf('greetUser'));
          });

          expect(reported.single.context.toString(), contains('handle an invocation'));
          expect(reported.single.context.toString(), isNot(contains('action')));
        });

        test('carries the invocation, without its argument values, in the report', () async {
          // toString withholds the values by design; this is the one place it
          // is for, and the channel and message are what make a report
          // attributable.
          final registry = AIToolRegistry()
            ..register(
              _RecordingTool(log: [], actionBody: (_) async => throw StateError('boom')),
            );
          final invocation = AIToolInvocation.tryParse({
            'tool': {'name': 'greetUser'},
            'cid': 'messaging:general',
            'args': {'name': 'ACME-SECRET-42'},
          })!;

          final reported = await _collectingErrors(() async {
            await registry.dispatch(invocation);
          });

          final information = reported.single.informationCollector!().join('\n');
          expect(information, contains('messaging:general'));
          expect(information, contains('name'));
          expect(information, isNot(contains('ACME-SECRET-42')));
        });

        test('tells the host through onToolError as well as FlutterError', () async {
          // A global handler cannot tell the user that something did not work.
          final failures = <(String, Object)>[];
          final registry = AIToolRegistry(
            onToolError: (invocation, error, _) => failures.add((invocation.tool.name, error)),
          )..register(_RecordingTool(log: [], actionBody: (_) async => throw StateError('boom')));

          await _collectingErrors(() async {
            await registry.dispatch(_invocationOf('greetUser'));
          });

          expect(failures, hasLength(1));
          expect(failures.single.$1, 'greetUser');
          expect(failures.single.$2, isStateError);
        });

        test('runs the remaining actions when onToolError itself throws', () async {
          // The callback is the host's code, doing what it is documented for:
          // a `ScaffoldMessenger.of` on an unmounted context throws. Reporting
          // a failure must not strand the actions after it.
          final log = <String>[];
          final tool = _RecordingTool(
            log: log,
            actionCount: 3,
            actionBody: (index) async {
              if (index == 0) throw StateError('boom');
              log.add('ran $index');
            },
          );
          final registry = AIToolRegistry(
            onToolError: (_, _, _) => throw StateError('no ScaffoldMessenger'),
          )..register(tool);

          final reported = await _collectingErrors(() async {
            expect(await registry.dispatch(_invocationOf('greetUser')), isTrue);
          });

          expect(log, ['ran 1', 'ran 2']);
          // The action's failure, and the callback's own failure alongside it.
          expect(reported, hasLength(2));
          expect(reported.last.context.toString(), contains('onToolError'));
        });

        test('runs the remaining actions when the host FlutterError handler rethrows', () async {
          // Same stranding, reached through the other half of the report.
          final log = <String>[];
          final registry = AIToolRegistry()
            ..register(
              _RecordingTool(
                log: log,
                actionCount: 3,
                actionBody: (index) async {
                  if (index == 0) throw StateError('boom');
                  log.add('ran $index');
                },
              ),
            );

          final reported = <FlutterErrorDetails>[];
          final previousOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            reported.add(details);
            throw StateError('this host rethrows');
          };
          try {
            expect(await registry.dispatch(_invocationOf('greetUser')), isTrue);
          } finally {
            FlutterError.onError = previousOnError;
          }

          expect(log, ['ran 1', 'ran 2']);
          expect(reported, hasLength(1));
        });
      });
    });

    group('runActions', () {
      test('gives the deferred path the same guarding dispatch has', () async {
        // A host that took the actions from resolve and scheduled them itself
        // would otherwise have to reimplement this, and the await is what keeps
        // a throw after an action's first await out of the zone.
        final log = <String>[];
        final registry = AIToolRegistry()
          ..register(
            _RecordingTool(
              log: log,
              actionCount: 2,
              actionBody: (index) async {
                if (index == 0) {
                  await Future<void>.delayed(Duration.zero);
                  throw StateError('failed after awaiting');
                }
                log.add('ran $index');
              },
            ),
          );

        final invocation = _invocationOf('greetUser');
        final actions = registry.resolve(invocation)!;

        final reported = await _collectingErrors(() async {
          await registry.runActions(invocation, actions);
        });

        expect(log, ['ran 1']);
        expect(reported, hasLength(1));
        expect(reported.single.exception, isStateError);
      });
    });
  });
}
