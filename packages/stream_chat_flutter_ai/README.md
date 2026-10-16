![Integrating Stream Chat with AI](https://raw.githubusercontent.com/GetStream/stream-chat-flutter-ai/main/assets/repo_cover.png)

# AI components for the [Stream Flutter Chat SDK](https://getstream.io/chat/sdk/flutter/)

[![Pub](https://img.shields.io/pub/v/stream_chat_flutter_ai.svg)](https://pub.dev/packages/stream_chat_flutter_ai)
[![CI](https://github.com/GetStream/stream-chat-flutter-ai/actions/workflows/stream_flutter_ai_workflow.yml/badge.svg?branch=main)](https://github.com/GetStream/stream-chat-flutter-ai/actions/workflows/stream_flutter_ai_workflow.yml)

This official repository for Stream Chat's UI components is designed specifically for AI-first
applications written in Flutter. When paired with our real-time [Chat API](https://getstream.io/chat/),
it makes integrating with and rendering responses from LLM providers such as ChatGPT, Gemini,
Anthropic or any custom backend easier, by providing rich out-of-the-box components able to render
Markdown, code blocks, tables, charts, thinking indicators and more.

The package has **no dependency on `stream_chat`, `stream_chat_flutter` or any other Stream Chat
package** — every widget operates on plain strings, callbacks and controllers, so it drops into any
Flutter app and pairs with any backend or LLM provider. See
[Using with Stream Chat](#using-with-stream-chat) below for wiring it up to a Stream Chat channel.

To start, this library includes the following components:

**`StreamingMessageView`** — renders text, markdown and code in real time with a
character-by-character animation, similar to ChatGPT.

**`AITypingIndicatorView`** — displays the different states of the LLM (thinking, checking external
sources, etc) with animated dots.

**`ChatComposer`** — a fully featured prompt composer with attachments, chat options, speech input,
and a send button that turns into a stop button while a response streams.

**`ChartView`** — renders line, bar, area, scatter, bubble, pie, histogram and heatmap charts from
the JSON an LLM emits, themed from your app and described to a screen reader.

**`CodeBlockView`** — a framed code fence with a language label, a copy button and opt-in syntax
highlighting.

**`SpeechToTextButton`** — records voice input and streams the recognized transcript into the
composer.

**`AIMessagePartsView`** — the steps an agent took while replying: its reasoning
(**`StreamingReasoningView`**), its tool calls (**`AIToolCallView`**) and the tool calls waiting for
the user's approval (**`AIToolApprovalView`**).

**`AIToolRegistry`** / **`AIClientToolRunner`** — client-side tool calling, letting the agent reach
into your app to open a screen, show an alert or read a sensor, and get the result back.

**`AILocalModel`** — a base class to implement over an on-device model, for answering when the
agent can't, such as when the user is offline.

This repository also includes a [showcase app](example) demonstrating every component, which needs
no API key to run.

Our team plans to keep iterating and adding more components over time. If there's a component you
use every day in your apps and would like to see added, please open an issue and we will try to add
it 😎.

**Quick Links**

- [Register](https://getstream.io/chat/trial/) to get an API key for Stream Chat
- [Flutter AI Assistant Tutorial](https://getstream.io/blog/flutter-assistant/)
- [Flutter Chat Tutorial](https://getstream.io/chat/flutter/tutorial/)
- [Sample apps](https://github.com/GetStream/chat-ai-samples) — backend-connected samples across
  Flutter, React, React Native, iOS and Android

## 📦 Installation

`stream_chat_flutter_ai` has no dependency on Stream Chat — install it on its own:

```yaml
dependencies:
  stream_chat_flutter_ai: ^0.1.0
```

## ⚙️ Usage

### `StreamingMessageView`

Renders markdown text with a character-by-character typewriter animation — ideal for
displaying streaming AI responses as they arrive. Markdown is fully parsed: code fences
get a `CodeBlockView` (with copy button, and syntax highlighting when you supply a
`codeHighlighter`), and JSON/chart fences are rendered as interactive charts via
`ChartView`. A code fence is styled from its opening line onwards, so a block still
being streamed doesn't show raw ` ``` ` markers while it arrives.

```dart
StreamingMessageView(
  text: markdownText,          // updated in real time as chunks arrive
  typingSpeed: Duration(milliseconds: 10),
  onTypewriterStateChanged: (state) {
    // TypewriterState.typing | idle | paused | stopped
  },
);
```

The typewriter usually falls behind the backend, so the reply is still being revealed after
generation ends. To know when it is completely on screen — to swap a stop button back to send,
say — pass `expectMoreText` and listen to `onFinished`:

```dart
StreamingMessageView(
  text: markdownText,
  expectMoreText: isGenerating,  // true while the backend may still send text
  onFinished: () {
    // Generation has ended and every character has been revealed.
  },
);
```

### `AITypingIndicatorView`

Shows the current AI state ("Thinking…", "Checking sources…") with animated pulsing dots.

```dart
AITypingIndicatorView(
  text: 'AI is thinking',
  dotColor: Colors.blue, // optional overrides; unset ones come from the theme
  dotCount: 3,
  dotSize: 8,
);
```

Style it app-wide with `AITheme(typingIndicatorTheme: TypingIndicatorThemeData(...))` or for a
subtree with `TypingIndicatorTheme`. The indicator is a screen-reader live region labelled with
`text`, so keep it mounted and change `text` to have each new state announced. With reduced motion
on, the dots are static, and `StreamingMessageView` shows each update in full instead of typing it
out.

### `TypewriterController`

Low-level controller for driving the typewriter effect independently of
`StreamingMessageView`. Use with `TypewriterBuilder` for custom layouts.

```dart
final controller = TypewriterController(text: '');

// As new chunks arrive from the LLM:
controller.updateText(accumulatedText);

// In your widget tree:
TypewriterBuilder(
  controller: controller,
  builder: (context, value, child) => Text(value.text),
);
```

### `AIMarkdownBody`

The markdown renderer used internally by `StreamingMessageView`. Use it directly when you
need markdown rendering without the typewriter animation.

```dart
AIMarkdownBody(
  data: markdownText,
  selectable: true,          // enables text selection on desktop / web
  onTapLink: (text, href, title) { /* handle link tap */ },
);
```

#### LaTeX

`\(…\)` and `\[…\]` are recognised out of the box, but typesetting them is left to you —
every Flutter TeX renderer brings a sizeable dependency tree, and this package stays
standalone. Supply a `mathBuilder` and math renders; leave it off and the TeX source shows
as plain text. Both `AIMarkdownBody` and `StreamingMessageView` accept it.

```dart
// with `flutter_math_fork` in your pubspec
StreamingMessageView(
  text: markdownText,
  mathBuilder: (context, tex, style, {required inline}) => Math.tex(
    tex,
    textStyle: style,
    mathStyle: inline ? MathStyle.text : MathStyle.display,
  ),
);
```

Pass `useDollarDelimitersForMath: true` to also accept `$…$` and `$$…$$`. It is off by
default because `$` collides with currency in ordinary prose.

### `CodeBlockView`

Renders a fenced code block with a framed background, monospace text, an optional
language label, and a copy-to-clipboard button.

```dart
CodeBlockView(
  code: 'void main() => print("hello");',
  language: 'dart',
);
```

Syntax highlighting is opt-in through `highlighter`, for the same reason `mathBuilder`
exists: a grammar set is several times the size of this whole package — `re_highlight`'s
194 grammars are ~2.7 MB of Dart source, and because each is a top-level `final` holding
a tree of constructor calls, nothing tree-shakes the unused ones back out of a host app.
So the package frames and chromes code fences, and takes the tokenizer from you.

`example/lib/code_highlighter.dart` is a complete implementation over `re_highlight`,
covering the 31 languages LLMs actually emit (plus the aliases each grammar declares —
`js`, `ts`, `py`, `sh`, `yml`, `c++`, `cs`, `html`, …). Copy it, trim the language list
to taste, and pass it in:

```dart
StreamingMessageView(
  text: message,
  codeHighlighter: highlightCode, // example/lib/code_highlighter.dart
);
```

`AIMarkdownBody` and `CodeBlockView` take the same callback, as `codeHighlighter` and
`highlighter` respectively. Its contract is small:

```dart
TextSpan? highlightCode(CodeHighlightRequest request);
```

The request carries `code`, `language`, `baseStyle` (the block's monospace style),
`brightness` (of the block's resolved background) and the resolved `theme`; more fields
may be added later. `request.language` arrives exactly as the fence wrote it — case folding and alias resolution are
yours. Return `null` for a language you don't cover and the block renders plain
monospace text; that is a normal outcome, not a failure. A highlighter that throws, or
that returns spans whose text doesn't match `code`, is reported through
`FlutterError.onError` and the block falls back to the same plain rendering — so a
grammar bug costs the reader colors, never their code.

Without a highlighter, every fence renders as plain monospace text. It stays selectable
and horizontally scrollable in all cases.

Your highlighter is not called on every frame of a streaming fence: a re-highlight waits
for the code to gain 64 characters, plus one final pass once it stops changing. The
characters in between render unhighlighted rather than being withheld, so the block is
never truncated — coloring simply trails the newest text by up to about a line. Blocks
over 20,000 characters skip highlighting altogether. Prefer a top-level or otherwise
hoisted function over an inline closure, so the widget can tell a genuinely new
highlighter from a new closure over the same one.

**Theming.** The frame comes from `CodeBlockThemeData` — `brightness`, `backgroundColor`,
`headerBackgroundColor`, `languageLabelStyle`, `copyIconColor`, `copiedIconColor` and
`codeTextStyle` — resolved from the widget's own `theme`, then the nearest
`CodeBlockTheme`, then `AITheme.codeBlockTheme`. `AIMarkdownBody` and
`StreamingMessageView` forward a `codeBlockTheme` to every fence. By default the block is
the same dark frame (`#1E1E1E` with `#D4D4D4` text) in light and dark mode alike.

`brightness` pins whether the block is a dark or a light surface. It is exactly what your
highlighter receives as `request.brightness`, and every color default follows it:
`Brightness.light` alone gives a light frame (`#F6F8FA` with `#1F2328` text). For code
blocks that stay dark whatever the app's mode, set it once:

```dart
AITheme(codeBlockTheme: CodeBlockThemeData(brightness: Brightness.dark))
```

Colors you set still win over those defaults, and are then yours to keep consistent with
`brightness`. Leave `brightness` null and it is estimated from `backgroundColor` instead —
set only a light background and the default text and icon colors turn dark to match.

**Mind the contrast.** The theme colors the frame and the base text; the token colors are
your highlighter's. A light frame under a palette built for a dark one is unreadable, so
pick the palette from `request.brightness` (not the app's brightness) — the example uses `vs2015` on a dark block and
`atom-one-light` on a light one:

```dart
final palette = request.brightness == Brightness.dark ? vs2015Theme : atomOneLightTheme;
```

**Migrating from 0.1.0.** The loose code colors and the positional highlighter signature are
gone:

```dart
// Before
StreamingMessageView(
  text: message,
  codeBackgroundColor: background, // also on AIMarkdownBody
  codeForegroundColor: foreground,
);
CodeBlockView(code: code, backgroundColor: background, foregroundColor: foreground);
TextSpan? highlightCode(String code, String language, TextStyle baseStyle) { ... }

// After
StreamingMessageView(
  text: message,
  codeBlockTheme: CodeBlockThemeData(backgroundColor: background, codeTextStyle: TextStyle(color: foreground)),
);
CodeBlockView(
  code: code,
  theme: CodeBlockThemeData(backgroundColor: background, codeTextStyle: TextStyle(color: foreground)),
);
TextSpan? highlightCode(CodeHighlightRequest request) {
  // request.code, request.language, request.baseStyle, plus request.brightness and request.theme
}
```

Or set it once app-wide with `AITheme(codeBlockTheme: ...)` instead of per widget.

### `ChartView` + `USpec`

Renders a `USpec` as a line, bar, area, scatter, bubble, pie, histogram or heatmap chart. All but
the heatmap are painted by `fl_chart`; the heatmap is a plain widget grid. Parse AI responses that
contain JSON chart data with `USpecParser`:

```dart
// Reads USpec, Chart.js, Plotly, ECharts, Highcharts, Vega-Lite and a flat pie schema.
final spec = USpecParser.tryParse(jsonString);
if (spec != null) ChartView(spec: spec);
```

**Theming.** Colors and sizes come from `ChartThemeData`, registered app-wide as part of the
package's `AITheme` extension:

```dart
MaterialApp(
  theme: ThemeData(
    colorSchemeSeed: brandBlue,
    extensions: const [
      AITheme(chartTheme: ChartThemeData(seriesColors: [Color(0xFF005FFF), Color(0xFF00C1FF)])),
    ],
  ),
  ...
)
```

Every field is nullable, and leaving one unset means "derive it from the ambient `ThemeData`" — so
overriding the palette leaves the grid lines, axis labels and heatmap ramp following your app, in
light and dark alike. The sizing fields (`height`, the scatter and bubble radii, `histogramBinCount`)
have no theme to derive from, so they fall back to fixed defaults instead. Override it for a
subtree with `ChartTheme(data: ..., child: ...)`, or for one chart with `ChartView(theme: ...)`;
those three compose, most specific first.

**Legends.** Pies, and line, area, bar, scatter and bubble charts with two or more series, get a
legend below the plot. Turn it off, or move it above, with `showLegend` and `legendPosition`. Pie
slices big enough for it (`piePercentageThreshold`) are labelled with their percentage unless
`showPiePercentages` is `false`:

```dart
ChartView(
  spec: spec,
  theme: const ChartThemeData(legendPosition: ChartLegendPosition.top, showPiePercentages: false),
);
```

Three things worth knowing:

- **`ThemeData.copyWith(extensions:)` replaces the whole extension set.** If your app already
  registers others, re-list them:
  `theme.copyWith(extensions: [...theme.extensions.values, const AITheme()])`.
- **Pie slice labels pick black or white per slice** — whichever has the better WCAG contrast
  against that slice's own fill. Set a color on `ChartThemeData.pieLabelStyle` to take that choice
  back.
- **Nesting `ChartTheme` replaces rather than layers**, the way `IconTheme` does. Use
  `ChartTheme.merge` to add to an enclosing scope instead of shadowing it.

**Accessibility.** `fl_chart` paints to a canvas and exposes nothing, so each chart describes
itself: one semantics node whose label summarises the kind, the title, the axes, the series and the
value range — "Bar chart, Messages per day, 5 categories, values 8 to 24". The node deliberately
excludes the subtree, because letting a screen reader walk the tick labels gives a run of bare
numbers with nothing saying which axis they belong to. Because of that exclusion a heatmap names
its rows and columns rather than only counting them — "Heatmap, 2 rows by 4 columns, rows: Mon,
Tue, columns: 9am, 12pm, 3pm, 6pm, values 2 to 14" — since a heatmap rarely has axis labels and
the row and column are what identify a cell. The sentence is composed by
`AITranslations.chartSemanticsLabel` (see [Localization](#localization)); pass
`ChartView(semanticsLabel: ...)` to replace it, or an empty string to describe the chart yourself.

---

### `ChatComposer`

A message composer designed for AI-powered conversations. Features:

- An **attachment sheet** on the leading "+" button — camera, recent photos, the full photo
  library, and the controller's `ChatOption`s listed alongside them.
- An **inline selected-option badge** (with dismiss button) inside the input box.
- A **send / stop toggle** — the send button (↑) becomes a stop button (⏹) while the
  AI is generating a response.
- An optional **voice / send toggle** (`enableSpeechToText: true`) — a single control that
  shows a microphone while the field is empty and swaps to send as soon as you type.
- Factory-based slot customisation via `ChatComposerFactory` — leading, trailing, the input
  field, and the attachment sheet.

```dart
ChatComposer(
  controller: controller,
  enableSpeechToText: true, // requires the platform permissions documented below
  onSendPressed: (text, selectedOption, attachments) async {
    await myBackend.sendMessage(text, attachments);
  },
  onStopPressed: () => myBackend.stopGenerating(),
);
```

`onSendPressed` may return a `Future` — a send is usually a network call. The composer does not
wait for it: the field is cleared **as soon as the callback is invoked**, not when it completes, so
the composer never sits unresponsive for a round trip. A host whose send can fail owns surfacing
that and re-seeding the composer; a rejected future is at least reported through
`FlutterError.onError` rather than lost as an unhandled asynchronous error.

### `ChatComposerController`

`ChangeNotifier` that manages all mutable state for `ChatComposer`.

```dart
final controller = ChatComposerController(
  chatOptions: [
    ChatOption(id: 'summarize', text: 'Summarize this', icon: Icons.summarize),
    ChatOption(id: 'email',     text: 'Write an email',  icon: Icons.email),
  ],
);

// While the AI is generating:
controller.isGenerating = true;

// When the response is fully shown, e.g. from `StreamingMessageView.onFinished`:
controller.isGenerating = false;
```

### `ChatComposerFactory`

Subclass to override any of the composer's four slots. Each slot receives a props object — a
`ChatComposerSlotProps` subclass — rather than a bare controller, which is what lets a slot be
handed values `ChatComposer` itself owns:

| Slot | Props | Default | Returns |
|---|---|---|---|
| `buildLeading` | `ChatComposerLeadingProps` | outlined circular "+" button | `Widget?` — `null` hides it |
| `buildTrailing` | `ChatComposerTrailingProps` | `null` (nothing) | `Widget?` — `null` hides it |
| `buildInput` | `ChatComposerInputProps` | `ChatComposerInput` | `Widget` |
| `buildAttachmentSheet` | `ChatComposerAttachmentSheetProps` | `ComposerAttachmentSheet` | `Widget` |

Every one of those props carries the composer's wiring — `controller`, `focusNode`, `onSend` and
`onStop` — so any slot can drive the composer, not just the input. `ChatComposerInputProps` adds
the text-field configuration (`hintText`, `minLines`, `maxLines`, `textInputAction`,
`enableSpeechToText`, `speechToTextConfig`) on top; the other three add nothing and exist to name
the slot.

```dart
class MyComposerFactory extends ChatComposerFactory {
  // Replace the leading "+" button.
  @override
  Widget? buildLeading(BuildContext context, ChatComposerLeadingProps props) {
    return IconButton(icon: const Icon(Icons.attach_file), onPressed: () { ... });
  }

  // Keep the default input pill, but decorate around it.
  @override
  Widget buildInput(BuildContext context, ChatComposerInputProps props) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ChatComposerInput(props: props),
    );
  }

  // Swap the contents of the sheet the leading button opens. Presentation
  // (`showModalBottomSheet`, drag handle) stays with the button, so don't draw
  // a drag handle of your own — override `buildLeading` to change how the
  // sheet is presented, or whether it is at all.
  @override
  Widget buildAttachmentSheet(BuildContext context, ChatComposerAttachmentSheetProps props) {
    return MyPicker(controller: props.controller);
  }
}

// Pass to the composer:
ChatComposer(
  factory: MyComposerFactory(),
  ...
);
```

Only `buildInput`'s result is rebuilt by the composer. `buildAttachmentSheet` runs inside a modal
route, outside that rebuild — a replacement sheet rendering controller state (a selection count,
tiles disabled at `maxAttachments`) has to listen to `props.controller` itself, as
`ComposerAttachmentSheet` does.

To replace the input field outright rather than decorate it, build from `props`:
`props.onSend` and `props.onStop` are the only route to `ChatComposer.onSendPressed` /
`onStopPressed` — `onSend` also clears the controller and returns focus to `props.focusNode`
afterwards, so calling it beats reimplementing the send path. `props.onStop` is `null` when the
host passed no `onStopPressed`, so a custom input can hide its stop control instead of offering a
dead one.

```dart
class MyInputFactory extends ChatComposerFactory {
  @override
  Widget buildInput(BuildContext context, ChatComposerInputProps props) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: props.controller.textEditingController,
            focusNode: props.focusNode,
            // `props.hintText` is null unless the host passed
            // `ChatComposer.hintText`; the composer leaves the placeholder to
            // you. Drop the fallback if your input has a hint of its own.
            decoration: InputDecoration(
              hintText: props.hintText ?? AITranslations.of(context).composerHint,
            ),
          ),
        ),
        IconButton(icon: const Icon(Icons.send), onPressed: props.onSend),
      ],
    );
  }
}
```

`buildInput`'s result is placed in an `Expanded` by the composer, so don't return an `Expanded`
yourself (a debug assert catches it). Unlike the leading and trailing slots it is non-nullable —
there is no layout for "no input field"; return `const SizedBox.shrink()` if you really want an
empty one.

Because the wiring is on the shared base, a control that sends doesn't have to live inside the
input at all — the trailing slot is empty by default and takes the same props:

```dart
class MySendButtonFactory extends ChatComposerFactory {
  @override
  Widget? buildTrailing(BuildContext context, ChatComposerTrailingProps props) {
    return IconButton(
      icon: const Icon(Icons.send),
      // `canSend` is the whole rule: there is something to send, and a
      // response isn't already streaming. `onSend` no-ops when it is false,
      // so wiring the button to it unconditionally leaves it looking enabled
      // and doing nothing.
      onPressed: props.canSend ? props.onSend : null,
    );
  }
}
```

By default the composer refuses to send while `controller.isGenerating` is `true` — the same rule
its own UI expresses by showing a stop button instead of a send button. If your backend accepts a
follow-up mid-stream, pass `allowSendWhileGenerating: true` to `ChatComposer`; `canSend` follows
it, so the example above needs no change.

`props.onSend` and `props.onStop` are only safe to call while the composer is still mounted.
Calling either across an async gap — after a confirmation dialog, say — once the composer has left
the tree throws an `AssertionError` in debug and returns without sending in release.

To change one value and keep everything else the host configured, use `props.copyWith` rather than
re-listing the fields — a field you forget silently reverts to its default:

```dart
@override
Widget buildInput(BuildContext context, ChatComposerInputProps props) {
  return ChatComposerInput(props: props.copyWith(hintText: 'Ask the docs…'));
}
```

---

### `AISuggestionsView`

A horizontally-scrolling row of free-text quick-reply chips, independent of `ChatOption`. Typically
docked above the composer on a "new chat" landing screen — tapping a chip fires the callback with
its exact text, and you decide what happens next (e.g. send it immediately).

```dart
Column(
  children: [
    const Spacer(),
    AISuggestionsView(
      suggestions: const [
        'Create a painting in Renaissance-style',
        'Help me study vocabulary for an exam',
      ],
      onSuggestionSelected: (text) => sendMessage(text),
    ),
  ],
)
```

---

### `SpeechToTextButton`

A microphone button that feeds partial and final speech recognition results directly
into an `ChatComposerController`'s text field. The button hides itself automatically
when the AI is generating or the text field is non-empty. Prefer
`ChatComposer(enableSpeechToText: true, ...)` over placing this widget manually — that
swaps it into the send button's own slot for a single toggling control, rather than a
separate button alongside send.

```dart
SpeechToTextButton(
  controller: controller,
  config: SpeechToTextConfig(
    localeId: 'en-US', // optional; defaults to the device locale
    listenFor: Duration(seconds: 30),
    pauseFor: Duration(seconds: 3),
    onError: (error) => debugPrint(error.errorMsg),
  ),
);
```

`ChatComposer(enableSpeechToText: true, speechToTextConfig: ...)` takes the same config.

#### Required platform permissions

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed for voice input.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Speech recognition is used to convert your voice to text.</string>
```

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

**macOS** — `macos/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed for voice input.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Speech recognition is used to convert your voice to text.</string>
```

`macos/Runner/DebugProfile.entitlements` (and `Release.entitlements`):
```xml
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.device.microphone</key>
<true/>
```

### Agent steps: `AIMessagePartsView`

An agent writes each step it takes — a round of reasoning, a tool call — as a custom attachment on
its reply (`ai_reasoning`, `ai_tool_call`, …), in order, with the final answer in the message text.
`AIMessagePart.parseAll` decodes those attachments, given as `(type:, payload:)` records, skipping
any that aren't steps, and `AIMessagePartsView` shows them; put it above the reply's text (see
[Using with Stream Chat](#using-with-stream-chat) for reading a Stream Chat message's attachments):

```dart
AIMessagePartsView(parts: AIMessagePart.parseAll(attachments));
```

Reasoning gets a `StreamingReasoningView`, a tool call an `AIToolCallView`, and a step this version
can't read a neutral `AIUnsupportedPartView`. To show some steps your own way, return a widget from
`partBuilder` (any part) or `toolCallBuilder` (tool calls only); return `null` to keep the default,
or `AIMessagePartsView.hidden` to leave the step out:

```dart
AIMessagePartsView(
  parts: parts,
  toolCallBuilder: (context, call) => switch (call.name) {
    'get_weather' => WeatherCard(call: call),
    'log_event' => AIMessagePartsView.hidden,
    _ => null,
  },
);
```

### `StreamingReasoningView`

A model's reasoning: open under a "Thinking… 7s" header while it streams, then folded into "Thought
for 12s" and its summary, which the reader can tap to open again. `expandedWhenDone` keeps it open
once done, and `showsLiveReasoning: false` keeps it folded while it streams. For an `ai_reasoning`
step, `StreamingReasoningView.part` reads the status, duration and summary from the step.

```dart
StreamingReasoningView(text: reasoning, isThinking: answer.isEmpty, duration: elapsed);
```

The header counts for as long as `isThinking` is `true`, so end it yourself if your stream stalls or
fails. Style it with `ReasoningThemeData` (see its API docs for the fields).

### `AIToolCallView`

One tool call as a row: a status icon, the tool's title, a summary or status line, and the duration
once it has finished. Style it with `ToolCallThemeData` (see its API docs for the fields).

```dart
AIToolCallView(call: part.toolCall!);
```

### Tool approvals: `AIToolApprover`

An agent can ask the user before running a tool: the call waits with status `awaiting_approval`, and
the user's answer, `AIToolApprovalDecision.allowed` or `.declined`, goes to your backend through an
`AIToolApprover`. Pass one to `AIMessagePartsView` and each call waiting for this user gets an
`AIToolApprovalView` under its row, which goes away once the backend updates the call.

```dart
late final approver = AIToolApprover(
  identity: AIClientIdentity(userId: currentUser.id, clientId: installId),
  decide: (call, decision) => backend.answerToolCall(call.id, decision.value), // throw to let them retry
);

AIMessagePartsView(parts: parts, approver: approver);
```

Create the approver once (not in `build`) and `dispose` it when done. A call you draw yourself
through `toolCallBuilder` or `partBuilder` gets no question; put an
`AIToolApprovalView(call: call, approver: approver)` in your widget then. Pass it a `builder` to ask
in your own design, and style the default card with `ToolApprovalThemeData` (see its API docs for
the fields).

### `AIToolRegistry`

Client-side tools let the AI agent reach into your app: open a screen, present a
native alert, read a sensor. You declare each one as an `AIClientTool`, register it,
and hand the registrations to your backend; the agent then invokes them by name.

There are two ways a call reaches the device, and the same tools serve both:

- **Events** (`custom_client_tool_invocation`), routed with `AIToolRegistry.dispatch`
  below. Fire-and-forget: nothing is returned to the model.
- **Steps** (`ai_tool_call` with `executor: client`, `status: awaiting_client`), run by
  an [`AIClientToolRunner`](#aiclienttoolrunner), which sends each tool's result back so
  the agent can carry on with it. Use this when your agent writes steps.

Declare a tool:

```dart
class GreetUserTool implements AIClientTool {
  GreetUserTool({required this.onGreet});

  final void Function(String message) onGreet;

  @override
  AIToolDefinition get definition => const AIToolDefinition(
    name: 'greetUser',
    description: 'Show the user a native greeting',
    instructions: 'Use greetUser when the user asks to be greeted.',
    parameters: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
      },
    },
  );

  @override
  List<AIToolAction> handleInvocation(AIToolInvocation invocation) {
    final name = invocation.args['name'] as String? ?? 'there';
    return [() => onGreet('Hello, $name!')];
  }
}
```

A tool returns its work as `AIToolAction`s rather than performing it, so you decide
when and where it runs — the decision lives in the tool, the effect in your widget
tree. Omit `parameters` entirely for a tool that takes no arguments.

Register it, and tell your backend:

```dart
final registry = AIToolRegistry()
  ..register(GreetUserTool(onGreet: (message) => showSnackBar(message)));

await http.post(
  Uri.parse('$myBackend/register-tools'),
  headers: {'content-type': 'application/json'},
  body: jsonEncode({'channel_id': channel.cid, 'tools': registry.registrationPayloads()}),
);
```

That endpoint is **yours**, not Stream's — this package ships no HTTP client. Its job
is to call the agent SDK's `registerClientTools(channelId, tools)`, which *persists*
the definitions server-side and re-applies them the next time the channel's agent
starts.

> **Check the casing your own backend expects.** `registrationPayloads()` emits
> camelCase keys (`showExternalSourcesIndicator`), which is what the reference
> `/register-tools` in
> [`chat-ai-samples`](https://github.com/GetStream/chat-ai-samples) reads — it takes
> the camelCase spelling and treats `show_external_sources_indicator` as a deprecated
> fallback. Since the endpoint consuming them is *yours*, that is a default rather
> than a rule, and a mismatch fails quietly, as a tool that simply never fires. The
> payloads are plain maps, so remapping keys is a couple of lines.

Then route invocations. `dispatch` runs the tool's actions in order, guarding each
one; `resolve` returns them unrun if you want to schedule them yourself — run those
with `runActions` to get the same guarding, rather than reimplementing it. `dispatch`
reports whether *a tool was registered* under the invoked name — not whether it
succeeded. A `false` is normal rather than an error: because registrations outlive
the build that made them, an older version of your app can register a tool this build
no longer has; a debug build also prints the name and what *is* registered, for the
case where the name is mismatched rather than stale. Failures inside a tool go to
`FlutterError.onError`, and to the registry's `onToolError` if you pass one — that
callback is how you tell the *user* something didn't work.

Set `showExternalSourcesIndicator: true` on a tool that consults something remote and
the agent will report a "checking external sources" state while it runs. This package
never reads the flag; to surface the state, pass your own caption for it to
[`AITypingIndicatorView`](#aitypingindicatorview), whose `text` is an ordinary string.

### `AIClientToolRunner`

For agents that write their tool calls as `ai_tool_call` steps and wait for the
device's answer. A tool that returns something extends `AIResultClientTool`:

```dart
class LocationTool extends AIResultClientTool {
  @override
  AIToolDefinition get definition => const AIToolDefinition(
    name: 'get_location',
    description: "The user's approximate location",
  );

  @override
  Future<AIClientToolResult> run(AIToolCallPart call) async {
    final position = await locator.approximatePosition();
    if (position == null) return const AIClientToolResult.failed('Location not shared');
    return AIClientToolResult.completed(
      {'lat': position.lat, 'lng': position.lng},
      summary: 'Shared approximate location', // every channel member sees this
    );
  }
}
```

Plain `AIClientTool`s work too: their actions run and the call completes with no output.

```dart
final runner = AIClientToolRunner(
  identity: AIClientIdentity(userId: currentUser.id, clientId: installId),
  tools: [LocationTool()],
  send: (call, result) async {
    final response = await http.post(
      Uri.parse('$myBackend/tool-results'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(result.toJson(toolCallId: call.id, clientId: installId)),
    );
    // Throw so the runner retries.
    if (response.statusCode >= 300) throw Exception('tool result rejected: ${response.statusCode}');
  },
);

// Register runner.registrations with your backend, send installId as `client_id`
// in every message's custom data, then on every update of an AI reply:
unawaited(runner.handle(parts)); // parts from AIMessagePart.parseAll
```

The round trip: the agent writes a call with `target_user_id` / `target_client_id`;
`handle` runs every call `AIClientIdentity.canRun` matches, **once per call id** — calling
it on every streaming update is safe, in flight or not; `send` posts
`{tool_call_id, client_id, output | failure, summary}` to *your* backend, which checks
the caller and feeds the result to the model. Make that endpoint idempotent on
`tool_call_id`: a retry can post the same result twice.

A tool that throws, times out (`runTimeout`) or isn't registered is answered with a
generic failure; the error itself only goes to `FlutterError.onError` and `onToolError`
(override the wording with `failureMessage`). `send` is tried up to `maxAttempts` times
with exponential backoff, then reported through `onDeliveryError`; the result is kept and
sent again, without rerunning the tool, if a later `handle` still sees the call waiting.

Keep one runner per conversation: a fresh runner doesn't know what an old one ran.
`close()` stops it taking on new calls, but calls already running still finish and send
their results, so `send` must not rely on a widget's state; `whenIdle()` completes when
they are done.

### `AILocalModel`

A fallback for when your agent can't answer — the user is offline, or the agent hit its usage limit
— from a model on the device. The package ships no model: extend `AILocalModel` over the one you
choose. `reply` streams the **whole answer so far** with each event, which is what
`StreamingMessageView.text` takes; cancelling the subscription stops the model, and failures arrive
as an `AILocalModelException`. On-device contexts are small, so your `reply` should fit the turns
with `AIConversationTurn.fitToBudget`.

```dart
if (await localModel.isAvailable) {
  // Create the stream once, when the question is sent — never in `build`.
  _answers = localModel.reply(
    instructions: 'Answer briefly. You have no tools.',
    turns: [...history, AIConversationTurn.user(text)],
  );
}

StreamBuilder<String>(
  stream: _answers,
  builder: (context, snapshot) => StreamingMessageView(text: snapshot.data ?? ''),
);
```

The reply exists only on the device; send it to your backend yourself if it should be kept.

### Theming

Colors come from `AITheme`, a `ThemeExtension` registered on your app's `ThemeData`. It carries one
data class per component — `ChartThemeData`, `CodeBlockThemeData`, `ComposerThemeData`,
`ReasoningThemeData`, `SuggestionsThemeData`, `ToolApprovalThemeData`, `ToolCallThemeData` and
`TypingIndicatorThemeData`:

```dart
MaterialApp(
  theme: ThemeData(
    colorSchemeSeed: brandBlue,
    extensions: const [
      AITheme(
        composerTheme: ComposerThemeData(sendButtonColor: Color(0xFF005FFF)),
        suggestionsTheme: SuggestionsThemeData(backgroundColor: Color(0xFFEFF4FF)),
      ),
    ],
  ),
  ...
)
```

Every field on every one of them is nullable, and leaving one unset means "derive it from the
ambient `ThemeData`" — so overriding the send button leaves the pill, the border, the hint and the
attachment sheet following your app, in light and dark alike. Registering no extension at all gets
the appearance the package has always had; theming is opt-in.

`ComposerThemeData` covers `ChatComposer` and `ComposerAttachmentSheet`: `fillColor` and
`borderColor` (the pill, the leading "+" button and the sheet's tiles — the surfaces meant to read
as one control), `hintStyle`, `iconColor` and `disabledIconColor`, `sendButtonColor`,
`stopButtonColor`, `recordingButtonColor`, `actionButtonForegroundColor` (the glyph on that filled
circle), `selectedOptionColor` and `selectedOptionForegroundColor`, `photoSelectionColor` (the photo
grid's ring and check), and `attachmentPlaceholderColor` with `attachmentPlaceholderForegroundColor`
(a thumbnail's placeholder and remove badge, and the glyphs on them). Each foreground field is paired
with the surface it is drawn on, so overriding one pair never leaves an icon on a surface it wasn't
chosen for. `SuggestionsThemeData` has three: `backgroundColor`, `borderColor` and `textStyle`.
`TypingIndicatorThemeData` has `textStyle`, `dotColor`, `dotSize`, `dotCount` and `dotSpacing`.

Narrow any of them to a subtree with its scope — `ChartTheme`, `CodeBlockTheme`, `ComposerTheme`,
`ReasoningTheme`, `SuggestionsTheme`, `ToolApprovalTheme`, `ToolCallTheme` or
`TypingIndicatorTheme` — or give one widget its own through `theme:` on `ChartView`,
`HeatmapChartView`, `CodeBlockView`, `StreamingReasoningView`, `AIToolCallView` or
`AIToolApprovalView`:

```dart
ComposerTheme(
  data: const ComposerThemeData(sendButtonColor: Colors.teal),
  child: ChatComposer(onSendPressed: send),
)
```

Four things worth knowing:

- **`ThemeData.copyWith(extensions:)` replaces the whole extension set.** If your app already
  registers others, re-list them:
  `theme.copyWith(extensions: [...theme.extensions.values, const AITheme()])`.
- **`disabledIconColor` derives from the *resolved* `iconColor`.** Set only `iconColor` and the
  disabled states dim to match it, rather than to a dimmed `onSurface` that no longer relates.
- **The idle microphone uses `sendButtonColor`, not `recordingButtonColor`.** It occupies the send
  button's slot, and the two are meant to read as one control morphing in place;
  `recordingButtonColor` applies only while it is listening.
- **Nesting a scope replaces rather than layers**, the way `IconTheme` does. Use
  each scope's `.merge` (`ComposerTheme.merge`, `TypingIndicatorTheme.merge`, …) to add to an
  enclosing scope instead of shadowing it. All eight are `InheritedTheme`s, so they carry across a
  `Navigator` — a scope above the composer still reaches the attachment sheet that
  `showModalBottomSheet` pushes.

The suggestion chips default to the same tokens as the composer's input pill, since a suggestion
row is normally docked directly above it. Recolor that surface and you want both.

---

### Localization

Every string the package renders itself resolves through an `AITranslations` instance. Register
none and the widgets use `DefaultAITranslations` and render the English they always have, so this
is opt-in.

Implement `AITranslations` for each language you support:

```dart
class DutchTranslations implements AITranslations {
  const DutchTranslations();

  @override
  String get composerHint => 'Vraag maar';

  @override
  String get send => 'Verstuur';

  @override
  String clearOption(String option) => '$option wissen';

  // ...and every other string.
}
```

Implement it rather than extending `DefaultAITranslations`: when a later version adds a string, you
get a compile error telling you there is something new to translate, instead of English silently
showing up in your app. Adding a string is not considered a breaking change.

Then hand them to the app through `AITranslationsDelegate`, a `LocalizationsDelegate` like any
other, so Flutter picks the instance for the app's locale and swaps it when the locale changes:

```dart
MaterialApp(
  localizationsDelegates: const [
    AITranslationsDelegate({
      'nl': DutchTranslations(),
      'de': GermanTranslations(),
    }),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en'), Locale('nl'), Locale('de')],
  home: ...,
)
```

Keys are `Locale.toString()`'s form: `'nl'`, or `'pt_BR'` for a country-specific one, which takes
precedence over a plain `'pt'` entry. Case is part of that form — lowercase language, uppercase
country — because `Locale` compares its subtags verbatim and never normalizes them, so `'NL'` would
match no locale at all. A debug-only assert rejects a key in any other shape rather than leaving it
to render English with no explanation. English itself needs no entry — a locale the delegate has
nothing for renders the defaults — so it is safe to register the delegate with one language in it
and add the rest later. The delegate adds no dependency; `GlobalMaterialLocalizations` above is
`flutter_localizations`, which you will already have if you are translating the rest of your app.

The example app under `example/` has this wired up — an `AITranslationsDelegate` carrying a Dutch
translation — so run it on a device set to Dutch to see the placeholder and the tooltips follow.

Most of these strings are `Tooltip` messages on icon-only buttons — the send, stop, mic, "+", copy
and dismiss controls — which makes them the only accessible label those buttons expose. Translating
them is what makes the composer legible to a screen reader in another locale.

To pin one language over part of the tree instead — a screen that is always in one language, a
preview, a test — wrap it in an `AITranslationsScope`:

```dart
AITranslationsScope(
  translations: const DutchTranslations(),
  child: ChatComposer(onSendPressed: ...),
)
```

A scope outranks the delegate, being the narrower of the two. `AITranslations.of(context)` resolves
the scope first, then the locale's delegate, then the English defaults, and never throws.

Three things worth knowing:

- **Give your class a `const` constructor** and construct it as `const DutchTranslations()`.
  A scope compares instances to decide whether to notify, so a fresh instance built in a `build`
  method rebuilds every dependent. A `const` map of them also makes the delegate itself `const`.
- **`ChatComposer.hintText` wins over `AITranslations.composerHint`.** A hint written for one
  composer is more specific than an app-wide string.
- **Both reach routes, not just the widgets under them.** The delegate's strings sit in
  `MaterialApp`'s own `Localizations`, above the `Navigator`, so every route gets them.
  `AITranslationsScope` is an `InheritedTheme`, so `showModalBottomSheet`, `showDialog` and
  `showMenu` carry it across the `Navigator` the same way they carry a `Theme` — a scope directly
  above a `ChatComposer` still translates that composer's attachment sheet, and so does one above a
  `ComposerAttachmentSheet` you present yourself. Those pushes *capture* the scope, so swapping it
  while such a route is open doesn't reach the open route, only the next one. The delegate has no
  such seam.

`chartSemanticsLabel` is the odd one out: it takes a `ChartSemantics` — the facts about a chart,
with their numbers already formatted — and composes a whole sentence, rather than being one short
label. A sentence's word order varies far more between languages than a tooltip's does, so
composing it is the point:

```dart
@override
String chartSemanticsLabel(ChartSemantics chart) {
  final kind = switch (chart.kind) {
    USpecKind.bar => 'Staafdiagram',
    USpecKind.pie => 'Cirkeldiagram',
    USpecKind.heatmap => 'Heatmap',
    _ => 'Grafiek',
  };
  if (chart.isEmpty) return '$kind, geen gegevens';
  final count = switch (chart.kind) {
    USpecKind.bar => '${chart.categoryCount} categorieën',
    USpecKind.pie => '${chart.pointCount} segmenten',
    USpecKind.heatmap => '${chart.rowCount} rijen bij ${chart.columnCount} kolommen',
    _ => '${chart.pointCount} punten',
  };
  return '$kind, $count, waarden ${chart.valueMin} tot ${chart.valueMax}';
}
```

Switch on `chart.kind` — it covers all eight `USpecKind`s, and a label that names the wrong kind is
worse than a generic one. The count fields are not interchangeable either: `categoryCount` is the x
axis a bar chart draws, `pointCount` counts plotted points (a pie's slices, a histogram's samples),
and `rowCount`/`columnLabels` are a heatmap's grid. Check `chart.isEmpty` before reading
`valueMin`/`valueMax`: they are `null` for a chart with no points. `sizeMin`/`sizeMax` are non-null
only for a bubble chart, the one kind that draws `UPoint.size`.

---

## Using with Stream Chat

The components in this package are provider-agnostic: they take plain text, callbacks,
and controllers, so you decide how to source and stream AI responses. If you're building
on top of [Stream Chat](https://getstream.io/chat/sdk/flutter/), here's how the pieces
typically connect to a `Channel` from `stream_chat_flutter`. This requires adding
`stream_chat_flutter` as a dependency of your app (not of this package):

```dart
channel.on(EventType.aiIndicatorUpdate).listen((event) {
  final state = event.aiState;     // AITypingState enum
  final msgId = event.aiMessage;   // ID of the message being generated
  controller.isGenerating = state == AITypingState.generating;
  setState(() => backendDone = false);
  // show AITypingIndicatorView / switch to StreamingMessageView
});

channel.on(EventType.aiIndicatorClear).listen((_) {
  setState(() => backendDone = true);
  // hide the indicator; the final message may still be typing out
});
```

The backend usually finishes well before the typewriter has revealed the reply, so flipping the
composer back to "send" on `aiIndicatorClear` hides the stop button while text is still appearing.
Leave that to the message view instead:

```dart
StreamingMessageView(
  text: message.text ?? '',
  expectMoreText: !backendDone,
  onFinished: () => controller.isGenerating = false,
);
```

Turn a message's attachments into [agent steps](#agent-steps-aimessagepartsview):

```dart
final parts = AIMessagePart.parseAll([
  for (final attachment in message.attachments)
    if (attachment.rawType case final type?)
      (type: type, payload: {'id': attachment.id, ...attachment.extraData}),
]);
```

Use `rawType` (`type` can be rewritten, such as into a link preview), and spread `extraData` last
so the agent's step `id` wins over `Attachment.id`. Pass
the same `parts` to `AIMessagePartsView` and, on every message update, to `AIClientToolRunner.handle`.

Route client-tool invocations to your `AIToolRegistry`:

```dart
channel.on(kClientToolInvocationEventType).listen((event) {
  final invocation = AIToolInvocation.tryParse(
    {...event.extraData, 'cid': event.cid, 'message_id': event.messageId},
    isInvocationEvent: true,
  );
  if (invocation != null) unawaited(registry.dispatch(invocation));
});
```

A payload that announced itself as an invocation and then failed to parse is reported
to `FlutterError.onError`: the tool the agent asked for will not run, and the agent is
never told, so that would otherwise be silent.

`tryParse` takes a flat map so the event's own fields can be merged in. `cid`,
`message_id` and `type` are all first-class fields on `Event` rather than part of
`extraData`, so the two the invocation needs are added by hand — forget `message_id`
and `invocation.messageId` is silently null.

`type` is the third one, and it is what `isInvocationEvent: true` stands in for: it
tells `tryParse` that you have already filtered the stream, so a payload that arrives
with no `tool` object is a malformed invocation worth reporting rather than some other
event to pass over. Filter on an event type of your own and the flag still holds — it
is the filtering it asserts, not the name.

Stop an in-progress AI response:

```dart
await channel.stopAIResponse();
```

Send the composer's text as a new message:

```dart
ChatComposer(
  controller: controller,
  onSendPressed: (text, selectedOption, attachments) => channel.sendMessage(Message(text: text)),
  onStopPressed: () => channel.stopAIResponse(),
);
```

See the [Flutter AI sample app](https://github.com/GetStream/chat-ai-samples/tree/main/flutter)
for a complete, working integration.

## Changelog

Check out the [changelog on pub.dev](https://pub.dev/packages/stream_chat_flutter_ai/changelog) to
see the latest changes in the package.

## 🛥 What is Stream?

Stream allows developers to rapidly deploy scalable feeds, chat messaging and video with an industry
leading 99.999% uptime SLA guarantee.

Stream provides UI components and state handling that make it easy to build real-time chat and video
calling for your app. Stream runs and maintains a global network of edge servers around the world,
ensuring optimal latency and reliability regardless of where your users are located.

## 📕 Tutorials

To learn more about integrating AI and chatbots into your application, we recommend checking out the
full list of tutorials across all of our supported frontend SDKs and providers. Stream's Chat SDK is
natively supported across:

* [React](https://getstream.io/chat/react-chat/tutorial/)
* [React Native](https://getstream.io/chat/react-native-chat/tutorial/)
* [Angular](https://getstream.io/chat/angular/tutorial/)
* [Jetpack Compose](https://getstream.io/tutorials/android-chat/)
* [SwiftUI](https://getstream.io/tutorials/ios-chat/)
* [Flutter](https://getstream.io/chat/flutter/tutorial/)
* [Javascript/Bring your own](https://getstream.io/chat/docs/javascript/)

The sibling AI component libraries live in
[stream-chat-android-ai](https://github.com/GetStream/stream-chat-android-ai) and
[stream-chat-swift-ai](https://github.com/GetStream/stream-chat-swift-ai).

## 👩‍💻 Free for Makers 👨‍💻

Stream is free for most side and hobby projects. To qualify, your project/company needs to have
< 5 team members and < $10k in monthly revenue. Makers get $100 in monthly credit for video for free.
For more details, check out the [Maker Account](https://getstream.io/maker-account).

## 💼 We are hiring!

We've recently closed a [\$38 million Series B funding round](https://techcrunch.com/2021/03/04/stream-raises-38m-as-its-chat-and-activity-feed-apis-power-communications-for-1b-users/)
and we keep actively growing. Our APIs are used by more than a billion end-users, and you'll have a
chance to make a huge impact on the product within a team of the strongest engineers all over the
world. Check out our current openings and apply via [Stream's website](https://getstream.io/team/#jobs).

## License

`stream_chat_flutter_ai` is released under the Stream Source Code License Agreement. See
[`LICENSE`](LICENSE) for the full text.
