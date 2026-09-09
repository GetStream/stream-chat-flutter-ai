# `stream_chat_flutter_ai` parity roadmap

This document tracks feature parity between `stream_chat_flutter_ai` and
[`stream-chat-swift-ai`](https://github.com/GetStream/stream-chat-swift-ai), Stream's equivalent
standalone AI-chat UI package for iOS/Swift.

> **Note:** Parity is measured against the Swift package's actual source (`Sources/`), not its
> README — the README undersells the package and omits two subsystems (chart rendering and MCP
> tool-calling) entirely.

Status legend: ⬜ Not started · 🚧 In progress · ✅ Done · 🅾️ Optional / won't-do

| # | Feature | Phase | Effort | Status |
|---|---|---|---|---|
| 1.1 | Standalone suggested-prompt chips (`SuggestionsView`) | 1 | S | ✅ |
| 1.2 | Chart schema & kind breadth (`USpec`) | 1 | M | ✅ |
| 2.1 | Code syntax highlighting (`CodeBlockView`) | 2 | M | ✅ |
| 2.2 | Composer factory slot coverage | 2 | M | ⬜ |
| 2.3 | Localization scaffolding | 2 | M | ⬜ |
| 2.4 | Chart theming & accessibility | 2 | M | ⬜ |
| 3.1 | MCP client-tool / agentic tool-calling | 3 | L | ⬜ |
| 3.2 | Generic sidebar / split-view (`SidebarView`) | 3 | S–M | 🅾️ |

---

## Phase 1 — Quick parity wins (low effort, high value)

### 1.1 Standalone suggested-prompt chips (`SuggestionsView`) ✅

**Gap:** Swift ships `SuggestionsView` — a horizontally-scrolling row of free-text quick-reply
chips, independent of `ChatOption`. Flutter had no equivalent; its only suggestion surface was
`ChatOption` rows inside `ComposerAttachmentSheet`. The reference Flutter sample
(`chat-ai-samples/flutter`) had already hand-rolled an equivalent inline `_LandingView` widget —
this work extracted that into the package and rewired the sample to consume it, matching how the
iOS sample docks `SuggestionsView` above its composer (`ContentView.swift`'s
`VStack { Spacer(); SuggestionsView(...) }`).

**Shipped API:** `lib/src/composer/suggestions_view.dart`:

```dart
AISuggestionsView({
  required List<String> suggestions,
  required ValueChanged<String> onSuggestionSelected,
  double itemMaxWidth = 160,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
})
```

Theme-driven (`Theme.of(context).colorScheme`), consistent with the composer pill tokens
(`surfaceContainerHigh`/`outlineVariant`).

- **Files:** new `suggestions_view.dart`; exported from `lib/stream_chat_flutter_ai.dart`; consumed
  by `chat-ai-samples/flutter`'s `_LandingView` (`chat_ai_assistant_home_page.dart`).
- **Note:** naming — the package is fully standalone (no `stream_chat`/`stream_chat_flutter`
  dependency), so its public types drop the `Stream`/`StreamAI` prefix entirely. The composer
  family follows the Android reference SDK's generic naming (`ChatComposer`,
  `ChatComposerFactory`, `ChatComposerController`, `ChatComposerSendCallback`); AI-specific widgets
  keep a capital `AI` token, consistently, matching Swift's `AITypingIndicator` (`AIMarkdownBody`,
  `AITypingIndicatorView`, `AISuggestionsView`).
- **Acceptance:** tapping a chip fires the callback with its text; row scrolls; long text
  truncates to 2 lines; widget test covering render + tap — see `suggestions_view_test.dart`.
- **Effort:** S (½ day).

### 1.2 Chart schema & kind breadth (`USpec`) ✅

