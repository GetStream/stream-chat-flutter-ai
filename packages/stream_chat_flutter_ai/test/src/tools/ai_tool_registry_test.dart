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
  });

  final List<String> log;
  final String name;
  final int actionCount;

  /// Runs instead of returning actions, so a test can make handling fail.
  final void Function()? onHandle;

  /// Runs in place of the default logging body, so a test can make an action
  /// fail.
  final Future<void> Function(int index)? actionBody;

  final invocations = <AIToolInvocation>[];

  @override
  AIToolDefinition get definition => AIToolDefinition(name: name, description: 'Records invocations');

  @override
  List<AIToolAction> handleInvocation(AIToolInvocation invocation) {
    invocations.add(invocation);
    onHandle?.call();
    return List.generate(actionCount, (index) {
      return () async {
        if (actionBody case final body?) return body(index);
        log.add('$name#$index');
      };
    });
  }
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

      test('produces one payload per tool, in registration order', () {
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
        // for it. That is expected, and outside the app's control — reporting it
        // would red-screen a debug build over something it cannot fix.
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
      });
    });
  });
}
