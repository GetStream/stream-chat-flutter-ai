## Upcoming

💥 Breaking

- `CodeHighlighter` now takes a single `CodeHighlightRequest` instead of `(code, language, baseStyle)`.
- `CodeBlockView.backgroundColor` and `CodeBlockView.foregroundColor` are replaced by `CodeBlockView.theme`.
- `AIMarkdownBody.codeBackgroundColor`/`codeForegroundColor` and
  `StreamingMessageView.codeBackgroundColor`/`codeForegroundColor` are replaced by `codeBlockTheme`.
- `AITypingIndicatorView.dotCount` and `dotSize` are now nullable; unset, they come from the theme.
- `AnimatedDots.count`, `size`, `spacing` and `color` are now nullable, and the dots default to the themed caption color instead of black.
- `AITypingIndicatorView`'s caption defaults to `bodyMedium` in `onSurfaceVariant` instead of inheriting `DefaultTextStyle`.

✅ Added

- `CodeBlockThemeData` — themes a code block's background, header, language label, copy icons and
  base code style. Its `brightness` pins the block light or dark, which picks the default colors and
  tells the highlighter which palette to use.
- `CodeBlockTheme` — narrows a `CodeBlockThemeData` to a subtree; `AITheme.codeBlockTheme` sets it
  app-wide.
- `CodeHighlightRequest` — what a `CodeHighlighter` is asked to highlight: the code, its language,
  the block's resolved theme, and the `baseStyle` and `brightness` derived from it.

- `StreamingMessageView.onFinished` — called once a reply is completely on screen: the new
  `expectMoreText` flag is `false` and the typewriter has revealed every character. The typewriter
  usually falls behind the backend, so this fires later than the end of generation, which
  `onTypewriterStateChanged` couldn't tell apart from a pause in the stream.
- `TypingIndicatorThemeData`, `TypingIndicatorTheme` and `AITheme.typingIndicatorTheme` — theme the
  typing indicator's caption style and the dots' color, size, count and spacing.
- `AITypingIndicatorView.dotSpacing`.
- `AITypingIndicatorView` is a polite live region labelled with its `text`, so a screen reader
  announces each new state; the dots are hidden from assistive technology.
- Reduced motion (`MediaQueryData.disableAnimations`): `AITypingIndicatorView` and `AnimatedDots`
  draw static dots, and `StreamingMessageView` shows each new text in full instead of typing it out,
  finishing any reveal in progress.
- `AIMessagePart` — one step an AI agent took while replying, decoded from an `ai_*` attachment.
  `AIMessagePart.parseAll` turns a message's `AIMessagePartAttachment`s (`type` + payload) into
  parts, skipping other attachments, and decoding is lenient. `AIMessagePartKind` is the step's
  kind: an open set, so a kind this package doesn't know keeps its raw value.
- `AIReasoningPart` — the typed view of an `ai_reasoning` step, with `AIReasoningStatus`.
- `AIToolCallPart` — the typed view of an `ai_tool_call` step, with `AIToolCallStatus` and
  `AIToolExecutor` (server or client).
- `AIToolApproval` — what a tool call asks before it runs, with `AIToolApprovalDecision`.
- `AIMessagePartsView` — shows a reply's steps in order, keyed by id. `AIMessagePartWidgetBuilder`
  builds parts your own way.
- `AIUnsupportedPartView` — the placeholder for a step this app version can't show.
- `AITranslations.unsupportedMessagePart` — that placeholder's text.
- `StreamingReasoningView` — a collapsible "Thinking… 7s / Thought for 12s" panel for the model's
  reasoning, revealing it smoothly as it streams in. `StreamingReasoningView.part` builds one from
  an `AIReasoningPart`, and `AIMessagePartsView` shows reasoning steps with it. Themed through
  `ReasoningThemeData` (`AITheme.reasoningTheme`), narrowed to a subtree with `ReasoningTheme`, and
  translated through the new `AITranslations` members `reasoningThinking`, `reasoningThinkingFor`,
  `reasoningTitle`, `reasoningThoughtFor`, `reasoningShowHint` and `reasoningHideHint`.
  `DefaultAITranslations.reasoningDuration` spells the durations.
- `AIToolCallView` — a one-line row for a tool-call step: a status icon, the title, a detail line
  (the summary, or the status in words) and the duration once the call has finished. Screen readers
  hear it as one node, announced as a live call finishes or starts waiting. `AIMessagePartsView`
  shows tool calls with it.
- `ToolCallThemeData` and `ToolCallTheme`, and `AITheme.toolCallTheme`, for styling tool-call rows.
- `AIMessagePartsView.toolCallBuilder` (an `AIToolCallWidgetBuilder`) — builds some tools your own
  way and leaves the rest to `AIToolCallView`.
- `AIMessagePartsView.hidden` — returned from `partBuilder` or `toolCallBuilder`, leaves a step out
  of the list, spacing and all.
- `AIToolCallPart.summaryText` — the call's summary, or `null` when it is absent or blank.
  `AIToolCallPart.displayName` trims the title, and treats a blank one as missing, falling back to
  the tool's name.
- `AITranslations.toolCallFallbackTitle`, `toolCallRunning`, `toolCallCompleted`,
  `toolCallAwaitingApproval`, `toolCallAwaitingClient`, `toolCallFailed`, `toolCallCancelled`,
  `toolCallDeclined`, `toolCallDuration` and `toolCallDurationBelowTenth` — the tool-call row's
  strings.
- `AIToolApprover` — sends a person's answers to tool calls' questions through an
  `AIToolApprovalDecider` and tracks each call's `AIToolApprovalState` (`AIToolApprovalIdle`,
  `AIToolApprovalSending`, `AIToolApprovalSent`, `AIToolApprovalFailed`). An optional `sentTimeout`
  bounds sending the answer and then waiting for the backend to move the call on.
- `AIClientIdentity` — the signed-in user and install id that a tool call's `target_user_id` and
  `target_client_id` are matched against, through `canApprove` and `canRun`.
- `AIToolApprovalView` and `AIToolApprovalCard` — ask the person a tool call waits for whether it
  may run, with Allow / Don't Allow buttons. An `AIToolApprovalContentBuilder`, given an
  `AIToolApprovalAnswer` callback, replaces the card.
- `ToolApprovalThemeData` and `ToolApprovalTheme`, and `AITheme.toolApprovalTheme`, for styling the
  approval card.
- `AIMessagePartsView.approver` — shows an `AIToolApprovalView` under each tool call waiting for the
  person.
- `AITranslations.toolApprovalTitle`, `toolApprovalAllow`, `toolApprovalDecline`,
  `toolApprovalSending`, `toolApprovalSent` and `toolApprovalNotSent` — the approval card's strings.
- `AIClientToolRunner` runs `awaiting_client` tool calls once and sends each `AIClientToolResult` back to the agent; `AIResultClientTool` returns one.

🔄 Changed

- The recommended way to provide translations is now to implement `AITranslations` rather than
  extend `DefaultAITranslations`, so a string added in a later version is a compile error instead
  of English silently showing up in your app. Existing subclasses of `DefaultAITranslations` keep
  working.

🐞 Fixed

- `AITypingIndicatorView`'s dots were black by default, which made them invisible in dark mode.
- `StreamingMessageView.onTypewriterStateChanged` is no longer called during a build, so the host can
  call `setState` from it. A state that changes mid-frame is reported after the frame.

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
