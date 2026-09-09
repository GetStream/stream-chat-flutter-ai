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
| 2.3 | Localization scaffolding | 2 | M | ✅ |
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
was no per-language target here. Recorded under
[Where Flutter already leads](#where-flutter-already-leads).

> Unverified from this repository: the Swift package is not vendored here, so the quote above
> reflects what that file said when this was written and no CI check here can re-verify it.

**Shipped, as a seam rather than a dependency.** `CodeHighlighter` —
`TextSpan? Function(String code, String language, TextStyle baseStyle)` — wired through
`CodeBlockView.highlighter`, `AIMarkdownBody.codeHighlighter` and
`StreamingMessageView.codeHighlighter`. The package recognises fences, frames them, caps them and
renders the spans; it holds no grammars and no highlighting dependency. This mirrors `mathBuilder`
exactly, and for the same reason.

**Why the seam and not the dependency** (this is the decision to re-read before "simplifying" it
back). Measured on a release web build of the example app:

| | |
|---|---|
| the whole package's own `lib/` | 198 KB of source |
| a curated 31-grammar `re_highlight` set | 872 KB of source — **4.4× the package** |
| `re_highlight`'s full `builtinAllLanguages` (194 grammars) | 2.7 MB of source |
| compiled cost of the curated set | +636 KB of `main.dart.js`, +56 KB gzipped |

Every grammar is a top-level `final` holding a tree of `Mode` constructor calls, so 73% of that
source survives into the bundle — nothing tree-shakes an unused grammar back out. Baking it in
would have meant every host paying for 31 languages whether they render code or not, and `swift`
alone is 388 KB of the 872 KB. As a seam, a host picks its own language set, its own theme, or no
highlighting at all, and the package's dependency list stays as short as its README claims.

**The host's side.** `example/lib/code_highlighter.dart` is the reference implementation: the
curated 31-grammar set — `bash c cpp csharp css dart diff dockerfile go graphql ini java javascript
json kotlin lua markdown objectivec php plaintext python r ruby rust scala shell sql swift
typescript xml yaml` — plus the aliases each grammar declares for itself (`js`, `ts`, `py`, `sh`,
`yml`, `c++`, `cs`, `html`, …), `vs2015Theme` for token colors, and `re_highlight` declared in
`example/pubspec.yaml`. `example/lib/main.dart` passes it as `codeHighlighter:` next to
`mathBuilder:`. Copy the file, drop the languages you don't need.

**Degradation, which the package still owns.** No highlighter, no language, a highlighter returning
null, or a body over 20,000 characters all render plain monospace text — selectable and
horizontally scrollable, with the copy button and language label intact.

**Throttling, which the package also owns.** A growing fence produces a longer prefix every
typewriter tick, and tokenizing each one makes the total quadratic in the block's length. Measured
on a 1839-character Dart fence: 1487 calls tokenizing 1.37 M characters, 746× the block. So a
re-highlight waits for a 64-character gain, plus one settling pass 120 ms after the last change so a
stream stopping mid-threshold still ends fully colored — 33 calls and 27.9 K characters for the same
fence, a 45× reduction. The gained characters are appended unhighlighted rather than withheld, so
the block is never truncated; the visible cost is about a line of uncolored text trailing the newest
characters. The 20,000-character cap bounds a single pass; this bounds how many there are. Both are
the package's business rather than the host's, because both are consequences of how it drives the
highlighter, not of what the highlighter does.

A highlighter that throws, or that returns spans whose text doesn't match the source, gets the same
plain fallback *and* a `FlutterError.reportError` (once per block, not once per tick — a failing
fence rebuilds every tick while streaming). The text check is not paranoia: `re_highlight` runs in
safe mode by default, so a mid-parse grammar failure comes back on `HighlightResult.errorRaised`
rather than as a throw, with an emitter holding only the tokens produced before the failure. A
`try`/`catch` never sees it, and rendering it silently drops the tail of the block or all of it.
The reference implementation checks `errorRaised` too, so both sides of the seam are covered.

**Theming.** `CodeBlockView.backgroundColor` / `.foregroundColor` (and
`codeBackgroundColor`/`codeForegroundColor` on the two wrappers) default to
`kDefaultCodeBackgroundColor` `#1E1E1E` and `kDefaultCodeForegroundColor` `#D4D4D4` — the colors
the block already had. The foreground drives the header's label and copy-button color at 60%
opacity, closing the "label color should come from the theme's token set" point below, and is
handed to the highlighter as its base style so tokens land on the same palette. Two `Color`s rather
than the scope map an earlier draft of this used: the map made `root` a magic key, exposed ~25
`TextStyle` fields of which two were read, and could be mutated behind the widget's back. Kept dark
regardless of the ambient `Theme`, deliberately.

**Folded in:**

- ~~**`fontFamily: 'monospace'` doesn't resolve on iOS/macOS/web.**~~ ✅ The style now carries
  `fontFamilyFallback: ['Menlo', 'Consolas', 'Roboto Mono', 'DejaVu Sans Mono', 'Courier New']`.
  iOS, macOS and Windows were all rendering code proportionally. `test/flutter_test_config.dart`
  still registers a system font under the `monospace` family, and still has to: `flutter test`
  resolves only families registered through `FontLoader`, never system fonts by name, so the
  fallback list is inert there.
- ~~**The copy button `setState`s after an `await` with no `mounted` guard**, and repeated taps race
  two 2-second reset timers against each other.~~ ✅ Fixed separately. `_CopyButtonState` now bails
  when unmounted and uses one restartable `Timer`, cancelled on dispose.
- ~~**No test coverage at all** for the copy button or the language label.~~ ✅ Covered by
  `test/src/code_block_view_test.dart`, which now also covers the seam: spans rendered with every
  character preserved, the language passed through verbatim, plain fallback for no highlighter / no
  language / a declining highlighter / an oversized block, the highlighter *not* called in the last
  two cases, report-and-fall-back for a highlighter that throws or drops text, reporting once
  across rebuilds, the base style handed to the highlighter, default and explicit chrome colors,
  and the monospace stack. Plus a golden, and three tests in `ai_markdown_body_test.dart` and one
  in `streaming_message_view_test.dart` covering the forwarding.
- ~~The block is hardcoded dark regardless of theme … the *header* row's label color should come out
  of the token set the highlighting theme establishes rather than a bare constant.~~ ✅ See
  **Theming** above. Still dark by choice; the label now derives from `foregroundColor`.

- **Files:** `lib/src/code_block_view.dart`, `lib/src/ai_markdown_body.dart`,
  `lib/src/streaming_message_view.dart`; new `example/lib/code_highlighter.dart`;
  `example/pubspec.yaml` and root `pubspec.yaml` (`melos.command.bootstrap`).
- **Rejected dependencies** (as a package dependency — all still open to a host):
  `syntax_highlight` (serverpod) — depends on `super_clipboard`, which forces a Rust/cargokit
  native build on every consuming app, plus asset bundles and an async `Highlighter.initialize()`,
  all for 15 languages. `flutter_highlight` + `highlight` — five years stale. Hand-rolling — no
  nested-mode awareness (no template literals, docstrings or regex literals) and we'd own every
  grammar bug. `re_highlight` is itself stale (0.0.3, last published 2024), which the earlier draft
  of this item got wrong; it is what the example uses anyway, because grammars don't rot the way UI
  APIs do, and a host is free to pick something else.
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

### 2.3 Localization scaffolding ✅

**Gap:** Swift externalizes strings via an `L10n` enum backed by a `.strings` bundle (English-only
today, but the seam exists for adding locales). Flutter hardcoded every user-facing string.

**Shipped:** `lib/src/localization/ai_translations.dart` — `AITranslations` (abstract, `const`
constructor, one getter per string), `DefaultAITranslations` (the English literals the widgets
already rendered) and `AITranslationsScope` (an `InheritedWidget`). Fourteen members cover the
fifteen literals that were there: the enabled and disabled send tooltips were separate literals for
the same button and collapsed into one `send`. `clearOption(String option)` is a method rather than
a getter, being the one interpolated string.

A host subclasses `DefaultAITranslations` and overrides only what it is changing — the same
subclass-and-override idiom `ChatComposerFactory` already established:

```dart
class DutchTranslations extends DefaultAITranslations {
  const DutchTranslations();

  @override
  String get send => 'Verstuur';
}

AITranslationsScope(translations: const DutchTranslations(), child: ChatComposer(...))
```

`AITranslations.of(context)` falls back to `const DefaultAITranslations()` rather than asserting, so
a scope is optional everywhere and a host that adds none sees no change at all. English only — no
locales ship.

**Naming.** `AITranslations`, not the `StreamAiTranslations` this item originally drafted. The
package dropped the `Stream` prefix when it dropped the `stream_chat` dependency, and its
AI-specific types carry a capital `AI` token (`AIMarkdownBody`, `AISuggestionsView`,
`AITypingIndicatorView`).

**Why a scope rather than constructor threading** (this is the decision to re-read before
"simplifying" it into parameters). Twelve of the fifteen literals live in *private* leaf widgets two
to four layers below a public one — `_TrailingControl`, `_AttachmentThumbnail`,
`_SelectedOptionChip`, `_AttachmentButton`, `_CameraTile`, `_MicButton`, `_CopyButtonState`. And
`CodeBlockView`'s two are constructed inside the top-level `_buildFenceCached`
(`lib/src/ai_markdown_body.dart`), which has no `BuildContext` at all. Threading would have meant
about ten new parameters and a new component in the fence cache key. A lookup in `build` costs
nothing and needs neither.

**The fence cache, which the scope survives.** `_fenceWidgetCache` returns the *identical* `Widget`
instance for a given fence source, and translations deliberately are **not** part of its key —
unlike `codeBackgroundColor`/`codeForegroundColor`, which must be, because they are constructor
arguments baked into the cached instance. That looks wrong and isn't: the cached object is an
unbuilt widget *configuration*, the string is resolved later in `_CopyButtonState.build` from that
element's own context, and the inherited-dependency mechanism marks the element dirty on a scope
change regardless of widget identity. One cached fence renders correctly under two different scopes,
and `ai_markdown_body_test.dart` asserts exactly that — same instance, different string.

**The modal route, which it doesn't survive unaided.** `ComposerAttachmentSheet` is pushed with
`showModalBottomSheet`, so it sits under the `Navigator` rather than under whatever wraps the
composer. `_AttachmentButton` therefore reads the translations from its own context *before*
pushing and re-provides them inside the sheet's route, so a scope placed directly above a
`ChatComposer` still reaches the sheet's four strings. A host presenting the sheet itself owns that
re-provision, which its class doc says.

**The `const` requirement.** `AITranslationsScope.updateShouldNotify` compares instances, so a
non-`const` subclass instance built inside a `build` that runs on every typewriter tick would notify
every dependent every ~10ms. `const` instances are canonicalized to one object. Documented on
`AITranslations`, on `AITranslationsScope.translations`, and in the README; asserted in
`ai_translations_test.dart`.

**Accessibility, which is the larger half of this.** Ten of the fourteen are `Tooltip` messages on
icon-only buttons, so they are also the only accessible label those buttons expose. Before this, a
screen reader outside English read English or nothing.

**Precedence.** `ChatComposer.hintText` still wins over `AITranslations.composerHint` — a hint
written for one composer is more specific than an app-wide string.

**Why subclass `DefaultAITranslations` and not implement `AITranslations`.** Both work, but a string
added in a later version arrives as an untranslated default for the former and a compile error for
the latter. The docs point at the former.

**No `flutter_localizations`, no `intl`, no `.arb`.** Fourteen strings do not justify putting every
host onto Flutter's localization delegates, and the package's dependency list stays as short as its
README claims. A host already using `flutter_localizations` bridges the two in a few lines by
reading its own `AppLocalizations` inside a `DefaultAITranslations` subclass.

- **Files:** new `lib/src/localization/ai_translations.dart`, exported from
  `lib/stream_chat_flutter_ai.dart`; `chat_composer.dart`, `chat_composer_factory.dart`,
  `composer_attachment_sheet.dart`, `speech_to_text_button.dart`, `code_block_view.dart`; new
  `test/src/localization/ai_translations_test.dart`, plus cases in `chat_composer_test.dart`,
  `speech_to_text_test.dart`, `code_block_view_test.dart` and `ai_markdown_body_test.dart`; a
  `### Localization` section in the README.
- **Not done here:** `lib/src/chart/uspec.dart`'s `'Series'` (×4) and `'Pie'` (×2) fallbacks. They
  are *parser* defaults assigned to `USeries.name`, and the parser has no `BuildContext`; only
  `'Series'` is visible today, as a heatmap row label. Folded into 2.4, which already owns chart
  presentation and would resolve them at render time.
- **Effort:** M (1 day), as estimated.

### 2.4 Chart theming & accessibility

**Gap:** `ChartView`'s presentation is entirely fixed. The chrome that was outright broken in dark
mode has been fixed (grid lines, heatmap cell borders and labels now come from the `ColorScheme`,
and the heatmap's sequential ramp inverts so higher values stay brighter than the surface), but
everything else is still a hardcoded constant with no way for a host to intervene:

- `_kSeriesColors` — a fixed six-color categorical palette, so charts can't follow an app's brand.
- `_kChartHeight` (220), the bubble radius range, and the histogram's 10-bucket count.
- `PieChartSectionData.titleStyle` is hardcoded white-on-slice.
- The `'Series'` / `'Pie'` fallback names `USpecParser` assigns to `USeries.name`
  (`lib/src/chart/uspec.dart`) are hardcoded English. `'Series'` reaches the screen as a heatmap row
  label. Left out of 2.3 because they are parser defaults with no `BuildContext` — resolving them
  means deferring the fallback to render time, where `AITranslations.of` is available.
- Charts carry **no `Semantics` at all**: to a screen reader a `ChartView` is an empty box. Even a
  summary label ("bar chart, Messages per day, 5 categories, values 8 to 24") would be a large
  improvement, and the data for it is all sitting in the `USpec`.

**Proposed work:** a `ChartTheme`-style object carrying the palette, height, and sizing constants,
plus a `Semantics` wrapper deriving a summary from the `USpec`. 2.3 settled the shape to mirror: an
abstract class with a `const` constructor, a concrete default holding today's values, and an
`InheritedWidget` scope read through a static `of(context)` that falls back to that default rather
than asserting — see `lib/src/localization/ai_translations.dart`. Unlike translations, a theme has a
real case for a per-widget constructor parameter too, since a host may want one chart styled
differently from the rest.
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
- **Per-language syntax highlighting, without the dependency:** `CodeBlockView` takes a
  `CodeHighlighter` from the host, so a fence is colored by its own language — the example wires up
  31 of them — while the package itself ships no grammars. Swift's `SplashCodeSyntaxHighlighter`
  applies the Swift grammar to *every* labelled fence (Splash supports no other language) and
  leaves unlabelled ones plain — see 2.1.

## At parity (no work needed)

Streaming/typewriter text rendering, the AI typing indicator, the composer state controller
(`ChatComposerController` ↔ Swift's `ComposerViewModel`), the `ChatOption` model (including its
`description` field), speech-to-text, and the attachment picker (camera + recent photos + full
library picker).
