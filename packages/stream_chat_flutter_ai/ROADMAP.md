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
| 2.4 | Chart theming & accessibility | 2 | M | ⬜ |
| 3.1 | Client-side tool-calling (`AIToolRegistry`) | 3 | L | ✅ |
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
`InheritedTheme` scope read through a static `of(context)` that falls back to that default rather
than asserting — see `lib/src/localization/ai_translations.dart`, including why the scope is an
`InheritedTheme` and not a plain `InheritedWidget`. Unlike translations, a theme has a
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

### 3.1 Client-side tool-calling (`AIToolRegistry`) ✅

**Gap:** Swift ships `Tools/ClientToolRegistry.swift` (`ClientTool`, `ClientToolRegistry`,
`ClientToolInvocation`, `ClientToolAction`, `ToolRegistrationPayload`), letting a host app register
client-side tools the AI can invoke. Flutter had nothing in this space.

**Correction to the premise, found during the design spike.** This item was written as "MCP
client-tool", with the spike expected to choose between `dart_mcp`, `mcp_dart`, and a hand-rolled
registry. The protocol turns out not to be MCP at all:

- Tool definitions are plain JSON Schema. The host POSTs them to its **own** backend (the reference
  Node sample exposes `/register-tools` taking `{channel_id, tools}`), which calls the agent SDK's
  `registerClientTools(channelId, tools)`. That **persists the definitions server-side and
  re-applies them the next time the channel's agent starts** — the single fact that shaped this API
  most.
- The AI invokes a tool by emitting a Stream Chat custom event `custom_client_tool_invocation`
  carrying `{cid, message_id, tool, args}`.
- **Nothing is returned to the model.** Actions are fire-and-forget side effects; there is no
  tool-result loop to build.

`Package.swift` does declare `modelcontextprotocol/swift-sdk`, but the entire use of it in `Tools/`
is two type references: `Tool` (a five-field struct) and `Value` (MCP's JSON-value enum, which is
why iOS spells an empty schema `.object(["type": .string("object"), …])`). No JSON-RPC, no
transport, no client, no session. The one thing MCP buys Swift is a type-safe JSON value, which in
Dart is `Map<String, Object?>` — so **no dependency was adopted**, and none is needed.

> Unverified from this repository: neither the Swift package nor `chat-ai-samples` is vendored here,
> so the claims above reflect what those sources said when this was written, and no CI check here
> can re-verify them.

**Shipped** — `lib/src/tools/`, pure Dart, no widgets:

```dart
class AIToolDefinition {
  const AIToolDefinition({
    required String name,
    required String description,
    String? instructions,
    Map<String, Object?> parameters = /* empty object schema */,
    bool showExternalSourcesIndicator = false,
  });
  Map<String, Object?> toJson();
}

typedef AIToolAction = FutureOr<void> Function();

abstract class AIClientTool {
  AIToolDefinition get definition;
  List<AIToolAction> handleInvocation(AIToolInvocation invocation);
}

class AIToolRegistry {
  List<String> get toolNames;
  void register(AIClientTool tool);
  bool unregister(String name);
  List<Map<String, Object?>> registrationPayloads();
  List<AIToolAction>? resolve(AIToolInvocation invocation);   // null = no such tool
  Future<bool> dispatch(AIToolInvocation invocation);         // bool = coverage, not success
}

// Plus AIToolInvocation.tryParse(Map<String, Object?>), AIInvokedTool, and
// kClientToolInvocationEventType.
```

**Where the seam sits.** The same place iOS puts it: the package holds the types and the name→tool
routing, and the host keeps everything that touches the network or the chat SDK. In
`chat-ai-samples/ios/AIComponents/` that is `TypingIndicatorHandler.swift` (event → invocation),
`AgentService.swift` (the `/register-tools` POST) and `ClientToolActionHandler.swift` (running the
closures). Here it is a `channel.on(...)` listener and an HTTP call, both shown in the README. No
`stream_chat` dependency was added, and none is implied.

**Decisions worth not re-litigating:**

- **Tools return deferred `AIToolAction`s** rather than acting, as in Swift. Not for testability — an
  opaque closure isn't much more testable — but because a host needs the actions *as values*: to run
  them where a `BuildContext` exists, queue them until the app is foregrounded, or drop them because
  the user left that channel. A `List` rather than one closure buys per-action error isolation.
  `FutureOr<void>` rather than `VoidCallback` so `dispatch` can catch a throw *after* an action's
  first `await`, which a `void` return would leak to the zone.
- **`resolve` returns `null` for an unregistered name, and that is not a `FlutterError`.** Because
  registrations outlive the build that made them, an old build receiving an invocation for a tool it
  dropped is expected and outside the app's control. `FlutterError` stays the bug channel; a tool
  that throws is reported there and `dispatch` still returns `true`, keeping coverage and success on
  separate axes.
- **`register` overwrites silently.** An assert can't distinguish a benign re-register (a
  `State.initState` running again, a hot reload) from two features colliding on one name, so it
  would only fire on the harmless case.
- **No `ToolRegistrationPayload` and no `ClientToolActionHandling`.** The first is a duplicate of
  `AIToolDefinition` once `description` is required (Swift needs it because MCP's is optional and
  falls back to `instructions`); the second exists to hold an `AnyObject`, which Dart doesn't need.
- **Names follow 1.1's convention** (`AIToolRegistry`, `AIClientTool`), not this item's draft
  `StreamAiClientTool` — the package dropped the `Stream` prefix from every public type in 0.0.1.
- **No widget work.** `showExternalSourcesIndicator` makes the *server* emit its "checking external
  sources" state, which `AITypingIndicatorView` already renders from a plain string.

- **Files:** new `lib/src/tools/ai_tool_definition.dart`, `ai_tool_invocation.dart`,
  `ai_tool_registry.dart`; exported from `lib/stream_chat_flutter_ai.dart`; README section plus the
  `channel.on` glue under **Using with Stream Chat**.
- **Acceptance:** met by `test/src/tools/` — the documented event payload, parsed by `tryParse`,
  routed through `dispatch`, asserting the tool's action ran; plus the `null`-vs-`[]` distinction,
  action ordering, and every failure path. The worked example lives in the README rather than the
  example app.
- **Follow-ups, deliberately not in scope:** wire the example app with a synthetic invocation
  trigger; wire `chat-ai-samples/flutter` end-to-end the way the iOS sample is (separate repo); and
  a real MCP client transport, if talking to MCP servers directly ever becomes a requirement — it is
  unrelated to this protocol.
- **Effort:** L as estimated, though the spike removed most of the risk by deleting the dependency
  question.

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
- **Invocation events parse themselves:** `AIToolInvocation.tryParse` turns a
  `custom_client_tool_invocation` payload into a typed invocation with decoded arguments, tolerating
  the `arguments`-as-JSON-string form the Anthropic/OpenAI tool-calling APIs emit. Swift's
  `ClientToolInvocation` carries raw `Data` and offers no initializer from an event, so the iOS
  sample has to define its own `ClientToolInvocationEventPayload` plus a `RawJSON` encoding
  extension — work every host would otherwise repeat. See 3.1.
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
