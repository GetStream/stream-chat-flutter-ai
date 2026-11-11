import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'ai_conversation_test_doubles.dart';

void main() {
  test('rate keeps the rating and tells the transport', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport)..rate(ChatMessage.reply('a1'), AIMessageRating.positive);
    expect(conversation.ratings['a1'], AIMessageRating.positive);
    await settle();
    conversation.rate(ChatMessage.reply('a1'), null);
    await settle();

    expect(conversation.ratings['a1'], isNull);
    expect(transport.ratings, [('a1', AIMessageRating.positive), ('a1', null)]);
  });

  test('rate does nothing given the same rating again', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    conversationOver(transport)
      ..rate(ChatMessage.reply('a1'), AIMessageRating.positive)
      ..rate(ChatMessage.reply('a1'), AIMessageRating.positive);
    await settle();

    expect(transport.ratings, hasLength(1));
  });

  test('rate puts the rating back when the transport fails', () async {
    captureErrors();
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')]);
    final conversation = conversationOver(transport)..rate(ChatMessage.reply('a1'), AIMessageRating.positive);
    await settle();

    transport.failsRating = (_) => true;
    conversation.rate(ChatMessage.reply('a1'), AIMessageRating.negative);
    await settle();

    expect(conversation.ratings['a1'], AIMessageRating.positive);
  });

  test('rate keeps the new rating when the transport fails after the rating changed again', () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')])
      ..failsRating = ((rating) => rating == AIMessageRating.positive);
    final conversation = conversationOver(transport)
      ..rate(ChatMessage.reply('a1'), AIMessageRating.positive)
      ..rate(ChatMessage.reply('a1'), AIMessageRating.negative);
    await settle();

    expect(conversation.ratings['a1'], AIMessageRating.negative);
    expect(transport.ratings, [('a1', AIMessageRating.negative)], reason: "the rating it replaced isn't sent");
  });

  test("rate sends each reply's ratings in order", () async {
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')])
      ..holdsRatings = true;
    final conversation = conversationOver(transport)..rate(ChatMessage.reply('a1'), AIMessageRating.positive);
    await settle();
    conversation.rate(ChatMessage.reply('a1'), AIMessageRating.negative);
    await settle();

    expect(transport.ratings, [('a1', AIMessageRating.positive)], reason: 'the next one waits');

    transport.finishRating(0);
    await settle();
    transport.finishRating(1);
    await settle();

    expect(transport.ratings, [('a1', AIMessageRating.positive), ('a1', AIMessageRating.negative)]);
    expect(conversation.ratings['a1'], AIMessageRating.negative);
  });

  test('rate keeps the latest rating when an earlier one fails', () async {
    captureErrors();
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), ChatMessage.reply('a1')])
      ..holdsRatings = true;
    final conversation = conversationOver(transport)..rate(ChatMessage.reply('a1'), AIMessageRating.positive);
    await settle();
    conversation.rate(ChatMessage.reply('a1'), AIMessageRating.negative);
    transport.finishRating(0, error: const TransportError());
    await settle();

    expect(conversation.ratings['a1'], AIMessageRating.negative);

    transport.finishRating(1, error: const TransportError());
    await settle();

    expect(conversation.ratings['a1'], isNull, reason: 'what the transport has');
  });

  test('rate keeps the rating on the device when the transport does not take ratings', () async {
    final conversation = conversationOver(MinimalTransport())..rate(ChatMessage.reply('a1'), AIMessageRating.negative);
    await settle();

    expect(conversation.ratings['a1'], AIMessageRating.negative);
  });

  test("rate shows the replies' own ratings until the person rates them", () async {
    final rated = ChatMessage.reply('a1', rating: AIMessageRating.positive);
    final transport = ConversationTransport(messages: [ChatMessage.user('u1'), rated, ChatMessage.reply('a2')]);
    final conversation = conversationOver(transport);

    expect(conversation.ratings, {'a1': AIMessageRating.positive});

    conversation.rate(rated, null);
    await settle();

    expect(conversation.ratings, isEmpty);
    expect(transport.ratings, [('a1', null)]);

    transport.update([ChatMessage.user('u1'), rated, ChatMessage.reply('a2')]);

    expect(conversation.ratings, isEmpty, reason: "the person's rating stays over the one the reply still has");
  });
}
