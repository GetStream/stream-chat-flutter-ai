import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ChatComposerController', () {
    test('hasContent is false when text is empty', () {
      final controller = ChatComposerController();
      expect(controller.hasContent, isFalse);
      controller.dispose();
    });

    test('hasContent is true when text is non-empty', () {
      final controller = ChatComposerController(initialText: 'hello');
      expect(controller.hasContent, isTrue);
      controller.dispose();
    });

    test('selectChatOption updates selectedChatOption', () {
      final controller = ChatComposerController();
      const option = ChatOption(id: 'a', text: 'Option A');
      controller.selectChatOption(option);
      expect(controller.selectedChatOption, equals(option));
      controller.dispose();
    });

    test('clearSelectedChatOption removes the selection', () {
      final controller = ChatComposerController()
        ..selectChatOption(const ChatOption(id: 'a', text: 'Option A'))
        ..clearSelectedChatOption();
      expect(controller.selectedChatOption, isNull);
      controller.dispose();
    });

    test('clear resets text, selectedChatOption, and attachments', () {
      final controller = ChatComposerController(initialText: 'some text')
        ..selectChatOption(const ChatOption(id: 'a', text: 'Option A'))
        ..addAttachments([XFile('a.png')])
        ..clear();
      expect(controller.text, isEmpty);
      expect(controller.selectedChatOption, isNull);
      expect(controller.attachments, isEmpty);
      controller.dispose();
    });

    test('isGenerating setter notifies listeners', () {
      final controller = ChatComposerController();
      var notified = false;
      controller
        ..addListener(() => notified = true)
        ..isGenerating = true;
      expect(notified, isTrue);
      expect(controller.isGenerating, isTrue);
      controller.dispose();
    });

    test('addAttachments appends files and notifies listeners', () {
      final controller = ChatComposerController();
      var notified = false;
      controller
        ..addListener(() => notified = true)
        ..addAttachments([XFile('a.png'), XFile('b.png')]);

      expect(notified, isTrue);
      expect(controller.attachments, hasLength(2));
      controller.dispose();
    });

    test('addAttachments makes hasContent true even with no text', () {
      final controller = ChatComposerController();
      expect(controller.hasContent, isFalse);

      controller.addAttachments([XFile('a.png')]);

      expect(controller.hasContent, isTrue);
      expect(controller.hasText, isFalse);
      controller.dispose();
    });

    test('removeAttachment removes a single file and notifies listeners', () {
      final fileA = XFile('a.png');
      final fileB = XFile('b.png');
      final controller = ChatComposerController()..addAttachments([fileA, fileB]);
      var notified = false;
      controller
        ..addListener(() => notified = true)
        ..removeAttachment(fileA);

      expect(notified, isTrue);
      expect(controller.attachments, equals([fileB]));
      controller.dispose();
    });

    test('removeAttachment matches by path, not identity', () {
      // The removal uses a separately-constructed XFile for the same image: the
      // type doesn't override `==`, so identity matching would silently fail.
      final controller = ChatComposerController()
        ..addAttachments([XFile('a.png')])
        ..removeAttachment(XFile('a.png'));

      expect(controller.attachments, isEmpty);
      controller.dispose();
    });

    test('addAttachments skips a file that is already attached', () {
      final controller = ChatComposerController()..addAttachments([XFile('a.png')]);
      var notified = false;
      controller.addListener(() => notified = true);

      final added = controller.addAttachments([XFile('a.png'), XFile('b.png')]);

      expect(added.map((it) => it.path), ['b.png']);
      expect(controller.attachments.map((it) => it.path), ['a.png', 'b.png']);
      expect(notified, isTrue);
      controller.dispose();
    });

    test('addAttachments does not notify when everything was a duplicate', () {
      final controller = ChatComposerController()..addAttachments([XFile('a.png')]);
      var notified = false;
      controller.addListener(() => notified = true);

      expect(controller.addAttachments([XFile('a.png')]), isEmpty);
      expect(notified, isFalse);
      controller.dispose();
    });

    test('addAttachments stops at maxAttachments', () {
      final controller = ChatComposerController(maxAttachments: 2);

      final added = controller.addAttachments([XFile('a.png'), XFile('b.png'), XFile('c.png')]);

      expect(added.map((it) => it.path), ['a.png', 'b.png']);
      expect(controller.attachments, hasLength(2));
      expect(controller.remainingAttachmentSlots, 0);
      controller.dispose();
    });

    test('the cap holds across separate addAttachments calls', () {
      final controller = ChatComposerController(maxAttachments: 2)
        ..addAttachments([XFile('a.png')])
        ..addAttachments([XFile('b.png')])
        ..addAttachments([XFile('c.png')]);

      expect(controller.attachments.map((it) => it.path), ['a.png', 'b.png']);
      controller.dispose();
    });

    test('removing frees a slot again', () {
      final controller = ChatComposerController(maxAttachments: 1)..addAttachments([XFile('a.png')]);
      expect(controller.addAttachments([XFile('b.png')]), isEmpty);

      controller
        ..removeAttachment(XFile('a.png'))
        ..addAttachments([XFile('b.png')]);

      expect(controller.attachments.map((it) => it.path), ['b.png']);
      controller.dispose();
    });

    test('hasAttachmentAt reports what is attached', () {
      final controller = ChatComposerController()..addAttachments([XFile('a.png')]);

      expect(controller.hasAttachmentAt('a.png'), isTrue);
      expect(controller.hasAttachmentAt('b.png'), isFalse);
      controller.dispose();
    });
  });

  group('ChatComposer', () {
    testWidgets('renders hint text in empty text field', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            hintText: 'Ask anything…',
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );
      expect(find.text('Ask anything…'), findsOneWidget);
    });

    testWidgets('displays send button when text is not empty', (tester) async {
      final controller = ChatComposerController(initialText: 'Hello');
      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      controller.dispose();
    });

    testWidgets('displays stop button when isGenerating is true', (tester) async {
      final controller = ChatComposerController()..isGenerating = true;
      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            onSendPressed: (_, __, ___) {},
            onStopPressed: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      controller.dispose();
    });

    testWidgets('does not render a chip row even when chatOptions is non-empty', (tester) async {
      // Regression test: chat options used to render as an always-visible
      // chip row above the input. That row was removed in favor of listing
      // them inside `ComposerAttachmentSheet` (opened from the "+" button) —
      // see the "ComposerAttachmentSheet" group below.
      final controller = ChatComposerController(
        chatOptions: [const ChatOption(id: '1', text: 'Summarize')],
      );
      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );
      expect(find.text('Summarize'), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
      controller.dispose();
    });

    testWidgets('send callback receives text, selected option, and attachments', (tester) async {
      String? capturedText;
      ChatOption? capturedOption;
      List<XFile>? capturedAttachments;
      const option = ChatOption(id: 'summarize', text: 'Summarize');
      final controller = ChatComposerController(chatOptions: [option])
        ..selectChatOption(option)
        ..addAttachments([XFile('a.png')]);

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            onSendPressed: (text, selectedOption, attachments) {
              capturedText = text;
              capturedOption = selectedOption;
              capturedAttachments = attachments;
            },
          ),
        ),
      );

      // Type a message.
      await tester.enterText(find.byType(TextField), 'Hello AI');
      await tester.pump();

      // Tap send.
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      expect(capturedText, equals('Hello AI'));
      expect(capturedOption, equals(option));
      expect(capturedAttachments, hasLength(1));
      controller.dispose();
    });

    testWidgets('onStopPressed is called when stop button is tapped', (tester) async {
      var stopped = false;
      final controller = ChatComposerController()..isGenerating = true;

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            onSendPressed: (_, __, ___) {},
            onStopPressed: () => stopped = true,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pump();
      expect(stopped, isTrue);
      controller.dispose();
    });

    testWidgets('trailing control shows mic when empty and speech is enabled', (tester) async {
      final controller = ChatComposerController();
      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            enableSpeechToText: true,
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );
      await tester.pump();

      // Asserting the mic is actually *there*, not merely that the send button
      // isn't: the button used to hide itself until the platform recognizer had
      // initialized, so this passed while the trailing slot rendered nothing at
      // all — no mic and no send button either.
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
      controller.dispose();
    });

    testWidgets('does not initialize speech recognition until the mic is tapped', (tester) async {
      // `SpeechToText.initialize` triggers the microphone permission prompt, so
      // it must not run just because a composer rendered.
      const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return call.method == 'initialize' ? true : null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

      final controller = ChatComposerController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            enableSpeechToText: true,
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );
      await tester.pump();

      expect(calls, isEmpty, reason: 'mounting the composer must not ask for the microphone');

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pump();

      expect(calls, contains('initialize'));
    });

    testWidgets('trailing control morphs from mic to send once text is entered', (tester) async {
      final controller = ChatComposerController();
      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            enableSpeechToText: true,
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      controller.dispose();
    });

    testWidgets('renders attachment thumbnails and removes them on tap', (tester) async {
      final controller = ChatComposerController()..addAttachments([XFile('a.png')]);
      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(controller.attachments, isEmpty);
      controller.dispose();
    });

    testWidgets('default leading slot renders an attachment button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('does not reserve a spacer for the absent trailing factory slot', (tester) async {
      // Regression test: `buildTrailing` defaults to `null` (no widget), and
      // the composer must only insert its 8px gap next to a slot that
      // actually renders something. Previously this was decided by comparing
      // the built widget against a `SizedBox.shrink()` sentinel, which is
      // *not* `identical`/`==` to another separately-constructed
      // `SizedBox.shrink()` in this Flutter version — so the gap was always
      // inserted, doubling the composer's right-hand margin.
      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );

      final gapSpacers = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 8 && widget.height == null,
      );
      expect(gapSpacers, findsOneWidget);
    });
  });

  group('ComposerAttachmentSheet', () {
    testWidgets('tapping "+" opens the sheet with chat options listed', (tester) async {
      const option = ChatOption(
        id: 'research',
        text: 'Deep research',
        description: 'Get a detailed report',
      );
      final controller = ChatComposerController(chatOptions: [option]);

      await tester.pumpWidget(
        _wrap(
          ChatComposer(controller: controller, onSendPressed: (_, __, ___) {}),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      // Not `pumpAndSettle` — the sheet shows an indeterminate
      // `CircularProgressIndicator` while its (unmocked, platform-channel-based)
      // photo permission/gallery check is in flight, which never "settles" on
      // its own. A bounded pump is enough to open the sheet; none of these
      // assertions depend on that photo section finishing loading.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Deep research'), findsOneWidget);
      expect(find.text('Get a detailed report'), findsOneWidget);
      controller.dispose();
    });

    testWidgets('selecting a chat option updates the controller and closes the sheet', (tester) async {
      const option = ChatOption(id: 'research', text: 'Deep research');
      final controller = ChatComposerController(chatOptions: [option]);

      await tester.pumpWidget(
        _wrap(
          ChatComposer(controller: controller, onSendPressed: (_, __, ___) {}),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      // Not `pumpAndSettle` — the sheet shows an indeterminate
      // `CircularProgressIndicator` while its (unmocked, platform-channel-based)
      // photo permission/gallery check is in flight, which never "settles" on
      // its own. A bounded pump is enough to open the sheet; none of these
      // assertions depend on that photo section finishing loading.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Deep research'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(controller.selectedChatOption, equals(option));
      // The sheet's own option row is gone (it closed); the one remaining
      // "Deep research" is the composer's inline selected-option chip.
      expect(find.byType(ListTile), findsNothing);
      expect(find.text('Deep research'), findsOneWidget);
      controller.dispose();
    });

    testWidgets('does not render a chat-options section when chatOptions is empty', (tester) async {
      final controller = ChatComposerController();

      await tester.pumpWidget(
        _wrap(
          ChatComposer(controller: controller, onSendPressed: (_, __, ___) {}),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      // Not `pumpAndSettle` — the sheet shows an indeterminate
      // `CircularProgressIndicator` while its (unmocked, platform-channel-based)
      // photo permission/gallery check is in flight, which never "settles" on
      // its own. A bounded pump is enough to open the sheet; none of these
      // assertions depend on that photo section finishing loading.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ListTile), findsNothing);
      controller.dispose();
    });
  });

  group('ChatComposer localization', () {
    testWidgets('the hint comes from the scope when hintText is null', (tester) async {
      await tester.pumpWidget(
        _wrapTranslated(ChatComposer(onSendPressed: (_, __, ___) {})),
      );

      expect(find.text('VRAAG MAAR'), findsOneWidget);
    });

    testWidgets('an explicit hintText wins over the scope', (tester) async {
      await tester.pumpWidget(
        _wrapTranslated(
          ChatComposer(hintText: 'Per-composer hint', onSendPressed: (_, __, ___) {}),
        ),
      );

      expect(find.text('Per-composer hint'), findsOneWidget);
      expect(find.text('VRAAG MAAR'), findsNothing);
    });

    testWidgets('the send tooltip is translated in both its enabled and disabled state', (tester) async {
      final controller = ChatComposerController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapTranslated(
          ChatComposer(controller: controller, onSendPressed: (_, __, ___) {}),
        ),
      );

      // Disabled arm: no content yet.
      expect(find.byTooltip('VERSTUUR'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hello');
      // Settled, or the AnimatedSwitcher still holds the outgoing disabled
      // button alongside the incoming enabled one.
      await tester.pumpAndSettle();

      // Enabled arm — a separate literal before this change.
      expect(find.byTooltip('VERSTUUR'), findsOneWidget);
    });

    testWidgets('the stop tooltip is translated', (tester) async {
      final controller = ChatComposerController()..isGenerating = true;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapTranslated(
          ChatComposer(controller: controller, onSendPressed: (_, __, ___) {}),
        ),
      );

      expect(find.byTooltip('STOP MAAR'), findsOneWidget);
    });

    testWidgets('the attachment-thumbnail dismiss tooltip is translated', (tester) async {
      final controller = ChatComposerController()..addAttachments([XFile('a.png')]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapTranslated(
          ChatComposer(controller: controller, onSendPressed: (_, __, ___) {}),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('WEG ERMEE'), findsOneWidget);
    });

    testWidgets('the selected-option chip dismiss tooltip is translated, with the option interpolated', (tester) async {
      final controller = ChatComposerController()..selectChatOption(const ChatOption(id: 'a', text: 'Weather'));
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapTranslated(
          ChatComposer(controller: controller, onSendPressed: (_, __, ___) {}),
        ),
      );

      expect(find.byTooltip('Weather WISSEN'), findsOneWidget);
    });

    testWidgets('the leading attachment-button tooltip is translated', (tester) async {
      await tester.pumpWidget(
        _wrapTranslated(ChatComposer(onSendPressed: (_, __, ___) {})),
      );

      expect(find.byTooltip('FOTO ERBIJ'), findsOneWidget);
    });

    testWidgets('the attachment sheet is translated across its own route', (tester) async {
      // The sheet is pushed with `showModalBottomSheet`, so it sits under the
      // Navigator rather than under the scope this test wraps the composer in.
      // It only reads these strings because the leading button re-provides the
      // scope inside the sheet's route.
      await tester.pumpWidget(
        _wrapTranslated(ChatComposer(onSendPressed: (_, __, ___) {})),
      );

      await tester.tap(find.byIcon(Icons.add));
      // Bounded pump rather than `pumpAndSettle` — see the note in the
      // ComposerAttachmentSheet group above.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('FOTOS'), findsOneWidget);
      expect(find.text('ALLE FOTOS'), findsOneWidget);
      expect(find.byTooltip('LACH EENS'), findsOneWidget);
    });
  });
}

Widget _wrapTranslated(Widget child) => _wrap(
  AITranslationsScope(translations: const _TestTranslations(), child: child),
);

/// Overrides every string [ChatComposer] and its attachment sheet render, so a
/// leaked English literal fails rather than merely looking the same.
class _TestTranslations extends DefaultAITranslations {
  const _TestTranslations();

  @override
  String get composerHint => 'VRAAG MAAR';

  @override
  String get send => 'VERSTUUR';

  @override
  String get stopGenerating => 'STOP MAAR';

  @override
  String get removeAttachment => 'WEG ERMEE';

  @override
  String clearOption(String option) => '$option WISSEN';

  @override
  String get addPhotos => 'FOTO ERBIJ';

  @override
  String get photos => 'FOTOS';

  @override
  String get allPhotos => 'ALLE FOTOS';

  @override
  String get takePhoto => 'LACH EENS';
}
