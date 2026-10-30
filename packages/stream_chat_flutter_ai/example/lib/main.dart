import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'package:stream_chat_flutter_ai_example/code_highlighter.dart';
import 'package:stream_chat_flutter_ai_example/fake_local_model.dart';

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

/// A single message in the conversation, as [AIConversationView] reads it.
///
/// User messages render as bubbles; assistant messages render their reasoning
/// and tool calls as steps, then the answer through [StreamingMessageView], so
/// markdown, code fences and chart fences are all handled.
class _Message with AIMessage {
  _Message({
    String? id,
    required this.text,
    required this.isUser,
    this.isGenerating = false,
    this.reasoning = '',
    this.isThinking = false,
    this.toolCalls = const [],
    this.note = '',
  }) : id = id ?? 'message_${_nextId++}';

  static int _nextId = 0;

  @override
  final String id;

  @override
  final String text;

  final bool isUser;

  @override
  AIMessageRole get role => isUser ? AIMessageRole.user : AIMessageRole.assistant;

  @override
  final bool isGenerating;

  /// What the app says about a reply it couldn't finish, such as that the
  /// on-device model is unavailable. Shown under the reply, or in its place
  /// when the reply has nothing else to show, and never sent to a model as
  /// part of the conversation.
  final String note;

  /// The model's reasoning so far, shown as a reasoning step above the reply.
  /// Empty for user messages.
  final String reasoning;

  /// Whether the fake model is still thinking about this reply.
  final bool isThinking;

  /// The tools the fake model called before answering, shown as steps between
  /// the reasoning and the reply.
  final List<AIToolCallPart> toolCalls;

  @override
  List<AIMessagePart> get parts => [
    if (reasoning.isNotEmpty)
      AIMessagePart.fromReasoning(
        AIReasoningPart(
          id: '${id}_reasoning',
          status: isThinking ? AIReasoningStatus.streaming : AIReasoningStatus.completed,
          summary: isThinking ? null : _reasoningSummary,
        ),
      ),
    ...toolCalls.map(AIMessagePart.fromToolCall),
  ];

  // The whole reasoning, rather than the preview a backend would put on the
  // step.
  @override
  String? reasoningText(AIReasoningPart step) => reasoning;

