import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import '../conversation/ai_conversation_test_doubles.dart';

const _icons = StreamIcons();

void main() {
  test('ChatComposerController.cancelEditing stops editing and empties the text field', () {
    final controller = ChatComposerController(initialText: 'Plan Porto')..isEditing = true;
    addTearDown(controller.dispose);

    controller.cancelEditing();

    expect(controller.isEditing, isFalse);
    expect(controller.text, '');
  });

  test('ChatComposerController.cancelEditing keeps the text while not editing', () {
    final controller = ChatComposerController(initialText: 'Half a thought');
    addTearDown(controller.dispose);

    controller.cancelEditing();

    expect(controller.text, 'Half a thought', reason: "it wasn't editing");
  });

  testWidgets('editing chip says the person is editing a message while they are', (tester) async {
    final controller = ChatComposerController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(ChatComposer(controller: controller, onSendPressed: (_, _, _) {})));

    expect(find.text('Editing message'), findsNothing);

    controller.isEditing = true;
    await tester.pump();

    expect(find.text('Editing message'), findsOneWidget);
    expect(find.byIcon(_icons.edit), findsOneWidget);
  });

  testWidgets('editing chip cancels editing from its button', (tester) async {
    final controller = ChatComposerController(initialText: 'Plan Porto')..isEditing = true;
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(ChatComposer(controller: controller, onSendPressed: (_, _, _) {})));

    await tester.tap(find.byTooltip('Cancel editing'));
    await tester.pump();

    expect(controller.isEditing, isFalse);
    expect(controller.text, '');
    expect(find.text('Editing message'), findsNothing);
  });

  testWidgets('editing chip translates its label and button', (tester) async {
    final controller = ChatComposerController()..isEditing = true;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(
        AITranslationsScope(
          translations: const _Translations(),
          child: ChatComposer(controller: controller, onSendPressed: (_, _, _) {}),
        ),
      ),
    );

    expect(find.text('Bericht bewerken'), findsOneWidget);
    expect(find.byTooltip('Bewerken annuleren'), findsOneWidget);
  });

  testWidgets('ChatComposer focuses its field when the controller asks for focus', (tester) async {
    final controller = ChatComposerController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(ChatComposer(controller: controller, onSendPressed: (_, _, _) {})));
    expect(_field(tester).focusNode!.hasFocus, isFalse);

    controller.requestFocus();
    await tester.pump();

    expect(_field(tester).focusNode!.hasFocus, isTrue);
  });

  testWidgets('ChatComposer focuses its field when it is shown while the person is editing', (tester) async {
    final controller = ChatComposerController()..isEditing = true;
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(ChatComposer(controller: controller, onSendPressed: (_, _, _) {})));
    await tester.pump();

    expect(_field(tester).focusNode!.hasFocus, isTrue);
  });

  testWidgets('ChatComposer leaves its field alone when it is shown while the person is not editing', (tester) async {
    final controller = ChatComposerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(ChatComposer(controller: controller, onSendPressed: (_, _, _) {})));
    await tester.pump();

    expect(_field(tester).focusNode!.hasFocus, isFalse);
  });

  testWidgets('ChatComposer stops listening to the controller it no longer shows', (tester) async {
    final first = ChatComposerController();
    final second = ChatComposerController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(_wrap(ChatComposer(controller: first, onSendPressed: (_, _, _) {})));
    await tester.pumpWidget(_wrap(ChatComposer(controller: second, onSendPressed: (_, _, _) {})));

    first.requestFocus();
    await tester.pump();

    expect(_field(tester).focusNode!.hasFocus, isFalse);

    second.requestFocus();
    await tester.pump();

    expect(_field(tester).focusNode!.hasFocus, isTrue);
  });

  testWidgets('ChatComposer.conversation sends to the conversation and stops it', (tester) async {
    final transport = ConversationTransport(
      messages: [
        ChatMessage.user('u1'),
        ChatMessage.reply('a1', text: 'Day one', generating: true),
      ],
    );
    final conversation = conversationOver(transport, replyTimeout: null);
    await tester.pumpWidget(_wrap(ChatComposer.conversation(conversation: conversation)));

    await tester.tap(find.byIcon(_icons.stopFill));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Make it three days');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(_icons.arrowUp));
    await tester.pump();

    expect(transport.stops, 1);
    expect(transport.lastRequest?.text, 'Make it three days');
    expect(conversation.composer.text, '', reason: 'the composer empties once it sends');
  });

  testWidgets('ChatComposer.conversation sends an edit of the message being edited', (tester) async {
    final transport = ConversationTransport(
      messages: [ChatMessage.user('u1', 'Plan Lisbon'), ChatMessage.reply('a1')],
    );
    final conversation = conversationOver(transport, replyTimeout: null);
    await tester.pumpWidget(_wrap(ChatComposer.conversation(conversation: conversation)));

    conversation.edit(ChatMessage.user('u1', 'Plan Lisbon'));
    await tester.pump();
    expect(find.text('Editing message'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Plan Porto');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(_icons.arrowUp));
    await tester.pump();

    expect(transport.lastRequest?.kind, AIConversationRequestKind.edit);
    expect(transport.lastRequest?.text, 'Plan Porto');
    expect(find.text('Editing message'), findsNothing);
  });

  testWidgets('ChatComposer.conversation focuses its field when a message is edited', (tester) async {
    final conversation = conversationOver(
      ConversationTransport(messages: [ChatMessage.user('u1', 'Plan Lisbon'), ChatMessage.reply('a1')]),
      replyTimeout: null,
    );
    await tester.pumpWidget(_wrap(ChatComposer.conversation(conversation: conversation)));
    expect(_field(tester).focusNode!.hasFocus, isFalse);

    conversation.edit(ChatMessage.user('u1', 'Plan Lisbon'));
    await tester.pump();

    expect(_field(tester).focusNode!.hasFocus, isTrue);
  });

  testWidgets('ChatComposer.conversation focuses its field again when a message is edited while it already is', (
    tester,
  ) async {
    final conversation = conversationOver(
      ConversationTransport(messages: [ChatMessage.user('u1', 'Plan Lisbon'), ChatMessage.reply('a1')]),
      replyTimeout: null,
    );
    await tester.pumpWidget(_wrap(ChatComposer.conversation(conversation: conversation)));
    conversation.edit(ChatMessage.user('u1', 'Plan Lisbon'));
    await tester.pump();
    _field(tester).focusNode!.unfocus();
    await tester.pump();
    expect(_field(tester).focusNode!.hasFocus, isFalse);

    conversation.edit(ChatMessage.user('u1', 'Plan Lisbon'));
    await tester.pump();

    expect(_field(tester).focusNode!.hasFocus, isTrue);
  });

  testWidgets('ChatComposer.conversation focuses its field when it is shown after a message was edited', (
    tester,
  ) async {
    final conversation = conversationOver(
      ConversationTransport(messages: [ChatMessage.user('u1', 'Plan Lisbon'), ChatMessage.reply('a1')]),
      replyTimeout: null,
    )..edit(ChatMessage.user('u1', 'Plan Lisbon'));

    await tester.pumpWidget(_wrap(ChatComposer.conversation(conversation: conversation)));
    await tester.pump();

    expect(_field(tester).focusNode!.hasFocus, isTrue);
  });

  testWidgets('ChatComposer.conversation shows the draft of the conversation it is given', (tester) async {
    final first = conversationOver(ConversationTransport());
    final second = conversationOver(ConversationTransport());

    await tester.pumpWidget(_wrap(ChatComposer.conversation(conversation: first)));
    expect(_field(tester).controller, same(first.composer.textEditingController));

    await tester.pumpWidget(_wrap(ChatComposer.conversation(conversation: second)));
    expect(
      _field(tester).controller,
      same(second.composer.textEditingController),
      reason: "not the first one's draft",
    );
  });
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

TextField _field(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField));

class _Translations extends DefaultAITranslations {
  const _Translations();

  @override
  String get editingMessage => 'Bericht bewerken';

  @override
  String get cancelEditing => 'Bewerken annuleren';
}
