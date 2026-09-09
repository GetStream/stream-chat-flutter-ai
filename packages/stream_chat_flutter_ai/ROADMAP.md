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
| 2.2 | Composer factory slot coverage | 2 | M | ✅ |
| 2.3 | Localization scaffolding | 2 | M | ✅ |
| 2.4 | Chart theming & accessibility | 2 | M | ✅ |
| 2.5 | Theming for the remaining components | 2 | M | ⬜ |
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

### 2.2 Composer factory slot coverage (`ChatComposerFactory`) ✅

**Gap:** Swift's `ComposerViewFactory` exposes **4** overridable slots (leading, trailing, input
view, picker sheet). Flutter's `ChatComposerFactory` exposed only **2** (leading, trailing) — the
text input was the private `_InputContainer` inside `chat_composer.dart`, and
`ComposerAttachmentSheet` was constructed directly inside `_AttachmentButton`.

**Shipped API.** Every slot now takes a props object instead of a bare controller:

```dart
class ChatComposerFactory {
  Widget? buildLeading(BuildContext context, ChatComposerLeadingProps props);              // "+" button
  Widget? buildTrailing(BuildContext context, ChatComposerTrailingProps props);            // null
  Widget buildInput(BuildContext context, ChatComposerInputProps props);                   // ChatComposerInput
  Widget buildAttachmentSheet(BuildContext context, ChatComposerAttachmentSheetProps props); // ComposerAttachmentSheet
}
```

`lib/src/composer/chat_composer_props.dart` holds `ChatComposerSlotProps` and one subclass per
slot. The base carries the four values a factory cannot otherwise see — `controller`, `focusNode`,
`onSend`, `onStop` — so every slot can drive the composer; `ChatComposerInputProps` adds the six
that are meaningless outside a text field: `hintText`, `minLines`, `maxLines`, `textInputAction`,
`enableSpeechToText`, `speechToTextConfig`.

**Correction to the proposed API, found while doing the work.** The signature this item proposed,
`buildInput(BuildContext, ChatComposerController)`, cannot work. `_InputContainer` needed ten
values and the controller is one of them; the other nine are owned by `_ChatComposerState`, and
`ChatComposerFactory` is a `const`-constructible plain class with no path to the widget or its
state. `onSend` is the load-bearing one — it is the only route to `ChatComposer.onSendPressed` plus
the `controller.clear()` + `focusNode.requestFocus()` that follows a send. A slot with the proposed
signature would have existed and silently not sent.

**Decisions taken:**

- **Props objects, for all four slots.** Named and shaped after `stream_chat_flutter`'s
  `MessageComposerComponentProps` / `MessageComposerLeadingProps` / `MessageComposerInputProps`
  family (`packages/stream_chat_flutter/lib/src/components/message_composer/`). Converting
  `buildLeading`/`buildTrailing` too is a breaking change, taken deliberately: the package is
  unpublished, no factory subclass existed outside one test and two doc snippets, and both 2.3 and
  2.4 will want to push more values through these slots. One convention beats two.
- **The wiring lives on the base, not on `ChatComposerInputProps`.** First cut put `focusNode`,
  `onSend` and `onStop` on the input props alone, which left the other three slots holding a bare
  controller and made the leading/trailing/sheet subclasses genuinely empty. That is backwards:
  `stream_chat_flutter` puts its *send button* in the trailing slot, and a leading button that
  wants to return focus to the field needs the node. Hoisting them also means 2.3 and 2.4 can add
  shared values — translations, a theme — in one place rather than breaking four signatures a
  second time.
- **One simplification versus the sibling, and one convergence.** Public `const` constructors
  rather than `._` private ones (a public constructor lets a test build props to drive a custom
  input directly). But the `.from(...)` constructors *are* kept: with a base this wide the composer
  builds the widest props once and narrows per slot, exactly as
  `MessageComposerLeadingProps.from(props)` does, so the shared values are named in one place. No
  `Default…` twin widget, though — the factory *is* the override seam here, so the sibling's
  builder-registry indirection buys nothing (see the decision below).
