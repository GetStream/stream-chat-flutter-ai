import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  test("AIAgentActivity has the states of Stream Chat's AI indicator", () {
    expect(AIAgentActivityState.thinking, 'AI_STATE_THINKING');
    expect(AIAgentActivityState.checkingExternalSources, 'AI_STATE_EXTERNAL_SOURCES');
    expect(AIAgentActivityState.generating, 'AI_STATE_GENERATING');
    expect(AIAgentActivityState.error, 'AI_STATE_ERROR');
    expect(AIAgentActivityState.thinking.isKnown, isTrue);
  });

  test("AIAgentActivity is made from an indicator's raw state", () {
    expect(
      const AIAgentActivity(state: AIAgentActivityState('AI_STATE_EXTERNAL_SOURCES'), text: 'Searching the web'),
      const AIAgentActivity(state: AIAgentActivityState.checkingExternalSources, text: 'Searching the web'),
    );
    expect(const AIAgentActivity(state: AIAgentActivityState.thinking).text, isNull);
  });

  test('AIAgentError tells the person what the agent said', () {
    expect(
      const AIAgentError(message: 'Rate limited').localizedMessage(const DefaultAITranslations()),
      'Rate limited',
    );
  });

  test("AIAgentError tells the person the agent couldn't answer when it said nothing", () {
    const translations = DefaultAITranslations();

    expect(const AIAgentError().localizedMessage(translations), "The agent couldn't answer. Try again.");
    expect(const AIAgentError(message: '').localizedMessage(translations), "The agent couldn't answer. Try again.");
  });

  test('AIConversationActions combined with | contain each of the actions combined', () {
    final editAndRate = AIConversationActions.edit | AIConversationActions.rate;

    expect(editAndRate.contains(AIConversationActions.edit), isTrue);
    expect(editAndRate.contains(AIConversationActions.rate), isTrue);
  });

  test('AIConversationActions combined with | contain no other action', () {
    final editAndRate = AIConversationActions.edit | AIConversationActions.rate;

    expect(editAndRate.contains(AIConversationActions.regenerate), isFalse);
  });

  test('AIConversationActions combined with every other action are all of them', () {
    final editAndRate = AIConversationActions.edit | AIConversationActions.rate;

    expect(editAndRate | AIConversationActions.regenerate, AIConversationActions.all);
  });

  test('AIConversationActions.none contains no action', () {
    expect(AIConversationActions.none.contains(AIConversationActions.rate), isFalse);
  });
}
