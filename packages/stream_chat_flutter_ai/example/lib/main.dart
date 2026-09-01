import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stream Chat Flutter AI',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF005FFF),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF005FFF),
        brightness: Brightness.dark,
      ),
      home: const AssistantScreen(),
    );
  }
}

/// A single message in the conversation.
///
/// [isUser] messages render as plain bubbles; assistant messages render
/// through [StreamingMessageView] so markdown, code fences and chart fences
/// are all handled.
class _Message {
  const _Message({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

/// The canned assistant reply, chosen to exercise every renderer the package
/// ships: markdown text, a fenced code block ([CodeBlockView]) and a chart
/// fence ([ChartView]). There is no backend here — the reply is revealed by
/// [StreamingMessageView]'s typewriter, the same way a real streamed response
/// would arrive.
// Raw so the LaTeX backslashes below read the way an LLM would emit them.
const _cannedReply = r'''
Sure — here's a quick tour of what this package renders.

### Markdown

Regular **bold**, *italic* and `inline code` all work, plus lists:

1. Streaming text with a typewriter effect
2. Syntax-highlighted code blocks
3. Charts from a JSON fence

### Code blocks

```dart
// Highlighting follows the fence's language.
final controller = ChatComposerController();
controller.isGenerating = true;
```

…and another language, to show it isn't hardcoded to one grammar:

```python
def average(values):
    """Mean of a non-empty sequence."""
    return sum(values) / len(values)
```

### Some maths

Inline like \(e^{i\pi} + 1 = 0\), or as its own block:

\[
\sum_{i=1}^{n} i = \frac{n(n+1)}{2}
\]

### A chart

```chart
{
  "kind": "bar",
  "title": "Messages per day",
  "beginAtZeroY": true,
  "series": [
    {
      "name": "Messages",
      "points": [
        {"x": "Mon", "y": 12},
        {"x": "Tue", "y": 19},
        {"x": "Wed", "y": 8},
        {"x": "Thu", "y": 24},
        {"x": "Fri", "y": 17}
      ]
    }
  ]
}
```

Ask me something else, or pick an option from the **+** button.
''';

const _suggestions = [
  'Create a painting in Renaissance-style',
  'Help me study vocabulary for an exam',
  'Plan a three-day trip to Lisbon',
];

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  late final ChatComposerController _composerController;
  final _scrollController = ScrollController();
  final _messages = <_Message>[];

  /// Non-null while the fake assistant is "thinking", so the pending reply can
  /// be cancelled when the user taps stop.
  Timer? _thinkingTimer;

  /// Non-null while chunks of the reply are still being delivered.
  Timer? _streamTimer;

  /// Whether the fake backend has finished sending chunks for the current reply.
  ///
  /// The typewriter goes briefly idle whenever it catches up with the chunks
  /// received so far, which is *not* the same as the reply being finished — so
  /// the composer only leaves its generating state once both are true.
  bool _streamComplete = true;

  /// How much of the reply each simulated chunk delivers.
  static const _chunkSize = 40;

  @override
  void initState() {
    super.initState();
    _composerController = ChatComposerController(
      chatOptions: const [
        ChatOption(
          id: 'image',
          text: 'Create image',
          icon: Icons.image_outlined,
          description: 'Visualize anything',
        ),
        ChatOption(
          id: 'summarize',
          text: 'Summarize',
          icon: Icons.summarize_outlined,
          description: 'Condense a long text',
        ),
      ],
    );
  }

  @override
  void dispose() {
    _thinkingTimer?.cancel();
    _streamTimer?.cancel();
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(String text, ChatOption? option, List<XFile> attachments) {
    final prefix = option == null ? '' : '[${option.text}] ';
    final suffix = attachments.isEmpty ? '' : ' (${attachments.length} image(s))';
    final message = '$prefix$text$suffix'.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(_Message(text: message, isUser: true));
      _composerController.isGenerating = true;
      _streamComplete = false;
    });
    _composerController.clear();
    _scrollToEnd();

    // Stand in for a real request: pause on the typing indicator, then start
    // streaming the reply in.
    _thinkingTimer = Timer(const Duration(milliseconds: 900), _streamReply);
  }

  /// Stands in for a streaming backend, appending the canned reply to the last
  /// message a chunk at a time the way server-sent tokens arrive.
  ///
  /// `StreamingMessageView` is handed the text received *so far* and types out
  /// whatever it hasn't shown yet, so the reveal stays smooth even though the
  /// chunks land in coarse steps.
  void _streamReply() {
    if (!mounted) return;
    setState(() => _messages.add(const _Message(text: '', isUser: false)));

    var delivered = 0;
    _streamTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (!mounted) return timer.cancel();

      delivered = min(delivered + _chunkSize, _cannedReply.length);
      setState(() {
        _messages[_messages.length - 1] = _Message(
          text: _cannedReply.substring(0, delivered),
          isUser: false,
        );
      });
      _scrollToEnd();

      if (delivered == _cannedReply.length) {
        timer.cancel();
        _streamComplete = true;
      }
    });
  }

  void _stop() {
    _thinkingTimer?.cancel();
    _streamTimer?.cancel();
    setState(() {
      _streamComplete = true;
      _composerController.isGenerating = false;
    });
  }

  void _scrollToEnd() {
    // Wait for the new message to be laid out before scrolling to it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        if (message.isUser) return _UserBubble(text: message.text);
                        return StreamingMessageView(
                          text: message.text,
                          // The package recognises LaTeX but ships no math
                          // engine; this is the seam where a host supplies one.
                          mathBuilder: (context, tex, style, {required inline}) => Math.tex(
                            tex,
                            textStyle: style,
                            mathStyle: inline ? MathStyle.text : MathStyle.display,
                            onErrorFallback: (error) => Text(tex, style: style),
                          ),
                          onTypewriterStateChanged: (state) {
                            // Flip the composer back to "send" once the backend
                            // has stopped sending chunks *and* the typewriter
                            // has caught up with the last one.
                            if (state == TypewriterState.idle && _streamComplete) {
                              _composerController.isGenerating = false;
                            }
                          },
                        );
                      },
                    ),
            ),
            ListenableBuilder(
              listenable: _composerController,
              builder: (context, child) {
                if (!_composerController.isGenerating) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AITypingIndicatorView(
                      text: 'Thinking',
                      textStyle: theme.textTheme.bodyMedium,
                      dotColor: theme.colorScheme.primary,
                    ),
                  ),
                );
              },
            ),
            if (_messages.isEmpty)
              AISuggestionsView(
                suggestions: _suggestions,
                onSuggestionSelected: (text) => _send(text, null, const []),
              ),
            ChatComposer(
              controller: _composerController,
              hintText: 'Ask anything',
              enableSpeechToText: true,
              onSendPressed: _send,
              onStopPressed: _stop,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'How can I help?',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a suggestion below, or type a message to see the '
              'streaming, code-block and chart renderers.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
    );
  }
}
