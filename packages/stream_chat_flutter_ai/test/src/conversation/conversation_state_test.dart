import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/conversation/conversation_state.dart';
import 'package:stream_chat_flutter_ai/src/util/file_size.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

class _Message with AIMessage {
  _Message(this.id, this.role, [this.text = '']) : isGenerating = false;

  _Message.generating(this.id, this.role, this.text) : isGenerating = true;

  @override
  final String id;

  @override
  final AIMessageRole role;

  @override
  final String text;

  @override
  final bool isGenerating;
}

_Message _user(String id, [String text = 'question']) => _Message(id, AIMessageRole.user, text);
_Message _reply(String id, [String text = 'answer']) => _Message(id, AIMessageRole.assistant, text);
_Message _writing(String id, [String text = '']) => _Message.generating(id, AIMessageRole.assistant, text);

List<String> _ids(List<ConversationEntry> entries) => [for (final e in entries) e.id];

void main() {
  group('ConversationTurn', () {
    test('starts a turn at each message the person sent', () {
      final tracker = PendingMessageTracker();
      final turns = ConversationTurn.of(
        tracker.entries([_reply('hello'), _user('u1'), _reply('r1'), _reply('r1b'), _user('u2')], null),
      );
      expect(
        [for (final t in turns) _ids(t.entries)],
        [
          ['hello'],
          ['u1', 'r1', 'r1b'],
          ['u2'],
        ],
      );
    });
  });

  group('PendingMessageTracker', () {
    test('leaves out a reply with nothing to show', () {
      final tracker = PendingMessageTracker();
      expect(_ids(tracker.entries([_user('u1'), _writing('r1')], null)), ['u1']);
    });

    test('marks a reply that ends the conversation as the latest', () {
      final entries = PendingMessageTracker().entries([_user('u1'), _reply('r1')], null);
      expect([for (final e in entries) e.isLatestReply], [false, true]);
    });

    test('shows a message on its way, and its copy takes over its row', () {
      final tracker = PendingMessageTracker();
      final pending = AIPendingMessage(text: 'hi');
      expect(_ids(tracker.entries([_user('u1')], pending)), ['u1', pending.id]);

      final entries = tracker.entries([_user('u1'), _user('u2', 'hi')], pending);
      expect(_ids(entries), ['u1', pending.id], reason: "the copy keeps the pending row's id");
      expect(entries.last.message!.id, 'u2');
    });

    test('a copy arriving in the update that stops passing it still takes over', () {
      final tracker = PendingMessageTracker();
      final pending = AIPendingMessage(text: 'hi');
      tracker.entries([_user('u1')], pending);
      expect(_ids(tracker.entries([_user('u1'), _user('u2', 'hi')], null)), ['u1', pending.id]);
    });

    test('finds the copy by id when the app knew it', () {
      final tracker = PendingMessageTracker();
      final pending = AIPendingMessage(id: 'u3', text: 'hi');
      tracker.entries([_user('u1')], pending);
      expect(_ids(tracker.entries([_user('u1'), _user('u2'), _user('u3', 'hi')], pending)), ['u1', 'u2', 'u3']);
    });

    test('keeps what was sent with a message on its way', () {
      final tracker = PendingMessageTracker();
      final photo = AIMessageAttachment.image(Uri.parse('file:///photo.jpg'));
      final pending = AIPendingMessage(text: 'look', attachments: [photo]);
      tracker.entries(const [], pending);
      final entries = tracker.entries([_user('u1', 'look')], pending);
      expect(entries.single.attachments, [photo]);
    });

    test('older messages arriving above are not the copy', () {
      final tracker = PendingMessageTracker();
      final pending = AIPendingMessage(text: 'new');
      tracker.entries([_user('u5')], pending);
      expect(_ids(tracker.entries([_user('u1'), _user('u5')], pending)), ['u1', 'u5', pending.id]);
    });

    test('is awaiting a reply while the message is on its way, and until its reply shows', () {
      final tracker = PendingMessageTracker();
      final pending = AIPendingMessage(text: 'hi');
      tracker.entries([_user('u1'), _reply('r1')], pending);
      expect(tracker.isAwaitingReply([_user('u1'), _reply('r1')], pending), isTrue);

      final arrived = [_user('u1'), _reply('r1'), _user('u2', 'hi')];
      tracker.entries(arrived, pending);
      expect(tracker.isAwaitingReply(arrived, pending), isTrue);

      final replying = [...arrived, _reply('r2', 'Sure')];
      tracker.entries(replying, pending);
      expect(tracker.isAwaitingReply(replying, pending), isFalse);
    });

    test('is awaiting a reply that is being written but shows nothing', () {
      final tracker = PendingMessageTracker();
      final messages = [_user('u1'), _writing('r1')];
      tracker.entries(messages, null);
      expect(tracker.isAwaitingReply(messages, null), isTrue);
    });
  });

  group('ThinkingClock', () {
    late DateTime now;
    late ThinkingClock clock;

    setUp(() {
      now = DateTime(2026);
      clock = ThinkingClock(now: () => now);
    });

    test("starts a turn's thinking the first time it thinks", () {
      clock.update(latest: 't1', isThinking: false);
      expect(clock.start('t1'), isNull);
      clock.update(latest: 't1', isThinking: true);
      expect(clock.start('t1'), now);
    });

    test('the first step of a streamed reply counts from the question', () {
      clock.update(latest: 't1', isThinking: true);
      now = now.add(const Duration(seconds: 3));
      clock.update(latest: 't1', isThinking: false, hasReplies: true);
      expect(clock.isFirstStep('r1', 't1'), isTrue);
      expect(clock.isFirstStep('r2', 't1'), isFalse);
      now = now.add(const Duration(seconds: 2));
      expect(clock.elapsed('t1'), const Duration(seconds: 5));
      now = now.add(const Duration(seconds: 1));
      expect(clock.durationOfFirstStep('t1', null), const Duration(seconds: 6));
      now = now.add(const Duration(seconds: 10));
      expect(clock.durationOfFirstStep('t1', null), const Duration(seconds: 6), reason: 'measured once');
    });

    test('a first step that arrived done ends at the end of the thinking', () {
      clock.update(latest: 't1', isThinking: true);
      now = now.add(const Duration(seconds: 4));
      clock.update(latest: 't1', isThinking: false, hasReplies: true);
      now = now.add(const Duration(seconds: 5));
      expect(clock.durationOfFirstStep('t1', null), const Duration(seconds: 4));
    });

    test("the step's own time counts when it is longer", () {
      clock.update(latest: 't1', isThinking: true);
      now = now.add(const Duration(seconds: 1));
      clock.update(latest: 't1', isThinking: false, hasReplies: true);
      expect(clock.durationOfFirstStep('t1', const Duration(seconds: 9)), const Duration(seconds: 9));
    });

    test('a turn whose replies were taken away thinks afresh', () {
      clock
        ..update(latest: 't1', isThinking: true)
        ..update(latest: 't1', isThinking: false, hasReplies: true);
      now = now.add(const Duration(seconds: 30));
      clock.update(latest: 't1', isThinking: true);
      expect(clock.start('t1'), now);
    });
  });

  group('formatFileSize', () {
    test('uses decimal units', () {
      expect(formatFileSize(1), '1 byte');
      expect(formatFileSize(512), '512 bytes');
      expect(formatFileSize(2400), '2 KB', reason: 'kilobytes have no decimals, as on iOS');
      expect(formatFileSize(2400000), '2.4 MB');
      expect(formatFileSize(512000000), '512 MB');
    });
  });

  group('AIMessageAttachment', () {
    test('names itself after its file', () {
      expect(AIMessageAttachment.file(Uri.parse('https://x.io/a/report.pdf')).displayName, 'report.pdf');
      expect(AIMessageAttachment.file(Uri.parse('https://x.io/a/report.pdf'), name: 'Q3').displayName, 'Q3');
      expect(const AIMessageAttachment(kind: AIMessageAttachmentKind.file).displayName, isNull);
    });

    test('labels its type from its name, URL or media type', () {
      expect(AIMessageAttachment.file(Uri.parse('https://x.io/r.pdf')).typeLabel, 'PDF');
      expect(AIMessageAttachment.file(Uri.parse('https://x.io/r'), name: 'notes.txt').typeLabel, 'TXT');
      expect(AIMessageAttachment.file(Uri.parse('https://x.io/r'), mimeType: 'application/json').typeLabel, 'JSON');
      expect(AIMessageAttachment.file(Uri.parse('https://x.io/r')).typeLabel, isNull);
    });
  });
}
