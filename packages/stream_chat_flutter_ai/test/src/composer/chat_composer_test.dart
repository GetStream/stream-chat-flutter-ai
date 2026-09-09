import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Mirror the private keys `ChatComposer` stamps on the 8px gaps it inserts
/// beside a rendered leading/trailing slot, so the gap-handling tests name
/// exactly those spacers — and which side each is on — rather than matching
/// any 8px `SizedBox` in the subtree.
const _leadingGapKey = Key('stream_chat_flutter_ai.composer.slot_gap.leading');
const _trailingGapKey = Key('stream_chat_flutter_ai.composer.slot_gap.trailing');

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

      expect(find.byKey(_leadingGapKey), findsOneWidget);
      expect(find.byKey(_trailingGapKey), findsNothing);
    });

    testWidgets('reserves a spacer on each side when both factory slots render', (tester) async {
      // The other half of the invariant the test above pins: the gap is
      // inserted for a slot that renders, and only for a slot that renders.
      // Found by key, not by width: the attachment thumbnails carry an 8px
      // separator of their own, so a width-only predicate would silently
      // start measuring that too the first time a test rendered an
      // attachment.
      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            factory: _TrailingSlotFactory(),
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );

      expect(find.byKey(_leadingGapKey), findsOneWidget);
      expect(find.byKey(_trailingGapKey), findsOneWidget);
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

  group('ChatComposerFactory', () {
    testWidgets('default input slot renders a ChatComposerInput', (tester) async {
      await tester.pumpWidget(_wrap(ChatComposer(onSendPressed: (_, __, ___) {})));

      expect(find.byType(ChatComposerInput), findsOneWidget);
    });

    testWidgets('buildInput can wrap the default input', (tester) async {
      var sent = false;
      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            factory: _WrappingInputFactory(),
            onSendPressed: (_, __, ___) => sent = true,
          ),
        ),
      );

      expect(find.byType(ChatComposerInput), findsOneWidget);
      expect(find.byType(_InputWrapper), findsOneWidget);

      // Decoration must not cost the wiring: the wrapped default still owns
      // the composer's send button.
      await tester.enterText(find.byType(TextField), 'Hello');
      // Settled, not a single pump: the trailing control's AnimatedSwitcher
      // has both the disabled and the enabled send button on screen while it
      // cross-fades, and `tap` needs one target.
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      expect(sent, isTrue);
    });

    testWidgets('buildInput can replace the input and reuse the send wiring', (tester) async {
      final controller = ChatComposerController();
      final focusNode = FocusNode();
      String? sentText;

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            focusNode: focusNode,
            factory: _ReplacementInputFactory(),
            onSendPressed: (text, _, __) => sentText = text,
          ),
        ),
      );

      expect(find.byType(ChatComposerInput), findsNothing);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.tap(find.text('go'));
      await tester.pump();

      expect(sentText, equals('Hello'));
      // The point of this test: `props.onSend` is the composer's own handler,
      // not just a hook that fires `onSendPressed`. Only the real one clears
      // the controller and returns focus afterwards, so these two assertions
      // are what prove a fully custom input inherits the whole send
      // behaviour rather than a lookalike that merely fires the callback.
      expect(controller.text, isEmpty);
      expect(focusNode.hasFocus, isTrue);
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('props.onSend does nothing when there is no content', (tester) async {
      // The `hasContent` guard in `_onSend` was near-unreachable while the
      // input was private — the default send button is disabled on an empty
      // field. `props.onSend` is now handed to host code under no obligation
      // to gate on it, so an always-enabled custom button would otherwise
      // fire `onSendPressed('', null, [])` at the backend.
      var sends = 0;

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            factory: _ReplacementInputFactory(),
            onSendPressed: (_, __, ___) => sends++,
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(sends, isZero);
    });

    testWidgets('props.onStop reaches onStopPressed from a replacement input', (tester) async {
      final controller = ChatComposerController()..isGenerating = true;
      var stopped = false;

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            factory: _ReplacementInputFactory(),
            onSendPressed: (_, __, ___) {},
            onStopPressed: () => stopped = true,
          ),
        ),
      );

      await tester.tap(find.text('stop'));
      await tester.pump();

      expect(stopped, isTrue);
      controller.dispose();
    });

    testWidgets('props.onStop is null when the host passed no onStopPressed', (tester) async {
      // So a custom input can tell that stopping is unsupported instead of
      // rendering a control that silently does nothing.
      final controller = ChatComposerController()..isGenerating = true;
      final factory = _CapturingInputFactory();

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            factory: factory,
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );

      expect(factory.captured!.onStop, isNull);

      // And the default input disables its stop button rather than offering
      // a dead one.
      final stopButton = tester.widget<ComposerActionButton>(find.byType(ComposerActionButton));
      expect(stopButton.icon, equals(Icons.stop_rounded));
      expect(stopButton.onPressed, isNull);
      controller.dispose();
    });

    testWidgets('a rejected onSendPressed future is reported, not swallowed', (tester) async {
      // `ChatComposerSendCallback` returns `FutureOr<void>`, and the docs and
      // README both show an `async` callback. A rejection used to reach the
      // enclosing Zone as an unhandled async error: one console line in
      // debug, nothing in release.
      final controller = ChatComposerController(initialText: 'Hello');
      final errors = <Object>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details.exception);
      addTearDown(() => FlutterError.onError = previousOnError);

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            factory: _ReplacementInputFactory(),
            onSendPressed: (_, __, ___) async => throw StateError('send failed'),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(errors, hasLength(1));
      expect(errors.single, isStateError);
      controller.dispose();
    });

    testWidgets('buildInput receives the composer controller, focus node and config', (tester) async {
      final controller = ChatComposerController();
      final focusNode = FocusNode();
      final factory = _CapturingInputFactory();

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            focusNode: focusNode,
            factory: factory,
            hintText: 'Ask me',
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            enableSpeechToText: true,
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );

      final props = factory.captured!;
      expect(identical(props.controller, controller), isTrue);
      expect(identical(props.focusNode, focusNode), isTrue);

      // Asserted on the rendered TextField, not on the props object: an echo
      // test (`props.minLines == 2`) passes just as happily when the default
      // input ignores the value entirely, which is the failure worth
      // catching.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintText, equals('Ask me'));
      expect(field.minLines, equals(2));
      expect(field.maxLines, equals(4));
      expect(field.textInputAction, equals(TextInputAction.send));
      expect(identical(field.focusNode, focusNode), isTrue);

      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('a custom input forwarding props.hintText gets the default placeholder', (tester) async {
      // The default used to live in `ChatComposerInput` as
      // `props.hintText ?? 'Ask anything…'`, so a custom input forwarding
      // `props.hintText` — exactly what the README shows — rendered no
      // placeholder at all.
      final factory = _CapturingInputFactory();

      await tester.pumpWidget(
        _wrap(ChatComposer(factory: factory, onSendPressed: (_, __, ___) {})),
      );

      expect(factory.captured!.hintText, equals(ChatComposerInputProps.defaultHintText));
      expect(find.text(ChatComposerInputProps.defaultHintText), findsOneWidget);
    });

    testWidgets('a send-action submit sends through props.onSend', (tester) async {
      var sent = false;

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            textInputAction: TextInputAction.send,
            onSendPressed: (_, __, ___) => sent = true,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      expect(sent, isTrue);
    });

    testWidgets('speechToTextConfig reaches the mic button', (tester) async {
      const config = SpeechToTextConfig(localeId: 'nl_NL');

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            enableSpeechToText: true,
            speechToTextConfig: config,
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );

      final button = tester.widget<SpeechToTextButton>(find.byType(SpeechToTextButton));
      expect(button.config, same(config));
    });

    testWidgets('default attachment sheet is a ComposerAttachmentSheet', (tester) async {
      final controller = ChatComposerController();

      await tester.pumpWidget(
        _wrap(
          ChatComposer(controller: controller, onSendPressed: (_, __, ___) {}),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      // Not `pumpAndSettle` — the default sheet shows an indeterminate
      // `CircularProgressIndicator` while its (unmocked,
      // platform-channel-based) photo permission/gallery check is in flight,
      // which never "settles" on its own.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ComposerAttachmentSheet), findsOneWidget);
      controller.dispose();
    });

    testWidgets('buildAttachmentSheet replaces the sheet the default "+" button opens', (tester) async {
      // Regression test for the plumbing that makes a sheet-only override
      // work: `_AttachmentButton` used to construct `ComposerAttachmentSheet`
      // itself, so a factory overriding just the sheet was silently ignored.
      // The default `buildLeading` now hands the button the factory instance,
      // and this factory leaves `buildLeading` alone — so the "+" below is
      // still the default button.
      final controller = ChatComposerController();
      final factory = _CustomSheetFactory();

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            factory: factory,
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      // `pumpAndSettle` is safe here, unlike in the test above: the
      // replacement sheet makes no platform-channel call, so there is nothing
      // left spinning once the modal's entrance animation finishes.
      await tester.pumpAndSettle();

      expect(find.text('custom sheet'), findsOneWidget);
      expect(find.byType(ComposerAttachmentSheet), findsNothing);
      // Pinned here rather than left to the default sheet's use of
      // `chatOptions`, so the custom-sheet path stands on its own.
      expect(identical(factory.captured!.controller, controller), isTrue);
      controller.dispose();
    });

    testWidgets('buildTrailing receives the composer controller', (tester) async {
      final controller = ChatComposerController();

      await tester.pumpWidget(
        _wrap(
          ChatComposer(
            controller: controller,
            factory: _TrailingSlotFactory(),
            onSendPressed: (_, __, ___) {},
          ),
        ),
      );

      // Rendered from the props rather than asserted on them, so a factory
      // handing the trailing slot the wrong controller fails here.
      controller.selectChatOption(const ChatOption(id: 'a', text: 'Deep research', icon: Icons.search));
      await tester.pump();

      expect(find.text('trailing:Deep research'), findsOneWidget);
      controller.dispose();
    });
  });

  group('ChatComposerInput', () {
    testWidgets('rebuilds standalone, without a ChatComposer above it', (tester) async {
      // It is public API now, so it has to drive its own rebuilds: as the
      // private `_InputContainer` its only construction site sat inside the
      // composer's ListenableBuilder. Without this, standalone use rendered
      // once and then froze — typing never enabled send, a dismissed chip
      // stayed on screen.
      final controller = ChatComposerController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _wrap(
          ChatComposerInput(
            props: ChatComposerInputProps(
              controller: controller,
              focusNode: focusNode,
              onSend: () {},
            ),
          ),
        ),
      );

      expect(find.text('Deep research'), findsNothing);

      controller.selectChatOption(const ChatOption(id: 'a', text: 'Deep research', icon: Icons.search));
      await tester.pumpAndSettle();

      expect(find.text('Deep research'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pumpAndSettle();

      final sendButton = tester.widget<ComposerActionButton>(find.byType(ComposerActionButton));
      expect(sendButton.icon, equals(Icons.arrow_upward_rounded));
      expect(sendButton.onPressed, isNotNull);

      controller.dispose();
      focusNode.dispose();
    });
  });

  group('ChatComposerInputProps', () {
    test('copyWith replaces only the named fields', () {
      final controller = ChatComposerController();
      final focusNode = FocusNode();
      void onSend() {}
      void onStop() {}
      final props = ChatComposerInputProps(
        controller: controller,
        focusNode: focusNode,
        onSend: onSend,
        onStop: onStop,
        hintText: 'Ask me',
        minLines: 2,
        maxLines: 4,
        textInputAction: TextInputAction.send,
        enableSpeechToText: true,
      );

      final copy = props.copyWith(hintText: 'Ask the docs');

      expect(copy.hintText, equals('Ask the docs'));
      // The point of copyWith: everything the host configured survives a
      // one-field tweak, where hand-listing all ten silently reverts any
      // field you forget to a constructor default.
      expect(identical(copy.controller, controller), isTrue);
      expect(identical(copy.focusNode, focusNode), isTrue);
      expect(copy.onSend, equals(onSend));
      expect(copy.onStop, equals(onStop));
      expect(copy.minLines, equals(2));
      expect(copy.maxLines, equals(4));
      expect(copy.textInputAction, equals(TextInputAction.send));
      expect(copy.enableSpeechToText, isTrue);

      controller.dispose();
      focusNode.dispose();
    });

    test('copyWith drops onStop only when asked', () {
      final controller = ChatComposerController();
      final focusNode = FocusNode();
      final props = ChatComposerInputProps(
        controller: controller,
        focusNode: focusNode,
        onSend: () {},
        onStop: () {},
      );

      expect(props.copyWith().onStop, isNotNull);
      expect(props.copyWith(clearOnStop: true).onStop, isNull);

      controller.dispose();
      focusNode.dispose();
    });

    test('rejects a maxLines below minLines', () {
      final controller = ChatComposerController();
      final focusNode = FocusNode();

      expect(
        () => ChatComposerInputProps(
          controller: controller,
          focusNode: focusNode,
          onSend: () {},
          minLines: 4,
          maxLines: 2,
        ),
        throwsAssertionError,
      );

      controller.dispose();
      focusNode.dispose();
    });
  });
}

