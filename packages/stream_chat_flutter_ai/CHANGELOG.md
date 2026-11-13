## Upcoming

🐞 Fixed

- A link in an agent's reply, or in its reasoning, opens when tapped: a web link in the browser, and any
  other URL with the platform's default app. It did nothing before.

## 0.2.0

💥 Breaking

- Built on `stream_core_flutter`: defaults come from `StreamTheme` instead of Material's `ColorScheme`/`TextTheme`, and buttons, sheets, spinners and most icons are core components.
- Flutter 3.44 / Dart 3.12 are the minimum, matching `stream_core_flutter`.
- `CodeHighlighter` now takes a single `CodeHighlightRequest` instead of `(code, language, baseStyle)`.
- `CodeBlockView.backgroundColor` and `CodeBlockView.foregroundColor` are replaced by `CodeBlockView.theme`.
- `AIMarkdownBody.codeBackgroundColor`/`codeForegroundColor` are replaced by `codeBlockTheme`.
- `StreamingMessageView.codeBackgroundColor`/`codeForegroundColor` are replaced by `codeBlockTheme`.
- `AITypingIndicatorView.dotSize` is now nullable; unset, it comes from the theme.
- `AITypingIndicatorView.dotCount` and `AnimatedDots` are removed; the dots are core's `StreamTypingIndicatorDots`.
- `ChatComposerFactory` and `ChatComposer.factory` are removed: register the composer's slots with `streamAIComponentBuilders` (`composerLeading`, `composerTrailing`, `composerInput`, `composerInputTrailing`, `composerAttachmentSheet`), and leave a slot out with `ChatComposer.hidden`. A `StreamComponentFactory` replaces its parent's builders rather than adding to them, so a per-composer override means a nested factory with all the builders that subtree needs.
- `ComposerThemeData.fillColor` and `SuggestionsThemeData.backgroundColor` default to transparent, so the composer's pill, "+" button and camera tile, and the suggestion chips, are outlined rather than filled.
- `ComposerThemeData.sendButtonColor` no longer colors the idle microphone, which is a ghost button in `iconColor`, or the disabled send button, which takes the Stream theme's disabled colors.
- `ComposerThemeData.fillColor` no longer fills a sheet photo while it loads; `attachmentPlaceholderColor` does.
- `ComposerThemeData.borderColor`, `attachmentPlaceholderColor` and `attachmentPlaceholderForegroundColor` no longer style an attachment thumbnail's remove badge, which is core's `StreamRemoveControl`.
- `StreamingMessageView` types only while `expectMoreText` is `true`, and in the update that turns it
  `false`; given only `text`, it shows each new text in full. A view created while it is `true` types
  its first `text` from the first character instead of showing it at once. Pass
  `expectMoreText: isGenerating` while a reply streams.
- `USpecKind` has four new values; an exhaustive `switch` on it, such as one in an `AITranslations.chartSemanticsLabel` implementation, needs a case for each.

✅ Added

