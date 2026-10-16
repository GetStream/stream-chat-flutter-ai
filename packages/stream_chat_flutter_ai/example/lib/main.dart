import 'dart:async';
import 'dart:convert';
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

/// A light code frame for the light theme: pinning the brightness picks the
/// package's light defaults and tells `code_highlighter.dart` to switch to its
/// Atom One Light palette. The dark theme keeps the package's default dark
/// frame; pin `Brightness.dark` in both to keep code dark in either mode.
const _lightCodeBlockTheme = CodeBlockThemeData(brightness: Brightness.light);

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
  const _Message({
    required this.text,
    required this.isUser,
    this.reasoning = '',
    this.isThinking = false,
    this.toolCalls = const [],
  });

  final String text;
  final bool isUser;

  /// The model's reasoning so far, shown in a [StreamingReasoningView] above
  /// the reply. Empty for user messages.
  final String reasoning;

  /// Whether the fake model is still thinking about this reply.
  final bool isThinking;

  /// The tools the fake model called before answering, shown as rows by
  /// [AIMessagePartsView] between the reasoning and the reply.
  final List<AIToolCallPart> toolCalls;

  _Message copyWith({String? text, String? reasoning, bool? isThinking, List<AIToolCallPart>? toolCalls}) => _Message(
    text: text ?? this.text,
    isUser: isUser,
    reasoning: reasoning ?? this.reasoning,
    isThinking: isThinking ?? this.isThinking,
    toolCalls: toolCalls ?? this.toolCalls,
  );
}

/// The canned tool calls run after the reasoning, each with how long it takes
/// and the summary it finishes with.
const _cannedToolCalls = [
  (
    call: AIToolCallPart(id: 'call_search', name: 'search_web', displayTitle: 'Searching the web'),
    takes: Duration(milliseconds: 1600),
    summary: 'Found 3 pages about Flutter rendering',
  ),
  // No display title: the row falls back to the tool's name, "load chart examples".
  (
    call: AIToolCallPart(id: 'call_charts', name: 'load_chart_examples'),
    takes: Duration(milliseconds: 400),
    summary: 'Loaded a bar, a pie and a heatmap',
  ),
];

/// Who the example's user is, and which install this is. A real app takes the
/// user id from its chat client and keeps an install id of its own.
const _identity = AIClientIdentity(userId: 'me', clientId: 'example-install');

/// The canned call to a tool this device runs itself: the [AIClientToolRunner]
/// picks it up because it awaits this person and this install, runs
/// [_DeviceClockTool], and sends the result back through a fake backend.
const _clockCall = AIToolCallPart(
  id: 'call_clock',
  name: 'read_device_clock',
  displayTitle: 'Reading your clock',
  status: AIToolCallStatus.awaitingClient,
  executor: AIToolExecutor.client,
  targetUserId: 'me',
  targetClientId: 'example-install',
);

/// A client tool that returns a result to the agent: the device's local time.
class _DeviceClockTool extends AIResultClientTool {
  @override
  AIToolDefinition get definition => const AIToolDefinition(
    name: 'read_device_clock',
    description: "The user's local time and time zone",
  );

  @override
  Future<AIClientToolResult> run(AIToolCallPart call) async {
    final now = DateTime.now();
    return AIClientToolResult.completed({
      'local_time': now.toIso8601String(),
      'time_zone': now.timeZoneName,
    }, summary: 'Read the local time');
  }
}