- **Both new slots are non-nullable**, against this item's own "keep the `Widget?` convention"
  constraint. That convention exists for *optional* slots, where `null` is how the composer knows
  not to reserve its 8px gap, and where the `SizedBox.shrink()` sentinel doubled the margin.
  Neither new slot has an absent state: `buildInput`'s result goes straight into an `Expanded`
  (there is no layout for "no input", and the base implementation can never return `null`), and
  `buildAttachmentSheet` is called only once the button has decided to open a modal. Nothing is
  compared against a sentinel in either case, so the original bug cannot recur. A host wanting no
  picker overrides `buildLeading`, which is still nullable.
- **`_InputContainer` moved to its own file** as public `ChatComposerInput`
  (`lib/src/composer/chat_composer_input.dart`), taking its private collaborators
  (`_TrailingControl`, `_AttachmentThumbnails`, `_AttachmentThumbnail` and its `State`,
  `_SelectedOptionChip`, `_trailingState`) with it.
  Not promoted in place: `chat_composer_factory.dart` has to name it in code, and it imports
  `chat_composer.dart` for doc links only. The separate file keeps the dependency direction
  one-way *in code* — props ← input ← factory ← composer. At the import level the graph is still
  cyclic: props and input both import the composer, for doc links only, as their own header
  comments say.
- **The sheet slot supplies content, not presentation.** `showModalBottomSheet`'s options
  (`isScrollControlled`, `showDragHandle`) stay in `_AttachmentButton`, so a replacement sheet must
  not draw its own drag handle; `buildLeading` is the seam for changing how, or whether, a picker
  is presented. `buildLeading`'s default passes `this` to the button, which is what makes a
  sheet-only override take effect — the button previously constructed the sheet itself.

- **Files:** new `chat_composer_props.dart` and `chat_composer_input.dart`;
  `chat_composer_factory.dart`, `chat_composer.dart`, the barrel, and the `buildLeading` snippet in
  `speech_to_text_button.dart`'s dartdoc.
