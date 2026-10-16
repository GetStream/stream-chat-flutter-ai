## Upcoming

💥 Breaking

- `CodeBlockThemeData` (`AITheme.codeBlockTheme`) replaces the code color parameters, and `CodeHighlighter` now takes a `CodeHighlightRequest`.
- `AITypingIndicatorView` is themed through `TypingIndicatorThemeData` (dot params now nullable, dots follow the text color instead of black), announces state changes to screen readers and honours reduced motion.
- `ChatComposer.factory` is nullable; `null` uses the factory from `AIComponents`.

✅ Added

- `StreamingMessageView.onFinished` — called once a reply is completely on screen: the new
  `expectMoreText` flag is `false` and the typewriter has revealed every character. The typewriter
  usually falls behind the backend, so this fires later than the end of generation, which
  `onTypewriterStateChanged` couldn't tell apart from a pause in the stream.
- `AIMessagePart` models and `AIMessagePartsView` for agent steps (`ai_reasoning` / `ai_tool_call` attachments), and `AITranslations.unsupportedMessagePart`.
- `StreamingReasoningView` — a collapsible "Thinking… / Thought for Ns" reasoning panel, themed via `ReasoningThemeData`.
- `AIToolCallView` — a tool-call row with status icon, summary and duration, themed via `ToolCallThemeData`; `AIMessagePartsView.toolCallBuilder` overrides it per tool, and `AIMessagePartsView.hidden` leaves a step out.
- `AIToolApprovalView` / `AIToolApprovalCard` — human-in-the-loop tool approvals via an `AIToolApprover`, themed via `ToolApprovalThemeData`; `AIMessagePartsView.approver` asks under each waiting call.
- `AIClientToolRunner` runs `awaiting_client` tool calls once and sends each `AIClientToolResult` back to the agent; `AIResultClientTool` returns one.
- Charts show a series legend (`ChartThemeData.showLegend` / `legendPosition`), and pie slices are labelled with their percentage.
- `AILocalModel` and `AIConversationTurn` for streaming a fallback reply from an on-device model.
- `AIComponentFactory` / `AIComponents` — one place to replace the code blocks, charts, agent steps, approval card and composer slots the package builds.

## 0.1.0

First release of `stream_chat_flutter_ai` — Flutter UI components for building LLM-driven chat
experiences. The package has no dependency on `stream_chat`, `stream_chat_flutter` or any other
Stream Chat package: every widget takes plain strings, callbacks and controllers, so it drops into
any Flutter app and pairs with any backend or LLM provider.

✅ Added

- `StreamingMessageView` — renders markdown with a character-by-character typewriter animation, for
  showing an AI response as it streams in. `TypewriterController` and `TypewriterBuilder` drive the
  same effect on a layout of your own.
- `AIMarkdownBody` — the markdown renderer without the animation. LaTeX and syntax highlighting are
  opt-in through the `mathBuilder` and `codeHighlighter` hooks, so neither pulls a dependency into
  hosts that don't want one.
- `CodeBlockView` — a fenced code block with a language label and a copy-to-clipboard button.
- `ChartView` and `USpec` — line, bar, area, scatter, bubble, pie, histogram and heatmap charts.
  `USpecParser` reads USpec, Chart.js, Plotly, ECharts, Highcharts and Vega-Lite payloads,
  `ChartThemeData` themes them from your app's `ThemeData`, and every chart describes itself to a
  screen reader.
- `AITypingIndicatorView` — animated LLM states such as "Thinking…" or "Checking sources…".
- `ChatComposer` — an AI composer with attachments, chat options, and a send button that becomes a
  stop button while a response streams. Its leading, trailing, input and attachment-sheet slots are
  replaceable through `ChatComposerFactory`.
- `AISuggestionsView` — a row of quick-reply chips for a new-chat landing screen.
- `SpeechToTextButton` — dictation into the composer, either standalone or folded into the
  composer's own send control with `enableSpeechToText: true`.
- `AIToolRegistry` — client-side tool calling. Declare `AIClientTool`s, hand their registrations to
  your backend, and dispatch the agent's invocations back into your app.
- `AITranslations` — every string the package renders is translatable, through an
  `AITranslationsDelegate` for the app's locale or an `AITranslationsScope` for a subtree.
- `AITheme` — a `ThemeExtension` carrying `ChartThemeData`, `ComposerThemeData` and
  `SuggestionsThemeData`, narrowed to a subtree with `ChartTheme`, `ComposerTheme` or
  `SuggestionsTheme`. Every field is optional and falls back to your app's `ThemeData`.
