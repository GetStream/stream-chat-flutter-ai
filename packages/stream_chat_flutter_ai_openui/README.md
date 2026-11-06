# OpenUI for Stream Chat AI Flutter components

Shows the interactive UI that an agent writes in [OpenUI Lang](https://github.com/thesysdev/openui) 1.0 in its
replies, through the generative UI of [`stream_chat_flutter_ai`](../stream_chat_flutter_ai).

## Installation

```yaml
dependencies:
  stream_chat_flutter_ai: ^0.1.0
  stream_chat_flutter_ai_openui: ^0.1.0
```

Both packages are released together, with the same version.

## Showing replies

With an `OpenUIRenderer` in the conversation's `AIUIHost`, a reply whose UI is OpenUI shows the components its
program describes in place of its text:

```dart
final ui = AIUIHost(
  renderers: [OpenUIRenderer()],
  send: (action) => channel.sendMessage(Message(text: action.label, extraData: action.toCustomData())),
);

AIConversationView(messages: messages, ui: ui)
```

A backend that takes what the person did beside their message, rather than in the message's custom data, gets
`action.label` as the message's text and `action.toJson()` as the action.

While the agent is still writing a reply, the conversation shows it writing until the program has its root
component, and each component comes in as it arrives. A reply that ends without one shows its text. A reply keeps the
values the person entered while the host keeps the reply, so they survive scrolling. Buttons and fields can't be used
until the reply is written, and the program's queries run only then.

When the person taps a button, the host's `send` gets an `AIUIAction` named after the button's action, such as
`continue_conversation`. Its `label`, the person's message, is the button's label, or, when it has none, `AITranslations.uiActionUntitled` (`Continue` in English). Its
payload holds, when there are any, the action's `context`, its other `params`, the agent's own `message` for it when
it differs from the label, and, in a form, the form's name under `form` and its values under `values`. A password is
never sent.

A web or email link the program opens goes to the host's `open`, never to `send`. The program's queries and mutations
run as the host's `tools`: a query only with a read-only tool, a mutation from the person's tap. A query that
refreshes pauses while the app is in the background, but not while its reply is scrolled off screen.

Problems with a reply's program, such as a component the library doesn't have or a query whose tool failed, go to the
renderer's `onError` with the reply's message id, each once, after the reply is written, so the app can send them
back to the agent. So does what a component's builder throws. Without `onError`, problems are reported in debug builds
only, and what a builder throws goes to `FlutterError.reportError`.

## What the agent is told

The host's `capabilities`, which the app sends to its backend, hold the renderer's: the `fence` the agent writes a
reply's program in, `openui-lang`, and the `instructions` its model needs, in Markdown. They are the library's system
prompt, with its components, examples and rules, the app's components and the host's `tools`, each saying whether a
`Query()` may run it. The renderer's `instructions` come first, such as which answers to write as UI:

```dart
final renderer = OpenUIRenderer(instructions: 'Show places as cards, and plans as steps.');
```

## The components

`OpenUILibrary.chat`, the default, is OpenUI's chat library, whose programs are a `Card` with the answer in it, and
`OpenUILibrary.standard` its standard library, whose programs are a `Stack`. Both draw their content, data display,
card, layout, list, table, form, button and chart components. The charts are the core package's `ChartView`, drawn in
the colors of `OpenUIColors.chartPalette`.

To draw a component another way, replace its builder; the agent still writes the component as the library describes
it. `buildDefault` draws what the package draws for it:

```dart
final library = OpenUILibrary.chat.replacing('Callout', (context, scope) {
  return BrandFrame(child: scope.buildDefault());
});
final renderer = OpenUIRenderer(library: library);
```

Keep a library in a `final` or `static` field rather than making it again in a `build` method. A component taken out
with `removing` isn't in what the agent is told, and shows nothing:

```dart
final renderer = OpenUIRenderer(library: OpenUILibrary.chat.removing(['ImageGallery']));
```

## The app's components

The host's `components`, the app's own widgets such as a place card, can be placed by the agent too, wherever the
library's own content goes, such as in a chat `Card`. The agent writes one by its name in PascalCase, `PlaceCard` for
`place_card`, with the component's parameters as its arguments, in order:

```dart
final ui = AIUIHost(
  components: const [PlaceCardComponent()],
  renderers: [OpenUIRenderer()],
  send: (action) => channel.sendMessage(Message(text: action.label, extraData: action.toCustomData())),
);
```

```
naum = PlaceCard("Monastery of Saint Naum", "Take the 10:00 boat")
```

The component shows nothing while its values don't fit its parameters and the agent is still writing them. Once the
reply is written, values that don't fit, and anything the component throws, are handled as a builder's error. An
event the component reports with `emit` is sent as an `AIUIAction` named after the event, with the label the
component gave and its payload, to which `component` (the app's name for it, such as `place_card`) is added.

A component whose name is already taken, by one of the library's components or by an earlier app component, is left
out, and reported in debug builds.

## The look

A reply's OpenUI is drawn with the app's Stream design system, so it follows light and dark mode. An
`OpenUIThemeData` given to the renderer, or an `OpenUITheme` above the conversation, overrides any of its colors,
spacing, corner radii and text styles; the values it leaves unset still come from the Stream theme:

```dart
final renderer = OpenUIRenderer(
  theme: const OpenUIThemeData(colors: OpenUIColors(accent: Color(0xFFE65100))),
);
```

Buttons, check boxes, switches, fields, images, spinners and sheets are the design system's own components, so the
component builders an app registers with `StreamComponentFactory` (`button`, `checkbox`, `toggleSwitch`, `textInput`,
`networkImage`, `loadingSpinner`, `sheetHeader`) draw them in OpenUI replies too. A password field is never given to
the `textInput` builder.

Images load only from web links, unless the renderer is given another `mediaUrl`.

The [example](example) shows a conversation whose replies are OpenUI, one of them written line by line as an agent
streams it, and a gallery of the programs the library's prompts teach the model with, one with every chart type. It
lists each action the agent would get.

## Tests

The OpenUI Lang 1.0 conformance fixtures it is tested against are vendored, unchanged, under
[`test/conformance/upstream`](test/conformance/upstream), with their license, and
[`test/conformance/generated`](test/conformance/generated).
