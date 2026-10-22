import 'dart:async';
import 'dart:convert';

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

final _defaultResult = AIClientToolResult.completed(const {'lat': 1}, summary: 'Shared');

/// A `get_location` result tool that runs `body`, recording every call it
/// gets.
class _ResultTool extends AIResultClientTool {
  _ResultTool({Future<AIClientToolResult> Function(AIToolCallPart call)? body})
    : _body = body ?? ((_) async => _defaultResult);

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
  _SideEffectTool({this.actions, this.onHandle});

  final List<AIToolAction>? actions;
  final void Function()? onHandle;
  final invocations = <AIToolInvocation>[];
  int ran = 0;

  @override
  AIToolDefinition get definition => const AIToolDefinition(name: 'open_screen', description: 'Opens a screen');

  @override
  List<AIToolAction> handleInvocation(AIToolInvocation invocation) {
    invocations.add(invocation);
    onHandle?.call();
    return actions ?? [() => ran++];
  }
}

/// Records what the runner sends, failing the first [failures] attempts, or
/// never completing when [hang] is set.
class _Sender {
  _Sender({this.failures = 0, this.hang = false});

  int failures;
  bool hang;
  int attempts = 0;
  final sent = <(AIToolCallPart, AIClientToolResult)>[];

  Future<void> call(AIToolCallPart call, AIClientToolResult result) async {
    attempts++;
    if (hang) return Completer<void>().future;
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
  Duration retryDelay = Duration.zero,
  Duration? runTimeout,
  Duration? sendTimeout,
  AIClientToolFailureMessage? failureMessage,
  AIClientToolCallErrorCallback? onToolError,
  AIClientToolDeliveryErrorCallback? onDeliveryError,
}) => AIClientToolRunner(
  identity: identity,
  tools: tools,
  send: sender.call,
  maxAttempts: maxAttempts,
  retryDelay: retryDelay,
  runTimeout: runTimeout,
  sendTimeout: sendTimeout,
  failureMessage: failureMessage,
  onToolError: onToolError,
  onDeliveryError: onDeliveryError,
);

