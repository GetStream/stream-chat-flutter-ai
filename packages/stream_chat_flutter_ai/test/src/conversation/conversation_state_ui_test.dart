import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/conversation/conversation_state.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import '../genui/genui_test_doubles.dart';

void main() {
  test('PendingMessageTracker.entries keeps a reply that shows only its UI so far', () {
    final entries = PendingMessageTracker().entries(
      [Reply('q1', role: AIMessageRole.user), Reply('a1', isGenerating: true, uiDocument: _writingUI())],
      null,
      canShowUI: _showsUI,
    );

    expect([for (final entry in entries) entry.id], ['q1', 'a1']);
  });

  test('PendingMessageTracker.entries leaves out a reply whose UI nothing shows', () {
    final entries = PendingMessageTracker().entries([
      Reply('q1', role: AIMessageRole.user),
      Reply('a1', isGenerating: true, uiDocument: _writingUI()),
    ], null);

    expect([for (final entry in entries) entry.id], ['q1']);
  });

  test("PendingMessageTracker.isAwaitingReply is false once the reply's UI shows", () {
    final messages = [Reply('q1', role: AIMessageRole.user), Reply('a1', isGenerating: true, uiDocument: _writingUI())];
    final tracker = PendingMessageTracker()..entries(messages, null, canShowUI: _showsUI);

    expect(tracker.isAwaitingReply(messages, null, canShowUI: _showsUI), isFalse);
  });

  test("PendingMessageTracker.isAwaitingReply is true while no renderer reads the reply's UI", () {
    final messages = [Reply('q1', role: AIMessageRole.user), Reply('a1', isGenerating: true, uiDocument: _writingUI())];
    final tracker = PendingMessageTracker()..entries(messages, null);

    expect(tracker.isAwaitingReply(messages, null), isTrue);
  });
}

AIUIDocument _writingUI() => openUI('root = Card([title])', isStreaming: true);

bool _showsUI(AIUIDocument document, String messageId) => true;