/// The canned tool call that asks first: run after the others, it waits for
/// the user to allow it, through [AIToolApprovalView]. No button titles, so
/// they come from the translations.
const _emailCall = AIToolCallPart(
  id: 'call_email',
  name: 'send_email',
  displayTitle: 'Emailing the summary',
  status: AIToolCallStatus.awaitingApproval,
  targetUserId: 'me',
  approval: AIToolApproval(
    title: 'Send the summary by email?',
    reason: 'so you have it in your inbox',
    message: 'It goes to your own address only.',
  ),
);

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

  /// Non-null while a pause is pending — before the reasoning starts, or while
  /// it folds before the reply — so it can be cancelled when the user taps
  /// stop.
  Timer? _thinkingTimer;

  /// Non-null while chunks of the reasoning are still being delivered.
  Timer? _reasoningTimer;

  /// Non-null while a canned tool call is running, or while the fake backend
  /// is about to update the call waiting for approval.
  Timer? _toolTimer;

  /// Non-null while chunks of the reply are still being delivered.
  Timer? _streamTimer;

  /// Whether the fake backend has already failed to take an answer to the
  /// current question — it fails the first one, to show the retry.
  bool _answerFailedOnce = false;

  /// Answers tool calls' questions for [_identity], through a fake backend
  /// that is slow and, the first time, fails. Kept for the screen's lifetime:
  /// it remembers where each answer is.
  late final _approver = AIToolApprover(identity: _identity, decide: _sendAnswer);

  /// Runs the client tool calls addressed to [_identity], and sends their
  /// results through [_sendToolResult]. A real app would also post
  /// `_toolRunner.registrations` to its backend once.
  late final _toolRunner = AIClientToolRunner(
    identity: _identity,
    tools: [_DeviceClockTool()],
    send: _sendToolResult,
  );

  /// Whether the fake backend has finished sending chunks for the current reply.
  ///
  /// The backend finishes well before the typewriter does, so this alone is not
  /// when the reply is done: it feeds `StreamingMessageView.expectMoreText`, and
  /// the composer leaves its generating state from `onFinished`.
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
    _toolTimer?.cancel();
    _streamTimer?.cancel();
    _approver.dispose();
    _toolRunner.close();
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
  /// runs the tools once the fold is done, so the two don't move at once.
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
        _thinkingTimer = Timer(StreamingReasoningView.foldDuration, () => _runTool(0));
      }
    });
  }

  /// Runs the canned tool call at [index] — a row that spins, then completes
  /// with its summary and duration — and the next one after it, then the call
  /// this device runs itself.
  void _runTool(int index) {
    if (!mounted) return;
    if (index == _cannedToolCalls.length) return _runClientTool();

    final (:call, :takes, :summary) = _cannedToolCalls[index];
    setState(() => _messages.last = _messages.last.copyWith(toolCalls: [..._messages.last.toolCalls, call]));
    _scrollToEnd();

    _toolTimer = Timer(takes, () {
      if (!mounted) return;
      final done = call.copyWith(
        status: AIToolCallStatus.completed,
        summary: summary,
        durationMs: takes.inMilliseconds,
      );
      setState(
        () => _messages.last = _messages.last.copyWith(toolCalls: [..._messages.last.toolCalls]..[index] = done),
      );
      _runTool(index + 1);
    });
  }

  /// Adds a call for this device to run, and hands the reply's calls to the
  /// runner, as an app would on every update of the reply.
  void _runClientTool() {
    // A fresh id per reply: the runner runs each call id only once.
    final call = _clockCall.copyWith(id: '${_clockCall.id}_${_messages.length}');
    setState(() => _messages.last = _messages.last.copyWith(toolCalls: [..._messages.last.toolCalls, call]));
    _scrollToEnd();
    unawaited(_toolRunner.handleCalls(_messages.last.toolCalls));
  }

  /// Stands in for posting a client tool's result to the agent's backend. Once
  /// it "arrives", the backend marks the call completed with the result's
  /// summary, and the agent goes on to ask to email the summary.
  Future<void> _sendToolResult(AIToolCallPart call, AIClientToolResult result) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final payload = result.toJson(toolCallId: call.id, clientId: _identity.clientId);
    debugPrint('Sent client tool result: ${jsonEncode(payload)}');
    if (!mounted || _messages.lastOrNull?.toolCalls.any((c) => c.id == call.id && !c.status.isFinished) != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent to the agent: ${jsonEncode(payload)}')));
    _updateToolCall(
      call.id,
      (call) => switch (result) {
        AIClientToolCompleted(:final summary) => call.copyWith(
          status: AIToolCallStatus.completed,
          summary: summary,
          durationMs: 600,
        ),
        AIClientToolFailed(:final reason) => call.copyWith(status: AIToolCallStatus.failed, summary: reason),
      },
    );
    _askToEmail();
  }

  /// Adds the call that waits for the user's approval. [_sendAnswer] carries
  /// on from there.
  void _askToEmail() {
    _answerFailedOnce = false;
    setState(() => _messages.last = _messages.last.copyWith(toolCalls: [..._messages.last.toolCalls, _emailCall]));
    _scrollToEnd();
  }

  /// Replaces the last message's tool call with [id] by [update]'s result.
  void _updateToolCall(String id, AIToolCallPart Function(AIToolCallPart call) update) {
    setState(
      () => _messages.last = _messages.last.copyWith(
        toolCalls: [
          for (final call in _messages.last.toolCalls)
            if (call.id == id) update(call) else call,
        ],
      ),
    );
  }

  /// Stands in for sending the user's answer to the agent's backend: slow,
  /// and failing the first time so the card shows its retry. Once it "arrives",
  /// the backend updates the call's step a moment later — which is what takes
  /// the question away — and then runs the tool or skips it.
  Future<void> _sendAnswer(AIToolCallPart call, AIToolApprovalDecision decision) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!_answerFailedOnce) {
      _answerFailedOnce = true;
      throw Exception('The fake backend dropped the answer');
    }

    if (!mounted) return;
    final allowed = decision == AIToolApprovalDecision.allowed;
    _toolTimer?.cancel();
    _toolTimer = Timer(const Duration(milliseconds: 500), () {
      // Stopped meanwhile: the call is no longer waiting.
      final current = _messages.lastOrNull?.toolCalls.where((c) => c.id == call.id).firstOrNull;
      if (!mounted || current?.status != AIToolCallStatus.awaitingApproval) return;
      _updateToolCall(
        call.id,
        (call) => call.copyWith(
          status: allowed ? AIToolCallStatus.running : AIToolCallStatus.cancelled,
          approval: call.approval?.copyWith(decision: decision),
        ),
      );
      if (!allowed) return _streamReply();

      const takes = Duration(milliseconds: 1100);
      _toolTimer = Timer(takes, () {
        if (!mounted) return;
        _updateToolCall(
          call.id,
          (call) => call.copyWith(
            status: AIToolCallStatus.completed,
            summary: 'Sent to your inbox',
            durationMs: takes.inMilliseconds,
          ),
        );
        _streamReply();
      });
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
        setState(() => _streamComplete = true);
      }
    });
  }

  void _stop() {
    _thinkingTimer?.cancel();
    _reasoningTimer?.cancel();
    _toolTimer?.cancel();
    _streamTimer?.cancel();
    setState(() {
      // Stopping mid-reply ends the thinking and cancels a tool still running.
      if (_messages.lastOrNull case final last? when !last.isUser) {
        _messages.last = last.copyWith(
          isThinking: false,
          toolCalls: [
            for (final call in last.toolCalls)
              if (call.status.isFinished) call else call.copyWith(status: AIToolCallStatus.cancelled),
          ],
        );
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
                        final isLatest = index == _messages.length - 1;
                        final reply = StreamingMessageView(
                          text: message.text,
                          // Only the latest reply can still be streaming, and
                          // only it drives the composer.
                          expectMoreText: isLatest && !_streamComplete,
                          onFinished: isLatest ? () => _composerController.isGenerating = false : null,
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
                        );
                        if (message.reasoning.isEmpty && message.toolCalls.isEmpty) return reply;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 12,
                          children: [
                            if (message.reasoning.isNotEmpty)
                              StreamingReasoningView(
                                text: message.reasoning,
                                isThinking: message.isThinking,
                                summary: _reasoningSummary,
                                footnote: 'Reasoning is generated by the model and may be incomplete.',
                              ),
                            if (message.toolCalls.isNotEmpty)
                              AIMessagePartsView(
                                parts: [...message.toolCalls.map(AIMessagePart.fromToolCall)],
                                approver: _approver,
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
                // The reasoning panel says "Thinking…" itself while it
                // streams, and a running tool's row spins.
                final last = _messages.lastOrNull;
                final busy = last != null && (last.isThinking || last.toolCalls.any((c) => !c.status.isFinished));
                if (!_composerController.isGenerating || busy) return const SizedBox.shrink();
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
  String reasoningThinkingFor(Duration elapsed) => 'Aan het nadenken… ${reasoningDuration(elapsed)}';

  @override
  String get reasoningTitle => 'Denkproces';

  @override
  String reasoningThoughtFor(Duration duration) => '${reasoningDuration(duration)} nagedacht';

  @override
  String get reasoningShowHint => 'Toont de redenering van het model';

  @override
  String get reasoningHideHint => 'Verbergt de redenering van het model';

  @override
  String get toolCallFallbackTitle => 'Hulpmiddel';

  @override
  String get toolCallRunning => 'Bezig';

  @override
  String get toolCallCompleted => 'Voltooid';

  @override
  String get toolCallAwaitingApproval => 'Wacht op toestemming';

  @override
  String get toolCallAwaitingClient => 'Wacht op het apparaat';

  @override
  String get toolCallFailed => 'Niet gelukt';

  @override
  String get toolCallCancelled => 'Geannuleerd';

  @override
  String get toolCallDeclined => 'Geweigerd';

  @override
  String toolCallDuration(Duration duration) {
    // English with a decimal comma, as Dutch writes it.
    return super.toolCallDuration(duration).replaceAll('.', ',');
  }

  @override
  String get toolCallDurationBelowTenth => '<0,1s';

  @override
  String toolApprovalTitle(String? toolName) =>
      toolName == null ? 'Dit hulpmiddel laten uitvoeren?' : '“$toolName” toestaan?';

  @override
  String get toolApprovalAllow => 'Toestaan';

  @override
  String get toolApprovalDecline => 'Niet toestaan';

  @override
  String get toolApprovalSending => 'Je antwoord wordt verstuurd…';

  @override
  String get toolApprovalSent => 'Verstuurd';

  @override
  String get toolApprovalNotSent => 'Je antwoord kon niet worden verstuurd. Probeer het opnieuw.';

  @override
  String unnamedChartSlice(int number) => 'Segment $number';

  @override
  String chartLegendMore(int count) => '+$count meer';
}
