## Upcoming

💥 Breaking

- `CodeHighlighter` now takes a single `CodeHighlightRequest` instead of `(code, language, baseStyle)`.
- `CodeBlockView.backgroundColor` and `CodeBlockView.foregroundColor` are replaced by `CodeBlockView.theme`.
- `AIMarkdownBody.codeBackgroundColor`/`codeForegroundColor` and
  `StreamingMessageView.codeBackgroundColor`/`codeForegroundColor` are replaced by `codeBlockTheme`.
- `AITypingIndicatorView.dotCount` and `dotSize` are now nullable; unset, they come from the theme.
- `AnimatedDots.count`, `size`, `spacing` and `color` are now nullable, and the dots default to the themed caption color instead of black.
- `AITypingIndicatorView`'s caption defaults to `bodyMedium` in `onSurfaceVariant` instead of inheriting `DefaultTextStyle`.
- `ChatComposer.factory` is nullable; `null` uses `AIComponentBuilders.composer`, then the default.

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
- `AIClientToolResult` — what a device reports for a client tool call: `AIClientToolResult.completed`
  (an `AIClientToolCompleted`, which throws when its output isn't JSON-encodable) or
  `AIClientToolResult.failed` (an `AIClientToolFailed`). `toJson` gives the backend's
  `{tool_call_id, client_id, output | failure, summary}` shape.
- `AIResultClientTool` — a client tool whose `run` returns an `AIClientToolResult`. It still
  dispatches through `AIToolRegistry`, where the result is dropped.
- `AIClientToolRunner` — runs the `awaiting_client` calls aimed at this device, each once, and sends
  each result back through `send` (an `AIClientToolResultSender`). A call for a tool it doesn't have
  is left for another runner unless `failUnknownTools` is set. Options: `maxAttempts`, `retryDelay`
  (capped at `AIClientToolRunner.maxRetryDelay`), `runTimeout`, `sendTimeout`, `failureMessage` (an
  `AIClientToolFailureMessage`), `onToolError` (an `AIClientToolCallErrorCallback`) and
  `onDeliveryError` (an `AIClientToolDeliveryErrorCallback`).
  Also `handle` / `handleCalls`, `registrations`, `toolNames`, `retryUndelivered`, `close`,
  `whenIdle`, `isClosed`, `hasPendingWork` and `hasUndelivered`.
- `AIToolRegistry.toolNamed` — the tool registered under a name, or `null`.
- `ChartView` draws a legend for a pie and for a chart with two or more series, themed via the new
  `ChartThemeData.showLegend`, `legendPosition` (a `ChartLegendPosition`) and `legendTextStyle`. A
  long legend is cut off with a "+N more" entry.
- `ChartThemeData.showPiePercentages` and `piePercentageThreshold` — pie slices show their share of
  the whole, from 8% up by default.
- `ChartSemantics.sliceLabels` — the names of the slices a pie draws.
- `ChartView.legendKey` — the key of a chart's legend, for finding it in widget tests.
- `AITranslations.unnamedChartSlice` and `chartLegendMore` — the legend's names for an unnamed slice
  and for the entries left out.
- `AILocalModel` — an interface over an on-device model that streams a fallback reply when the person is offline or the agent hit its usage limit. Each event is the whole answer so far, which is what `StreamingMessageView.text` takes, and cancelling the subscription stops the model.
- `AIConversationTurn` and `AIConversationRole` — one turn of the conversation handed to an `AILocalModel`. `AIConversationTurn.fitToBudget` trims the history to a small context, keeping the newest unbroken run of turns and always the question; `estimateTokens` and `tokensPerTurn` set what a turn costs.
- `AILocalModelException` and `AILocalModelErrorReason` (`unavailable`, `invalidConversation`, `contextExceeded`, `failed`) — the error an `AILocalModel.reply` stream emits when the model can't answer.
- `AIComponentFactory` and `AIComponentBuilders` (+ `AIComponentBuilder<T>`) replace the code blocks, charts, agent steps, approval card and composer slots the package builds.
- `AICodeBlockProps`, `AIChartProps`, `AIReasoningProps`, `AIToolCallProps`, `AIToolApprovalProps` and `AIUnsupportedPartProps` — the props each `AIComponentBuilders` slot gets.
- `AIReplyActionsView` — the buttons under a finished reply: copy, which confirms with a check and
  "Copied!" for a moment, then share, regenerate and 👍 / 👎 when the app handles them. Tapping the
  current rating takes it back, and the selected rating is reported to screen readers.
- `AIReplyActions` — what `AIReplyActionsView` offers besides copying: the `rating`, and the
  `onShare`, `onRegenerate` and `onRate` callbacks. Each button shows only when its callback is set.
- `AIMessageRating` — how the person rated a reply, `positive` or `negative`.
- `AIReplyShareCallback` — shares a reply's text, given the share button's rectangle to anchor a
  share sheet to. The package has no share dependency, so pass `onShare` (with `share_plus`, say) to
  show the share button.
- `ReplyActionsThemeData` and `ReplyActionsTheme`, and `AITheme.replyActionsTheme`, for the buttons'
  icon color, selected icon color and icon size.
- `AITranslations.copyReply`, `replyCopied`, `shareReply`, `regenerateReply`, `rateReplyPositive`
  and `rateReplyNegative` — the buttons' tooltips and labels.
- `AIConversationView` — an AI conversation laid out in turns. A question the person sends scrolls
  to the top and its reply types out below it without the list moving; a conversation opens at its
  end, `loadOlderMessages` loads older messages at its start without moving what is on screen, and a
  button scrolls back to the latest. `isThinking` shows the agent thinking, and the reply's first
  reasoning step carries on its count. `footer` sits under the latest turn, such as for an error
  with a way to retry.
- `AIMessage` — the message type `AIConversationView` shows: mix it into your own, with `id`,
  `role` (an `AIMessageRole`), `text`, `isGenerating`, `parts`, `attachments` and `reasoningText`.
- `AIPendingMessage` — a message the person sent, shown at once until its copy arrives.
- `AIMessageAttachment` — an image or file a message carries, or a kind of your own with its raw
  fields in `extraData`, which compares by value. `AIMessageAttachmentKind` is an open set.
- `AIUserMessageView`, `AIAssistantMessageView` and `AIThinkingView` — a conversation's rows and its
  "Thinking… 4s".
- `AIMessageAttachmentView` — an image as a thumbnail and anything else as a file card;
  `AIComponentBuilders.messageAttachment` shows kinds of your own.
- `AIComponentBuilders.userMessage`, `assistantMessage`, `replyActions` (empty by default) and
  `messageAttachment`, with `AIUserMessageProps`, `AIAssistantMessageProps`, `AIReplyActionsProps`
  and `AIMessageAttachmentProps`.
- `AIReasoningProps.text` and `duration` — a step's full reasoning, and the duration the
  conversation measured for its first step.
- `ConversationThemeData` and `ConversationTheme`, and `AITheme.conversationTheme`, for the bubbles,
  attachments and scroll-to-latest button.
- `AITranslations.copyMessage`, `editMessage`, `scrollToLatest`, `attachmentImage`,
  `attachmentFile`, `attachmentDetails` and `fileSize` — the conversation's strings.
- `AIVoiceGlowView` and `AIVoiceWaveView` — a globe of drifting color and a waveform line that show
  what a voice agent is doing, drawn with fragment shaders. They ease from one state into the next,
  ripple where they are tapped and barely move with reduced motion on.
- `AIVoiceAgentState` — what the agent is doing: `idle`, `connecting`, `listening`, `thinking` or
  `speaking`.
- `colors` (one to five, `ColorScheme.primary` by default), `expressivity` (0 to 2) and
  `audioLevel` (0 to 1, a live voice level such as a call participant's) on both views.
- `AITranslations.voiceAgent`, `voiceIdle`, `voiceConnecting`, `voiceListening`, `voiceThinking`
  and `voiceSpeaking` — what screen readers hear: the view, and the state as its value.

🔄 Changed

- The recommended way to provide translations is now to implement `AITranslations` rather than
  extend `DefaultAITranslations`, so a string added in a later version is a compile error instead
  of English silently showing up in your app. Existing subclasses of `DefaultAITranslations` keep
  working.
- Pie slices are labelled with their percentage; when the chart has a legend the name moves there.
- A pie's screen-reader summary lists its slice names.
- `ChartSemantics.isEmpty` is `true` for a pie with no positive slice.
- The README documents the new components — agent steps, reasoning, tool calls, approvals, the client tool runner, `AILocalModel` and chart legends — and its `SpeechToTextButton` snippet now uses `SpeechToTextConfig`.
- `AIConversationView`, `AIUserMessageView` and `AIReplyActionsView` take the iOS SDK's sizes: 8
  between turns; a 40 dp scroll-to-latest circle with a light shadow and a 48 dp tap target, which
  fades and scales in once the end is more than 24 dp out of view; a 20 dp older-messages spinner;
  a user bubble 40 dp from the leading edge with 16×12 padding; and 40 dp reply actions, 8 apart and
  8 below the answer.

🐞 Fixed

- `AITypingIndicatorView`'s dots were black by default, which made them invisible in dark mode.
- `StreamingMessageView.onTypewriterStateChanged` is no longer called during a build, so the host can
  call `setState` from it. A state that changes mid-frame is reported after the frame.
- A `NaN` or infinite value no longer breaks a chart: the parsers drop it, and a pie leaves such
  slices out.
- A pie with mixed-sign values no longer shows percentages such as "250%"; only positive slices are
  drawn and counted.
- A gap in a series (a Chart.js `null`) no longer shifts the points after it one category over: a
  line breaks at the gap and a bar chart leaves the bar out.

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