- The package re-exports what its API uses from `stream_core_flutter` (Stream's design system):
  `StreamTheme` and its tokens (`StreamColorScheme`, `StreamTextTheme`, `StreamSpacing`,
  `StreamRadius`, `StreamIcons`, `StreamColors`, and `context.streamColorScheme` and the like) and
  the component factory (`StreamComponentFactory`, `StreamComponentBuilders`, `StreamComponentBuilder`,
  `StreamComponentBuilderExtension`). Core's widgets come from `stream_core_flutter` itself.
- `ChatComposer.hidden` — returned from the `composerLeading` or `composerTrailing` builder, leaves
  that slot out, gap and all.
- `ComposerAttachmentButton` — the "+" button a `ChatComposer` leads with by default.
- `composerInputTrailing` in `streamAIComponentBuilders`, with `ChatComposerInputTrailingProps` —
  replaces the control at the input's right edge, shown while the field is empty or dictation runs.
- `ChatComposerSlotProps.openAttachmentSheet` — a custom composer slot, such as `composerLeading`,
  calls it to open the attachment sheet the "+" button opens.
- `ComposerAttachmentSheet.show` — opens the attachment sheet from any slot's props.
- `ComposerAttachmentSheet.scrollController` and `ChatComposerAttachmentSheetProps.scrollController`
  — the sheet's scroll controller. A custom sheet passes it to its scrollable so the sheet scrolls
  with its drag.
- Generative UI: `AIConversationView.ui` takes an `AIUIHost` that shows a reply's `AIMessage.uiDocument`
  with app-supplied renderers and components, and `AIToolDefinition.isReadOnly` marks the tools it may
  run on its own.
- `AITranslations.playMedia` and `pauseMedia` — the labels of the buttons that play and pause a video or
  an audio clip in generated UI.
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
  `onTypewriterStateChanged` can't tell apart from a pause in the stream.
- `TypingIndicatorThemeData`, `TypingIndicatorTheme` and `AITheme.typingIndicatorTheme` — theme the
  typing indicator's caption style and the dots' color, size and spacing.
- `AITypingIndicatorView.dotSpacing`.
- `AITypingIndicatorView` is a polite live region labelled with its `text`, so a screen reader
  announces each new state; the dots are hidden from assistive technology.
- Reduced motion (`MediaQueryData.disableAnimations`): `AITypingIndicatorView` draws static dots, and `StreamingMessageView` shows each new text in full instead of typing it out,
  finishing any reveal in progress.
- `AIMessagePart` — one step an AI agent took while replying, decoded from an `ai_*` attachment.
  `AIMessagePart.parseAll` turns a message's `AIMessagePartAttachment`s (`type` + payload) into
  parts, skipping other attachments, and decoding is lenient. `AIMessagePartKind` is the step's
  kind, a `String` extension type and an open set: a kind this package doesn't know keeps its raw
  value and reports `false` from `isKnown`.
- `AIReasoningPart` — the typed view of an `ai_reasoning` step, with `AIReasoningStatus`, a `String`
  extension type and an open set with `values` and `isKnown`.
- `AIToolCallPart` — the typed view of an `ai_tool_call` step, with `AIToolCallStatus` and
  `AIToolExecutor` (server or client), both `String` extension types and open sets with `values` and
  `isKnown`.
- `AIToolApproval` — what a tool call asks before it runs, with `AIToolApprovalDecision`, a `String`
  extension type and an open set with `values` and `isKnown`.
- `AIMessagePartsView` — shows a reply's steps in order, keyed by id, filling its width.
  `AIMessagePartWidgetBuilder` builds parts your own way.
- `AIUnsupportedPartView` — the placeholder for a step this app version can't show.
- `AITranslations.unsupportedMessagePart` — that placeholder's text.
- `StreamingReasoningView` — a collapsible "Thinking… 7s / Thought for 12s" panel for the model's
  reasoning, revealing it smoothly as it streams in. `StreamingReasoningView.part` builds one from
  an `AIReasoningPart`, and `AIMessagePartsView` shows reasoning steps with it. Themed through
  `ReasoningThemeData` (`AITheme.reasoningTheme`), narrowed to a subtree with `ReasoningTheme`, and
  translated through the new `AITranslations` members `reasoningThinking`, `reasoningThinkingFor`,
  `reasoningTitle`, `reasoningThoughtFor`, `reasoningShowHint` and `reasoningHideHint`.
  `DefaultAITranslations.reasoningDuration` spells the durations.
- `AIToolCallView` — a one-line row for a tool-call step: a status icon that follows the call's
  status (a shimmering hand while it waits for approval, a cross once declined), the title, a detail
  line (the summary, or the status in words) and the duration once the call has finished, declined
  included. Screen readers hear it as one node, announced as a live call finishes or starts
  waiting. `AIMessagePartsView` shows tool calls with it.
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
- `AIClientIdentity.installId()` — an id for this install, created on first use and kept across
  launches. It isn't backed up on Android, iOS or macOS, so a restored device gets its own.
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
  `onDeliveryError` (an `AIClientToolDeliveryErrorCallback`). A plain `AIClientTool` whose schema
  requires arguments isn't run when its call arrives without them: the call fails with "This call's
  arguments didn't reach the device".
  Also `handle` / `handleCalls`, `registrations`, `toolNames`, `retryUndelivered`, `close`,
  `whenIdle`, `isClosed`, `hasPendingWork` and `hasUndelivered`.
- `AIToolRegistry.toolNamed` — the tool registered under a name, or `null`.
- `ChartView` draws a legend for a pie, and for a line, area, bar, scatter or bubble chart with two
  or more series (a histogram or heatmap gets none), themed via the new `ChartThemeData.showLegend`,
  `legendPosition` (a `ChartLegendPosition`) and `legendTextStyle`. A long legend is cut off with a
  "+N more" entry.
- `ChartThemeData.showPiePercentages` and `piePercentageThreshold` — pie slices show their share of
  the whole, from 8% up by default.
- `ChartSemantics.sliceLabels` — the names of the slices a pie draws.
- `ChartSemantics.fromSpec`'s `unnamedSlice:` — names a pie slice the chart data didn't name, given
  its position.
- `ChartView.legendKey` — the key of a chart's legend, for finding it in widget tests.
- `AITranslations.unnamedChartSlice` and `chartLegendMore` — the legend's names for an unnamed slice
  and for the entries left out.
- `ChartView` draws horizontal, stacked, radar, radial, single stacked bar and donut/semicircle pie
  charts, with smooth and stepped lines (`USpecKind`, `USpec.barLayout`/`curve`/`donut`/`pieShape`,
  `ChartThemeData.donutHoleRatio`/`radialTrackColor`, `kMaxDonutHoleRatio`), and `USpec` gains `copyWith` and `toString`.
- `AILocalModel` — an interface over an on-device model that streams a fallback reply when the person is offline or the agent hit its usage limit. Each event is the whole answer so far, which is what `StreamingMessageView.text` takes, and cancelling the subscription stops the model.
- `AIConversationTurn` and `AIConversationRole` — one turn of the conversation handed to an `AILocalModel`. `AIConversationTurn.fitToBudget` trims the history to a small context, keeping the newest unbroken run of turns and always the question; `estimateTokens` and `tokensPerTurn` set what a turn costs.
- `AILocalModelException` and `AILocalModelErrorReason` (`unavailable`, `invalidConversation`, `contextExceeded`, `failed`) — the error an `AILocalModel.reply` stream emits when the model can't answer.
- `streamAIComponentBuilders` — registers your own components in place of the ones the package
  builds inside its own widgets (code blocks, charts, agent steps, the approval and sign-in cards, a
  conversation's messages, reply actions and the composer's slots) with `stream_core_flutter`'s
  `StreamComponentFactory`, next to Stream Chat's. `context.aiComponentBuilder<Props>()` reads one.
- `AICodeBlockProps`, `AIChartProps`, `AIReasoningProps`, `AIToolCallProps`, `AIToolApprovalProps` and `AIUnsupportedPartProps` — the props each builder gets.
- `AIReplyActionsView` — the buttons under a finished reply: while it has text, copy, which confirms
  with a check and "Copied!" for a moment, and share, which opens the platform share sheet (or an
  email draft on Linux and in browsers without the Web Share API), then regenerate and 👍 / 👎 when
  the app handles them. Tapping the
  current rating takes it back, and the selected rating is reported to screen readers.
- `AIReplyActions` — what `AIReplyActionsView` offers besides copying and sharing: the `rating`, and
  the `onRegenerate` and `onRate` callbacks, each of whose buttons shows only when it is set. Set
  `onShare` to share the reply in place of the share sheet.
- `AIMessageRating` — how the person rated a reply, `positive` or `negative`.
- `AIReplyShareCallback` — shares a reply's text in place of the share sheet, given the share
  button's rectangle to anchor a popover to.
- `ReplyActionsThemeData` and `ReplyActionsTheme`, and `AITheme.replyActionsTheme`, for the buttons'
  icon color, selected icon color and icon size.
- `AITranslations.copyReply`, `replyCopied`, `shareReply`, `regenerateReply`, `rateReplyPositive`
  and `rateReplyNegative` — the buttons' tooltips and labels.
- `AIConversationView` — an AI conversation laid out in turns. A question the person sends scrolls
  to the top and its reply types out below it without the list moving; a conversation opens at its
  end, `loadOlderMessages` loads older messages at its start, without moving what is on screen, when
  its spinner comes into view and again each time the first turn changes while it stays there, and a
  button, shown once the latest is out of view, scrolls back to it. `isThinking` shows the agent
  thinking, and the reply's first reasoning step carries on its count; one that arrives done opens
  for a moment, then folds before the answer types out. `footer` sits under the latest
  turn, or under the empty content while there are no messages, such as for an error with a way to
  retry. A bottom `padding` the size of a composer floated
  over the list keeps the latest message and the scroll-to-latest button above it, and a list
  showing its end keeps showing it when that padding changes. The view caches its rows, so a builder reads state
  that changes, such as a reply's rating, through a `Listenable`, and is created once.
- `AIMessage` — the message type `AIConversationView` shows: mix it into your own, with `id`,
  `role` (an `AIMessageRole`), `text`, `isGenerating`, `parts`, `attachments`, `rating` (how the
  backend has the reply rated) and `reasoningText`.
  `AIMessageRole` is a `String` extension type and an open set, with `values` and `isKnown`.
- `AIPendingMessage` — a message the person sent, shown at once until its copy arrives.
- `AIMessageAttachment` — an image or file a message carries, or a kind of your own with its raw
  fields in `extraData`, which compares by value. `AIMessageAttachmentKind` is a `String`
  extension type and an open set, with `values` and `isKnown`.
- `AIUserMessageView`, `AIAssistantMessageView` and `AIThinkingView` — a conversation's rows and its
  "Thinking… 4s".
- `AIMessageAttachmentView` — an image as a thumbnail and anything else as a file card;
  the `messageAttachment` builder shows kinds of your own. A file card with a URL opens it when
  tapped, in the browser for a web link and through the platform for any other URL, with a notice when
  nothing opens it, unless `AIConversationView.onAttachmentTap` or `onTap` is set.
- The `userMessage`, `assistantMessage`, `replyActions` (empty by default unless the list shows an
  `AIConversation`) and `messageAttachment` builders, with `AIUserMessageProps`,
  `AIAssistantMessageProps`, `AIReplyActionsProps` and `AIMessageAttachmentProps`. In a list that
  shows an `AIConversation`, `AIUserMessageProps.onEdit` edits the person's latest message, and
  `AIReplyActionsProps.actions` holds the conversation's rating and regenerate actions, which an
  `AIReplyActionsView` shows by default. Actions show under a finished reply that has only
  attachments too.
- `AIReasoningProps.text` and `duration` — a step's full reasoning, and the duration the
  conversation measured for its first step.
- `ConversationThemeData` and `ConversationTheme`, and `AITheme.conversationTheme`, for the bubbles,
  attachments and scroll-to-latest button.
- `AITranslations.copyMessage`, `editMessage`, `editingMessage`, `cancelEditing`, `agentError`,
  `scrollToLatest`, `attachmentImage`, `attachmentFile`, `attachmentDetails`, `fileSize`,
  `openAttachment` and `cannotOpenAttachment` — the conversation's strings.
- `AIConversation` — the state behind an AI conversation, and what the person does in it: its
  messages, the message on its way, where the latest exchange is (`AIConversationStatus`), why it
  failed, what the agent says it is doing (`AIAgentActivity`, `AIAgentActivityState`) and the
  ratings. It sends, stops, regenerates, edits, retries and rates through an
  `AIConversationTransport`, which tells it what the conversation holds through an
  `AIConversationFeed` until the conversation calls its `disconnect`, and gets each
  `AIConversationRequest` (`AIConversationRequestKind`). A reply that doesn't start in time, or an
  agent that says it couldn't answer, shows as an `AIAgentError`; a transport ends a request without
  an error with an `AIConversationCancelledException`. `AIConversationActions` chooses what its
  views offer. `AIConversationView.conversation` and `ChatComposer.conversation` show it and follow
  it.
- `ChatComposerController.isEditing` and `cancelEditing` — while the person edits a message they
  sent, the composer says so above the text field, with a button that cancels it.
  `requestFocus` focuses the field of the composer that shows the controller, and a composer shown
  while the person is editing focuses it as it appears.
- `AIVoiceGlowView` and `AIVoiceWaveView` — a globe of drifting color and a waveform line that show
  what a voice agent is doing, drawn with fragment shaders. They ease from one state into the next,
  ripple where they are tapped and barely move with reduced motion on.
- `AIVoiceAgentState` — what the agent is doing: `idle`, `connecting`, `listening`, `thinking` or
  `speaking`.
- `colors` (one to five, the Stream theme's `accentPrimary` by default), `expressivity` (0 to 2) and
  `audioLevel` (0 to 1, a live voice level such as a call participant's) on both views.
- `AITranslations.voiceAgent`, `voiceIdle`, `voiceConnecting`, `voiceListening`, `voiceThinking`
  and `voiceSpeaking` — what screen readers hear: the view, and the state as its value.
- Tool sign-ins: a tool call can wait for the person to sign in at a provider, such as "Connect
  Linear", with status `AIToolCallStatus.awaitingAuthorization` and an `AIToolCallPart.authorization`
  (`AIToolAuthorization`: the provider, the title and message, the sign-in page, its handoff token,
  expiry and how it ended). `AIToolAuthorization.launchUrl` is the page to open, with the handoff
  token in its fragment; only an `https` page is read, or an `http` one on a loopback host for a
  router run locally, since a cleartext page elsewhere would expose the token.
  `AIToolCallPart.isAwaitingAuthorization` and `AIClientIdentity.canAuthorize` say whether a call
  waits for this person, and a declined sign-in makes the call `isDeclined`.
- `AIToolAuthorizer` — set as `AIToolApprover.authorizer`, it is how the person signs in: `connect`
  (an `AIToolAuthorizationConnector`) gets the call and the sign-in page, which your app opens in a
  browser, and completes with whether the person connected; `decline` (an
  `AIToolAuthorizationDecliner`) sends their "not now". The package doesn't open the sign-in page
  itself. The approver keeps where each sign-in is (`AIToolAuthorizationState`): one
  page at a time; back connected, it reads connecting for a while as the step changes;
  a sign-in issued again on the same step starts over; past `expiresAt` it reads `isExpired` and
  `canConnect` turns false.
- `AIToolAuthorizationView` and `AIToolAuthorizationCard` — ask the person to sign in, with Connect
  and Not now, styled by the approval card's theme. Once the sign-in expires, the card says so and
  stops offering Connect. `AIMessagePartsView` shows the view under each
  call waiting for this person's sign-in when its approver has an authorizer.
- The `toolAuthorization` builder and `AIToolAuthorizationProps` — replace the sign-in card.
- `AIToolCallView` shows a call waiting for a sign-in with a key and "Waiting for sign-in". Given the
  viewer's `userId`, which `AIMessagePartsView` passes when its approver offers the sign-in, it tells the person the call
  waits for "Waiting for you to sign in".
- `AITranslations.toolCallAwaitingAuthorization`, `toolCallAwaitingYourAuthorization`,
  `toolAuthorizationConnect`, `toolAuthorizationConnecting`, `toolAuthorizationDecline`,
  `toolAuthorizationNotOpened` and `toolAuthorizationExpired`.
- The `math` builder of `streamAIComponentBuilders` and `AIMathProps` — render LaTeX in every `AIMarkdownBody` given no
  `mathBuilder` of its own, such as the replies in an `AIConversationView`.
- A notice when the microphone permission is denied and the person taps the mic: by default a snackbar
  that stays until dismissed, with a "Settings" action on Android, iOS and macOS, and that in a
  `ChatComposer` floats above the composer rather than over it, or `SpeechToTextConfig.onPermissionDenied`
  instead.
- `SpeechToTextController.isPermissionDenied` — whether the person denied the microphone.
- A "Photos not added" alert when a photo picked in the attachment sheet can't be loaded, such as a
  photo stored only online with no connection, or the photo library picker fails.
- `AITranslations.microphonePermissionDenied`, `openSettings`, `photosNotAddedTitle` and
  `photosNotAddedMessage`.

🔄 Changed

- `SpeechToTextButton` stays tappable after the person denies the microphone, rather than rendering disabled,
  so tapping it can show the permission notice.
- A pie starts its first slice at the top and is solid, filling its plot. It used to start at the right
  and leave a hole in the middle that grew with the chart's height; set `USpec.donut` for a ring.
  A Chart.js `doughnut` keeps its hole. A `radar` chart draws as a radar rather than as bars.
- The recommended way to provide translations is now to implement `AITranslations` rather than
  extend `DefaultAITranslations`, so a string added in a later version is a compile error instead
  of English silently showing up in your app. Existing subclasses of `DefaultAITranslations` keep
  working.
- A pie, and a line, area, bar, scatter or bubble chart with two or more series, shows a legend by
  default. Set `ChartThemeData.showLegend` to `false` to hide it.
- A line breaks at a category its series has no value for (a Chart.js `null`), instead of joining
  the points on either side.
- `AITypingIndicatorView`'s caption defaults to the Stream theme's `bodyDefault` in `textSecondary`
  instead of inheriting `DefaultTextStyle`.
- Pie slices are labelled with their percentage; when the chart has a legend the name moves there.
- A pie's screen-reader summary lists its slice names.
- `ChartSemantics.isEmpty` is `true` for a pie with no positive slice.
- A chart's screen-reader summary names at most eight series or slices, then says "and N more".
- When `text` is replaced by something other than a continuation, `StreamingMessageView` and
  `TypewriterController.updateText` keep the part it shares with what is on screen and type only the
  rest, instead of starting over from the first character.
- The default typing speed of `StreamingMessageView` and `TypewriterController` is 5 ms per
  character instead of 10 ms.

🐞 Fixed

- `SpeechToTextController.start` threw an unhandled error on an Android 12 or later device with no
  speech recognizer. It reports the error to `FlutterError` and returns `false`, and the mic is
  disabled.
- On Android 13, `ComposerAttachmentSheet` showed "Allow photo access" even after photos were
  allowed, unless the app also declared `READ_MEDIA_VIDEO`. It now asks for photos only, so an app
  no longer needs `READ_MEDIA_VIDEO`, which Google Play asks you to justify.
- `AITypingIndicatorView`'s dots were black by default, which made them invisible
  in dark mode. They now default to the themed caption color.
- `StreamingMessageView.onTypewriterStateChanged` is no longer called during a build, so the host can
  call `setState` from it. A state that changes mid-frame is reported after the frame.
- A `NaN` or infinite value no longer breaks a chart: the parsers drop it, and a pie leaves such
  slices out.
- A pie with negative values draws and counts only its positive slices.
- The README's `SpeechToTextButton` snippet passes its options through `SpeechToTextConfig`; the
  0.1.0 snippet passed them to the button, which doesn't compile.

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