  _Message copyWith({
    String? text,
    bool? isGenerating,
    String? reasoning,
    bool? isThinking,
    List<AIToolCallPart>? toolCalls,
    String? note,
  }) => _Message(
    id: id,
    text: text ?? this.text,
    isUser: isUser,
    isGenerating: isGenerating ?? this.isGenerating,
    reasoning: reasoning ?? this.reasoning,
    isThinking: isThinking ?? this.isThinking,
    toolCalls: toolCalls ?? this.toolCalls,
    note: note ?? this.note,
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

/// The canned tool call that needs the user's own account: run after the
/// email, it waits for them to connect Linear, through
/// [AIToolAuthorizationView]. `final` rather than `const`, as a [Uri] can't be
/// const; the expiry is set when it is added.
final _linearCall = AIToolCallPart(
  id: 'call_linear',
  name: 'create_linear_issue',
  displayTitle: 'Filing a Linear issue',
  status: AIToolCallStatus.awaitingAuthorization,
  targetUserId: 'me',
  authorization: AIToolAuthorization(
    provider: 'linear',
    providerName: 'Linear',
    title: 'Connect Linear',
    message: 'To file the issue under your own name.',
    url: Uri.parse('https://example.com/connect/linear'),
    handoffToken: 'example-handoff-token',
  ),
);

/// The canned reasoning streamed before the reply, the way a reasoning model
/// "thinks out loud" before it answers.
const _cannedReasoning = '''
The user wants to see what this package can render, so the reply should be a **tour** rather than an answer to a question.

I'll start with plain markdown — bold, italics, `inline code` and a list — since every other renderer sits inside it.

Then code blocks in two languages, to show highlighting follows the fence rather than being hardcoded. Dart first, then Python.

Some LaTeX would be good too: one inline formula and one display block.

Finally charts: a two-series bar chart (for the legend), a pie (the amber slice tests label contrast) and a heatmap with an unnamed series, which exercises `AITranslations.unnamedChartSeries`.
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
    },
    {
      "name": "Replies",
      "points": [
        {"x": "Mon", "y": 9},
        {"x": "Tue", "y": 14},
        {"x": "Wed", "y": 6},
        {"x": "Thu", "y": 20},
        {"x": "Fri", "y": 11}
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
  final _messages = <_Message>[];

  /// Non-null while a pause is pending — before the reasoning starts, or while
  /// it folds before the reply — so it can be cancelled when the user taps
  /// stop.
  Timer? _thinkingTimer;

  /// Non-null while chunks of the reasoning are still being delivered.
  Timer? _reasoningTimer;

  /// Non-null while a canned tool call is running, or while the fake backend
  /// is about to update the call waiting for approval or a sign-in.
  Timer? _toolTimer;

  /// Non-null while chunks of the reply are still being delivered.
  Timer? _streamTimer;

  /// Whether the fake backend has already failed to take an answer to the
  /// current question — it fails the first one, to show the retry.
  bool _answerFailedOnce = false;

  /// Answers tool calls' questions for [_identity], through a fake backend
  /// that is slow and, the first time, fails, and signs them in through a fake
  /// provider page. Kept for the screen's lifetime: it remembers where each
  /// answer is.
  late final _approver = AIToolApprover(
    identity: _identity,
    decide: _sendAnswer,
    authorizer: AIToolAuthorizer(connect: _connect, decline: _declineSignIn),
  );

  /// Runs the client tool calls addressed to [_identity], and sends their
  /// results through [_sendToolResult]. A real app would also post
  /// `_toolRunner.registrations` to its backend once.
  late final _toolRunner = AIClientToolRunner(
    identity: _identity,
    tools: [_DeviceClockTool()],
    send: _sendToolResult,
  );

  /// Created once, not in `build`: new builders would rebuild every row.
  late final _builders = AIComponentBuilders(
    // The full constructor rather than `.part`, so a reply's first reasoning
    // step carries on the conversation's "Thinking…" count from
    // `props.duration` instead of restarting it.
    reasoning: (context, props) => StreamingReasoningView(
      text: props.text ?? props.reasoning.preview ?? props.reasoning.summary ?? '',
      isThinking: props.reasoning.isStreaming,
      duration: props.duration ?? props.reasoning.duration,
      summary: props.reasoning.summary,
      footnote: 'Reasoning is generated by the model and may be incomplete.',
    ),
    // Fences are recognised and framed by the package, but the grammars that
    // color them live here. See `code_highlighter.dart`.
    codeBlock: (context, props) =>
        CodeBlockView(code: props.code, language: props.language, highlighter: highlightCode, theme: props.theme),
    assistantMessage: _assistantMessage,
  );

  /// How much of the reply each simulated chunk delivers.
  static const _chunkSize = 40;

  /// Whether to pretend the backend is unreachable and answer from
  /// [_localModel] instead, as an app would when offline or out of quota.
  bool _offline = false;

  final AILocalModel _localModel = const FakeLocalModel();

  /// Non-null while the local model is answering; cancelling it stops the
  /// model.
  StreamSubscription<String>? _localReply;

  /// Bumped by every local reply and every stop, so a reply still waiting on
  /// [AILocalModel.isAvailable] can tell it has been superseded.
  int _replyGeneration = 0;

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
    unawaited(_localReply?.cancel());
    _composerController.dispose();
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
    });
    _composerController.clear();

    if (_offline) {
      unawaited(_replyLocally());
      return;
    }

    // Stand in for a real request: pause while the turn says it's thinking,
    // then let the model think out loud before it answers.
    _thinkingTimer = Timer(const Duration(milliseconds: 600), _streamReasoning);
  }

  /// Streams the canned reasoning into a new assistant message for a few
  /// seconds, then ends the thinking — which folds the reasoning panel — and
  /// runs the tools once the fold is done, so the two don't move at once.
  void _streamReasoning() {
    if (!mounted) return;
    // Marked generating until its last chunk arrives, which keeps it typing
    // out as chunks land.
    setState(() => _messages.add(_Message(text: '', isUser: false, isGenerating: true, isThinking: true)));

    var delivered = 0;
    _reasoningTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted) return timer.cancel();

      delivered = min(delivered + 12, _cannedReasoning.length);
      setState(() => _messages.last = _messages.last.copyWith(reasoning: _cannedReasoning.substring(0, delivered)));

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
      if (!allowed) return _askToConnectLinear();

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
        _askToConnectLinear();
      });
    });
  }

  /// Adds the call that waits for the user to connect Linear, its sign-in
  /// expiring in a few minutes. [_connect] and [_declineSignIn] carry on from
  /// there.
  void _askToConnectLinear() {
    // A fresh id per reply, so the approver doesn't take it for an earlier one.
    final call = _linearCall.copyWith(
      id: '${_linearCall.id}_${_messages.length}',
      authorization: _linearCall.authorization?.copyWith(expiresAt: DateTime.now().add(const Duration(minutes: 5))),
    );
    setState(() => _messages.last = _messages.last.copyWith(toolCalls: [..._messages.last.toolCalls, call]));
  }

  /// Stands in for opening [url] in a browser: a dialog plays the provider's
  /// page. Connected, the provider hands the grant to the agent's backend,
  /// which moves the call on by itself a moment later; nothing goes back from
  /// the app.
  Future<bool> _connect(AIToolCallPart call, Uri url) async {
    if (!mounted) return false;
    final connected = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(call.authorization?.title ?? 'Sign in'),
        content: Text("Pretend you're at Linear's sign-in page.\n\n$url"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back without connecting')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Connect')),
        ],
      ),
    );
    // Dismissed by tapping outside: back without connecting.
    if (connected != true) return false;
    _toolTimer?.cancel();
    _toolTimer = Timer(const Duration(seconds: 1), () => _settleSignIn(call.id, connected: true));
    return true;
  }

  /// Stands in for sending the user's "not now" to the agent's backend: slow,
  /// and once it "arrives", the backend cancels the call a moment later.
  Future<void> _declineSignIn(AIToolCallPart call) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _toolTimer?.cancel();
    _toolTimer = Timer(const Duration(milliseconds: 500), () => _settleSignIn(call.id, connected: false));
  }

  /// The fake backend ending the sign-in for the call with [id]: connected,
  /// the call runs and files the issue; declined, it is cancelled unrun.
  void _settleSignIn(String id, {required bool connected}) {
    // Stopped meanwhile: the call is no longer waiting.
    final current = _messages.lastOrNull?.toolCalls.where((c) => c.id == id).firstOrNull;
    if (!mounted || current?.status != AIToolCallStatus.awaitingAuthorization) return;
    _updateToolCall(
      id,
      (call) => call.copyWith(
        status: connected ? AIToolCallStatus.running : AIToolCallStatus.cancelled,
        authorization: call.authorization?.copyWith(
          status: connected ? AIToolAuthorizationStatus.connected : AIToolAuthorizationStatus.declined,
        ),
      ),
    );
    if (!connected) return _streamReply();

    const takes = Duration(milliseconds: 1100);
    _toolTimer = Timer(takes, () {
      if (!mounted) return;
      _updateToolCall(
        id,
        (call) => call.copyWith(
          status: AIToolCallStatus.completed,
          summary: 'Filed ENG-42 in Linear',
          durationMs: takes.inMilliseconds,
        ),
      );
      _streamReply();
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

      if (delivered == _cannedReply.length) {
        timer.cancel();
        setState(() {
          _messages.last = _messages.last.copyWith(isGenerating: false);
          _composerController.isGenerating = false;
        });
      }
    });
  }

  /// Answers from the on-device model. Each event is the whole answer so far,
  /// which is exactly what [StreamingMessageView.text] takes.
  Future<void> _replyLocally() async {
    final generation = ++_replyGeneration;
    await _localReply?.cancel();
    _localReply = null;

    final turns = [
      for (final message in _messages)
        if (message.isUser) AIConversationTurn.user(message.text) else AIConversationTurn.assistant(message.text),
    ];
    setState(() => _messages.add(_Message(text: '', isUser: false, isGenerating: true)));

    bool available;
    try {
      available = await _localModel.isAvailable;
    } on Exception catch (error) {
      // isAvailable answers false rather than throwing; anything else is a bug
      // and is left to surface.
      debugPrint('Checking the on-device model failed: $error');
      available = false;
    }
    // Stop was tapped, another message was sent, or the screen went away
    // while the check ran.
    if (!mounted || generation != _replyGeneration) return;
    if (!available) return _endLocalReply('The on-device model is not available right now.');

    _localReply = _localModel
        .reply(instructions: 'Answer briefly. You have no tools.', turns: turns)
        .listen(
          (answer) {
            if (!mounted) return;
            setState(() => _messages.last = _messages.last.copyWith(text: answer));
          },
          onError: (Object error) {
            debugPrint('The on-device model failed: $error');
            _endLocalReply(switch (error) {
              AILocalModelException(reason: AILocalModelErrorReason.unavailable) =>
                'The on-device model is not available right now.',
              AILocalModelException(reason: AILocalModelErrorReason.contextExceeded) =>
                'That question is too long for the on-device model.',
              AILocalModelException(reason: AILocalModelErrorReason.invalidConversation) =>
                'The on-device model could not read this conversation.',
              _ => 'The on-device model could not answer. Try again.',
            });
          },
          onDone: () {
            _localReply = null;
            _finishLocalReply();
          },
        );
  }

  /// Ends a local reply that failed, showing [note] under any answer it had
  /// already given, and leaving the generating state at once.
  void _endLocalReply(String note) {
    _localReply = null;
    if (!mounted) return;
    setState(() {
      _messages.last = _messages.last.copyWith(note: note, isGenerating: false);
      _composerController.isGenerating = false;
    });
  }

  /// Ends a local reply whose stream closed.
  void _finishLocalReply() {
    if (!mounted) return;
    setState(() {
      _messages.last = _messages.last.copyWith(isGenerating: false);
      _composerController.isGenerating = false;
    });
  }

  void _stop() {
    _thinkingTimer?.cancel();
    _reasoningTimer?.cancel();
    _toolTimer?.cancel();
    _streamTimer?.cancel();
    _replyGeneration++;
    unawaited(_localReply?.cancel());
    _localReply = null;
    if (!mounted) return;
    setState(() {
      // Stopping mid-reply ends the reply and its thinking, and cancels a tool
      // still running.
      if (_messages.lastOrNull case final last? when !last.isUser) {
        _messages.last = last.copyWith(
          isGenerating: false,
          isThinking: false,
          toolCalls: [
            for (final call in last.toolCalls)
              if (call.status.isFinished) call else call.copyWith(status: AIToolCallStatus.cancelled),
          ],
        );
      }
      _composerController.isGenerating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final last = _messages.lastOrNull;
    // While nothing on screen moves — before the reply starts, or between its
    // steps, such as after the tools finish and before the answer starts — the
    // turn says the agent is thinking. The reasoning says so itself while it
    // streams, a running tool's row spins, and a call waiting on the user isn't
    // the agent.
    final waiting =
        _composerController.isGenerating &&
        last != null &&
        (last.isUser || (last.text.isEmpty && !last.isThinking && last.toolCalls.every((c) => c.status.isFinished)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            tooltip: _offline ? 'Offline: answering on device' : 'Online',
            isSelected: _offline,
            icon: const Icon(Icons.cloud_outlined),
            selectedIcon: const Icon(Icons.cloud_off_outlined),
            onPressed: () => setState(() => _offline = !_offline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AIComponentFactory(
                builders: _builders,
                // Scrolls each question to the top and lets its reply type
                // out below it, leaving the list alone while the user scrolls.
                child: AIConversationView(
                  messages: _messages,
                  isThinking: waiting,
                  approver: _approver,
                  // A reply that failed before saying anything shows nothing,
                  // so the conversation leaves it out, and its note with it.
                  footer: last != null && !last.isUser && last.text.isEmpty && last.note.isNotEmpty
                      ? _Note(last.note)
                      : null,
                  emptyContent: const _EmptyState(),
                ),
              ),
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

/// The package's reply row, with the app's [_Message.note] under it.
Widget _assistantMessage(BuildContext context, AIAssistantMessageProps props) {
  final reply = AIAssistantMessageView(
    text: props.text,
    isGenerating: props.isGenerating,
    parts: props.parts,
    attachments: props.attachments,
    approver: props.approver,
    reasoningText: props.message.reasoningText,
    onAttachmentTap: props.onAttachmentTap,
  );
  // The row is built again only when what the package shows changes; the note
  // lands with the end of generation, which is such a change.
  final note = (props.message as _Message).note;
  if (note.isEmpty) return reply;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [reply, _Note(note)],
  );
}

/// Why a reply ended early, such as the on-device model not being available.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

/// Implements [AITranslations] rather than extending [DefaultAITranslations],
/// so a string added in a later version fails to compile until it's translated.
class DutchTranslations implements AITranslations {
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
  String get unnamedChartSeries => 'Reeks';

  @override
  String chartSemanticsLabel(ChartSemantics chart) {
    final kind = switch (chart.kind) {
      USpecKind.line => 'Lijndiagram',
      USpecKind.area => 'Vlakdiagram',
      USpecKind.bar => 'Staafdiagram',
      USpecKind.pie => 'Cirkeldiagram',
      USpecKind.scatter => 'Spreidingsdiagram',
      USpecKind.bubble => 'Bellendiagram',
      USpecKind.heatmap => 'Heatmap',
      USpecKind.histogram => 'Histogram',
    };
    final name = [kind, ?chart.title].join(', ');
    if (chart.isEmpty) return '$name, geen gegevens';
    return '$name, waarden ${chart.valueMin} tot ${chart.valueMax}';
  }

  @override
  String get reasoningThinking => 'Aan het nadenken…';

  @override
  String reasoningThinkingFor(Duration elapsed) => 'Aan het nadenken… ${_duration(elapsed)}';

  @override
  String get reasoningTitle => 'Denkproces';

  @override
  String reasoningThoughtFor(Duration duration) => '${_duration(duration)} nagedacht';

  static String _duration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    if (minutes == 0) return '${seconds}s';
    return seconds == 0 ? '${minutes}m' : '${minutes}m ${seconds}s';
  }

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
  String get toolCallAwaitingAuthorization => 'Wacht op inloggen';

  @override
  String get toolCallAwaitingYourAuthorization => 'Wacht tot je inlogt';

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
    // As the English, with a decimal comma as Dutch writes it.
    final tenths = (duration.inMicroseconds.clamp(0, 1 << 62) / (Duration.microsecondsPerSecond / 10)).round();
    if (tenths == 0) return toolCallDurationBelowTenth;
    if (tenths < 10) return '0,${tenths}s';
    return _duration(Duration(seconds: (duration.inMilliseconds / Duration.millisecondsPerSecond).round()));
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
  String get toolAuthorizationConnect => 'Verbinden';

  @override
  String get toolAuthorizationConnecting => 'Verbinden…';

  @override
  String get toolAuthorizationDecline => 'Niet nu';

  @override
  String get toolAuthorizationNotOpened => 'Het inloggen kon niet worden geopend. Probeer het opnieuw.';

  @override
  String get toolAuthorizationExpired => 'Dit inloggen is verlopen.';

  @override
  String unnamedChartSlice(int number) => 'Segment $number';

  @override
  String chartLegendMore(int count) => '+$count meer';

  @override
  String get copyReply => 'Kopiëren';

  @override
  String get replyCopied => 'Gekopieerd!';

  @override
  String get shareReply => 'Delen';

  @override
  String get regenerateReply => 'Opnieuw genereren';

  @override
  String get rateReplyPositive => 'Goed antwoord';

  @override
  String get rateReplyNegative => 'Slecht antwoord';

  @override
  String get copyMessage => 'Kopiëren';

  @override
  String get editMessage => 'Bewerken';

  @override
  String get scrollToLatest => 'Naar nieuwste bericht';

  @override
  String get attachmentImage => 'Afbeelding';

  @override
  String get attachmentFile => 'Bestand';

  @override
  String attachmentDetails(String type, String size) => '$type · $size';

  @override
  String fileSize(int bytes) {
    // Decimal units like the English, with a decimal comma as Dutch writes it.
    if (bytes < 1000) return '$bytes bytes';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var value = bytes / 1000;
    var unit = 0;
    while (value >= 1000 && unit < units.length - 1) {
      value /= 1000;
      unit++;
    }
    final digits = value >= 100 || unit == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits).replaceAll('.', ',')} ${units[unit]}';
  }

  @override
  String get voiceAgent => 'Spraakassistent';

  @override
  String get voiceIdle => 'Klaar';

  @override
  String get voiceConnecting => 'Verbinden';

  @override
  String get voiceListening => 'Luistert';

  @override
  String get voiceThinking => 'Denkt na';

  @override
  String get voiceSpeaking => 'Spreekt';
}