- **Acceptance:** ✅ `chat_composer_test.dart` gained a `ChatComposerFactory` group — the default
  input is a `ChatComposerInput`; `buildInput` can wrap the default and keep its send button
  working; a full replacement wired to `props.onSend` fires `onSendPressed` **and** leaves the
  field cleared (the assertion that proves it got the composer's real handler, not a lookalike);
  the props carry the composer's controller, focus node and text-field config; the default sheet is
  a `ComposerAttachmentSheet`; and a sheet-only override replaces it while still opening from the
  default "+" button. Plus a companion to the existing gap-spacer regression test, pinning the
  other half of that invariant (both slots rendering ⇒ two spacers).
- **Effort:** M (1 day) — as estimated.

**Follow-up pass (post-review).** Six things the slot work exposed, all fixed before merge:

- **`ChatComposerInput` drives its own rebuilds.** As private `_InputContainer` its only
  construction site sat inside `_ChatComposerState`'s `ListenableBuilder`; public, it read
  controller state and `SpeechToTextController.instance` while subscribing to neither, so
  standalone use rendered once and froze — worst case a live dictation session whose only stop
  control never appeared. It now nests its own listeners (not `Listenable.merge`, for the reason
  recorded on `_ChatComposerState._listenable`).
- **`hintText` is nullable, and `null` means "the host expressed no preference".** It was
  non-nullable with a constant default, so a custom input could not tell a hint the host chose from
  the package's own. The slot that renders the field now decides what an absent hint falls back to;
  2.3 made that fallback a localized lookup.
- **`onStop` is nullable.** `_onStop` wrapped `onStopPressed?.call()` unconditionally, so props
  always handed over a callable and a custom input could not tell that stopping was unsupported.
- **A rejected send is reported.** `ChatComposerSendCallback` now returns `FutureOr<void>`,
  matching the `async` callback the docs have always shown; the future was previously discarded,
  so a failed send was silent in release. The clear stays optimistic, now documented as such.
- **`onSend`/`onStop` guard `mounted`.** They are handed to host code that may call them across
  an async gap, which previously notified a disposed controller.
- **Asserts where the docs were the only defence:** `minLines`/`maxLines` ordering (on both the
  props and `ChatComposer`), and `buildInput` not returning an `Expanded`/`Flexible`.

Plus `copyWith` on `ChatComposerInputProps` (ten fields; hand-listing them silently reverts any
you forget), an `abstract` base for `ChatComposerSlotProps`, and twelve tests — the composer group
went from 65 to 77 — closing gaps a mutation pass found, including refocus-after-send, the
`hasContent` guard, and the text-field configuration actually reaching the field rather than just
echoing back off the props.

### 2.3 Localization scaffolding ✅

**Gap:** Swift externalizes strings via an `L10n` enum backed by a `.strings` bundle (English-only
today, but the seam exists for adding locales). Flutter hardcoded every user-facing string.

**Shipped:** `lib/src/localization/ai_translations.dart` — `AITranslations` (abstract, `const`
constructor, one getter per string), `DefaultAITranslations` (the English literals the widgets
already rendered), `AITranslationsDelegate` (a `LocalizationsDelegate`) and `AITranslationsScope`
(an `InheritedTheme`). Fourteen members, one per literal — 2.2 had already collapsed the enabled and disabled send tooltips into a single call site,
so `send` covers both states. `clearOption(String option)` is a method rather than a getter, being
the one interpolated string.

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

**Two ways in, and a lookup that never throws.** `AITranslationsDelegate` goes on
`MaterialApp.localizationsDelegates` with a `const` map keyed by `Locale.toString()`'s form, which
is how an app covers several languages: Flutter resolves the locale, picks the instance, and reloads
on a locale change, routes included. `AITranslationsScope` pins one instance over a subtree.
`AITranslations.of(context)` reads the scope, then the delegate, then
`const DefaultAITranslations()` — so both are optional and a host that registers neither sees no
change at all. English only — no locales ship.

This mirrors `stream_chat_flutter`, which resolves through `Localizations` the same way
(`StreamChatLocalizations.of(context) ?? DefaultTranslations.instance`), so a host of both SDKs
registers two delegates side by side. Two deliberate differences: the map is keyed by `String`
rather than `Locale`, because `Locale` overrides `==` and Dart forbids such a type as a `const` map
key — a `Locale`-keyed delegate could not be `const`, which is exactly what the scope's identity
comparison wants; and `isSupported` returns `true` unconditionally, because `WidgetsApp` warns in
debug about any `supportedLocales` entry that some delegate refuses, and "this locale gets the
English defaults" is not a refusal. `resolve` is the honest answer for anything that needs one.

There is no separate `stream_chat_ai_localizations` package and no shipped locales: fourteen
strings are a seam, not a translation project, and a host writing two subclasses does not need a
package to hold them.

**Naming.** `AITranslations`, not the `StreamAiTranslations` this item originally drafted. The
package dropped the `Stream` prefix when it dropped the `stream_chat` dependency, and its
AI-specific types carry a capital `AI` token (`AIMarkdownBody`, `AISuggestionsView`,
`AITypingIndicatorView`).

**Why a scope rather than constructor threading** (this is the decision to re-read before
"simplifying" it into parameters). Ten of the fourteen live in *private* leaf widgets two to four
layers below a public one — `_TrailingControl`, `_AttachmentThumbnail`, `_SelectedOptionChip`,
`_AttachmentButton`, `_CameraTile`, `_MicButton`, `_CopyButtonState` — and three more in
`ComposerAttachmentSheet`'s private `State`. `CodeBlockView`'s two are constructed inside the
top-level `_buildFenceCached` (`lib/src/ai_markdown_body.dart`), which has no `BuildContext` at all.
Threading would have meant about ten new parameters and a new component in the fence cache key. A
lookup in `build` costs nothing and needs neither.

The fourteenth, the composer hint, looked like an exception and is not one. It is a field of
`ChatComposerInputProps`, but the composer only forwards `ChatComposer.hintText` into it —
unresolved, `null` when the host passed none. `ChatComposerInput` does its own
`AITranslations.of(context)` lookup like every other string, at the widget that renders it. Having
the composer resolve it first was tried and dropped: it made the hint the one string a custom input
got for free, at the cost of a second resolution site whose result a factory could not distinguish
from a hint the host had chosen.

**The fence cache, which the scope survives.** `_fenceWidgetCache` returns the *identical* `Widget`
instance for a given fence source, and translations deliberately are **not** part of its key —
unlike `codeBackgroundColor`/`codeForegroundColor`, which must be, because they are constructor
arguments baked into the cached instance. That looks wrong and isn't: the cached object is an
unbuilt widget *configuration*, the string is resolved later in `_CopyButtonState.build` from that
element's own context, and the inherited-dependency mechanism marks the element dirty on a scope
change regardless of widget identity. One cached fence renders correctly under two different scopes,
and `ai_markdown_body_test.dart` asserts exactly that — same instance, different string.

**The modal route, which it survives because the scope is an `InheritedTheme`.**
`ComposerAttachmentSheet` is pushed with `showModalBottomSheet`, so it sits under the `Navigator`
rather than under whatever wraps the composer. Rather than snapshot the translations at the push and
re-provide them inside the sheet — which works, but only for the one call site that remembers to do
it — `AITranslationsScope` extends `InheritedTheme` and overrides `wrap`. `showModalBottomSheet`,
`showDialog` and `showMenu` all call `InheritedTheme.capture` on the way to the `Navigator`, so a
scope placed directly above a `ChatComposer` reaches the sheet's four strings with no cooperation
from the pushing code, and a host presenting the sheet itself gets the same for free. Pinned by
three tests: the composer's own sheet, a host-presented one, and a `showDialog` that proves the
mechanism is general rather than bottom-sheet-specific.

The one seam left is that `InheritedTheme.capture` snapshots at push time, so a scope swapped while
such a route is already open reaches it only on the next open. Documented on the scope and in the
README.

**The `const` requirement.** `AITranslationsScope.updateShouldNotify` compares instances, so a
fresh subclass instance per `build` would rebuild every dependent. Documented on `AITranslations`,
on `AITranslationsScope.translations`, and in the README; asserted in `ai_translations_test.dart`.

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

- **Still not `flutter_localizations`, `intl` or `.arb`.** `LocalizationsDelegate` and
  `Localizations` are both in `package:flutter/widgets.dart`, so delegate support cost no
  dependency. A host that wants translated *Material* strings adds `flutter_localizations` itself,
  as it would anyway.
- **Files:** new `lib/src/localization/ai_translations.dart`, exported from
  `lib/stream_chat_flutter_ai.dart`; `chat_composer.dart`, `chat_composer_input.dart`,
  `chat_composer_props.dart`, `chat_composer_factory.dart`, `composer_attachment_sheet.dart`,
  `speech_to_text_button.dart`, `code_block_view.dart`; new
  `test/src/localization/ai_translations_test.dart`, plus cases in `chat_composer_test.dart`,
  `speech_to_text_test.dart`, `code_block_view_test.dart` and `ai_markdown_body_test.dart`; a
  `### Localization` section in the README.
- **Not done here:** `lib/src/chart/uspec.dart`'s `'Series'` (×4) and `'Pie'` (×2) fallbacks. They
  are *parser* defaults assigned to `USeries.name`, and the parser has no `BuildContext`; only
  `'Series'` was visible, as a heatmap row label. Folded into 2.4, which owns chart presentation and
  resolved them at render time — the parser now leaves the name empty and the widgets substitute
  `AITranslations.unnamedChartSeries`.
- **Effort:** M (1 day), as estimated.

### 2.4 Chart theming & accessibility ✅

**Gap:** `ChartView`'s presentation was entirely fixed. The chrome that was outright broken in dark
mode had already been fixed (grid lines, heatmap cell borders and labels from the `ColorScheme`, and
a sequential ramp that inverts so higher values stay brighter than the surface), but everything else
was a hardcoded constant with no way for a host to intervene: `_kSeriesColors`, `_kChartHeight`, the
bubble radius range, the histogram's bucket count, a white-on-slice pie label, and `USpecParser`'s
English `'Series'` / `'Pie'` fallback names, which 2.3 deferred here because a parser has no
`BuildContext`. And charts carried **no `Semantics` at all** — to a screen reader a `ChartView` was
an empty box.

**Shipped API.** A package-level theme, because there was nothing to hang a chart theme on: no
`ThemeExtension` and no `InheritedWidget` existed here outside 2.3's translations scope.

- `lib/src/theme/ai_theme.dart` — `AITheme`, a `ThemeExtension` a host registers on
  `ThemeData.extensions`, read through a never-throwing `AITheme.of`.
- `lib/src/theme/components/chart_theme.dart` — `ChartThemeData` (thirteen nullable fields:
  `seriesColors`, `height`, `scatterRadius`, `bubbleMinRadius`/`bubbleMaxRadius`,
  `histogramBinCount`, `axisLabelStyle`, `pieLabelStyle`, `titleTextStyle`, `gridLineColor`, and the
  three `heatmap*Color` ramp stops) plus `ChartTheme`, an `InheritedTheme` whose `of` merges a
  subtree's overrides over `AITheme`'s. `kDefaultChartSeriesColors` is the old six-color palette,
  exported so a host can extend rather than replace it.
- `ChartView.theme` / `HeatmapChartView.theme` override it for one chart. The three compose, most
  specific first, and `lib/src/chart/resolved_chart_theme.dart` (unexported) fills in every default
  in one place.
- `ChartView.semanticsLabel`, `ChartSemantics.fromSpec`, and two new `AITranslations` members —
  `unnamedChartSeries` and `chartSemanticsLabel(ChartSemantics)`.

**Every field nullable, defaults resolved in `build`.** An unset field means "derive it from the
ambient `ThemeData`", so a host overriding the palette leaves the grid line, the axis labels and the
heatmap ramp following the app in both brightnesses. This is the shape `stream_core_flutter`'s
`StreamTheme` uses (`<Component>ThemeData` + an `InheritedTheme` + defaults in the widget), which is
what a host of both SDKs will expect.

**Divergences from that reference, and from what this item originally sketched:**

- **Not the translations shape.** 2.3's draft of this item said to mirror `AITranslations` — an
  abstract class with a concrete default subclass. Only the `of`-falls-back-to-a-default third
  carried over. Translations are *behaviour you subclass*; a theme is *data that interpolates*, so
  `ChartThemeData` is a concrete value class with `lerp`, reached through a `ThemeExtension` so it
  composes with Material and animates across a light/dark switch.
- **`AITheme` carries no brightness, color scheme, typography or token layer.** `stream_core_flutter`
  needs those because it *is* a design system; every widget here already resolves from the ambient
  `ColorScheme`, and a second brightness would be a second source of truth able to disagree with
  `Theme.of`. So there are no `.light()`/`.dark()` factories either — one instance covers both.
- **Hand-written `copyWith`/`merge`/`lerp`/`==`, not `theme_extensions_builder`.** One component
  theme does not justify a codegen dependency in a package whose premise is a short dependency list.
  Revisit if 2.5 brings the count to six.
- **No `BuildContext` extension getters.** `stream_core_flutter` has `context.streamAvatarTheme` and
  friends, but its names are all `Stream`-prefixed; unprefixed getters on `BuildContext` would leak
  into every host file that imports this barrel. `ChartTheme.of(context)` is the whole API.

**`lerp` swaps unset fields rather than interpolating them** (the detail to re-read before
"simplifying" it). `null` means "derive from the theme", not "transparent" and not "zero":
`Color.lerp(null, c, t)` fades in from transparent and would make a grid line vanish halfway through
a light/dark transition, `lerpDouble(null, 220, t)` reads the null as 0 and would grow a chart up
from nothing, and `TextStyle.lerp` with a null side fades colors out of transparent. So a field set
on only one side snaps at `t == 0.5`, which lands at the right value at both ends. Palettes of
different lengths interpolate by *wrapping* the shorter one, the same way it is cycled at paint time,
so no series loses its color mid-animation.

**No new parameter on `AIMarkdownBody` or `StreamingMessageView`,** and so nothing added to
`_fenceWidgetCache`'s key or to `didUpdateWidget`. Both lookups reach a chart through its own
`BuildContext`, and the inherited-dependency mechanism marks the cached element dirty on a change
regardless of widget identity — the same call 2.3 made for translations, asserted the same way in
`ai_markdown_body_test.dart` ("a chart theme reaches a cached fence": one identical widget instance,
two palettes). A `chartTheme` constructor argument left out of that global key would instead let two
differently-themed bodies share one palette.

**Accessibility: one node, and it excludes its subtree.** `Semantics(container: true,
excludeSemantics: true, label: …)`. `container` is load-bearing — without it the annotation is not a
semantic boundary and the label gets merged into an ancestor or dropped. Excluding is the judgement
call: `fl_chart` contributes nothing, but the axis tick labels and a heatmap's row, column and legend
labels *are* real `Text` widgets, and letting a reader walk them yields a run of bare numbers with
nothing saying which axis they belong to. The summary already carries the range, the counts and the
axis names. A host can only undo this by passing `semanticsLabel: ''` and wrapping the chart itself.

The summary is split in two so only the half that needs translating is translatable:
`ChartSemantics.fromSpec` gathers the facts (and formats the numbers for speech — `10.0` reads as
"10"), `AITranslations.chartSemanticsLabel` composes the sentence. That is one method rather than a
dozen phrase-sized ones because a whole sentence's word order varies far more between languages than
a tooltip's does. Sentences are `USpecKind`-aware; the heatmap's omits the series clause, since its
series *are* the rows it already counts. Per-point or per-series child nodes were not built — there
is no geometry to attach them to in a canvas-painted chart, and the summary is the large win.

This is also the first thing in the package to read `USpec.xLabel` / `USpec.yLabel`, which the
parsers had been filling in for nobody.

**Pie labels changed appearance.** White-on-slice is a contrast bug the moment a host supplies a pale
color, so the label now picks black or white per slice via
`ThemeData.estimateBrightnessForColor`. Under the shipped palette that flips every default pie label
from white to dark — a deliberate behaviour change, recorded in the CHANGELOG. The committed CI
goldens don't move: alchemist blocks `fl_chart`'s canvas-painted slice titles with an opaque paint
that ignores the text color.

**The parser's fallback names** are gone: `USpecParser` now leaves an unnamed series' `name` empty
and the render side substitutes `AITranslations.unnamedChartSeries`. The `'Pie'` variant was dropped
rather than given its own translation — a pie's slices are labelled from `UPoint.x` and its summary
has no series clause, so that string reached the screen nowhere.

**Left as private constants,** deliberately, and said so in `ChartThemeData`'s doc so the omissions
don't read as oversights: the area fill opacity, the bar rod width and spacing, the pie radius and
slice gap, the grid stroke width, the plot padding, and the axis gutter sizes — those last because
they exist only to match the `reservedSize` values handed to `fl_chart`, so making one themeable
without the other would silently stop a heatmap lining up with the bar chart above it. One known
consequence: `height` is settable while the pie's radius is not, so a much taller chart leaves the
pie undersized.

- **Files:** new `lib/src/theme/ai_theme.dart`, `lib/src/theme/components/chart_theme.dart`,
  `lib/src/chart/resolved_chart_theme.dart`, `lib/src/chart/chart_semantics.dart`;
  `lib/src/chart/chart_view.dart`, `lib/src/chart/heatmap_chart_view.dart`,
  `lib/src/chart/uspec.dart`, `lib/src/localization/ai_translations.dart`, the barrel; new
  `test/src/theme/ai_theme_test.dart`, `test/src/theme/chart_theme_test.dart`,
  `test/src/chart/chart_semantics_test.dart`, plus cases in `chart_view_test.dart`,
  `uspec_test.dart` and `ai_markdown_body_test.dart`; `example/lib/main.dart` (a brand palette, and
  pie and heatmap fences so the label contrast and the row-name fallback are visible); README.
- **Acceptance:** met — a host palette reaches `LineChartBarData.color`, `BarChartRodData.color` and
  `PieChartSectionData.color`; each kind exposes its summary under `tester.getSemantics`; all ten
  committed CI goldens are unchanged, defaults having been preserved verbatim.
- **Effort:** M, as estimated.

### 2.5 Theming for the remaining components

**Gap:** 2.4 built the `AITheme` machinery but gave it one component. Every other widget still
resolves its colors straight from the ambient `ColorScheme` with no seam for a host to intervene:

| Surface | Where |
|---|---|
| Input pill fill/border, hint color, selected-option chip, send/stop/mic colors | `chat_composer.dart` |
| The leading "+" button | `chat_composer_factory.dart` |
| Suggestion chip fill/border/text | `suggestions_view.dart` |
| Sheet tiles, the photo-grid selection ring | `composer_attachment_sheet.dart` |
| Dot color, count and size | `ai_typing_indicator_view.dart` (already constructor parameters) |
| Code block background/foreground | `code_block_view.dart` (already constructor parameters, and deliberately theme-independent — code reads as code) |

Swift's equivalent is its `Colors` struct, whose sub-structs are `composer` (`attachmentButtonIcon`,
`selectedOptionForeground`), `suggestions` (`background`) and `transcription` (`icon`) — a much
smaller surface than the list above, and injected per view rather than through a theme.

