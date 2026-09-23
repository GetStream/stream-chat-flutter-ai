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
