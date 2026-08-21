## 0.0.1

First release of `stream_chat_flutter_ai`.

> **On the 🔄 Changed entries below:** they describe how the package differs from the unreleased code
> it grew out of, which lived on a branch in the
> [`stream-chat-flutter`](https://github.com/GetStream/stream-chat-flutter) repo. Nothing here was
> ever published, so there is no earlier version to upgrade from — read them as design notes rather
> than migration steps.

🔄 Changed

- `stream_chat_flutter_ai` no longer depends on `stream_chat_flutter` (or any `stream_chat*` package). The package is fully standalone and can be used in any Flutter app, independent of Stream Chat. Wiring it up to a Stream Chat channel is now shown in the docs as an optional integration, not a dependency.
- Renamed the composer family to drop the `Stream`/`StreamAI` branding, since the package has no Stream dependency: `StreamAIComposer` → `ChatComposer`, `StreamAIComposerFactory` → `ChatComposerFactory`, `AIComposerController` → `ChatComposerController`, `AIComposerSendCallback` → `ChatComposerSendCallback`, `StreamAISuggestionsView` → `AISuggestionsView`, `StreamTypewriterBuilder` → `TypewriterBuilder`. `StreamingMessageView` is unchanged (descriptive name, not branding).
- Redesigned `ChatComposer` to match spacing and sizing in the reference Android/iOS AI samples: 8dp gaps around the leading/input/trailing row, and a single 40x40 circular trailing control that morphs between mic, send, and stop instead of stacking a bare-icon mic button underneath a differently-styled send button.
- `ChatComposerSendCallback` (the type of `ChatComposer.onSendPressed`) now takes a third `List<XFile> attachments` parameter — **breaking change** for existing callers.
- `ChatComposerFactory.buildLeading`/`buildTrailing` now return `Widget?` instead of `Widget`, and default to the "+" attachment button / `null` respectively — **breaking change** for factory subclasses overriding either method. Returning `null` (rather than an empty `SizedBox.shrink()`) is also how a slot now opts out of the composer's 8px gap; passing an empty widget no longer works for that, since two separately-constructed `SizedBox.shrink()`s aren't guaranteed `identical`/`==` and using one as an "empty" sentinel silently doubled the composer's trailing-edge margin.
- `ChatComposerFactory.buildLeading` now defaults to an outlined circular "+" button that opens `ComposerAttachmentSheet` (see below), instead of an empty `SizedBox.shrink()`.
- Removed the always-visible row of `ChatOption` chips that used to render above the input whenever `ChatComposerController.chatOptions` was non-empty — **breaking change in behavior** (no API removed, but the row no longer renders). Confirmed against `stream-chat-swift-ai`: chat options aren't shown as a standalone chip row there either — they're listed inside the composer's attachment sheet (`ComposerPickerView` in `ComposerView.swift`), alongside the photo picker. `ChatComposer`'s inline selected-option chip (shown inside the input box once an option is chosen) is unaffected and still matches iOS.
- Fixed vertical alignment of the leading/trailing circles against the input pill: both Rows now use `CrossAxisAlignment.center` instead of `.end`. The pill is naturally taller than the fixed-size 40x40 circles, so bottom-aligning them dumped 100% of that extra height above the circles as a lopsided gap — visually different from the reference Android layout, where the "+" and mic sit evenly inset within the pill's height. Centering fixes this without needing to change either the pill's or the circles' size.
- The input pill and the default "+" attachment button now use the same, lighter `colorScheme.surfaceContainerHigh` fill and `outlineVariant` border (previously the pill used the darker/more-tinted `surfaceContainerHighest` while the button used plain `surface`, so the two visibly didn't match). The text field's hint text now uses `onSurfaceVariant` at 60% opacity instead of the theme's default (near-black) hint color, matching the muted placeholder look of the reference Android/iOS composers.
- The inline selected-option chip (shown inside the input box once a `ChatOption` is chosen) is now a proper pill badge — `colorScheme.primaryContainer` background, larger icon/text/dismiss-button — instead of plain icon+text directly on the input's own background.
- The attachment cap moved from `ChatComposerFactory.maxAttachments` (a `static const`, now removed) to `ChatComposerController.maxAttachments`, a constructor parameter still defaulting to 3 — **breaking change** for anything reading the old constant. It sits on the controller because that is where it can actually be enforced: the controller owns the attachment list, so every picker funnels through it. `addAttachments` also returns the files it accepted rather than `void`, so a caller can tell what the cap and the duplicate check dropped.
- `SpeechToTextButton`'s `localeId`, `listenFor`, `pauseFor`, `onError` and `onStatus` parameters are replaced by a single `config` of the new `SpeechToTextConfig` — **breaking change** for direct callers. The same object is accepted by `ChatComposer.speechToTextConfig`, which previously had no way at all to configure or observe voice input.
- `SpeechToTextConfig.pauseFor` defaults to `null` (resolved per platform) instead of a flat 3 seconds — see 🐞 Fixed below for why the flat value was wrong on Android.
- While a dictation session is running, the composer's trailing control stays on the mic (in its stop state) instead of morphing to send as soon as recognised words give the field content.

✅ Added

- `AISuggestionsView` — a horizontally-scrolling row of free-text quick-reply chips, independent of `ChatOption`. Mirrors `stream-chat-swift-ai`'s `SuggestionsView`, which the reference iOS sample docks above the composer on the "new chat" landing screen.
- `ChatComposerController` gained attachment support: `attachments`, `addAttachments`, `removeAttachment`, and `hasText` (pure-text check, separate from `hasContent` which also considers attachments). `clear()` now also clears attachments.
- `ChatComposer` renders picked images as a row of removable thumbnails inside the input box, and now depends on `package:image_picker` for attachment picking.
- `ChatComposer.enableSpeechToText` — when `true`, the composer's single trailing control shows a mic while the text field is empty and morphs into send/stop as content changes or the AI starts generating, instead of two separate buttons.
- `ComposerAttachmentSheet` — the combined bottom sheet opened by the composer's default "+" button, mirroring `stream-chat-swift-ai`'s `ComposerPickerView`: a camera tile, a horizontal strip of recent photos (via the new `package:photo_manager` dependency) with tap-to-toggle multi-select, an "All Photos" full-library picker button, and — if `ChatComposerController.chatOptions` is non-empty — the chat-option list below, replacing the removed chip row.
- `ChatOption.description` — an optional subtitle shown under `text` in `ComposerAttachmentSheet`'s option rows (e.g. `"Visualize anything"` under `"Create image"`), matching `stream-chat-swift-ai`'s `ChatOption.description`.
- Initial implementation of `stream_chat_flutter_ai`:
  - `AITypingIndicatorView` — animated dots indicator for AI states (thinking, checking sources, etc.).
  - `AnimatedDots` — standalone animated dots widget.
  - `TypewriterController` / `TypewriterValue` / `TypewriterState` — controller for character-by-character text reveal.
  - `TypewriterBuilder` — `ValueListenableBuilder` wrapper for `TypewriterController`.
  - `StreamingMessageView` — renders markdown with a typewriter animation, used for streaming AI responses.
  - `AIMarkdownBody` — markdown renderer that handles text, fenced code blocks, chart blocks, and LaTeX.
  - `CodeBlockView` — dark-themed code block with copy-to-clipboard button and language label.
  - `ChartView` — renders `USpec` chart data as line, bar, or pie charts via `fl_chart`.
  - `USpec` / `USeries` / `UPoint` / `USpecKind` — chart data model.
  - `USpecParser` — parses JSON code fences in USpec or Chart.js format into `USpec`.
  - `ChatComposer` — AI-aware message composer with a selected-option chip, send/stop toggle, attachment thumbnails, and factory-based slot overrides.
  - `ChatComposerController` — `ChangeNotifier` that manages input text, AI generating state, chat option selection, and pending image attachments.
  - `ChatOption` — data class for the selectable options shown in `ComposerAttachmentSheet`.
  - `ChatComposerFactory` — subclass to override the leading and trailing regions of the composer.
  - `SpeechToTextButton` — microphone button that streams partial speech-to-text results into the composer's text field; hidden while AI is generating or text is non-empty.
- `ChartView` now renders `USpecKind.scatter` as a real scatter plot (via `fl_chart`'s `ScatterChart`) instead of silently falling back to a line chart, plus new `USpecKind.bubble` (scatter with point size driven by `UPoint.size`) and `USpecKind.histogram` (auto-binned into 10 buckets, mirroring `stream-chat-swift-ai`'s `makeBins`) renders. `USpecKind.heatmap` renders as a real grid — one row per series, one column per distinct point, cell color from `UPoint.z` (falling back to `UPoint.y`) on a sequential blue scale, plus a gradient scale bar labelled with the value range. `fl_chart` has no heatmap widget, so the grid is drawn with plain Material widgets by `HeatmapChartView`.
- `USpecParser` recognises five additional chart schemas, matching `stream-chat-swift-ai`'s `parseUSpec` breadth: Plotly (single-spec and figure heatmaps), ECharts, Highcharts, a Vega-Lite subset (mark + encoding), and a flat pie schema (`{type: "pie", data: [{label, value}]}`). Its existing Chart.js adapter now also recognises pie/doughnut, scatter/bubble point objects (`{x, y, r}`), the `radar`/`polarArea` fallback mappings, and `options.scales.y.beginAtZero`.
- `UPoint` gained optional `size` (bubble radius) and `z` (heatmap intensity) fields; `USpec` gained `beginAtZeroY`, applied to the y-axis in `ChartView`.
- `AIMarkdownBody` now also routes ` ```highcharts ` fences to the chart parser.
- `XFile` is re-exported from `package:cross_file` (now a direct dependency), where the type is
  actually defined, rather than from `package:image_picker`, which merely re-exports it.
- **LaTeX support.** `AIMarkdownBody` and `StreamingMessageView` recognise `\(…\)` inline and `\[…\]`
  display math (`MathInlineSyntax` / `MathBlockSyntax`, built on `package:markdown`, now a direct
  dependency). Rendering goes through a new `mathBuilder` callback rather than a bundled math engine:
  every Flutter TeX renderer pulls a non-trivial dependency tree behind it (`flutter_math_fork`, the
  usual pick, brings `flutter_svg` and `provider`), and this package stays standalone — the same
  trade `styleSheet` already makes for text styling. With no `mathBuilder` the TeX source is shown as
  plain text rather than dropped. The example app wires up `flutter_math_fork` to demonstrate it.
  `useDollarDelimitersForMath` additionally accepts `$…$` / `$$…$$`; it is off by default because `$`
  collides with currency in ordinary prose.
- `SpeechToTextController` — the owner of the app's recognition session, and the thing
  `SpeechToTextButton` is now merely a view over. Exposes `isListening`, `isAvailable`, `start`,
  `stop` and `cancel`, so a host can drive or observe dictation without going through the button.
- `SpeechToTextConfig` — locale, timeouts and status/error callbacks for voice input, accepted by
  both `ChatComposer` and `SpeechToTextButton`.
- `ChartView` renders `USpec.title` as a heading above the plot when the spec carries one, matching
  the reference Android/iOS packages. A blank title is treated as absent.
- `ChatComposerController.remainingAttachmentSlots` and `hasAttachmentAt`, which let a picker
  disable itself at the cap and show which images are already attached.
- `HeatmapChartView` and `ComposerActionButton` are exported from the library. Both are public,
  documented types that were only reachable through a `src/` import.

🐞 Fixed

- **`CodeBlockView`'s copy button could crash, and repeated taps cleared the confirmation early.** The
  `setState` after `Clipboard.setData` ran unguarded, so a block disposed during that platform
  round-trip — scrolled out of a list, or a streamed message replaced — hit `setState` on a defunct
  state object. The 2-second revert is also a single restartable `Timer` now instead of a
  `Future.delayed` per tap; two overlapping delays raced, and the first to resolve cleared the check
  mark while the later tap still expected it. The timer is cancelled on dispose.
- **Code blocks now appear as soon as their opening fence arrives, instead of after the closing one.**
  `AIMarkdownBody` used to pre-split the markdown with a regex that required *both* fences, so a code
  block still being streamed showed its raw ` ``` ` markers and unstyled source for as long as it was
  arriving, then snapped into a `CodeBlockView` once complete. Fences are now found by
  `package:markdown`, which — as CommonMark requires — treats an unclosed fence as running to the end
  of the document, so the block is styled and its language labelled from the first line. Dropping that
  pre-split fixed three more things with it:
  - An ordered list interrupted by an indented code fence no longer restarts its numbering at 1. Each
    segment used to be rendered by a separate `MarkdownBody`, and two of those share no parser state.
  - Fences nested inside a list item or blockquote reach `CodeBlockView` (and the chart parser) rather
    than falling through to the default `pre` rendering.
  - `~~~` fences and 4-space-indented code blocks are recognised; the old regex only looked for
    backticks.
- **`StreamingMessageView` could get stuck on stale text.** Replacing the text with anything shorter
  than what was already revealed — a regenerated or edited reply, an error message swapping in for a
  partial one — left the *previous* text on screen indefinitely, because `TypewriterController` only
  swapped its target string and left the char index pointing past the end of it. Text that continues
  what is on screen still types on from where it was; anything else is now revealed from the start.
- **`StreamingMessageView.onTypewriterStateChanged` never fired for an already-complete message.** A
  view built with its full text is revealed immediately and so never transitioned, leaving hosts that
  flip a "generating" flag off on `TypewriterState.idle` stuck in the generating state forever. The
  initial state is now reported once, after the first frame.
- `TypewriterController.stopTyping` reset its char index but not the revealed text, so a following
  `startTyping` jumped from the fully-revealed text back to its first character.
- **`USpecParser` now accepts `type` and `label` as aliases for `kind` and `name`.** Models asked for
  a USpec routinely reach for the Chart.js vocabulary instead, and such a spec used to degrade to a
  raw code block. Relatedly, a `kind`/`series` payload that yields no points is no longer claimed by
  the USpec adapter (it would render an empty chart) and falls through to the adapter that
  understands it, and numeric strings (`"y": "12"`) are accepted as values.
- A Vega-Lite spec whose `encoding` field names don't match its data no longer coerces every missing
  `y` to zero — producing a chart of flat zeroes that read as real data — and falls through instead.
- **Multi-series bar charts dropped data.** The category count was read off the *first* series, so
  any later series' extra points were silently discarded; and a series with no point at a given
  category had a zero-height bar drawn for it rather than no bar. Categories now come from the
  longest series, and absent points are omitted.
- **Scatter and bubble charts mispositioned categorical series.** The fallback x for a non-numeric
  label was the running count of points across *all* series, so each series was pushed to the right
  of the one before it instead of sharing the same categories. They also drew no bottom-axis labels
  at all; category names (or the raw numeric values) are now shown.
- Bubble radii are normalized across the chart instead of clamped as though `UPoint.size` were
  already a pixel value — any data-domain size (a population, a revenue figure) previously pinned
  every bubble to the maximum radius, flattening the encoding.
- A histogram whose values are all identical renders a single bin instead of a blank chart.
- **Charts and heatmaps are legible in a dark theme.** Grid lines, heatmap cell borders and axis
  labels now come from the `ColorScheme` rather than hardcoded translucent black, and the heatmap's
  sequential ramp inverts in a dark theme so higher values stay brighter than the surface instead of
  receding into it.
- **`SpeechToTextButton` no longer asks for the microphone at mount.** `initialize()` ran in
  `initState`, so merely rendering a composer with `enableSpeechToText: true` prompted for microphone
  and speech-recognition access before the user had shown any interest in dictating; it now
  initializes on first tap. When no recognizer is available the button renders *disabled* rather than
  hiding itself — hiding left the composer's trailing slot completely empty, with no mic and no send
  button either.
- Dictation appends to whatever is already in the field instead of replacing it, so using
  `SpeechToTextButton` in a custom slot no longer discards typed text.
- **Dictation cancelled itself as soon as it produced a word, and every mic button after the first
  was inert.** Both came from the recognition session being owned by `SpeechToTextButton`, a widget
  the composer creates and destroys constantly. The first recognised word gave the field content,
  which morphed the trailing control from mic to send, which disposed the button, whose `dispose`
  cancelled the session — roughly 170ms after dictation started working. Separately, `SpeechToText`
  is a process singleton whose `initialize()` returns early once it has succeeded *without*
  re-registering the `onStatus`/`onError` handlers it is given, so only the very first button
  instance in the process ever received status callbacks; every later one rendered a mic that never
  switched to "stop" (reproducible by typing a character and deleting it, which swaps the button
  out and back). The session now lives in `SpeechToTextController.instance`, which initializes once
  and outlives the widgets observing it; the button reads and drives it and no longer cancels on
  dispose; and the composer holds the mic in its stop state for the length of a session so there is
  always a control to end it with. The composer does cancel the session when the composer itself is
  disposed.
- **Speech recognition cut off after ~3 seconds on some Android devices.** `pauseFor` — which the
  package hardcoded to 3 seconds — starts a timer in `speech_to_text` that measures the gap between
  *recognition results*, not silence in the audio. Engines that deliver nothing until the utterance
  ends (a Galaxy A05s takes ~3.3s to produce its first partial) were therefore killed mid-sentence,
  every time. `SpeechToTextConfig.pauseFor` now resolves per platform when left unset: 3 seconds on
  iOS/macOS, where Apple's recognizer streams partials continuously and the gap really does
  approximate silence, and nothing on Android, where the engine's own audio-based endpointing ends
  the utterance and `listenFor` stays the backstop.
- **The attachment cap only applied to one of the three pickers.** `maxAttachments` was passed to
  `pickMultiImage`, so the "All Photos" picker respected it while the recent-photo strip and the
  camera tile let the user add without limit. It is enforced in `ChatComposerController` now — the
  one place every picker goes through — and the sheet's tiles disable themselves once the cap is
  reached rather than accepting taps that do nothing. The "All Photos" picker also asks for only
  the *remaining* slots, falling back to the single-image picker for the last one, since
  `pickMultiImage` rejects a limit below 2.
- **The same photo could be attached twice.** The recent-photo strip and the "All Photos" picker
  don't know about each other, and `addAttachments` appended unconditionally, so picking one image
  through both produced two identical thumbnails. Attachments are now de-duplicated by path.
- **The sheet's checkmarks drifted out of sync with the composer.** They were driven by a map local
  to the sheet's state rather than derived from `ChatComposerController.attachments`, which broke in
  both directions: removing an attachment with the composer thumbnail's ✕ left the sheet still
  showing it as selected, and reopening the sheet forgot about photos that were still attached (no
  checkmark — and tapping one again added a duplicate). Selection is now read from the controller,
  and the sheet rebuilds with it.
- `ChatComposerController.removeAttachment` matches by path instead of by identity. `XFile` doesn't
  override `==`, so a caller holding a freshly-constructed `XFile` for an image it could plainly see
  attached silently failed to remove it.
- `AnimatedDots.spacing` was documented and accepted but ignored — the row was hardcoded to 4.
- Suggestion chips use `TextAlign.start` instead of `TextAlign.left`, so they render correctly in
  right-to-left locales (their width measurement already respected the text direction).
- The circular composer buttons ("+", send/stop/mic, the thumbnail remove and chip dismiss buttons,
  the sheet's camera tile) show an ink ripple when tapped. Their `InkWell` sat *inside* an opaque
  decoration, which painted over the splash and left taps with no feedback. The remove, dismiss and
  camera controls also gained tooltips, which double as their accessible label.
- Fixed doc comments referencing names that don't exist (`AI_STATE_THINKING`,
  `AI_STATE_CHECKING_SOURCES`) or aren't resolvable from their library, which rendered as dead links
  in the generated API docs. `comment_references` is now enabled repo-wide to keep them honest.
- **Stopping dictation early no longer throws the whole transcript away.** Tapping stop within the
  first couple of seconds — before the engine had reported a partial — left the text field empty.
  `speech_to_text` is documented to deliver a final result *because* you stopped it, so it necessarily
  arrives after the fact, and `SpeechToTextController` was detaching its result callback in the same
  breath as flipping `isListening`. Those two lifetimes are now separate: the flag still flips
  immediately (so the button doesn't feel stuck), while the callback stays attached until the final
  result has had its chance to land. Reproduced on a Galaxy A05s, whose engine reports nothing until
  the utterance is over, so that final result was the entire dictation. `cancel()` — including the one
  `ChatComposer` issues on dispose — still discards a pending transcript, and a transcript owed to a
  finished session can no longer land in the next one's field.

🚀 Performance

- **`AIMarkdownBody` no longer re-parses every chart fence on every build.** While streaming, a
  `jsonDecode` plus a full schema walk ran for each chart fence once per typewriter tick — roughly
  every 10ms — including the throw-and-catch for a fence that holds no chart data at all. Those parses
  are memoized on the fence's content (which stops changing as soon as its closing fence arrives),
  failures included.
- **Completed charts and code blocks no longer rebuild and repaint on every typewriter frame.**
  Memoizing the parse still left a new `ChartView` constructed per tick, so a message with several
  charts kept re-laying-out and re-rasterizing work that could not have changed — visible as heavy
  jank while streaming on a low-end device (measured on a Galaxy A05s). The built widget is memoized
  on language + content as well: returning the identical instance lets the framework skip the
  subtree's rebuild, and each entry is wrapped in a `RepaintBoundary` so the raster cache keeps its
  pixels while only the growing trailing text repaints. A fence whose content is still arriving
  misses the cache and rebuilds as before.
- **A streaming fence no longer evicts the finished fences above it from those caches.** Both caches
  are capacity-bound and evicted their oldest *insertion*, while a fence that is still arriving keys a
  brand-new entry on every tick, because its content has grown — so within a few hundred milliseconds
  the cache was full of throwaway partial snapshots and what had been evicted to make room was the
  completed charts and code blocks still on screen. Those then re-parsed and rebuilt from scratch on
  every subsequent tick, which is the opposite of the point. Both now evict the least recently *used*
  entry (a small internal `LruCache`): a partial snapshot is never looked up twice, so it ages out on
  its own, while anything still being rendered stays resident. `ComposerAttachmentSheet`'s
  asset-id → path cache, which made the same assumption, uses it too.
- `AIMarkdownBody` renders the whole message with a single `MarkdownBody` rather than a `Column` of
  one per text segment, and its element builders and syntax lists are built once instead of per frame.
- **Attachment thumbnails are read and decoded once.** The `Future` was created inside `build`, and
  the composer rebuilds on every keystroke, so each character re-read every attachment off disk in
  full and re-decoded it. They now also decode at thumbnail resolution rather than full camera
  resolution.
- Recent-photo tiles in `ComposerAttachmentSheet` likewise request their thumbnail once, instead of
  re-requesting every visible one each time a photo is selected.
- `SpeechToTextButton`'s pulse animation only runs while listening; it previously ticked every frame
  for the button's whole lifetime. It also no longer rebuilds on unrelated controller changes.
- `AITypingIndicatorView`'s dots build their `CurvedAnimation` and tweens once instead of allocating
  a fresh (and undisposed) set on every frame of the animation.
- Suggestion chips dispose the `TextPainter` used to measure their label.
- Heatmap column collection is linear rather than quadratic in the number of cells.