**Proposed work:** a `ChartThemeData`-shaped sibling per component — all-nullable fields, defaults
resolved in the widget's `build`, an `InheritedTheme` for subtree overrides, a new field on
`AITheme` — taking the composer and suggestions first, since those are what Swift covers. Whether
`CodeBlockView`'s two colors move onto the theme is a real question: they are deliberately
independent of the ambient `Theme`, and a `codeTheme` that a `ThemeData` change could reach would
undo that on purpose.

- **Reconsider then:** at five or six component themes the hand-written
  `copyWith`/`merge`/`lerp`/`==` stops being cheaper than `theme_extensions_builder`, which is what
  `stream_core_flutter` uses. Also a `BuildContext` extension, which 2.4 skipped because unprefixed
  getters would leak into a host's namespace for the sake of one component.
- **Acceptance:** a host theme overrides the composer and suggestion colors; existing appearance is
  unchanged with no theme registered; goldens re-baked on CI for whatever does move.
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

### Composer customisation: subclass a factory, not a builder registry 🅾️

`ChatComposerFactory` is a plain class you subclass and pass to `ChatComposer.factory`. The sibling
Flutter SDKs have converged on something structurally different, and the difference is worth
recording before someone "aligns" them by reflex.

`stream_core_flutter` ships `StreamComponentFactory` — an `InheritedWidget` holding a
`StreamComponentBuilders` value object of nullable `Widget Function(BuildContext, T props)`
builders, keyed by **props type**. `stream_chat_flutter` consumes it: each slot is a public widget
that looks its own override up and falls back to a `Default…` twin.