const _genericFailure = AIClientToolResult.failed('The "get_location" tool failed on this device');

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

      test('for a duplicate name, the last tool wins', () async {
        final first = _ResultTool();
        final last = _ResultTool();
        final runner = _runner(tools: [first, last], sender: _Sender());

        await runner.handleCalls([_waitingCall()]);

        expect(runner.toolNames, ['get_location']);
        expect(first.calls, isEmpty);
        expect(last.calls, hasLength(1));
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

          await _runner(tools: [tool], sender: sender).handleCalls([call]);

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
        ).handleCalls([_waitingCall()]);

        expect(tool.calls, isEmpty);
        expect(sender.attempts, 0);
      });

      test('runs a call waiting for this device and sends its result', () async {
        final tool = _ResultTool();
        final sender = _Sender();
        final call = _waitingCall(arguments: {'precise': false});

        await _runner(tools: [tool], sender: sender).handleCalls([call]);

        expect(tool.calls, [call]);
        expect(sender.sent, [(call, _defaultResult)]);
      });

      test('reads tool calls out of message parts and skips other parts', () async {
        final tool = _ResultTool();
        final sender = _Sender();

        await _runner(tools: [tool], sender: sender).handle([
          AIMessagePart.fromReasoning(const AIReasoningPart(id: 'r1', summary: 'thinking')),
          AIMessagePart.fromToolCall(_waitingCall()),
        ]);

        expect(tool.calls.single.id, 'call_1');
        expect(sender.sent, hasLength(1));
      });
    });

    group('dedupe', () {
      test('runs a call once across repeated handle calls', () async {
        final tool = _ResultTool();
        final sender = _Sender();
        final runner = _runner(tools: [tool], sender: sender);
        final parts = [AIMessagePart.fromToolCall(_waitingCall())];

        await runner.handle(parts);
        await runner.handle(parts);
        await runner.handle(parts);

        expect(tool.calls, hasLength(1));
        expect(sender.sent, hasLength(1));
      });

      test('runs a call once while it is still in flight', () async {
        final gate = Completer<AIClientToolResult>();
        final tool = _ResultTool(body: (_) => gate.future);
        final sender = _Sender();
        final runner = _runner(tools: [tool], sender: sender);
        final parts = [AIMessagePart.fromToolCall(_waitingCall())];

        final first = runner.handle(parts);
        unawaited(runner.handle(parts));
        unawaited(runner.handle(parts));
        expect(runner.hasPendingWork, isTrue);

        gate.complete(AIClientToolResult.completed('done'));
        await first;
        await runner.handle(parts);

        expect(tool.calls, hasLength(1));
        expect(sender.sent, hasLength(1));
        expect(runner.hasPendingWork, isFalse);
      });

      test('runs a duplicate id in one list once', () async {
        final tool = _ResultTool();

        await _runner(tools: [tool], sender: _Sender()).handleCalls([_waitingCall(), _waitingCall()]);

        expect(tool.calls, hasLength(1));
      });

      test('runs each distinct call', () async {
        final tool = _ResultTool();
        final sender = _Sender();

        await _runner(tools: [tool], sender: sender).handleCalls([_waitingCall(), _waitingCall(id: 'call_2')]);

        expect(tool.calls.map((call) => call.id), ['call_1', 'call_2']);
        expect(sender.sent, hasLength(2));
      });
    });

    group('unknown tool', () {
      test('is answered with a failure once, and reported', () async {
        final sender = _Sender();
        final toolErrors = <Object>[];
        final runner = _runner(
          tools: [_ResultTool()],
          sender: sender,
          onToolError: (call, error, stack) => toolErrors.add(error),
        );
        final call = _waitingCall(name: 'not_here');

        final reported = await _collectingErrors(() async {
          await runner.handleCalls([call]);
          await runner.handleCalls([call]);
        });

        expect(sender.sent.single.$2, const AIClientToolResult.failed('This device has no tool named "not_here"'));
        expect(toolErrors.single, isA<StateError>());
        expect(reported.single.exception.toString(), contains('not_here'));
      });
    });

    group('tool failures', () {
      test('a throwing result tool gets a generic failure; the error stays local', () async {
        final tool = _ResultTool(body: (_) async => throw StateError('secret at /home/me'));
        final sender = _Sender();
        final toolErrors = <Object>[];

        final reported = await _collectingErrors(
          () => _runner(
            tools: [tool],
            sender: sender,
            onToolError: (call, error, stack) => toolErrors.add(error),
          ).handleCalls([_waitingCall()]),
        );

        expect(sender.sent.single.$2, _genericFailure);
        expect(sender.sent.single.$2.toJson().toString(), isNot(contains('secret')));
        expect(toolErrors.single, isA<StateError>());
        expect(reported.single.exception, isA<StateError>());
      });

      test('failureMessage words the failure', () async {
        final tool = _ResultTool(body: (_) async => throw StateError('boom'));
        final sender = _Sender();

        await _collectingErrors(
          () => _runner(
            tools: [tool],
            sender: sender,
            failureMessage: (call, error) => 'Kon ${call.name} niet uitvoeren',
          ).handleCalls([_waitingCall()]),
        );

        expect(sender.sent.single.$2, const AIClientToolResult.failed('Kon get_location niet uitvoeren'));
      });

      test('a throwing failureMessage falls back to the generic failure', () async {
        final tool = _ResultTool(body: (_) async => throw StateError('boom'));
        final sender = _Sender();

        final reported = await _collectingErrors(
          () => _runner(
            tools: [tool],
            sender: sender,
            failureMessage: (call, error) => throw StateError('callback'),
          ).handleCalls([_waitingCall()]),
        );

        expect(sender.sent.single.$2, _genericFailure);
        expect(reported, hasLength(2));
      });

      test('a completed result with unencodable output becomes a failure', () async {
        final tool = _ResultTool(body: (_) async => AIClientToolResult.completed(Object()));
        final sender = _Sender();

        final reported = await _collectingErrors(
          () => _runner(tools: [tool], sender: sender).handleCalls([_waitingCall()]),
        );

        expect(sender.sent.single.$2, _genericFailure);
        expect(reported.single.exception, isA<JsonUnsupportedObjectError>());
      });

      test('a result tool returning a failure is sent as is, without a report', () async {
        final tool = _ResultTool(body: (_) async => const AIClientToolResult.failed('Location not shared'));
        final sender = _Sender();

        final reported = await _collectingErrors(
          () => _runner(tools: [tool], sender: sender).handleCalls([_waitingCall()]),
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
          ).handleCalls([_waitingCall()]),
        );

        expect(sender.sent, hasLength(1));
        expect(reported, hasLength(2));
      });

      test('a throwing FlutterError.onError still sends the failure', () async {
        final tool = _ResultTool(body: (_) async => throw StateError('no GPS'));
        final sender = _Sender();
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (details) => throw StateError('reporter');
        try {
          await _runner(tools: [tool], sender: sender).handleCalls([_waitingCall()]);
        } finally {
          FlutterError.onError = previousOnError;
        }

        expect(sender.sent.single.$2, _genericFailure);
      });

      testWidgets('a tool that runs past runTimeout is answered with a failure', (tester) async {
        final tool = _ResultTool(body: (_) => Completer<AIClientToolResult>().future);
        final sender = _Sender();
        final toolErrors = <Object>[];
        final runner = _runner(
          tools: [tool],
          sender: sender,
          runTimeout: const Duration(seconds: 5),
          onToolError: (call, error, stack) => toolErrors.add(error),
        );

        final reported = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = reported.add;
        unawaited(runner.handleCalls([_waitingCall()]));
        await tester.pump(const Duration(seconds: 5));
        FlutterError.onError = previousOnError;

        expect(sender.sent.single.$2, _genericFailure);
        expect(toolErrors.single, isA<TimeoutException>());
        expect(reported, hasLength(1));
      });
    });

    group('side-effect tools', () {
      test('run their actions and complete with no output', () async {
        final tool = _SideEffectTool();
        final sender = _Sender();

        await _runner(tools: [tool], sender: sender).handleCalls([
          _waitingCall(name: 'open_screen', arguments: {'screen': 'settings'}),
        ]);

        expect(tool.ran, 1);
        expect(tool.invocations.single.tool.name, 'open_screen');
        expect(tool.invocations.single.args, {'screen': 'settings'});
        expect(sender.sent.single.$2, AIClientToolResult.completed(null));
      });

      test('get empty args when the call has no arguments', () async {
        final tool = _SideEffectTool();

        await _runner(tools: [tool], sender: _Sender()).handleCalls([_waitingCall(name: 'open_screen')]);

        expect(tool.invocations.single.args, isEmpty);
      });

      test('failing actions are all reported, the rest still run, and the first error is used', () async {
        var later = 0;
        final first = StateError('first');
        final second = ArgumentError('second');
        final tool = _SideEffectTool(
          actions: [() => throw first, () async => throw second, () => later++],
        );
        final sender = _Sender();
        final toolErrors = <Object>[];

        final reported = await _collectingErrors(
          () => _runner(
            tools: [tool],
            sender: sender,
            onToolError: (call, error, stack) => toolErrors.add(error),
          ).handleCalls([_waitingCall(name: 'open_screen')]),
        );

        expect(later, 1);
        expect(toolErrors, unorderedEquals([first, second]));
        expect(reported.map((details) => details.exception), unorderedEquals([first, second]));
        expect(
          sender.sent.single.$2,
          const AIClientToolResult.failed('The "open_screen" tool failed on this device'),
        );
      });

      test('an async action throwing fails the call', () async {
        final tool = _SideEffectTool(actions: [() async => throw StateError('async')]);
        final sender = _Sender();

        await _collectingErrors(
          () => _runner(tools: [tool], sender: sender).handleCalls([_waitingCall(name: 'open_screen')]),
        );

        expect(sender.sent.single.$2, isA<AIClientToolFailed>());
      });

      test('handleInvocation throwing fails the call and is reported', () async {
        final tool = _SideEffectTool(onHandle: () => throw StateError('handle'));
        final sender = _Sender();
        final toolErrors = <Object>[];

        final reported = await _collectingErrors(
          () => _runner(
            tools: [tool],
            sender: sender,
            onToolError: (call, error, stack) => toolErrors.add(error),
          ).handleCalls([_waitingCall(name: 'open_screen')]),
        );

        expect(sender.sent.single.$2, isA<AIClientToolFailed>());
        expect(toolErrors.single, isA<StateError>());
        expect(reported, hasLength(1));
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
          ).handleCalls([_waitingCall()]),
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
          ).handleCalls([_waitingCall()]),
        );

        expect(sender.attempts, 2);
        expect(sender.sent, isEmpty);
        expect(deliveryErrors.single.$1.id, 'call_1');
        expect(deliveryErrors.single.$2, _defaultResult);
        expect(reported.single.context.toString(), contains('gave up after 2 attempts'));
      });

      test('a throwing onDeliveryError is reported, not rethrown', () async {
        final reported = await _collectingErrors(
          () => _runner(
            tools: [_ResultTool()],
            sender: _Sender(failures: 10),
            maxAttempts: 1,
            onDeliveryError: (call, result, error, stack) => throw StateError('callback'),
          ).handleCalls([_waitingCall()]),
        );

        expect(reported, hasLength(2));
      });

      testWidgets('maxAttempts 1 sends once, without waiting', (tester) async {
        final sender = _Sender(failures: 10);
        final runner = _runner(
          tools: [_ResultTool()],
          sender: sender,
          maxAttempts: 1,
          retryDelay: const Duration(hours: 1),
        );

        final reported = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = reported.add;
        unawaited(runner.handleCalls([_waitingCall()]));
        await tester.pump();
        FlutterError.onError = previousOnError;

        expect(sender.attempts, 1);
        expect(runner.hasPendingWork, isFalse);
        expect(reported, hasLength(1));
      });

      test('after giving up, a later handle resends the stored result without rerunning the tool', () async {
        final tool = _ResultTool();
        final sender = _Sender(failures: 2);
        final runner = _runner(tools: [tool], sender: sender, maxAttempts: 2);

        await _collectingErrors(() => runner.handleCalls([_waitingCall()]));
        expect(sender.sent, isEmpty);

        await runner.handleCalls([_waitingCall()]);

        expect(tool.calls, hasLength(1));
        expect(sender.attempts, 3);
        expect(sender.sent.single.$2, _defaultResult);

        await runner.handleCalls([_waitingCall()]);
        expect(sender.attempts, 3, reason: 'a delivered result is not sent again');
      });

      test('a result given up on again is reported only once', () async {
        final sender = _Sender(failures: 10);
        var deliveryErrors = 0;
        final reported = await _collectingErrors(() async {
          final r = _runner(
            tools: [_ResultTool()],
            sender: sender,
            maxAttempts: 1,
            onDeliveryError: (call, result, error, stack) => deliveryErrors++,
          );
          await r.handleCalls([_waitingCall()]);
          await r.handleCalls([_waitingCall()]);
          await r.handleCalls([_waitingCall()]);
          expect(r.hasUndelivered, isTrue);
        });
        expect(sender.attempts, 3, reason: 'each update still tries again');
        expect(reported, hasLength(1));
        expect(deliveryErrors, 1);
      });

      test('retryUndelivered sends a given-up result again', () async {
        final sender = _Sender(failures: 1);
        final runner = _runner(tools: [_ResultTool()], sender: sender, maxAttempts: 1);
        await _collectingErrors(() => runner.handleCalls([_waitingCall()]));
        expect(runner.hasUndelivered, isTrue);

        await runner.retryUndelivered();
        expect(sender.sent.single.$2, _defaultResult);
        expect(runner.hasUndelivered, isFalse);
      });

      test('an unregistered tool is answered with the failure message too', () async {
        final sender = _Sender();
        await _collectingErrors(
          () => _runner(
            tools: [_ResultTool()],
            sender: sender,
            failureMessage: (call, error) => 'Not on this phone',
          ).handleCalls([_waitingCall(name: 'unknown_tool')]),
        );
        expect(sender.sent.single.$2, const AIClientToolResult.failed('Not on this phone'));
      });

      test('a stored result is dropped once its call no longer waits', () async {
        final tool = _ResultTool();
        final sender = _Sender(failures: 1);
        final runner = _runner(tools: [tool], sender: sender, maxAttempts: 1);

        await _collectingErrors(() => runner.handleCalls([_waitingCall()]));
        await runner.handleCalls([_waitingCall().copyWith(status: AIToolCallStatus.cancelled)]);
        await runner.handleCalls([_waitingCall()]);

        expect(tool.calls, hasLength(1));
        expect(sender.attempts, 1);
      });

      testWidgets('a send that runs past sendTimeout counts as a failed attempt', (tester) async {
        final sender = _Sender(hang: true);
        final deliveryErrors = <Object>[];
        final runner = _runner(
          tools: [_ResultTool()],
          sender: sender,
          maxAttempts: 2,
          sendTimeout: const Duration(seconds: 3),
          onDeliveryError: (call, result, error, stack) => deliveryErrors.add(error),
        );

        final previousOnError = FlutterError.onError;
        FlutterError.onError = (_) {};
        unawaited(runner.handleCalls([_waitingCall()]));
        await tester.pump();
        expect(sender.attempts, 1);
        await tester.pump(const Duration(seconds: 3));
        expect(sender.attempts, 2);
        await tester.pump(const Duration(seconds: 3));
        FlutterError.onError = previousOnError;

        expect(deliveryErrors.single, isA<TimeoutException>());
        expect(runner.hasPendingWork, isFalse);
      });

      testWidgets('waits retryDelay, doubling it, between attempts', (tester) async {
        final sender = _Sender(failures: 2);
        final runner = _runner(tools: [_ResultTool()], sender: sender, retryDelay: const Duration(seconds: 1));

        unawaited(runner.handleCalls([_waitingCall()]));
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

      testWidgets('caps the wait at maxRetryDelay', (tester) async {
        final sender = _Sender(failures: 1);
        final runner = _runner(tools: [_ResultTool()], sender: sender, retryDelay: const Duration(minutes: 10));

        unawaited(runner.handleCalls([_waitingCall()]));
        await tester.pump();
        await tester.pump(AIClientToolRunner.maxRetryDelay);

        expect(sender.attempts, 2);
      });
    });

    group('close', () {
      test('stops taking on new calls', () async {
        final tool = _ResultTool();
        final sender = _Sender();
        final runner = _runner(tools: [tool], sender: sender)..close();

        await runner.handleCalls([_waitingCall()]);

        expect(runner.isClosed, isTrue);
        expect(tool.calls, isEmpty);
        expect(sender.attempts, 0);
      });

      test('lets calls in flight finish and send their results, retries included', () async {
        final gate = Completer<AIClientToolResult>();
        final tool = _ResultTool(body: (_) => gate.future);
        final sender = _Sender(failures: 1);
        final runner = _runner(tools: [tool], sender: sender);

        unawaited(runner.handleCalls([_waitingCall()]));
        runner.close();
        gate.complete(AIClientToolResult.completed('late'));
        await runner.whenIdle();

        expect(sender.attempts, 2);
        expect(sender.sent.single.$2, AIClientToolResult.completed('late'));
        expect(runner.hasPendingWork, isFalse);
      });
    });

    test('whenIdle waits for calls started while it waits', () async {
      final firstGate = Completer<AIClientToolResult>();
      final secondGate = Completer<AIClientToolResult>();
      final tool = _ResultTool(body: (call) => call.id == 'call_1' ? firstGate.future : secondGate.future);
      final sender = _Sender();
      final runner = _runner(tools: [tool], sender: sender);

      unawaited(runner.handleCalls([_waitingCall()]));
      var idle = false;
      unawaited(runner.whenIdle().then((_) => idle = true));

      unawaited(runner.handleCalls([_waitingCall(id: 'call_2')]));
      firstGate.complete(_defaultResult);
      await pumpEventQueue();
      expect(idle, isFalse);

      secondGate.complete(_defaultResult);
      await pumpEventQueue();
      expect(idle, isTrue);
      expect(sender.sent, hasLength(2));
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

    test('a failed result is reported through onToolError', () async {
      final tool = _ResultTool(body: (_) async => const AIClientToolResult.failed('Location not shared'));
      final errors = <Object>[];
      final registry = AIToolRegistry(onToolError: (invocation, error, stack) => errors.add(error))..register(tool);

      final reported = await _collectingErrors(
        () => registry.dispatch(const AIToolInvocation(tool: AIInvokedTool(name: 'get_location'))),
      );

      expect(errors.single.toString(), contains('Location not shared'));
      expect(reported, hasLength(1));
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
}
