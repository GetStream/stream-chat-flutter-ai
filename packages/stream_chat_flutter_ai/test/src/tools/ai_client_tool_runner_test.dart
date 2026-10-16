import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

const _identity = AIClientIdentity(userId: 'me', clientId: 'install-1');

/// A call waiting for [_identity] to run [name].
AIToolCallPart _waitingCall({String id = 'call_1', String name = 'get_location', Map<String, Object?>? arguments}) =>
    AIToolCallPart(
      id: id,
      name: name,
      status: AIToolCallStatus.awaitingClient,
      executor: AIToolExecutor.client,
      targetUserId: 'me',
      targetClientId: 'install-1',
      arguments: arguments,
    );

/// A `get_location` result tool that runs `body`, recording every call it
/// gets.
class _ResultTool extends AIResultClientTool {
  _ResultTool({Future<AIClientToolResult> Function(AIToolCallPart call)? body})
    : _body = body ?? ((_) async => AIClientToolResult.completed(const {'lat': 1}, summary: 'Shared'));

  final Future<AIClientToolResult> Function(AIToolCallPart call) _body;
  final calls = <AIToolCallPart>[];

  @override
  AIToolDefinition get definition => const AIToolDefinition(name: 'get_location', description: 'Test tool');

  @override
  Future<AIClientToolResult> run(AIToolCallPart call) {
    calls.add(call);
    return _body(call);
  }
}

/// A plain, side-effect-only tool, as written before results existed.
class _SideEffectTool implements AIClientTool {
  _SideEffectTool({this.actions});

  final List<AIToolAction>? actions;
  final invocations = <AIToolInvocation>[];
  int ran = 0;

  @override
  AIToolDefinition get definition => const AIToolDefinition(name: 'open_screen', description: 'Opens a screen');

  @override
  List<AIToolAction> handleInvocation(AIToolInvocation invocation) {
    invocations.add(invocation);
    return actions ?? [() => ran++];
  }
}

/// Records what the runner sends, failing the first [failures] attempts.
class _Sender {
  _Sender({this.failures = 0});

  int failures;
  int attempts = 0;
  final sent = <(AIToolCallPart, AIClientToolResult)>[];

  Future<void> call(AIToolCallPart call, AIClientToolResult result) async {
    attempts++;
    if (failures > 0) {
      failures--;
      throw Exception('offline');
    }
    sent.add((call, result));
  }
}

/// Runs [body] with [FlutterError.onError] collecting, and returns what it
/// collected. Lifted before returning, so a failed expectation still reports.
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

AIClientToolRunner _runner({
  required List<AIClientTool> tools,
  required _Sender sender,
  AIClientIdentity identity = _identity,
  int maxAttempts = 3,
  AIClientToolCallErrorCallback? onToolError,
  AIClientToolDeliveryErrorCallback? onDeliveryError,
}) => AIClientToolRunner(
  identity: identity,
  tools: tools,
  send: sender.call,
  maxAttempts: maxAttempts,
  retryDelay: Duration.zero,
  onToolError: onToolError,
  onDeliveryError: onDeliveryError,
);