```dart
// stream_chat_flutter, message_composer_leading.dart
final leadingProps = MessageComposerLeadingProps.from(props);
return context.chatComponentBuilder<MessageComposerLeadingProps>()?.call(context, leadingProps)
    ?? DefaultStreamMessageComposerLeading(props: leadingProps);
```

That buys per-subtree overrides, override composition, and customisation without subclassing. It is
the better mechanism, and it is **not adopted here**, for one blocking reason: `StreamComponentFactory`
lives in `stream_core_flutter`, and this package's premise is that it depends on no Stream package
at all (see the top of `CLAUDE.md`). Adopting the pattern means reimplementing the primitive —
`InheritedWidget`, the typed builder registry, the extension lookup — which is a package-wide
change about how *every* component is customised, not a composer change.

Two consequences to keep in mind meanwhile:

- **The name collides with a different idea.** A reader arriving from `stream_chat_flutter` will
  expect `ChatComposerFactory.of(context)`. There is no such thing; the factory is a constructor
  argument.
- **The props are already shaped for the migration.** Slot props are per-slot types derived with
  `.from(...)`, which is exactly what a type-keyed registry dispatches on. If this is ever picked
  up, the cheapest path keeps today's method signatures and has `ChatComposer` consult a
  context-provided override *before* falling back to `widget.factory`, so existing factory
  subclasses keep working.

Reopen this if the package gains a second customisable surface of comparable size, or if the
no-Stream-dependency premise changes.

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