**Gap:** Swift's `parseUSpec` auto-detects **7 schemas** (Chart.js, Plotly single + full figure,
ECharts, Highcharts, Vega-Lite, a legacy custom schema, flat pie) and renders **8 kinds** (line,
bar, area, scatter, bubble, pie, heatmap, histogram). Flutter's `USpecParser.tryParse`
(`lib/src/chart/uspec.dart`) recognises only **2 schemas** (native USpec + Chart.js) and **5
kinds**, and `ChartView` (`lib/src/chart/chart_view.dart`) silently renders **scatter as a line
chart** (the `switch` default case, `_ => _buildLineChart()`).

**Proposed work** (incremental, land independently):

- [x] 1.2.1 Implement a real scatter render in `ChartView` (fl_chart `ScatterChart`) instead of the
      line fallback.
- [x] 1.2.2 Add a Vega-Lite adapter to `USpecParser` (mark + encoding subset) — the most common
      LLM output after Chart.js.
- [x] 1.2.3 Add ECharts + Highcharts adapters.
- [x] 1.2.4 Add Plotly adapter (single-spec + first-trace-of-figure).
- [x] 1.2.5 Add `USpecKind.histogram` (auto-bin into ~10 buckets, mirroring Swift's `makeBins`) and
      `USpecKind.bubble` (point size from a `size`/`z` field — requires an optional `size` field
      on `UPoint`).
- [x] 1.2.6 Add heatmap. `fl_chart` has no native heatmap, so `HeatmapChartView`
      (`lib/src/chart/heatmap_chart_view.dart`) draws the grid with plain Material widgets: one row
      per series (labelled with `USeries.name`), one column per distinct `UPoint.x`, cell color from
      `UPoint.z ?? UPoint.y` on a sequential blue scale, plus a gradient scale bar labelled with the
      value range. Axis gutters match the `fl_chart` kinds' reserved sizes so a heatmap lines up
      with a bar/line chart in the same message.

Fence-language routing lives in `lib/src/ai_markdown_body.dart` — `kDefaultChartLanguages`
(`json, chart, chartjs, echarts, highcharts, plotly, vega`), consulted by the `pre` element builder
and overridable per widget via `AIMarkdownBody.chartLanguages`. Extend the default set as new
schemas land; hosts that need a narrower one (keeping plain ```json fences readable, say) pass their
own.

- **Acceptance:** a unit test per new schema, feeding a representative JSON payload and asserting
  the resulting `USpec.kind`/series; scatter/bubble/histogram render visibly distinct from a plain
  line chart.
- **Effort:** M overall — schemas are independent, landed 1.2.1–1.2.2 first, the rest as follow-ups.

---

## Phase 2 — Core parity (medium effort)

### 2.1 Code syntax highlighting (`CodeBlockView`) ✅

**Gap:** Flutter's `CodeBlockView` showed plain monospace `SelectableText` with a decorative
language label — no token coloring.

**Correction to the premise, found while doing the work.** This item was written believing Swift had
"tokenized, per-language colored highlighting" to reach parity with. It doesn't.
`Sources/StreamChatAI/CodeSyntaxHighlighter.swift` is, in full:

```swift
func highlightCode(_ content: String, language: String?) -> Text {
    guard language != nil else { return Text(content) }
    return self.syntaxHighlighter.highlight(content)
}
```

and [`Splash`](https://github.com/JohnSundell/Splash) highlights exactly one language: **Swift**. So
iOS applies the *Swift* grammar to every labelled fence regardless of its label — a ```python block
gets Swift keyword coloring — and renders unlabelled fences plain (note the inverted `guard`). There
was no per-language target here; Flutter now covers 31 languages properly. Recorded under
[Where Flutter already leads](#where-flutter-already-leads).

**Shipped:** `re_highlight` (MIT, highlight.js grammars ported to Dart; no native code, no assets,
no async init) added under `melos.command.bootstrap` in the root `pubspec.yaml`.
`lib/src/highlight/code_languages.dart` registers a curated 31-grammar set — `bash c cpp csharp css
dart diff dockerfile go graphql ini java javascript json kotlin lua markdown objectivec php
plaintext python r ruby rust scala shell sql swift typescript xml yaml` — plus the aliases each
grammar declares for itself (`js`, `ts`, `py`, `sh`, `yml`, `c++`, `cs`, `html`, …).

**On the curated set** (the decision most likely to be "simplified" later): every grammar is a
top-level `final` holding a tree of `Mode` constructor calls, and `builtinAllLanguages` references
all 194 of them, so naming that map makes 2.7 MB of Dart source reachable with nothing to
tree-shake it back out of a host app. The curated set is ~870 KB — of which `swift.dart` alone is
388 KB, kept because it is the one language the iOS package highlights at all. Blocks over 20,000
characters are left unhighlighted: a fence that is still streaming re-highlights on every frame it
grows by, which makes the total cost quadratic in the block's length.

**Theming.** `CodeBlockView.theme` takes a `Map<String, TextStyle>` keyed by highlight.js scope name
— pure Flutter types, so no `re_highlight` type reaches the public API — defaulting to the exported
`kDefaultCodeBlockTheme` (`vs2015Theme`, whose `root` is `#1E1E1E` on `#DCDCDC`, i.e. exactly the
background the block already had). The `root` entry now supplies the background and, at 60% opacity,
the header's label and copy-button color, which is what closes the "label color should come from the
theme's token set" point below. Kept dark regardless of the ambient `Theme`, deliberately.

`AIMarkdownBody.codeBlockTheme` and `StreamingMessageView.codeBlockTheme` forward it — without that
the parameter would be unreachable for the main use case, since fences are constructed by
`ai_markdown_body.dart`'s private `_CodeFenceBuilder`. The fence widget cache keys on the theme's
*identity*, so a host rebuilding the map every frame costs memoization (not correctness); pass a
`const` or hoisted map.

**Folded in:**

- ~~**`fontFamily: 'monospace'` doesn't resolve on iOS/macOS/web.**~~ ✅ The style now carries
  `fontFamilyFallback: ['Menlo', 'Consolas', 'Roboto Mono', 'DejaVu Sans Mono', 'Courier New']`.
  Web turned out to be fine — Flutter hands family names straight to the browser, where `monospace`
  is a CSS generic — but iOS, macOS and Windows were all rendering code proportionally.
  `test/flutter_test_config.dart` still registers a system font under the `monospace` family, and
  still has to: the fallbacks name real fonts, but `flutter test` has none of them either.
- ~~**The copy button `setState`s after an `await` with no `mounted` guard**, and repeated taps race
  two 2-second reset timers against each other.~~ ✅ Fixed separately — it needed no rewrite of the
  body, so it wasn't worth carrying. `_CopyButtonState` now bails when unmounted and uses one
  restartable `Timer`, cancelled on dispose.
- ~~**No test coverage at all** for the copy button or the language label.~~ ✅ Covered by
  `test/src/code_block_view_test.dart`, which now also asserts the span tree: multi-color output for
  a recognised language with every character preserved, alias resolution, plain fallback for an
  unknown language / no language / an oversized block, re-highlighting on a code or theme change,
  and chrome colors taken from the theme. Plus a golden, and two tests in
  `ai_markdown_body_test.dart` covering the markdown path.
- ~~The block is hardcoded dark regardless of theme … the *header* row's label color should come out
  of the token set the highlighting theme establishes rather than a bare constant.~~ ✅ See
  **Theming** above. Still dark by choice; the constants are now fallbacks for a theme with no
  `root` entry.

- **Files:** `lib/src/code_block_view.dart`, new `lib/src/highlight/code_languages.dart`,
  `lib/src/ai_markdown_body.dart`, `lib/src/streaming_message_view.dart`; root `pubspec.yaml`
  (`melos.command.bootstrap`) and the package `pubspec.yaml`.
- **Rejected dependencies:** `syntax_highlight` (serverpod) — depends on `super_clipboard`, which
  forces a Rust/cargokit native build on every consuming app, plus asset bundles and an async
  `Highlighter.initialize()`, all for 15 languages. `flutter_highlight` + `highlight` — five years
  stale. Hand-rolling — no nested-mode awareness (no template literals, docstrings or regex
  literals) and we'd own every grammar bug. `re_highlight` is itself stale (0.0.3, last published
  2024), which the earlier draft of this item got wrong; taken anyway because grammars don't rot the
  way UI APIs do, and vendoring the 31 MIT files is a mechanical fallback if it is ever abandoned.
- **Effort:** M (1–2 days including dependency vetting).

### 2.2 Composer factory slot coverage (`ChatComposerFactory`)

**Gap:** Swift's `ComposerViewFactory` exposes **4** overridable slots (leading, trailing, input
view, picker sheet). Flutter's `ChatComposerFactory`
(`lib/src/composer/chat_composer_factory.dart`) exposes only **2** (leading, trailing) — the
text input and the attachment sheet are hardcoded inside `chat_composer.dart` and
`_AttachmentButton`.

**Proposed work:** add two nullable slot methods mirroring the existing pattern:

- `Widget? buildInput(BuildContext, ChatComposerController)` — defaults to the current
  `_InputContainer` (promote it out of private, or wrap it). Lets hosts fully replace the input
  field.
- `Widget buildAttachmentSheet(BuildContext, ChatComposerController)` — defaults to
  `ComposerAttachmentSheet`; `_AttachmentButton` calls the factory instead of constructing the
  sheet directly.

- **Files:** `chat_composer_factory.dart`, `chat_composer.dart` (wire
  `_InputContainer`/`_TrailingControl` through the factory).
- **Constraint:** keep the established `Widget?`-null-to-opt-out convention — no
  `SizedBox.shrink()` sentinels (two separately-constructed instances aren't `identical`/`==`,
  which is exactly the bug the existing `buildLeading`/`buildTrailing` nullability fix addressed).
- **Acceptance:** a custom factory can swap both the input and the sheet; existing default
  behavior is unchanged; extend `chat_composer_test.dart` with an override test.
- **Effort:** M (1 day).

### 2.3 Localization scaffolding

**Gap:** Swift externalizes strings via an `L10n` enum backed by a `.strings` bundle (English-only
today, but the seam exists for adding locales). Flutter hardcodes every user-facing string. The
complete list as of now, so the work can be done in one pass:

| String | Where |
|---|---|
| `'Ask anything…'` | `chat_composer.dart` — default `hintText` |
| `'Send'` | `chat_composer.dart` — trailing button tooltip (enabled and disabled) |
| `'Stop generating'` | `chat_composer.dart` — stop button tooltip |
| `'Remove attachment'` | `chat_composer.dart` — thumbnail remove tooltip |
| `'Clear {option}'` | `chat_composer.dart` — selected-option chip dismiss tooltip |
| `'Add photos'` | `chat_composer_factory.dart` — leading "+" tooltip |
| `'Photos'`, `'All Photos'`, `'Allow photo access'`, `'Take a photo'` | `composer_attachment_sheet.dart` |
| `'Voice input'`, `'Stop recording'` | `speech_to_text_button.dart` — mic tooltips |
| `'Copy code'`, `'Copied!'` | `code_block_view.dart` |

Several of these are tooltips doubling as the only accessible label for an icon-only button, so the
translations object is also what makes those buttons legible to a screen reader in any locale.

**Proposed work:** introduce a single injectable translations object — a `StreamAiTranslations`
abstract class plus a `DefaultStreamAiTranslations` implementation holding today's English
literals — passed via constructor/`InheritedWidget` rather than pulling in
`flutter_localizations` (keeps the package dependency-light and framework-agnostic, matching its
standalone design goal). Replace hardcoded literals with lookups against this object.

- **Files:** new `lib/src/localization/stream_ai_translations.dart`; touch every widget listed in the
  table above.
- **Acceptance:** all user-facing strings resolve through the translations object; a test injecting
  a custom translations instance observes the overridden strings.
- **Effort:** M (1 day). Ships no non-English translations yet — just the seam for adding them
  later.

### 2.4 Chart theming & accessibility

**Gap:** `ChartView`'s presentation is entirely fixed. The chrome that was outright broken in dark
mode has been fixed (grid lines, heatmap cell borders and labels now come from the `ColorScheme`,
and the heatmap's sequential ramp inverts so higher values stay brighter than the surface), but
everything else is still a hardcoded constant with no way for a host to intervene:

- `_kSeriesColors` — a fixed six-color categorical palette, so charts can't follow an app's brand.
- `_kChartHeight` (220), the bubble radius range, and the histogram's 10-bucket count.
- `PieChartSectionData.titleStyle` is hardcoded white-on-slice.
- Charts carry **no `Semantics` at all**: to a screen reader a `ChartView` is an empty box. Even a
  summary label ("bar chart, Messages per day, 5 categories, values 8 to 24") would be a large
  improvement, and the data for it is all sitting in the `USpec`.

**Proposed work:** a `ChartTheme`-style object (constructor parameter plus optional
`InheritedWidget`, mirroring whatever shape 2.3 settles on for translations) carrying the palette,
height, and sizing constants; plus a `Semantics` wrapper deriving a summary from the `USpec`.
Consider `USpecKind`-aware summaries and per-series labels.

- **Files:** `lib/src/chart/chart_view.dart`, `lib/src/chart/heatmap_chart_view.dart`; new theme
  class.
- **Acceptance:** a host palette overrides the series colors; a chart exposes a non-empty semantic
  label under `SemanticsTester`; goldens regenerated.
- **Effort:** M.

---

## Phase 3 — Large / optional

### 3.1 MCP client-tool / agentic tool-calling — largest effort, needs a design spike

**Gap:** Swift ships `Tools/ClientToolRegistry.swift` (`ClientTool` protocol, `ClientToolRegistry`,
`ClientToolInvocation`, `ClientToolAction`, `ToolRegistrationPayload`) built on Anthropic's official
MCP `swift-sdk`, letting a host app register client-side tools the AI can invoke. Flutter has
nothing in this space.

**Proposed work** (spike first, then build):

1. **Design spike** — decide the Dart MCP surface. Options: adopt an existing Dart MCP client
   package (e.g. `dart_mcp` / `mcp_dart`), or build a minimal hand-rolled registry mirroring
   Swift's shape (`StreamAiClientTool` interface with a tool schema + `handleInvocation`, a
   registry keyed by tool name, a `registrationPayloads()` serializer). **Recommendation:** start
   with the minimal registry to stay decoupled and avoid a heavy transport dependency; wire it to
   a real MCP transport in a follow-up once the shape is validated.
2. Define types: `StreamAiClientTool`, `StreamAiToolRegistry`, `ClientToolInvocation`,
   `ToolRegistrationPayload`.
3. Provide a worked example + README section showing registration and invocation routing.

- **Files:** new `lib/src/tools/` directory; barrel export from
  `lib/stream_chat_flutter_ai.dart`.
- **Acceptance:** register a sample tool, feed a synthetic invocation, assert the tool's handler
  runs and produces the expected action; documented example in the README.
- **Effort:** L (multi-day; blocked on the design spike landing first). This is the highest-value
  strategic gap if the AI story is meant to cover agentic/tool-use scenarios, but also the biggest
  lift — schedule accordingly.

### 3.2 Generic sidebar / split-view (`SidebarView`) — optional 🅾️

**Gap:** Swift ships `SidebarView` — a swipeable drawer/split-view (edge-drag gestures, spring
animation, dimming overlay) for a ChatGPT-style conversation-list drawer. It is **not
chat-specific**.

**Recommendation:** mark optional / won't-do by default. Flutter already has first-class
`Drawer`/`NavigationDrawer` and `Scaffold.drawer` with built-in edge-swipe support, so a bespoke
widget adds little value. Only build if a sample app specifically needs the exact split-view
offset behavior Swift's version has. If it is built, it belongs in a shared UI package (mirroring
the `stream_core_flutter` split from the chat-specific packages), not in
`stream_chat_flutter_ai`.

