import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
      expect(call, const AIToolCallPart(id: 'ai_tool_call-1', name: ''));
      expect(call.status, AIToolCallStatus.running);
      expect(call.executor, AIToolExecutor.server);
      expect(call.approval, isNull);
      expect(call.arguments, isNull);
      expect(call.duration, isNull);
    });

    test('reads wrong-typed fields as missing, without throwing', () {
      final part = _single('ai_tool_call', const {
        'id': 42,
        'v': 'one',
        'name': ['get_weather'],
        'display_title': '',
        'status': 3,
        'executor': true,
        'target_user_id': {'id': 'alice'},
        'arguments': 'not json',
        'duration_ms': '800',
        'approval': 'yes',
      });

      expect(part.id, 'ai_tool_call-0');
      expect(part.version, 1);
      expect(part.toolCall, const AIToolCallPart(id: 'ai_tool_call-0', name: ''));
    });

    test('reads integral doubles as ints and drops fractional ones', () {
      final parts = AIMessagePart.parseAll([
        (type: 'ai_reasoning', payload: const {'v': 1.0, 'duration_ms': 1200.0}),
        (type: 'ai_reasoning', payload: const {'duration_ms': 1200.5}),
      ]);

      expect(parts[0].version, 1);
      expect(parts[0].reasoning!.durationMs, 1200);
      expect(parts[1].reasoning!.durationMs, isNull);
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

    test('drops an approval without a title', () {
      final call = _single('ai_tool_call', const {
        'approval': {'message': 'No question here'},
      }).toolCall!;

      expect(call.approval, isNull);
    });

    test('keeps unknown kinds with their payload but no typed view', () {
      final part = _single('ai_citation', const {
        'id': 'c1',
        'url': 'https://example.com',
      });

      expect(part.kind.value, 'ai_citation');
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
      expect(call.status.value, 'queued');
      expect(call.status.isKnown, isFalse);
      expect(call.status.isFinished, isFalse);
      expect(call.executor.value, 'browser');
      expect(call.executor.isKnown, isFalse);
      expect(call.approval!.decision!.value, 'later');
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
    });

    test('uses the attachment position, not the step index, for missing ids', () {
      final parts = AIMessagePart.parseAll([
        (type: 'image', payload: const {}),
        (type: 'ai_reasoning', payload: const {}),
      ]);

      expect(parts.single.id, 'ai_reasoning-1');
    });

    test('tryParse returns null for attachments that are not AI steps', () {
      expect(AIMessagePart.tryParse('image', const {}), isNull);
      expect(AIMessagePart.tryParse('giphy', const {'id': 'ai_x'}), isNull);
      expect(AIMessagePart.tryParse('ai_reasoning', const {}), isNotNull);
    });

    test('the payload is unmodifiable and detached from the source', () {
      final source = <String, Object?>{'id': 'r1'};
      final part = _single('ai_reasoning', source);
      source['id'] = 'changed';

      expect(part.payload['id'], 'r1');
      expect(() => part.payload['id'] = 'x', throwsUnsupportedError);
    });
  });

  group('AIMessagePart.decode', () {
    test('decodes a kind of your own', () {
      final part = _single('ai_citation', const {'id': 'c1', 'url': 'https://example.com'});

      expect(part.decode((json) => json['url']! as String), 'https://example.com');
    });

    test('returns null when the decoder throws', () {
      final part = _single('ai_citation', const {'id': 'c1'});

      expect(part.decode((json) => json['url']! as String), isNull);
      expect(part.decode<String>((json) => throw const FormatException('bad')), isNull);
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

    test('open sets compare by value', () {
      // Built from runtime strings, so they are distinct instances of the consts.
      String raw(String value) => String.fromCharCodes(value.codeUnits);

      expect(AIMessagePartKind(raw('ai_reasoning')), AIMessagePartKind.reasoning);
      expect(AIReasoningStatus(raw('completed')), AIReasoningStatus.completed);
      expect(AIToolCallStatus(raw('failed')), AIToolCallStatus.failed);
      expect(AIToolExecutor(raw('client')), AIToolExecutor.client);
      expect(AIToolApprovalDecision(raw('declined')), AIToolApprovalDecision.declined);
      expect(AIToolCallStatus(raw('x')).hashCode, AIToolCallStatus(raw('x')).hashCode);
      expect(AIToolCallStatus.running, isNot(const AIToolExecutor('running')));
    });

    test('known values report isKnown', () {
      expect(AIMessagePartKind.values.every((kind) => kind.isKnown), isTrue);
      expect(AIReasoningStatus.values.every((status) => status.isKnown), isTrue);
      expect(AIToolCallStatus.values.every((status) => status.isKnown), isTrue);
      expect(AIToolExecutor.values.every((executor) => executor.isKnown), isTrue);
      expect(AIToolApprovalDecision.values.every((decision) => decision.isKnown), isTrue);
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

      const noQuestion = AIToolCallPart(
        id: 'call_3',
        name: 'x',
        status: AIToolCallStatus.awaitingApproval,
        targetUserId: 'alice',
      );
      expect(noQuestion.isAwaitingApproval(userId: 'alice'), isFalse);
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
    });

    test('isFinished covers completed, failed and cancelled', () {
      expect(
        AIToolCallStatus.values.where((status) => status.isFinished),
        [AIToolCallStatus.completed, AIToolCallStatus.failed, AIToolCallStatus.cancelled],
      );
    });
  });
}
