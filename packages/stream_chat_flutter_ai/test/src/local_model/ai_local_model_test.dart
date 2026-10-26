import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// A model that streams its answer word by word, the way the class's docs
/// tell an implementer to.
class _WordModel extends AILocalModel {
  _WordModel(this.answer, {this.available = true});

  final String answer;
  final bool available;
  List<AIConversationTurn>? lastTurns;
  bool stopped = false;

  @override
  Future<bool> get isAvailable async => available;

  @override
  Stream<String> reply({required String instructions, required List<AIConversationTurn> turns}) async* {
    if (!available) {
      throw const AILocalModelException(AILocalModelErrorReason.unavailable, 'Model not downloaded');
    }
    final fitted = AIConversationTurn.fitToBudget(turns, maxTokens: 100, instructions: instructions);
    if (fitted.lastOrNull?.role != AIConversationRole.user) {
      throw const AILocalModelException(AILocalModelErrorReason.invalidConversation, 'No question to answer');
    }
    lastTurns = fitted;
    try {
      var soFar = '';
      for (final word in answer.split(' ')) {
        await Future<void>.delayed(Duration.zero);
        soFar = soFar.isEmpty ? word : '$soFar $word';
        yield soFar;
      }
    } finally {
      stopped = true;
    }
  }
}

Matcher _modelError(AILocalModelErrorReason reason) =>
    isA<AILocalModelException>().having((error) => error.reason, 'reason', reason);

void main() {
  test('events are cumulative and cancelling stops the model', () async {
    final model = _WordModel('one two three four');
    final events = <String>[];
    final cancelled = Completer<void>();
    late final StreamSubscription<String> subscription;
    subscription = model.reply(instructions: 'Be brief.', turns: const [AIConversationTurn.user('Count')]).listen((
      answer,
    ) {
      events.add(answer);
      if (events.length == 2) cancelled.complete(subscription.cancel());
    });

    await cancelled.future;
    await Future<void>.delayed(Duration.zero);

    expect(events, ['one', 'one two']);
    expect(model.stopped, isTrue);
    expect(model.lastTurns, [const AIConversationTurn.user('Count')]);
  });

  test('a complete answer closes the stream', () async {
    final model = _WordModel('all done');
    final answers = await model.reply(instructions: '', turns: const [AIConversationTurn.user('Hi')]).toList();
    expect(answers, ['all', 'all done']);
  });

  test('an unavailable model reports it and emits an unavailable error', () async {
    final model = _WordModel('unused', available: false);
    expect(await model.isAvailable, isFalse);
    // Calling reply doesn't throw; the error arrives on the stream, which then closes.
    final answers = model.reply(instructions: '', turns: const [AIConversationTurn.user('Hi')]);
    await expectLater(answers, emitsInOrder([emitsError(_modelError(AILocalModelErrorReason.unavailable)), emitsDone]));
  });

  test('a conversation that does not end with a question emits invalidConversation', () async {
    final model = _WordModel('unused');
    await expectLater(
      model.reply(instructions: '', turns: const []),
      emitsError(_modelError(AILocalModelErrorReason.invalidConversation)),
    );
    await expectLater(
      model.reply(
        instructions: '',
        turns: const [AIConversationTurn.user('Hi'), AIConversationTurn.assistant('Hello')],
      ),
      emitsError(_modelError(AILocalModelErrorReason.invalidConversation)),
    );
  });

  group('AILocalModelException', () {
    test('carries its reason, message and cause', () {
      final cause = StateError('out of memory');
      final error = AILocalModelException(AILocalModelErrorReason.failed, 'Generation failed', cause: cause);
      expect(error.reason, AILocalModelErrorReason.failed);
      expect(error.message, 'Generation failed');
      expect(error.cause, same(cause));
      expect(error, isA<Exception>());
    });

    test('toString names the reason and the cause', () {
      expect(
        const AILocalModelException(AILocalModelErrorReason.unavailable, 'Switched off').toString(),
        'AILocalModelException(unavailable): Switched off',
      );
      expect(
        const AILocalModelException(AILocalModelErrorReason.failed, 'Boom', cause: 'disk full').toString(),
        'AILocalModelException(failed): Boom (caused by: disk full)',
      );
    });
  });

  testWidgets('a reply streams into StreamingMessageView', (tester) async {
    final model = _WordModel('Offline answer');
    final answers = model.reply(instructions: '', turns: const [AIConversationTurn.user('Hi')]);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: StreamBuilder<String>(
              stream: answers,
              builder: (context, snapshot) => StreamingMessageView(text: snapshot.data ?? ''),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();

    expect(find.text('Offline answer', findRichText: true), findsOneWidget);
  });
}