void main() {
  group('AIClientToolRunner', () {
    group('registrations', () {
      test('are the tools’ definitions, in order', () {
        final runner = _runner(tools: [_ResultTool(), _SideEffectTool()], sender: _Sender());

        expect(runner.toolNames, ['get_location', 'open_screen']);
        expect(runner.registrations, [
          _ResultTool().definition.toJson(),
          _SideEffectTool().definition.toJson(),
        ]);
      });
    });

    group('targeting', () {
      final cases = <String, AIToolCallPart>{
        'another person': _waitingCall().copyWith(targetUserId: 'someone-else'),
        'another install': _waitingCall().copyWith(targetClientId: 'install-2'),
        'no install': const AIToolCallPart(
          id: 'call_1',
          name: 'get_location',
          status: AIToolCallStatus.awaitingClient,
          executor: AIToolExecutor.client,
          targetUserId: 'me',
        ),
        'no id from the agent': _waitingCall().copyWith(hasPayloadId: false),
        'a call that is not awaiting the client': _waitingCall().copyWith(status: AIToolCallStatus.running),
        'a completed call': _waitingCall().copyWith(status: AIToolCallStatus.completed),
        'a server tool': _waitingCall().copyWith(executor: AIToolExecutor.server),
      };

      for (final MapEntry(key: description, value: call) in cases.entries) {
        test('ignores $description', () async {
          final tool = _ResultTool();
          final sender = _Sender();

          await _runner(tools: [tool], sender: sender).runCalls([call]);

          expect(tool.calls, isEmpty);
          expect(sender.attempts, 0);
        });
      }

      test('ignores everything when the identity has no install id', () async {
        final tool = _ResultTool();
        final sender = _Sender();

        await _runner(
          tools: [tool],
          sender: sender,
          identity: const AIClientIdentity(userId: 'me'),
        ).runCalls([_waitingCall()]);

        expect(tool.calls, isEmpty);
        expect(sender.attempts, 0);
      });

      test('runs a call waiting for this device and sends its result', () async {
        final tool = _ResultTool();
        final sender = _Sender();
        final call = _waitingCall(arguments: {'precise': false});

        await _runner(tools: [tool], sender: sender).runCalls([call]);

        expect(tool.calls, [call]);
        expect(sender.sent, [
          (call, AIClientToolResult.completed(const {'lat': 1}, summary: 'Shared')),
        ]);
      });

      test('reads tool calls out of message parts and skips other parts', () async {
        final tool = _ResultTool();
        final sender = _Sender();

        await _runner(tools: [tool], sender: sender).run([
          AIMessagePart.fromReasoning(const AIReasoningPart(id: 'r1', summary: 'thinking')),
          AIMessagePart.fromToolCall(_waitingCall()),
        ]);

        expect(tool.calls.single.id, 'call_1');
        expect(sender.sent, hasLength(1));
      });
    });

    group('dedupe', () {
      test('runs a call once across repeated run calls', () async {
        final tool = _ResultTool();
        final sender = _Sender();
        final runner = _runner(tools: [tool], sender: sender);
        final parts = [AIMessagePart.fromToolCall(_waitingCall())];

        await runner.run(parts);
        await runner.run(parts);
        await runner.run(parts);

        expect(tool.calls, hasLength(1));
        expect(sender.sent, hasLength(1));
      });

      test('runs a call once while it is still in flight', () async {
        final gate = Completer<AIClientToolResult>();
        final tool = _ResultTool(body: (_) => gate.future);
        final sender = _Sender();
        final runner = _runner(tools: [tool], sender: sender);
        final parts = [AIMessagePart.fromToolCall(_waitingCall())];

        final first = runner.run(parts);
        // Every streaming update hands the runner the same, still-waiting call.
        unawaited(runner.run(parts));
        unawaited(runner.run(parts));
        expect(runner.hasPendingWork, isTrue);

        gate.complete(AIClientToolResult.completed('done'));
        await first;
        await runner.run(parts);

        expect(tool.calls, hasLength(1));
        expect(sender.sent, hasLength(1));
        expect(runner.hasPendingWork, isFalse);
      });

      test('runs a duplicate id in one list once', () async {
        final tool = _ResultTool();
        final sender = _Sender();

        await _runner(tools: [tool], sender: sender).runCalls([_waitingCall(), _waitingCall()]);

        expect(tool.calls, hasLength(1));
      });

      test('runs each distinct call', () async {
        final tool = _ResultTool();
        final sender = _Sender();

        await _runner(tools: [tool], sender: sender).runCalls([_waitingCall(), _waitingCall(id: 'call_2')]);

        expect(tool.calls.map((call) => call.id), ['call_1', 'call_2']);
        expect(sender.sent, hasLength(2));
      });
    });

    group('unknown tool', () {
      test('is answered with a failure, once', () async {
        final sender = _Sender();
        final runner = _runner(tools: [_ResultTool()], sender: sender);
        final call = _waitingCall(name: 'not_here');

        await runner.runCalls([call]);
        await runner.runCalls([call]);

        expect(sender.sent, hasLength(1));
        final (_, result) = sender.sent.single;
        expect(result.isFailure, isTrue);
        expect(result.failure, contains('not_here'));
      });
    });

    group('tool failures', () {
      test('a throwing result tool is answered with a failure and reported', () async {
        final tool = _ResultTool(body: (_) async => throw StateError('no GPS'));
        final sender = _Sender();
        final toolErrors = <Object>[];

        final reported = await _collectingErrors(
          () => _runner(
            tools: [tool],
            sender: sender,
            onToolError: (call, error, stack) => toolErrors.add(error),
          ).runCalls([_waitingCall()]),
        );

        expect(sender.sent.single.$2, AIClientToolResult.failed(StateError('no GPS').toString()));
        expect(toolErrors.single, isA<StateError>());
        expect(reported.single.exception, isA<StateError>());
      });

      test('a result tool returning a failure is sent as is, without a report', () async {
        final tool = _ResultTool(body: (_) async => const AIClientToolResult.failed('Location not shared'));
        final sender = _Sender();

        final reported = await _collectingErrors(
          () => _runner(tools: [tool], sender: sender).runCalls([_waitingCall()]),
        );

        expect(sender.sent.single.$2, const AIClientToolResult.failed('Location not shared'));
        expect(reported, isEmpty);
      });

      test('a throwing onToolError is reported, not rethrown', () async {
        final tool = _ResultTool(body: (_) async => throw StateError('no GPS'));
        final sender = _Sender();

        final reported = await _collectingErrors(
          () => _runner(
            tools: [tool],
            sender: sender,
            onToolError: (call, error, stack) => throw StateError('callback'),
          ).runCalls([_waitingCall()]),
        );

        expect(sender.sent, hasLength(1));
        expect(reported, hasLength(2));
      });
    });

    group('side-effect tools', () {
      test('run their actions and complete with no output', () async {
        final tool = _SideEffectTool();
        final sender = _Sender();

        await _runner(tools: [tool], sender: sender).runCalls([
          _waitingCall(name: 'open_screen', arguments: {'screen': 'settings'}),
        ]);

        expect(tool.ran, 1);
        expect(tool.invocations.single.tool.name, 'open_screen');
        expect(tool.invocations.single.args, {'screen': 'settings'});
        expect(sender.sent.single.$2, AIClientToolResult.completed(null));
      });

      test('a failing action is reported, the rest still run, and the call fails', () async {
        var later = 0;
        final tool = _SideEffectTool(actions: [() => throw StateError('boom'), () => later++]);
        final sender = _Sender();

        final reported = await _collectingErrors(
          () => _runner(tools: [tool], sender: sender).runCalls([_waitingCall(name: 'open_screen')]),
        );

        expect(later, 1);
        expect(sender.sent.single.$2.isFailure, isTrue);
        expect(reported.single.exception, isA<StateError>());
      });
    });

    group('delivery', () {
      test('retries a failed send and succeeds on the second attempt', () async {
        final tool = _ResultTool();
        final sender = _Sender(failures: 1);
        final deliveryErrors = <Object>[];

        final reported = await _collectingErrors(
          () => _runner(
            tools: [tool],
            sender: sender,
            onDeliveryError: (call, result, error, stack) => deliveryErrors.add(error),
          ).runCalls([_waitingCall()]),
        );

        expect(sender.attempts, 2);
        expect(sender.sent, hasLength(1));
        expect(tool.calls, hasLength(1), reason: 'a retry resends the result; it does not rerun the tool');
        expect(deliveryErrors, isEmpty);
        expect(reported, isEmpty);
      });

      test('gives up after maxAttempts and reports it', () async {
        final sender = _Sender(failures: 10);
        final deliveryErrors = <(AIToolCallPart, AIClientToolResult)>[];

        final reported = await _collectingErrors(
          () => _runner(
            tools: [_ResultTool()],
            sender: sender,
            maxAttempts: 2,
            onDeliveryError: (call, result, error, stack) => deliveryErrors.add((call, result)),
          ).runCalls([_waitingCall()]),
        );

        expect(sender.attempts, 2);
        expect(sender.sent, isEmpty);
        expect(deliveryErrors.single.$1.id, 'call_1');
        expect(deliveryErrors.single.$2, AIClientToolResult.completed(const {'lat': 1}, summary: 'Shared'));
        expect(reported.single.context.toString(), contains('gave up after 2 attempts'));
      });

      testWidgets('waits retryDelay, doubling it, between attempts', (tester) async {
        final sender = _Sender(failures: 2);
        final runner = AIClientToolRunner(
          identity: _identity,
          tools: [_ResultTool()],
          send: sender.call,
          retryDelay: const Duration(seconds: 1),
        );

        unawaited(runner.runCalls([_waitingCall()]));
        await tester.pump();
        expect(sender.attempts, 1);

        await tester.pump(const Duration(milliseconds: 999));
        expect(sender.attempts, 1);
        await tester.pump(const Duration(milliseconds: 1));
        expect(sender.attempts, 2);

        await tester.pump(const Duration(milliseconds: 1999));
        expect(sender.attempts, 2);
        await tester.pump(const Duration(milliseconds: 1));
        expect(sender.attempts, 3);
        expect(sender.sent, hasLength(1));
      });
    });

    group('dispose', () {
      test('stops taking on new calls', () async {
        final tool = _ResultTool();
        final sender = _Sender();
        final runner = _runner(tools: [tool], sender: sender)..dispose();

        await runner.runCalls([_waitingCall()]);

        expect(runner.isDisposed, isTrue);
        expect(tool.calls, isEmpty);
        expect(sender.attempts, 0);
      });

      test('lets calls in flight finish and send their results, retries included', () async {
        final gate = Completer<AIClientToolResult>();
        final tool = _ResultTool(body: (_) => gate.future);
        final sender = _Sender(failures: 1);
        final runner = _runner(tools: [tool], sender: sender);

        unawaited(runner.runCalls([_waitingCall()]));
        runner.dispose();
        gate.complete(AIClientToolResult.completed('late'));
        await runner.whenIdle();

        expect(sender.attempts, 2);
        expect(sender.sent.single.$2, AIClientToolResult.completed('late'));
        expect(runner.hasPendingWork, isFalse);
      });
    });
  });

  group('AIResultClientTool on the event path', () {
    test('dispatch runs it with the invocation’s arguments', () async {
      final tool = _ResultTool();
      final registry = AIToolRegistry()..register(tool);

      final handled = await registry.dispatch(
        const AIToolInvocation(
          tool: AIInvokedTool(name: 'get_location'),
          args: {'precise': true},
        ),
      );

      expect(handled, isTrue);
      final call = tool.calls.single;
      expect(call.name, 'get_location');
      expect(call.arguments, {'precise': true});
      expect(call.hasPayloadId, isFalse);
      expect(call.executor, AIToolExecutor.client);
    });

    test('the registry finds a tool by name', () {
      final tool = _SideEffectTool();
      final registry = AIToolRegistry()..register(tool);

      expect(registry.toolNamed('open_screen'), same(tool));
      expect(registry.toolNamed('missing'), isNull);
    });

    test('a side-effect tool still dispatches as before', () async {
      final tool = _SideEffectTool();
      final registry = AIToolRegistry()..register(tool);

      expect(await registry.dispatch(const AIToolInvocation(tool: AIInvokedTool(name: 'open_screen'))), isTrue);
      expect(tool.ran, 1);
    });
  });

  group('AIClientIdentity.canRun', () {
    test('matches a call awaiting this person and install', () {
      expect(_identity.canRun(_waitingCall()), isTrue);
    });

    test('never matches without an install id', () {
      expect(const AIClientIdentity(userId: 'me').canRun(_waitingCall()), isFalse);
    });
  });
}