- **Effort:** S–M if pursued.

---

## Decisions taken

Recorded so they aren't re-litigated. State the counter-evidence if you want to reopen one.

### Markdown renderer: stay on `flutter_markdown_plus` 🅾️

`gpt_markdown` was evaluated as a replacement (July 2026) and **rejected**. It markets itself as the
LLM-oriented renderer, and it does have real AI-shaped features — built-in LaTeX, `SourceTag`
citation markers, a `closed` flag on its `codeBuilder`. But:

- **The streaming claim doesn't hold up.** It is the headline reason to switch, and there is no
  streaming API, no documentation of partial-input behaviour, and
  [issue #67](https://github.com/Infinitix-LLC/gpt_markdown/issues/67) ("Can AI streaming chat render
  Markdown in real time?") has been open and unanswered since June 2025. Its inline syntaxes all
  require paired closers, so a half-typed `**wor` renders as literal asterisks.
- **It parses with its own regexes**, not `package:markdown`, so it isn't CommonMark/GFM-compliant.
  Missing what LLMs actually emit: `_italic_` / `__bold__`, reference-style links, autolinks,
  footnotes, setext headings.
- **No `selectable` parameter** ([#118](https://github.com/Infinitix-LLC/gpt_markdown/issues/118)),
  which `StreamingMessageView` relies on for desktop/web.
- **No built-in syntax highlighting**, despite the docs claiming it (`custom_widgets/code_field.dart`
  renders plain text) — so 2.1 above would be unaffected either way.
- Switching would break the public API: `MarkdownStyleSheet` is exported and is the documented seam
  for matching a host's `stream_chat_flutter` text theme. `GptMarkdownThemeData` is less expressive.
- It pulls `flutter_svg` + `provider` + `tuple` transitively, against this package's standalone,
  dependency-light design.

`flutter_markdown_plus` is also the better-supported option: ~3× the downloads, a direct handover
from Google's discontinued `flutter_markdown` to foresightmobile.com, and `package:markdown`
underneath.

Crucially, the one genuine architectural win — replacing the hand-rolled fence pre-split with a real
element builder — needed no dependency change at all; `flutter_markdown_plus`' `builders` API already
provided it, and taking it fixed four bugs (see the CHANGELOG). LaTeX landed in place too, as
`src/markdown/math_syntax.dart` plus a `mathBuilder` seam.

**Still worth stealing from `gpt_markdown`:** `SourceTag`-style inline citation markers
(`【…[1]`) have no equivalent here. If inline citations become a requirement, that is a custom
`md.InlineSyntax` plus a builder, in the same shape as the math support.

## Where Flutter already leads

Recorded here so future parity work doesn't regress these — they are intentional improvements over
Swift, not gaps:

- **Image-only sends:** `ChatComposerController.hasContent` gates the send button on text **or**
  attachments; Swift's send button only appears when text is non-empty.
- **Unified morphing trailing control:** a single 40×40 control that morphs between mic/send/stop
  is a more deliberate design than Swift's separately-styled buttons.
- **Grapheme-cluster-aware typewriter:** `TypewriterController` uses `Characters`, which is safer
  for emoji/multi-byte text during streaming than Swift's raw `Character` array indexing.
- **Real per-language syntax highlighting:** `CodeBlockView` colors 31 languages from their fence
  label. Swift's `SplashCodeSyntaxHighlighter` applies the Swift grammar to *every* labelled fence
  (Splash supports no other language) and leaves unlabelled ones plain — see 2.1.

## At parity (no work needed)

Streaming/typewriter text rendering, the AI typing indicator, the composer state controller
(`ChatComposerController` ↔ Swift's `ComposerViewModel`), the `ChatOption` model (including its
`description` field), speech-to-text, and the attachment picker (camera + recent photos + full
library picker).
