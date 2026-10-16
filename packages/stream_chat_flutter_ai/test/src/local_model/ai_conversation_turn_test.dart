import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// What [AIConversationTurn.fitToBudget] charges for a turn of [text].
int _cost(String text) => AIConversationTurn.estimateTokens(text) + AIConversationTurn.tokensPerTurn;

void main() {
  group('AIConversationTurn', () {
    test('factories set the role', () {
      expect(const AIConversationTurn.user('Hi').role, AIConversationRole.user);
      expect(const AIConversationTurn.assistant('Hello').role, AIConversationRole.assistant);
      expect(
        const AIConversationTurn.user('Hi'),
        const AIConversationTurn(role: AIConversationRole.user, text: 'Hi'),
      );
    });

    test('has value equality', () {
      // Built at runtime so the comparison isn't between canonical constants.
      final text = ['H', 'i'].join();
      expect(AIConversationTurn.user(text), const AIConversationTurn.user('Hi'));
      expect(AIConversationTurn.user(text).hashCode, const AIConversationTurn.user('Hi').hashCode);
      expect(const AIConversationTurn.user('Hi'), isNot(const AIConversationTurn.assistant('Hi')));
      expect(const AIConversationTurn.user('Hi'), isNot(const AIConversationTurn.user('Hey')));
    });

    test('toString names the role', () {
      expect(const AIConversationTurn.assistant('Hello').toString(), 'AIConversationTurn.assistant(Hello)');
    });
  });

  group('AIConversationTurn.estimateTokens', () {
    test('counts three bytes of UTF-8 per token, rounded up', () {
      expect(AIConversationTurn.estimateTokens(''), 0);
      expect(AIConversationTurn.estimateTokens('a'), 1);
      expect(AIConversationTurn.estimateTokens('abc'), 1);
      expect(AIConversationTurn.estimateTokens('abcd'), 2);
      expect(AIConversationTurn.estimateTokens('abcdefg'), 3);
    });

    test('counts bytes, not characters, for multi-byte text', () {
      // 'é' is 2 bytes, '日' is 3, the emoji is 4 (a surrogate pair in Dart).
      expect(AIConversationTurn.estimateTokens('ééé'), 2);
      expect(AIConversationTurn.estimateTokens('日本語'), 3);
      expect(AIConversationTurn.estimateTokens('😀'), 2);
      expect(AIConversationTurn.estimateTokens('😀😀😀'), 4);
    });
  });

  group('AIConversationTurn.fitToBudget', () {
    // 300 × 5 bytes = 1500 bytes, about 500 tokens.
    final long = 'word ' * 300;
    final turns = [
      AIConversationTurn.user('First question $long'),
      AIConversationTurn.assistant('First answer $long'),
      const AIConversationTurn.user('Second question'),
      const AIConversationTurn.assistant('Second answer'),
      const AIConversationTurn.user('Third question'),
    ];

    test('keeps everything that fits, in order', () {
      expect(AIConversationTurn.fitToBudget(turns, maxTokens: 4000), turns);
    });

    test('keeps the newest turns that fit, oldest first', () {
      expect(
        AIConversationTurn.fitToBudget(turns, maxTokens: 600).map((turn) => turn.text),
        ['First answer $long', 'Second question', 'Second answer', 'Third question'],
      );
    });

    test('always keeps the question, untruncated', () {
      expect(AIConversationTurn.fitToBudget(turns, maxTokens: 1), [const AIConversationTurn.user('Third question')]);

      final huge = AIConversationTurn.user(long);
      expect(
        AIConversationTurn.fitToBudget([...turns, const AIConversationTurn.assistant('Go on'), huge], maxTokens: 10),
        [huge],
      );
    });

    test('asserts a positive budget', () {
      expect(() => AIConversationTurn.fitToBudget(turns, maxTokens: 0), throwsAssertionError);
      expect(() => AIConversationTurn.fitToBudget(turns, maxTokens: -10), throwsAssertionError);
    });

    test('stops at the first turn that does not fit', () {
      // The long first answer doesn't fit, so the short first question before
      // it is left out too: the history has no gaps.
      final withShortStart = [const AIConversationTurn.user('Hi'), ...turns.skip(1)];
      expect(
        AIConversationTurn.fitToBudget(withShortStart, maxTokens: 100).map((turn) => turn.text),
        ['Second question', 'Second answer', 'Third question'],
      );
    });

    test('a turn that fills the budget exactly is kept', () {
      final exact = [const AIConversationTurn.assistant('abcdef'), const AIConversationTurn.user('abc')];
      final budget = _cost('abcdef') + _cost('abc');
      expect(AIConversationTurn.fitToBudget(exact, maxTokens: budget), exact);
      expect(AIConversationTurn.fitToBudget(exact, maxTokens: budget - 1), [const AIConversationTurn.user('abc')]);
    });

    test('a short turn costs at least one token plus the per-turn overhead', () {
      expect(_cost('a'), 1 + AIConversationTurn.tokensPerTurn);
      final short = [const AIConversationTurn.assistant('a'), const AIConversationTurn.user('b')];
      expect(AIConversationTurn.fitToBudget(short, maxTokens: 2 * _cost('a')), short);
      expect(AIConversationTurn.fitToBudget(short, maxTokens: 2 * _cost('a') - 1), [
        const AIConversationTurn.user('b'),
      ]);
    });

    test('counts the per-turn overhead, so many short turns cannot overflow', () {
      final many = [
        for (var i = 0; i < 10; i++)
          AIConversationTurn(role: i.isEven ? AIConversationRole.user : AIConversationRole.assistant, text: 'a'),
      ];
      // Each costs 1 + 4 = 5: 20 tokens hold 4 turns, not all 10.
      expect(AIConversationTurn.fitToBudget(many, maxTokens: 20), many.sublist(6));
    });

    test('counts the instructions against the budget', () {
      const instructions = 'abcdefghi'; // 3 tokens
      final short = [const AIConversationTurn.assistant('abcdef'), const AIConversationTurn.user('abc')];
      final budget = 3 + _cost('abcdef') + _cost('abc');
      expect(AIConversationTurn.fitToBudget(short, maxTokens: budget, instructions: instructions), short);
      expect(
        AIConversationTurn.fitToBudget(short, maxTokens: budget - 1, instructions: instructions),
        [const AIConversationTurn.user('abc')],
      );
    });

    test('keeps only the question when the instructions alone are over the budget', () {
      expect(
        AIConversationTurn.fitToBudget(turns, maxTokens: 50, instructions: long),
        [const AIConversationTurn.user('Third question')],
      );
    });

    test('estimates multi-byte text by its bytes', () {
      // Three emoji are 12 bytes: 4 tokens, not 1.
      final emoji = [const AIConversationTurn.assistant('😀😀😀'), const AIConversationTurn.user('Hi')];
      final budget = 4 + AIConversationTurn.tokensPerTurn + _cost('Hi');
      expect(AIConversationTurn.fitToBudget(emoji, maxTokens: budget), emoji);
      expect(AIConversationTurn.fitToBudget(emoji, maxTokens: budget - 1), [const AIConversationTurn.user('Hi')]);
    });

    test('merges consecutive turns of one role and drops empty ones', () {
      const repeated = [
        AIConversationTurn.user('Are you there?'),
        AIConversationTurn.user('  '),
        AIConversationTurn.user('Hello?'),
        AIConversationTurn.assistant(''),
        AIConversationTurn.user('Anyone?'),
      ];
      expect(
        AIConversationTurn.fitToBudget(repeated, maxTokens: 1000),
        [const AIConversationTurn.user('Are you there?\n\nHello?\n\nAnyone?')],
      );
    });

    test('keeps the text untrimmed when merging', () {
      const padded = [AIConversationTurn.user('  first \n'), AIConversationTurn.user(' second')];
      expect(
        AIConversationTurn.fitToBudget(padded, maxTokens: 1000),
        [const AIConversationTurn.user('  first \n\n\n second')],
      );
    });

    test('measures merged turns as one', () {
      const split = [
        AIConversationTurn.assistant('abc'),
        AIConversationTurn.assistant('abc'),
        AIConversationTurn.user('Hi'),
      ];
      // One merged turn of 'abc\n\nabc' pays the overhead once.
      final budget = _cost('abc\n\nabc') + _cost('Hi');
      expect(AIConversationTurn.fitToBudget(split, maxTokens: budget), [
        const AIConversationTurn.assistant('abc\n\nabc'),
        const AIConversationTurn.user('Hi'),
      ]);
      expect(AIConversationTurn.fitToBudget(split, maxTokens: budget - 1), [const AIConversationTurn.user('Hi')]);
    });

    test('keeps the last turn even when it is the assistant’s', () {
      const trailing = [AIConversationTurn.user('Hi'), AIConversationTurn.assistant('Hello')];
      expect(AIConversationTurn.fitToBudget(trailing, maxTokens: 1), [const AIConversationTurn.assistant('Hello')]);
    });

    test('is empty when no turn has text', () {
      expect(AIConversationTurn.fitToBudget(const [], maxTokens: 100), isEmpty);
      expect(
        AIConversationTurn.fitToBudget(const [
          AIConversationTurn.user(' \n'),
          AIConversationTurn.assistant(''),
        ], maxTokens: 100),
        isEmpty,
      );
    });

    test('returns an unmodifiable list and leaves the input alone', () {
      final input = [...turns];
      final result = AIConversationTurn.fitToBudget(input, maxTokens: 4000);
      expect(() => result.add(const AIConversationTurn.user('x')), throwsUnsupportedError);
      expect(input, turns);
    });
  });
}
