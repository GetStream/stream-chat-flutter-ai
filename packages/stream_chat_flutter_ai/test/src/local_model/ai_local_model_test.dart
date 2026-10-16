import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// A model that streams its answer word by word, the way the interface's docs
/// tell an implementer to.
class _WordModel implements AILocalModel {
  _WordModel(this.answer);

  final String answer;
  List<AIConversationTurn>? lastTurns;
  bool stopped = false;

  @override
  Future<bool> get isAvailable async => true;

  @override
  Stream<String> reply({required String instructions, required List<AIConversationTurn> turns}) async* {
    lastTurns = AIConversationTurn.fitToBudget(turns, maxTokens: 100, instructions: instructions);
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
