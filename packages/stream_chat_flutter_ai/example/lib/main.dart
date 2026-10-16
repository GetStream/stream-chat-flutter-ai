import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'package:stream_chat_flutter_ai_example/code_highlighter.dart';

void main() => runApp(const ExampleApp());

/// Charts follow the host app rather than the package's own constants.
///
/// One instance covers light and dark: everything this leaves unset — the grid
/// line, the axis labels, the heatmap ramp — still derives from the ambient
/// `ColorScheme`. Delete the `extensions:` lines below to get the defaults back.
const _chartTheme = ChartThemeData(seriesColors: _brandChartPalette);

/// A light code frame for the light theme, matching the Atom One Light token
/// palette `code_highlighter.dart` switches to on a light background. The dark
/// theme keeps the package's default dark frame.
const _lightCodeBlockTheme = CodeBlockThemeData(
  backgroundColor: Color(0xFFFAFAFA),
  headerBackgroundColor: Color(0xFFF0F0F0),
);

/// A six-hue palette seeded on the same blue as the color scheme.
const _brandChartPalette = [
  Color(0xFF005FFF),
  Color(0xFF00C1FF),
  Color(0xFF7A5CFF),
  Color(0xFF00D4A0),
  Color(0xFFFFB000),
  Color(0xFFFF5A5F),
];

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stream Chat Flutter AI',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF005FFF),
        brightness: Brightness.light,
        extensions: const [AITheme(chartTheme: _chartTheme, codeBlockTheme: _lightCodeBlockTheme)],
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF005FFF),
        brightness: Brightness.dark,
        extensions: const [AITheme(chartTheme: _chartTheme)],
      ),
      // English needs no entry: a locale the delegate has nothing for falls
      // back to DefaultAITranslations.
      localizationsDelegates: const [
        AITranslationsDelegate({'nl': DutchTranslations()}),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('nl')],
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
  const _Message({required this.text, required this.isUser, this.reasoning = '', this.isThinking = false});

  final String text;
  final bool isUser;

  /// The model's reasoning so far, shown in a [StreamingReasoningView] above
  /// the reply. Empty for user messages.
  final String reasoning;

  /// Whether the fake model is still thinking about this reply.
  final bool isThinking;

  _Message copyWith({String? text, String? reasoning, bool? isThinking}) => _Message(
    text: text ?? this.text,
    isUser: isUser,
    reasoning: reasoning ?? this.reasoning,
    isThinking: isThinking ?? this.isThinking,
  );
}

/// The canned reasoning streamed before the reply, the way a reasoning model
/// "thinks out loud" before it answers.
const _cannedReasoning = '''
The user wants to see what this package can render, so the reply should be a **tour** rather than an answer to a question.

I'll start with plain markdown — bold, italics, `inline code` and a list — since every other renderer sits inside it.

Then code blocks in two languages, to show highlighting follows the fence rather than being hardcoded. Dart first, then Python.

Some LaTeX would be good too: one inline formula and one display block.

Finally charts: a bar chart, a pie (the amber slice tests label contrast) and a heatmap with an unnamed series, which exercises `AITranslations.unnamedChartSeries`.
''';

/// A one-line summary shown beside "Thought for Ns" once the reasoning folds.
const _reasoningSummary = 'Planned a tour of every renderer';

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

A pie, where each slice's label picks black or white for contrast — note the
amber slice:

```chart
{
  "kind": "pie",
  "title": "Where the time went",
  "series": [
    {
      "name": "Share",
      "points": [
        {"x": "Writing", "y": 40},
        {"x": "Reviewing", "y": 25},
        {"x": "Meetings", "y": 18},
        {"x": "Waiting on CI", "y": 12},
        {"x": "Email", "y": 5}
      ]
    }
  ]
}
```

And a heatmap, whose ramp inverts between light and dark so the busiest cells
stay the brightest. Its second row names no series, so it falls back to
`AITranslations.unnamedChartSeries`:

