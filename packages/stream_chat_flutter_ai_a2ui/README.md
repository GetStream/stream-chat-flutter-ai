# A2UI for Stream Chat AI Flutter components

Show the interactive UI an AI agent writes in [A2UI](https://a2ui.org) 1.0: cards, forms, lists, buttons and more,
drawn with your app's Stream design system, in light and dark.

This package is a renderer for the generative UI of
[`stream_chat_flutter_ai`](https://github.com/GetStream/stream-chat-flutter-ai/tree/main/packages/stream_chat_flutter_ai).
When the person taps a button, the host gets an `AIUIAction`; forward it to your agent.

- [Installation](#installation)
- [Quickstart](#quickstart)
- [Renderer options](#renderer-options)
- [Handling actions, links and tools](#handling-actions-links-and-tools)
- [What the agent is told](#what-the-agent-is-told)
- [Components](#components)
- [Theming](#theming)
- [Customising](#customising)
- [Errors](#errors)
- [Video and audio](#video-and-audio)
- [More](#more)

## Installation

```yaml
dependencies:
  stream_chat_flutter_ai: ^0.2.0
  stream_chat_flutter_ai_a2ui: ^0.2.0
```

Both packages are released together, with the same version.

## Quickstart

Add an `A2UIRenderer` to the conversation's `AIUIHost`, and give the host a `send` function for what the person does:

```dart
final ui = AIUIHost(
  renderers: [A2UIRenderer()],
  send: (action) async {
    // Forward the action to your agent as the person's next message.
    print('${action.label}: ${action.toJson()}');
  },
);

AIConversationView(messages: messages, ui: ui);
```

A reply shows its A2UI when the message carries a document in the A2UI format:

```dart
final reply = AIUIDocument(
  format: AIUIFormat.a2ui,
  version: A2UIRenderer.version,
  content: a2uiMessages, // The agent's A2UI messages, one JSON object per line.
);
```

The `AIMessage` that holds it returns it as its `uiDocument`. Your agent writes the messages inside a fenced block
(see [What the agent is told](#what-the-agent-is-told)); you take them out of the reply and put them in the document.

What the person sees:

- While the agent writes, the reply's text shows until the first surface arrives. Then each part comes in as it
  arrives.
- A reply shows its surfaces in place of its text. They keep what the person entered while the host keeps the reply, so
  a form survives scrolling.
- A tap on a button sends the host an action.

## Renderer options

| Option | What it does | Default | Change it to |
| --- | --- | --- | --- |
| `catalog` | The builder for each component type. | `A2UICatalog.basic` | Draw a component your way, or [remove one](#customising). |
| `catalogId` | The id the agent names your catalog by. It goes to the agent in the host's `capabilities`, and a surface that names no catalog gets this one. | `A2UIRenderer.defaultCatalogId` | Match the id your backend or prompt already uses. |
| `instructions` | Text the agent's model reads before A2UI's own instructions. | none | Say which answers to write as UI, or how to use your components. |
| `theme` | Overrides for the look of every surface. | none | Brand colors, fonts or corners; see [Theming](#theming). |
| `mediaUrl` | Gives the URL each image, video and audio clip loads from, or `null` to not load it. | `A2UIRenderer.webUrl`: web links only | Load from your own CDN or proxy, or allow other schemes. |
| `onError` | Receives the problems with a reply's A2UI. | debug builds only | Log or report them; see [Errors](#errors). |

```dart
final renderer = A2UIRenderer(
  instructions: 'Show places as cards, and plans as a list of steps.',
  mediaUrl: (url) => url.host == 'cdn.example.com' ? url : null,
);
```

## Handling actions, links and tools

**Actions.** A button whose action names an event calls the host's `send` with an `AIUIAction`:

- `name` is the event's name.
- `label`, the person's message, is the text of the button's child, or else the event's name in words (`Submit form`
  for `submit_form`). It is never the agent's own words.
- `payload` holds `surfaceId`, `sourceComponentId`, `context` (the values the agent asked for), the agent's
  `userMessage` when it wrote one, and the surface's `dataModel` when the agent asked for it.

`toJson()` gives the action for your backend. `toCustomData()` wraps it under the `ai_ui_action` key, for a chat
message's custom data:

```dart
send: (action) => channel.sendMessage(Message(text: action.label, extraData: action.toCustomData())),
```

**Links.** A link a button's action opens goes to the host's `open`, which by default opens only web and email
links. Only `http`, `https`, `mailto` and `tel` links reach it, so if you give the host your own `open`, check each
link before you open it.

**Tools.** A function the agent's UI calls that no catalog has runs as one of the host's `tools`. A read-only tool runs
whenever the UI calls it; any other only from the person's tap.

## What the agent is told

Send the host's `capabilities` to your backend, so the model knows what it can write. The renderer's part holds:

- `fence`: the fenced block the agent writes a reply's A2UI in (`A2UIRenderer.fence`).
- `catalog_id`: the id it names your catalog by.
- `instructions`: Markdown that explains the protocol, lists the host's `tools`, and describes the components as JSON
  Schema: the basic ones your `catalog` draws, and your own.

Your `instructions` come first. A component you take out of the catalog is left out of what the agent is told, and
one the agent writes anyway is reported to `onError` as a component the catalog doesn't have.

## Components

`A2UICatalog.basic` draws all 18 components of A2UI's basic catalog. The
[component reference](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md)
lists each one's properties, what it writes to the surface's data model, how it is checked and drawn, and its edge
cases.

| Component | Shows | Writes to the data model | Runs an action |
| --- | --- | --- | --- |
| [`Text`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#text) | Markdown text, in a body or caption style | | |
| [`Image`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#image) | An image, in a box sized by its variant | | |
| [`Icon`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#icon) | A named icon, or a shape drawn from an SVG path | | |
| [`Video`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#video) | A poster; plays the video when tapped | | |
| [`AudioPlayer`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#audioplayer) | A play button and a caption | | |
| [`Row`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#row), [`Column`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#column) | Children side by side, or one below the other, with weights | | |
| [`List`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#list) | Children in a column, or in a row that scrolls; may be a template over a list | | |
| [`Card`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#card) | One child on the surface color | | |
| [`Divider`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#divider) | A horizontal or vertical line | | |
| [`Tabs`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#tabs) | Tab titles over the selected tab's child | | |
| [`Modal`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#modal) | A trigger that opens a sheet with its content | | Its trigger's, if a `Button` |
| [`Button`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#button) | A button, disabled while one of its checks fails | | Yes |
| [`TextField`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#textfield) | A text field: short, long, number or secret | The text | |
| [`CheckBox`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#checkbox) | A check box with a label | `true` or `false` | |
| [`ChoicePicker`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#choicepicker) | Options to pick one or several of, as rows or chips, filterable | The picked values | |
| [`Slider`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#slider) | A slider over a range, with optional steps | The number | |
| [`DateTimeInput`](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md#datetimeinput) | A date, a time, or both, picked in the device's pickers | An ISO 8601 date or time | |

## Theming

A reply is drawn with your app's Stream theme, so it follows light and dark mode. Override any value with an
`A2UIThemeData`; what you leave unset still comes from the Stream theme.

```dart
final renderer = A2UIRenderer(theme: A2UIThemeData(accent: const Color(0xFFE65100), cornerRadius: 8));
```

A value that depends on the context goes in an `A2UITheme` above the conversation, which is read each time a reply
builds. `A2UITheme.merge` layers over an enclosing one:

```dart
A2UITheme(
  data: A2UIThemeData(cornerRadius: 8),
  child: AIConversationView(messages: messages, ui: ui),
)
```

### Restyle with your design system

Most input components are drawn by
[`stream_core_flutter`](https://pub.dev/packages/stream_core_flutter)'s components. Register a builder for one with
`StreamComponentFactory`, and it draws that component in A2UI replies too, as it does everywhere else in your app. Your
component themes apply as well.

```dart
final builders = StreamComponentBuilders(
  button: (context, props) {
    final button = FilledButton(
      onPressed: props.onPressed,
      style: FilledButton.styleFrom(shape: const StadiumBorder()),
      // A button of only an icon has no `child`: its icon is `iconLeft`.
      child: props.child ?? props.iconLeft ?? const SizedBox.shrink(),
    );
    final tooltip = props.tooltip;
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  },
);

MaterialApp(
  builder: (context, child) => StreamComponentFactory(builders: builders, child: child!),
  home: const ChatScreen(),
);
```

| A2UI component | Drawn by the builder |
| --- | --- |
| `Button`, and a button of only an `Icon` | `button` |
| `CheckBox` | `checkbox` |
| `ChoicePicker` with `multipleSelection` as rows | `checkbox` |
| `TextField`, and a `ChoicePicker`'s `filterable` search field | `textInput` |
| `Image`, and a `Video`'s poster | `networkImage` |

A `Modal`'s sheet takes the app's sheet theme, and your builders apply inside it. The other components, and a
`ChoicePicker` with a single choice or as chips, are drawn by this package from the A2UI theme.

A secret field (`TextField` with the `obscured` variant) never reaches your `textInput` builder, so it can't show the
secret. It is drawn in the same style.

The full list of builders and their props is in
[`stream_core_flutter`](https://pub.dev/packages/stream_core_flutter).

## Customising

### Replace or remove a component

The agent still writes the component as A2UI describes it. Only how it is drawn changes.

```dart
final catalog = A2UICatalog.basic
    .replacing('Card', (context, scope) {
      final child = scope.child();
      return BrandCard(child: child == null ? null : scope.build(child));
    })
    .removing(['Video']);

final renderer = A2UIRenderer(catalog: catalog);
```

Keep a catalog in a `final` or `static` field. A catalog made again in a `build` method is never equal to the last one,
and everything drawn with it builds again.

### Write your own builder

A builder is a function `Widget Function(BuildContext, A2UIComponentScope)`. The scope is what the agent wrote for one
component, with bindings already resolved. It builds again when the properties or children change.

| Read | |
| --- | --- |
| `id`, `type` | The component's id and type. |
| `value(name)` | A property as JSON, or `null`. |
| `string(name)` | A property as text: numbers, booleans, lists and maps are converted. `null` only when it is missing. |
| `number(name)`, `boolean(name)`, `stringList(name)` | A property as that type, or `null` when it isn't one. A numeric string counts as a number. |
| `hint(name)` | A style property such as `variant`, as the agent wrote it, never read from the data model. |
| `isBound(name)` | Whether the property is bound to the data model, so `write` can change it. |
| `child([name])`, `children([name])` | One child, or the list of children, as `A2UIChild`s. A child that shows nothing is left out. |
| `isValid`, `validationErrors` | Whether none of the component's checks blocks it, and their messages. |
| `hasAction` | Whether the agent gave the component an `action`. |

| Act | |
| --- | --- |
| `build(child)` | The widget of a child, drawn with the surface's catalog. |
| `write(name, value)` | Write a value to the data model path the property is bound to. |
| `performAction()` | Run the component's action as the person's own act. Call it only from their gesture. |

An `A2UIChild` has an `id`, a `key` that stays the same while the agent updates the surface (use it for
`ValueKey`), and a `weight` in a `Row` or `Column`.

A complete input: a switch that writes `true` or `false`, shows its failing checks, and runs its action.

```dart
Widget buildSwitch(BuildContext context, A2UIComponentScope scope) {
  final errors = scope.validationErrors;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SwitchListTile(
        title: Text(scope.string('label') ?? ''),
        value: scope.boolean('value') ?? false,
        // Read-only when the agent didn't bind the value to the data model.
        onChanged: scope.isBound('value')
            ? (value) {
                scope.write('value', value);
                if (scope.hasAction) scope.performAction();
              }
            : null,
      ),
      for (final error in errors) Text(error, style: const TextStyle(color: Colors.red)),
    ],
  );
}

final catalog = A2UICatalog.basic.replacing('CheckBox', buildSwitch);
```

### Place your app's components

The host's `components` are your own widgets, such as a place card, that the agent places too. It writes one by its name
in PascalCase, `PlaceCard` for `place_card`, with the component's parameters as properties, each a value or bound to the
surface's data:

```dart
final ui = AIUIHost(
  components: const [PlaceCardComponent()],
  renderers: [A2UIRenderer()],
  send: send,
);
```

```json
{"id": "naum", "component": "PlaceCard", "title": "Monastery of Saint Naum", "note": {"@path": "/boat"}}
```

- The component shows nothing while its values don't fit its parameters, such as while the agent is still writing them.
  Once the reply is written, values that don't fit, a missing required value, and anything the component throws are
  reported to `onError`.
- An event the component reports with `emit` is sent as an `AIUIAction` named after the event, with the label you gave
  and your payload, plus `component` (your name for it, such as `place_card`), `surfaceId` and `sourceComponentId`.
- An app component holds no other components and no `action`. One the agent can't place, such as one named like a basic
  component or with a parameter named `id` or `weight`, is left out and logged in debug builds.

## Errors

`onError` receives an `A2UIError` and the id of the reply it is in:

```dart
final renderer = A2UIRenderer(
  onError: (error, messageId) {
    debugPrint('A2UI problem in $messageId: ${error.code} ${error.message} (${error.surfaceId}${error.path ?? ''})');
  },
);
```

An `A2UIError` has a `code`, a `message` written for the developer of the agent, the `surfaceId` it is on, and a JSON
pointer `path` to where it is (`/version` for the message's version, `/text` for a component's property), when known.

Each problem arrives once, after the frame being built, so you can rebuild in the handler. It arrives again only if the
reply's messages changed rather than grew. Problems are values and are never thrown.

Without an `onError`, problems are reported in debug builds only. Messages that aren't JSON objects, and a finished
reply whose components don't form a whole tree, are reported in debug builds only, even with one.

| `A2UIErrorCode` | Means |
| --- | --- |
| `validationFailed` | A message, component or value doesn't match what A2UI or the catalog allows. |
| `unallowedParent`, `unallowedChild` | A component is placed where its catalog doesn't allow it. |
| `integrityError` | Messages contradict each other or the surfaces they name, such as an update for a surface that doesn't exist. |
| `invalidFunctionCall` | A function call the agent asked for can't run. |
| `expressionError` | A binding or function call can't be evaluated. |
| `executionError` | A function, an action or a builder failed while it ran. |
| `catalogNotFound` | A surface or component names a catalog this package doesn't have. |
| `recursionLimitExceeded` | Components hold each other, or nest or expand too far to build. |
| `unknownComponentType` | A component's type isn't in the catalog. |
| `invalidAction` | An action names no event or function. |
| `dataError` | A data model path can't be read or written. |
| `stateError` | Messages contradict a surface's own state. |

The codes are A2UI's, and this package doesn't report every one. A code is a string, so a code A2UI adds later still
arrives.

## Video and audio

A `Video` shows its poster and an `AudioPlayer` its description. Neither loads its media until the person taps play.
Media loads only from web links, unless you give the renderer another `mediaUrl`.

- **Android.** The app needs the `INTERNET` permission in its manifest (Flutter adds it only to debug and profile
  builds). Media over plain `http` also needs `android:usesCleartextTraffic="true"` on `<application>`.
- **macOS.** A sandboxed app needs the `com.apple.security.network.client` entitlement.
- **iOS and macOS.** Media over plain `http` needs `NSAllowsArbitraryLoadsForMedia` under `NSAppTransportSecurity` in
  `Info.plist`. That covers video and audio, not a video's poster or an `Image`, which need an ATS exception for their
  domain.
- Media over `https` needs nothing more.

A player is let go, and starts again from the beginning, when another screen is pushed over it. It plays on under a
bottom sheet or a dialog, such as a `Modal`. Players don't pause each other. When the app goes to the background, a
video pauses; audio keeps playing on Android, and on iOS follows the app's audio session and background modes.

## More

- [Example app](https://github.com/GetStream/stream-chat-flutter-ai/tree/main/packages/stream_chat_flutter_ai_a2ui/example):
  a streaming conversation, a page of examples for each component, and the examples published with A2UI's basic
  catalog. Each lists the actions the agent would get and the links that would open.
- [Component reference](https://github.com/GetStream/stream-chat-flutter-ai/blob/main/packages/stream_chat_flutter_ai_a2ui/doc/components.md).
