import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

const _reasoning = <String, Object?>{
  'id': 'r1',
  'v': 1,
  'status': 'streaming',
  'summary': 'Compared both plans',
  'preview': 'The user wants…',
  'duration_ms': 2400,
};

const _toolCall = <String, Object?>{
  'id': 'call_1',
  'v': 1,
  'name': 'get_location',
  'display_title': 'Checking your location',
  'status': 'awaiting_approval',
  'executor': 'client',
  'target_user_id': 'alice',
  'target_client_id': 'install-1',
  'arguments': {
    'precision': 'city',
    'nested': {
      'list': [1, 2],
    },
  },
  'summary': 'Found your location',
  'duration_ms': 800,
  'approval': {
    'title': 'Share your location?',
    'message': 'Only your city is shared.',
    'reason': 'to check the local weather',
    'allow_title': 'Share',
    'decline_title': 'Not now',
    'decision': 'allowed',
  },
};

AIMessagePart _single(String type, Map<String, Object?> payload) =>
    AIMessagePart.parseAll([(type: type, payload: payload)]).single;

void main() {
  // Every debug report the parser makes, captured rather than printed.
  final reports = <String>[];
  setUp(() {
    reports.clear();
    debugPartIssueReporter = reports.add;
  });
  tearDown(() => debugPartIssueReporter = null);

  group('AIMessagePart.parseAll', () {
    test('decodes AI steps in order and skips other attachments', () {
      final parts = AIMessagePart.parseAll([
        (type: 'image', payload: const {'image_url': 'https://example.com/a.png'}),
        (type: 'ai_reasoning', payload: _reasoning),
        (type: 'file', payload: const {}),
        (type: 'ai_tool_call', payload: _toolCall),
        (type: 'ai_citation', payload: const {'id': 'c1', 'url': 'https://example.com'}),
      ]);

      expect(parts.map((part) => part.id), ['r1', 'call_1', 'c1']);
      expect(parts.map((part) => part.kind), [
        AIMessagePartKind.reasoning,
        AIMessagePartKind.toolCall,
        const AIMessagePartKind('ai_citation'),
      ]);
    });

    test('reads every reasoning field', () {
      final part = _single('ai_reasoning', _reasoning);

      expect(part.version, 1);
      expect(part.isSupported, isTrue);
      expect(part.toolCall, isNull);
      expect(
        part.reasoning,
        const AIReasoningPart(
          id: 'r1',
          status: AIReasoningStatus.streaming,
          summary: 'Compared both plans',
          preview: 'The user wants…',
          durationMs: 2400,
        ),
      );
      expect(part.reasoning!.isStreaming, isTrue);
      expect(part.reasoning!.duration, const Duration(milliseconds: 2400));
    });

    test('reads every tool-call field', () {
      final call = _single('ai_tool_call', _toolCall).toolCall!;

      expect(call.id, 'call_1');
      expect(call.name, 'get_location');
      expect(call.displayTitle, 'Checking your location');
      expect(call.status, AIToolCallStatus.awaitingApproval);
      expect(call.executor, AIToolExecutor.client);
      expect(call.targetUserId, 'alice');
      expect(call.targetClientId, 'install-1');
      expect(call.arguments, {
        'precision': 'city',
        'nested': {
          'list': [1, 2],
        },
      });
      expect(call.summary, 'Found your location');
      expect(call.durationMs, 800);
      expect(call.duration, const Duration(milliseconds: 800));
      expect(
        call.approval,
        const AIToolApproval(
          title: 'Share your location?',
          message: 'Only your city is shared.',
          reason: 'to check the local weather',
          allowTitle: 'Share',
          declineTitle: 'Not now',
          decision: AIToolApprovalDecision.allowed,
        ),
      );
    });

    test('gives missing fields their defaults', () {
      final parts = AIMessagePart.parseAll([
        (type: 'ai_reasoning', payload: const {}),
        (type: 'ai_tool_call', payload: const {}),
      ]);

      expect(parts[0].id, 'ai_reasoning-0');
      expect(parts[0].version, AIMessagePart.supportedVersion);
      expect(parts[0].reasoning, const AIReasoningPart(id: 'ai_reasoning-0'));
      expect(parts[0].reasoning!.status, AIReasoningStatus.completed);

      expect(parts[1].id, 'ai_tool_call-1');
      final call = parts[1].toolCall!;
      expect(call, const AIToolCallPart(id: 'ai_tool_call-1', name: '', hasPayloadId: false));
      expect(parts[0].hasPayloadId, isFalse);
      expect(call.status, AIToolCallStatus.running);
      expect(call.executor, AIToolExecutor.server);
      expect(call.approval, isNull);
      expect(call.arguments, isNull);
      expect(call.duration, isNull);
    });

    test('reads wrong-typed fields as missing, without throwing', () {
      final part = _single('ai_tool_call', const {
        'id': 42,
        'name': ['get_weather'],
        'display_title': '',
        'status': 3,
        'executor': true,
        'target_user_id': {'id': 'alice'},
        'arguments': 'not json',
        'duration_ms': 'eight hundred',
        'approval': 'yes',
      });

      expect(part.id, 'ai_tool_call-0');
      expect(part.version, 1);
      expect(part.toolCall, const AIToolCallPart(id: 'ai_tool_call-0', name: '', hasPayloadId: false));
      for (final key in [
        'id',
        'name',
        'status',
        'executor',
        'target_user_id',
        'arguments',
        'duration_ms',
        'approval',
      ]) {
        expect(reports, contains(contains('`$key`')), reason: key);
      }
      expect(reports, contains(contains('has no `id`')));
    });

    test('reads integer strings as durations and drops negative ones', () {
      final parts = AIMessagePart.parseAll([
        (type: 'ai_reasoning', payload: const {'duration_ms': '2400'}),
        (type: 'ai_reasoning', payload: const {'duration_ms': -5}),
        (type: 'ai_tool_call', payload: const {'id': 'c', 'duration_ms': '-5'}),
      ]);

      expect(parts[0].reasoning!.durationMs, 2400);
      expect(parts[1].reasoning!.durationMs, isNull);
      expect(parts[2].toolCall!.durationMs, isNull);
      expect(reports.where((report) => report.contains('`duration_ms`')), hasLength(2));
    });

    test('a v that is not a positive whole number means no typed view', () {
      for (final v in <Object>['two', 2.5, 0, -1, true]) {
        final part = _single('ai_reasoning', {'id': 'r1', 'v': v});
        expect(part.version, 0, reason: '$v');
        expect(part.isSupported, isFalse, reason: '$v');
        expect(part.reasoning, isNull, reason: '$v');
      }
      expect(reports.where((report) => report.contains('`v`')), hasLength(5));
      expect(_single('ai_reasoning', const {'v': 1}).isSupported, isTrue);
      expect(_single('ai_reasoning', const {'v': '2'}).version, 2, reason: 'an integer string is a version');
      expect(_single('ai_reasoning', const {}).version, 1);
    });

    test('reads integral doubles as ints and rounds fractional durations', () {
      final parts = AIMessagePart.parseAll([
        (type: 'ai_reasoning', payload: const {'v': 1.0, 'duration_ms': 1200.0}),
        (type: 'ai_reasoning', payload: const {'duration_ms': 1200.5}),
      ]);

      expect(parts[0].version, 1);
      expect(parts[0].reasoning!.durationMs, 1200);
      expect(parts[1].reasoning!.durationMs, 1201);
    });

    test('decodes JSON-encoded arguments and loosely typed maps', () {
      final parts = AIMessagePart.parseAll([
        (
          type: 'ai_tool_call',
          payload: {
            'arguments': jsonEncode({'city': 'Amsterdam'}),
          },
        ),
        (
          type: 'ai_tool_call',
          payload: {
            'arguments': <Object?, Object?>{'city': 'Utrecht', 1: 'dropped'},
            'approval': <dynamic, dynamic>{'title': 'Allow?'},
          },
        ),
        (type: 'ai_tool_call', payload: const {'arguments': '[1, 2]'}),
      ]);

      expect(parts[0].toolCall!.arguments, {'city': 'Amsterdam'});
      expect(parts[1].toolCall!.arguments, {'city': 'Utrecht'});
      expect(parts[1].toolCall!.approval, const AIToolApproval(title: 'Allow?'));
      expect(parts[2].toolCall!.arguments, isNull);
    });

    test('keeps an approval without a title', () {
      final call = _single('ai_tool_call', const {
        'approval': {'message': 'Only your city is shared.'},
      }).toolCall!;

      expect(call.approval, const AIToolApproval(message: 'Only your city is shared.'));
      expect(call.approval!.title, isNull);
    });

    test('decodes a JSON-encoded approval', () {
      final call = _single('ai_tool_call', {
        'approval': jsonEncode({'title': 'Allow?', 'decision': 'declined'}),
      }).toolCall!;

      expect(call.approval, const AIToolApproval(title: 'Allow?', decision: AIToolApprovalDecision.declined));
    });

    test('reports a call awaiting approval without one', () {
      _single('ai_tool_call', const {'id': 'c', 'status': 'awaiting_approval'});

      expect(reports, [contains('awaiting approval but has no `approval`')]);
    });

    test('keeps unknown kinds with their payload but no typed view', () {
      final part = _single('ai_citation', const {
        'id': 'c1',
        'url': 'https://example.com',
      });

      expect(part.kind, 'ai_citation');
      expect(part.kind.isKnown, isFalse);
      expect(part.isSupported, isFalse);
      expect(part.reasoning, isNull);
      expect(part.toolCall, isNull);
      expect(part.payload['url'], 'https://example.com');
    });

    test('keeps a step newer than the supported version without a typed view', () {
      final parts = AIMessagePart.parseAll([
        (type: 'ai_reasoning', payload: const {'id': 'r1', 'v': 2, 'status': 'completed'}),
        (type: 'ai_tool_call', payload: const {'id': 'call_1', 'v': 2, 'name': 'x'}),
      ]);

      for (final part in parts) {
        expect(part.version, 2);
        expect(part.isSupported, isFalse);
        expect(part.reasoning, isNull);
        expect(part.toolCall, isNull);
        expect(part.payload['id'], part.id);
      }
    });

    test('round-trips unknown statuses, executors and decisions', () {
      final reasoning = _single('ai_reasoning', const {'status': 'paused'}).reasoning!;
      expect(reasoning.status, const AIReasoningStatus('paused'));
      expect(reasoning.status.isKnown, isFalse);
      expect(reasoning.isStreaming, isFalse);

      final call = _single('ai_tool_call', const {
        'status': 'queued',
        'executor': 'browser',
        'approval': {'title': 'Allow?', 'decision': 'later'},
      }).toolCall!;
      expect(call.status, 'queued');
      expect(call.status.isKnown, isFalse);
      expect(call.status.isFinished, isFalse);
      expect(call.executor, 'browser');
      expect(call.executor.isKnown, isFalse);
      expect(call.approval!.decision, 'later');
      expect(call.approval!.decision!.isKnown, isFalse);
      expect(call.approval!.isAnswered, isTrue);
      expect(call.isDeclined, isFalse);
    });

    test('keeps parts that share an id', () {
      final parts = AIMessagePart.parseAll([
        (type: 'ai_reasoning', payload: const {'id': 'same'}),
        (type: 'ai_tool_call', payload: const {'id': 'same'}),
      ]);

      expect(parts.map((part) => part.id), ['same', 'same']);
      expect(reports, [contains('"same"')]);
    });

    test('names a step with no id by its index among the AI steps', () {
      final parts = AIMessagePart.parseAll([
        (type: 'image', payload: const {}),
        (type: 'ai_reasoning', payload: const {}),
        (type: 'file', payload: const {}),
        (type: 'ai_reasoning', payload: const {}),
      ]);

      expect(parts.map((part) => part.id), ['ai_reasoning-0', 'ai_reasoning-1']);
    });

    test('clean payloads report nothing', () {
      AIMessagePart.parseAll([
        (type: 'ai_reasoning', payload: _reasoning),
        (type: 'ai_tool_call', payload: _toolCall),
      ]);

      expect(reports, isEmpty);
    });

    test('tryParse returns null for attachments that are not AI steps', () {
      expect(AIMessagePart.tryParse('image', const {}), isNull);
      expect(AIMessagePart.tryParse('giphy', const {'id': 'ai_x'}), isNull);
      expect(AIMessagePart.tryParse('ai_reasoning', const {}), isNotNull);
    });

    test('the payload is deeply unmodifiable and detached from the source', () {
      final arguments = <String, Object?>{
        'city': 'Amsterdam',
        'tags': ['a'],
      };
      final approval = <String, Object?>{'title': 'Allow?'};
      final source = <String, Object?>{'id': 'call_1', 'arguments': arguments, 'approval': approval};
      final part = _single('ai_tool_call', source);
      final hash = part.hashCode;
      final copy = _single('ai_tool_call', jsonDecode(jsonEncode(source)) as Map<String, Object?>);

      source['id'] = 'changed';
      arguments['city'] = 'Utrecht';
      (arguments['tags']! as List<Object?>).add('b');
      approval['decision'] = 'allowed';

      expect(part, copy);
      expect(part.hashCode, hash);
      expect(part.toolCall!.arguments, {
        'city': 'Amsterdam',
        'tags': ['a'],
      });
      expect(part.toolCall!.approval!.decision, isNull);
      expect(() => part.payload['id'] = 'x', throwsUnsupportedError);
      expect(() => (part.payload['arguments']! as Map<String, Object?>)['x'] = 1, throwsUnsupportedError);
      expect(() => part.toolCall!.arguments!['x'] = 1, throwsUnsupportedError);
      expect(() => (part.toolCall!.arguments!['tags']! as List<Object?>).add('c'), throwsUnsupportedError);
    });
  });

  group('AIMessagePart.decode', () {
    test('decodes a kind of your own', () {
      final part = _single('ai_citation', const {'id': 'c1', 'url': 'https://example.com'});

      expect(part.decode((json) => json['url']! as String), 'https://example.com');
    });

    test('reports and returns null when the decoder throws', () {
      final part = _single('ai_citation', const {'id': 'c1'});
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      expect(part.decode((json) => json['url']! as String), isNull);
      expect(part.decode<String>((json) => throw const FormatException('bad')), isNull);

      expect(errors, hasLength(2));
      expect(errors.last.exception, isA<FormatException>());
      expect(errors.last.library, 'stream_chat_flutter_ai');
      expect(errors.last.context.toString(), contains('ai_citation message part "c1"'));
    });
  });

  group('equality', () {
    test('parts compare by value, payload deeply', () {
      final a = _single('ai_tool_call', _toolCall);
      final b = _single('ai_tool_call', jsonDecode(jsonEncode(_toolCall)) as Map<String, Object?>);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toolCall, b.toolCall);
      expect(a.toolCall.hashCode, b.toolCall.hashCode);
    });

    test('a changed field makes parts unequal', () {
      final a = _single('ai_reasoning', _reasoning);
      final b = _single('ai_reasoning', {..._reasoning, 'status': 'completed'});

      expect(a, isNot(b));
      expect(a.reasoning, isNot(b.reasoning));
      expect(
        _single('ai_reasoning', _reasoning),
        isNot(_single('ai_reasoning', {..._reasoning, 'v': 2})),
      );
    });

    test('a changed nested argument or approval decision makes parts unequal', () {
      final a = _single('ai_tool_call', _toolCall);
      final changedArgument = _single('ai_tool_call', {
        ..._toolCall,
        'arguments': {
          'precision': 'city',
          'nested': {
            'list': [1, 3],
          },
        },
      });
      final changedDecision = _single('ai_tool_call', {
        ..._toolCall,
        'approval': {...(_toolCall['approval']! as Map<String, Object?>), 'decision': 'declined'},
      });

      expect(a, isNot(changedArgument));
      expect(a.toolCall, isNot(changedArgument.toolCall));
      expect(a, isNot(changedDecision));
      expect(a.toolCall, isNot(changedDecision.toolCall));
    });

    test('open sets are their raw strings', () {
      // Built from runtime strings, so they are distinct instances of the consts.
      String raw(String value) => String.fromCharCodes(value.codeUnits);

      expect(AIMessagePartKind(raw('ai_reasoning')), AIMessagePartKind.reasoning);
      expect(AIReasoningStatus(raw('completed')), AIReasoningStatus.completed);
      expect(AIToolCallStatus(raw('failed')), AIToolCallStatus.failed);
      expect(AIToolExecutor(raw('client')), AIToolExecutor.client);
      expect(AIToolApprovalDecision(raw('declined')), AIToolApprovalDecision.declined);
      expect(AIMessageRole(raw('assistant')), AIMessageRole.assistant);
      expect(AIMessageAttachmentKind(raw('image')), AIMessageAttachmentKind.image);
      expect(AIToolCallStatus.awaitingApproval, 'awaiting_approval');
      expect(AIMessagePartKind.toolCall, 'ai_tool_call');
      expect(const AIToolCallStatus('queued'), 'queued');
    });

    test('known values report isKnown', () {
      expect(AIMessagePartKind.values.every((kind) => kind.isKnown), isTrue);
      expect(AIReasoningStatus.values.every((status) => status.isKnown), isTrue);
      expect(AIToolCallStatus.values.every((status) => status.isKnown), isTrue);
      expect(AIToolExecutor.values.every((executor) => executor.isKnown), isTrue);
      expect(AIToolApprovalDecision.values.every((decision) => decision.isKnown), isTrue);
      expect(AIMessageRole.values.every((role) => role.isKnown), isTrue);
      expect(AIMessageAttachmentKind.values.every((kind) => kind.isKnown), isTrue);
      expect(const AIMessageRole('system').isKnown, isFalse);
      expect(const AIMessageAttachmentKind('athena_image').isKnown, isFalse);
    });
  });

  group('AIToolCallPart helpers', () {
    const clientCall = AIToolCallPart(
      id: 'call_1',
      name: 'get_location',
      status: AIToolCallStatus.awaitingClient,
      executor: AIToolExecutor.client,
      targetUserId: 'alice',
      targetClientId: 'install-1',
    );

    test('a call that names nobody waits for nobody', () {
      const untargeted = AIToolCallPart(
        id: 'call_1',
        name: 'get_location',
        status: AIToolCallStatus.awaitingClient,
        executor: AIToolExecutor.client,
      );
      expect(untargeted.isAwaiting(userId: 'alice', clientId: 'install-1'), isFalse);
      const asking = AIToolCallPart(id: 'call_2', name: 'send_email', status: AIToolCallStatus.awaitingApproval);
      expect(asking.isAwaitingApproval(userId: 'alice'), isFalse, reason: 'anybody could answer it otherwise');
      expect(
        asking.copyWith(targetClientId: 'install-1').isAwaitingApproval(userId: 'alice', clientId: 'install-1'),
        isFalse,
        reason: 'naming an install is not naming a person',
      );
    });

    test('reports a value it does not know, and keeps it', () {
      final call = _single('ai_tool_call', {..._toolCall, 'status': 'complete', 'executor': 'Client'}).toolCall!;
      expect(call.status, const AIToolCallStatus('complete'));
      expect(reports.where((r) => r.contains('`status`')), hasLength(1));
      expect(reports.where((r) => r.contains('`executor`')), hasLength(1));
    });

    test('isAwaiting matches a client call targeted at this user and install', () {
      expect(clientCall.isAwaiting(userId: 'alice', clientId: 'install-1'), isTrue);
      expect(clientCall.isAwaiting(userId: 'bob', clientId: 'install-1'), isFalse);
      expect(clientCall.isAwaiting(userId: 'alice', clientId: 'install-2'), isFalse);

      const server = AIToolCallPart(
        id: 'call_2',
        name: 'x',
        status: AIToolCallStatus.awaitingClient,
        targetUserId: 'alice',
        targetClientId: 'install-1',
      );
      expect(server.isAwaiting(userId: 'alice', clientId: 'install-1'), isFalse);

      const done = AIToolCallPart(
        id: 'call_3',
        name: 'x',
        status: AIToolCallStatus.completed,
        executor: AIToolExecutor.client,
        targetUserId: 'alice',
        targetClientId: 'install-1',
      );
      expect(done.isAwaiting(userId: 'alice', clientId: 'install-1'), isFalse);
    });

    test('isAwaitingApproval needs a question and the targeted person', () {
      const serverCall = AIToolCallPart(
        id: 'call_1',
        name: 'delete_file',
        status: AIToolCallStatus.awaitingApproval,
        targetUserId: 'alice',
        approval: AIToolApproval(title: 'Delete it?'),
      );
      // A server tool's question can be answered from any of the person's devices.
      expect(serverCall.isAwaitingApproval(userId: 'alice'), isTrue);
      expect(serverCall.isAwaitingApproval(userId: 'alice', clientId: 'any'), isTrue);
      expect(serverCall.isAwaitingApproval(userId: 'bob'), isFalse);

      const clientCall = AIToolCallPart(
        id: 'call_2',
        name: 'get_location',
        status: AIToolCallStatus.awaitingApproval,
        executor: AIToolExecutor.client,
        targetUserId: 'alice',
        targetClientId: 'install-1',
        approval: AIToolApproval(title: 'Share your location?'),
      );
      expect(clientCall.isAwaitingApproval(userId: 'alice', clientId: 'install-1'), isTrue);
      expect(clientCall.isAwaitingApproval(userId: 'alice', clientId: 'install-2'), isFalse);
      expect(clientCall.isAwaitingApproval(userId: 'alice'), isFalse);

      // Without an approval object the call still waits; a view asks in its
      // own words.
      const noQuestion = AIToolCallPart(
        id: 'call_3',
        name: 'x',
        status: AIToolCallStatus.awaitingApproval,
        targetUserId: 'alice',
      );
      expect(noQuestion.isAwaitingApproval(userId: 'alice'), isTrue);

      // As on iOS, a client tool that names no install can be answered from any.
      const clientNoInstall = AIToolCallPart(
        id: 'call_4',
        name: 'x',
        status: AIToolCallStatus.awaitingApproval,
        executor: AIToolExecutor.client,
        targetUserId: 'alice',
      );
      expect(clientNoInstall.isAwaitingApproval(userId: 'alice', clientId: 'install-9'), isTrue);

      final answered = serverCall.copyWith(
        approval: const AIToolApproval(title: 'Delete it?', decision: AIToolApprovalDecision.allowed),
      );
      expect(answered.isAwaitingApproval(userId: 'alice'), isFalse);
      final oddlyAnswered = serverCall.copyWith(
        approval: const AIToolApproval(decision: AIToolApprovalDecision('later')),
      );
      expect(oddlyAnswered.isAwaitingApproval(userId: 'alice'), isFalse);
    });

    test('a call without an id from the agent is never awaited', () {
      final fallback = clientCall.copyWith(hasPayloadId: false);
      expect(fallback.isAwaiting(userId: 'alice', clientId: 'install-1'), isFalse);

      final approval = fallback.copyWith(status: AIToolCallStatus.awaitingApproval);
      expect(approval.isAwaitingApproval(userId: 'alice', clientId: 'install-1'), isFalse);
      expect(approval.copyWith(hasPayloadId: true).isAwaitingApproval(userId: 'alice', clientId: 'install-1'), isTrue);
    });

    test('isDeclined reads the approval decision', () {
      const declined = AIToolCallPart(
        id: 'call_1',
        name: 'x',
        status: AIToolCallStatus.cancelled,
        approval: AIToolApproval(title: 'Allow?', decision: AIToolApprovalDecision.declined),
      );
      expect(declined.isDeclined, isTrue);
      expect(declined.approval!.isAllowed, isFalse);
      expect(clientCall.isDeclined, isFalse);
    });

    test('displayName prefers the display title, then the spaced-out name', () {
      expect(clientCall.displayName, 'get location');
      expect(
        const AIToolCallPart(id: 'x', name: 'get_location', displayTitle: 'Finding you').displayName,
        'Finding you',
      );
      expect(
        const AIToolCallPart(id: 'x', name: 'get_location', displayTitle: '  ').displayName,
        'get location',
        reason: 'a blank title counts as none',
      );
      expect(const AIToolCallPart(id: 'x', name: '').displayName, isEmpty);
    });

    test('summaryText reads a blank summary as absent', () {
      expect(const AIToolCallPart(id: 'x', name: 'n', summary: 'Sunny').summaryText, 'Sunny');
      expect(const AIToolCallPart(id: 'x', name: 'n', summary: ' \n').summaryText, isNull);
      expect(const AIToolCallPart(id: 'x', name: 'n').summaryText, isNull);
    });

    test('rejects a negative duration', () {
      expect(() => AIToolCallPart(id: 'x', name: 'n', durationMs: -1), throwsAssertionError);
    });

    test('isFinished covers completed, failed and cancelled', () {
      expect(
        AIToolCallStatus.values.where((status) => status.isFinished),
        [AIToolCallStatus.completed, AIToolCallStatus.failed, AIToolCallStatus.cancelled],
      );
    });
  });

  group('copyWith and toJson', () {
    test('typed parts round-trip through toJson', () {
      final reasoning = _single('ai_reasoning', _reasoning).reasoning!;
      expect(AIReasoningPart.fromJson(reasoning.toJson(), id: reasoning.id), reasoning);

      final call = _single('ai_tool_call', _toolCall).toolCall!;
      expect(AIToolCallPart.fromJson(call.toJson(), id: call.id), call);
      expect(AIToolApproval.fromJson(call.approval!.toJson()), call.approval);

      final fallback = _single('ai_tool_call', const {'name': 'x'}).toolCall!;
      expect(fallback.toJson().containsKey('id'), isFalse);
      expect(AIToolCallPart.fromJson(fallback.toJson(), id: fallback.id), fallback);
    });

    test('a toJson payload parses back to an equal message part', () {
      final parts = AIMessagePart.parseAll([
        (type: 'ai_reasoning', payload: _reasoning),
        (type: 'ai_tool_call', payload: _toolCall),
        (type: 'ai_citation', payload: const {'url': 'https://example.com'}),
        (type: 'ai_reasoning', payload: const {'status': 'completed'}),
      ]);
      for (final (position, part) in parts.indexed) {
        expect(AIMessagePart.fromJson(part.toJson(), position: position), part);
      }
      expect(AIMessagePart.fromJson(const {'type': 'image'}), isNull);
      expect(AIMessagePart.fromJson(const {}), isNull);
    });

    test('a part built by hand keeps its version through toJson', () {
      final part = AIMessagePart(id: 'x', kind: AIMessagePartKind.reasoning, version: 2, payload: const {'id': 'x'});
      final read = AIMessagePart.fromJson(part.toJson())!;
      expect(read.version, 2);
      expect(read.reasoning, isNull, reason: 'a newer format gets no typed view');
    });

    test('withToolCall keeps the fields the typed view does not read', () {
      final part = _single('ai_tool_call', {..._toolCall, 'trace_id': 't-1'});
      final answered = part.withToolCall(part.toolCall!.copyWith(status: AIToolCallStatus.running));
      expect(answered.payload['trace_id'], 't-1');
      expect(answered.toolCall!.status, AIToolCallStatus.running);
      expect(answered.id, part.id);
    });

    test('withReasoning keeps a fallback id out of the payload', () {
      final part = _single('ai_reasoning', const {'status': 'streaming'});
      expect(part.hasPayloadId, isFalse);
      final done = part.withReasoning(part.reasoning!.copyWith(status: AIReasoningStatus.completed));
      expect(done.hasPayloadId, isFalse);
      expect(done.payload.containsKey('id'), isFalse);
      expect(done.reasoning!.status, AIReasoningStatus.completed);
    });

    test('reads an integer string as the version', () {
      expect(_single('ai_reasoning', const {'v': '1'}).reasoning, isNotNull);
    });

    test('rounds a fractional duration', () {
      expect(_single('ai_reasoning', const {'duration_ms': 812.6}).reasoning!.durationMs, 813);
    });

    test('a part built from a typed view decodes back to it', () {
      final call = _single('ai_tool_call', _toolCall).toolCall!;
      final updated = call.copyWith(
        status: AIToolCallStatus.awaitingClient,
        approval: call.approval!.copyWith(decision: AIToolApprovalDecision.allowed),
      );
      expect(AIMessagePart.fromToolCall(updated).toolCall, updated);

      final reasoning = _single('ai_reasoning', _reasoning).reasoning!.copyWith(status: AIReasoningStatus.completed);
      expect(AIMessagePart.fromReasoning(reasoning).reasoning, reasoning);
    });

    test('copyWith replaces only the given fields', () {
      const reasoning = AIReasoningPart(id: 'r1', summary: 'a');
      expect(reasoning.copyWith(), reasoning);
      expect(reasoning.copyWith(preview: 'p'), const AIReasoningPart(id: 'r1', summary: 'a', preview: 'p'));

      const approval = AIToolApproval(title: 'Allow?');
      expect(approval.copyWith(), approval);
      expect(
        approval.copyWith(decision: AIToolApprovalDecision.declined),
        const AIToolApproval(title: 'Allow?', decision: AIToolApprovalDecision.declined),
      );

      const call = AIToolCallPart(id: 'c', name: 'x');
      expect(call.copyWith(), call);
      final withArguments = call.copyWith(arguments: {'a': 1});
      expect(withArguments.arguments, {'a': 1});
      expect(() => withArguments.arguments!['b'] = 2, throwsUnsupportedError);
      expect(withArguments.copyWith(summary: 'done').arguments, {'a': 1});
    });
  });
}