```chart
{
  "kind": "heatmap",
  "title": "Messages by hour",
  "series": [
    {
      "name": "Mon",
      "points": [
        {"x": "9", "y": 0, "z": 3},
        {"x": "12", "y": 0, "z": 9},
        {"x": "15", "y": 0, "z": 6},
        {"x": "18", "y": 0, "z": 2}
      ]
    },
    {
      "points": [
        {"x": "9", "y": 0, "z": 5},
        {"x": "12", "y": 0, "z": 14},
        {"x": "15", "y": 0, "z": 11},
        {"x": "18", "y": 0, "z": 4}
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

  /// Non-null while chunks of the reasoning are still being delivered.
  Timer? _reasoningTimer;

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
    _reasoningTimer?.cancel();
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

    // Stand in for a real request: pause on the typing indicator, then let the
    // model think out loud before it answers.
    _thinkingTimer = Timer(const Duration(milliseconds: 600), _streamReasoning);
  }

  /// Streams the canned reasoning into a new assistant message for a few
  /// seconds, then ends the thinking — which folds the reasoning panel — and
  /// starts the answer once the fold is done, so the two don't move at once.
  void _streamReasoning() {
    if (!mounted) return;
    setState(() => _messages.add(const _Message(text: '', isUser: false, isThinking: true)));

    var delivered = 0;
    _reasoningTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted) return timer.cancel();

      delivered = min(delivered + 12, _cannedReasoning.length);
      setState(() => _messages.last = _messages.last.copyWith(reasoning: _cannedReasoning.substring(0, delivered)));
      _scrollToEnd();

      if (delivered == _cannedReasoning.length) {
        timer.cancel();
        setState(() => _messages.last = _messages.last.copyWith(isThinking: false));
        _thinkingTimer = Timer(StreamingReasoningView.foldDuration, _streamReply);
      }
    });
  }

  /// Stands in for a streaming backend, appending the canned reply to the last
  /// message a chunk at a time the way server-sent tokens arrive.
  ///
  /// `StreamingMessageView` is handed the text received *so far* and types out
  /// whatever it hasn't shown yet, so the reveal stays smooth even though the
  /// chunks land in coarse steps.
  void _streamReply() {
    if (!mounted) return;

    var delivered = 0;
    _streamTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (!mounted) return timer.cancel();

      delivered = min(delivered + _chunkSize, _cannedReply.length);
      setState(() => _messages.last = _messages.last.copyWith(text: _cannedReply.substring(0, delivered)));
      _scrollToEnd();

      if (delivered == _cannedReply.length) {
        timer.cancel();
        _streamComplete = true;
      }
    });
  }

  void _stop() {
    _thinkingTimer?.cancel();
    _reasoningTimer?.cancel();
    _streamTimer?.cancel();
    setState(() {
      if (_messages.lastOrNull case final last? when last.isThinking) {
        _messages.last = last.copyWith(isThinking: false);
      }
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
                        final reply = StreamingMessageView(
                          text: message.text,
                          // The package recognises LaTeX but ships no math
                          // engine; this is the seam where a host supplies one.
                          mathBuilder: (context, tex, style, {required inline}) => Math.tex(
                            tex,
                            textStyle: style,
                            mathStyle: inline ? MathStyle.text : MathStyle.display,
                            onErrorFallback: (error) => Text(tex, style: style),
                          ),
                          // Same arrangement for code: fences are recognised
                          // and framed by the package, but the grammars that
                          // color them live here. See `code_highlighter.dart`.
                          codeHighlighter: highlightCode,
                          onTypewriterStateChanged: (state) {
                            // Flip the composer back to "send" once the backend
                            // has stopped sending chunks *and* the typewriter
                            // has caught up with the last one.
                            if (state == TypewriterState.idle && _streamComplete) {
                              _composerController.isGenerating = false;
                            }
                          },
                        );
                        if (message.reasoning.isEmpty) return reply;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 12,
                          children: [
                            StreamingReasoningView(
                              text: message.reasoning,
                              isThinking: message.isThinking,
                              summary: _reasoningSummary,
                              footnote: 'Reasoning is generated by the model and may be incomplete.',
                            ),
                            if (message.text.isNotEmpty) reply,
                          ],
                        );
                      },
                    ),
            ),
            ListenableBuilder(
              listenable: _composerController,
              builder: (context, child) {
                // The reasoning panel says "Thinking…" itself while it streams.
                final thinking = _messages.lastOrNull?.isThinking ?? false;
                if (!_composerController.isGenerating || thinking) return const SizedBox.shrink();
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
              // No `hintText`: passing one would win over the translation.
              controller: _composerController,
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

/// Extends [DefaultAITranslations] rather than implementing [AITranslations],
/// so anything left out keeps rendering English.
class DutchTranslations extends DefaultAITranslations {
  const DutchTranslations();

  @override
  String get composerHint => 'Vraag maar raak…';

  @override
  String get send => 'Verstuur';

  @override
  String get stopGenerating => 'Stop met genereren';

  @override
  String get removeAttachment => 'Bijlage verwijderen';

  @override
  String clearOption(String option) => '$option wissen';

  @override
  String get addPhotos => "Foto's toevoegen";

  @override
  String get photos => "Foto's";

  @override
  String get allPhotos => "Alle foto's";

  @override
  String get allowPhotoAccess => "Geef toegang tot je foto's";

  @override
  String get takePhoto => 'Maak een foto';

  @override
  String get voiceInput => 'Spraakinvoer';

  @override
  String get stopRecording => 'Stop met opnemen';

  @override
  String get copyCode => 'Kopieer code';

  @override
  String get codeCopied => 'Gekopieerd!';

  @override
  String get unsupportedMessagePart => 'Een stap die deze app-versie niet kan tonen';

  @override
  String get reasoningThinking => 'Aan het nadenken…';

  @override
  String reasoningThinkingFor(String duration) => 'Aan het nadenken… $duration';

  @override
  String get reasoningThought => 'Denkproces';

  @override
  String reasoningThoughtFor(String duration) => '$duration nagedacht';

  @override
  String get showReasoningHint => 'Toont de redenering van het model';

  @override
  String get hideReasoningHint => 'Verbergt de redenering van het model';
}