/// Renders something in the otherwise-empty trailing slot, so the composer's
/// gap handling can be observed on both sides of the input.
class _TrailingSlotFactory extends ChatComposerFactory {
  @override
  Widget buildTrailing(BuildContext context, ChatComposerTrailingProps props) {
    return Text('trailing:${props.controller.selectedChatOption?.text ?? ''}');
  }
}

/// Keeps the default input and decorates around it.
class _WrappingInputFactory extends ChatComposerFactory {
  @override
  Widget buildInput(BuildContext context, ChatComposerInputProps props) =>
      _InputWrapper(child: ChatComposerInput(props: props));
}

/// A distinguishable wrapper, so the test can assert the decoration rendered
/// rather than inferring it from the default input's presence.
class _InputWrapper extends StatelessWidget {
  const _InputWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Discards the default input entirely, wiring a bare field and button to the
/// composer's own send handler.
class _ReplacementInputFactory extends ChatComposerFactory {
  @override
  Widget buildInput(BuildContext context, ChatComposerInputProps props) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: props.controller.textEditingController,
          focusNode: props.focusNode,
        ),
        // Deliberately always enabled, unlike the default input's send
        // button: that is what exercises `_onSend`'s own `hasContent` guard.
        TextButton(onPressed: props.onSend, child: const Text('go')),
        TextButton(onPressed: props.onStop, child: const Text('stop')),
      ],
    );
  }
}

/// Records the props the composer passes to the input slot.
class _CapturingInputFactory extends ChatComposerFactory {
  ChatComposerInputProps? captured;

  @override
  Widget buildInput(BuildContext context, ChatComposerInputProps props) {
    captured = props;
    return ChatComposerInput(props: props);
  }
}

/// Swaps the sheet's contents without touching [ChatComposerFactory.buildLeading].
class _CustomSheetFactory extends ChatComposerFactory {
  ChatComposerAttachmentSheetProps? captured;

  @override
  Widget buildAttachmentSheet(BuildContext context, ChatComposerAttachmentSheetProps props) {
    captured = props;
    return const Text('custom sheet');
  }
}
