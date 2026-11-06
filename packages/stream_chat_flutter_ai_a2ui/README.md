# A2UI for Stream Chat AI Flutter components

Shows the interactive UI that an agent writes in [A2UI](https://a2ui.org) 1.0 in its replies, through the
generative UI of [`stream_chat_flutter_ai`](../stream_chat_flutter_ai).

## Installation

```yaml
dependencies:
  stream_chat_flutter_ai: ^0.1.0
  stream_chat_flutter_ai_a2ui: ^0.1.0
```

Both packages are released together, with the same version.

## Showing replies

With an `A2UIRenderer` in the conversation's `AIUIHost`, a reply whose UI is A2UI shows its surfaces in place of its
text:

```dart
final ui = AIUIHost(
  renderers: [A2UIRenderer()],
  send: (action) => channel.sendMessage(Message(text: action.label, extraData: action.toCustomData())),
);

AIConversationView(messages: messages, ui: ui)
```

A backend that takes what the person did beside their message, rather than in the message's custom data, gets
`action.label` as the message's text and `action.toJson()` as the action.

While the agent is still writing a reply, its text shows until the first surface arrives, and each part comes in as
it arrives. A reply keeps its surfaces while the host keeps the reply, so what the person enters survives scrolling.

When the person taps a button, the host's `send` gets an `AIUIAction` named after the button's event. Its `label`,
the person's message, is the text of the button's child, or else the event's name in words ("Submit form" for
`submit_form`), never the agent's own words for the action. Its payload holds `surfaceId`, `sourceComponentId`,
`context`, the agent's `userMessage` when it wrote one, and the surface's `dataModel` when the agent asked for it.

A web link the person's tap opens goes to the host's `open`. A function the agent's UI calls that no catalog has runs
as one of the host's `tools`: a read-only one whenever the UI calls it, any other only from the person's tap.

Problems with a reply's A2UI, such as a component the catalog doesn't have, go to the renderer's `onError` with the
reply's message id; without it they are reported in debug builds only. Messages that aren't JSON objects, and a
finished reply whose components don't form a whole tree, are reported in debug builds only.

## What the agent is told

The host's `capabilities`, which the app sends to its backend, hold the renderer's: the `fence` the agent writes a
reply's A2UI in, the `catalog_id` it names the app's catalog by, and the `instructions` its model needs, in Markdown.
They explain how a reply carries A2UI and the protocol, list the host's `tools`, and hold the catalog the agent writes
with as JSON Schema: the basic components the renderer's `catalog` draws and the app's components. The renderer's
`instructions` come first, such as which answers to write as UI:

```dart
final renderer = A2UIRenderer(instructions: 'Show places as cards, and plans as a list of steps.');
```

A component taken out of the catalog with `removing` isn't in what the agent is told, and one the agent writes anyway
is reported to `onError` as a component the catalog doesn't have:

```dart
final renderer = A2UIRenderer(catalog: A2UICatalog.basic.removing(['Video']));
```

## The app's components

The host's `components`, the app's own widgets such as a place card, can be placed by the agent too. The agent writes
one by its name in PascalCase, `PlaceCard` for `place_card`, with the component's parameters as its properties, each
a value or bound to the surface's data:

```dart
final ui = AIUIHost(
  components: const [PlaceCardComponent()],
  renderers: [A2UIRenderer()],
  send: (action) => channel.sendMessage(Message(text: action.label, extraData: action.toCustomData())),
);
```

```json
{"id": "naum", "component": "PlaceCard", "title": "Monastery of Saint Naum", "note": {"@path": "/boat"}}
```

The component shows nothing while its values don't fit its parameters, such as while the agent is still writing them,
and one the agent wrote without a required value, or with `null` for it, is reported to `onError`. A parameter's value
is passed as written or as the binding or function resolves it; the component itself decides whether it fits.

An event the component reports with `emit` is sent as an `AIUIAction` named after the event, with the label the
component gave, and its payload with `component` set to the component's name. An app component holds no other
components and no `action` of the agent's.

A component the agent can't place is left out, and reported in debug builds: one whose name in PascalCase isn't an
A2UI identifier, is `Surface`, or is the name of one of the basic catalog's components or of an earlier app
component, and one with a parameter whose name isn't an identifier or is `id` or `component`.

## The look

A reply's A2UI is drawn with the app's Stream design system, so it follows light and dark mode. An `A2UIThemeData`
given to the renderer, or an `A2UITheme` above the conversation, overrides any of its values; the ones it leaves unset
still come from the Stream theme, read each time the reply is built:

```dart
final renderer = A2UIRenderer(theme: A2UIThemeData(cornerRadius: 8));
```

The renderer's `theme` stays as it was given. An override that depends on the context, such as on the app's own
theme, goes in an `A2UITheme` above the conversation instead, which is read each time the reply is built too.

Buttons, check boxes, fields, images and sheets are the design system's own components, so the component builders an
app registers with `StreamComponentFactory` (`button`, `checkbox`, `textInput`, `networkImage`) draw them in A2UI
replies too, and its component themes apply to them. Around each surface, the design system's colors, body text and
corners are the A2UI theme's. A secret field is never given to the `textInput` builder, so it stays hidden.

## The components

`A2UICatalog.basic` draws A2UI's basic `Text`, `Image`, `Icon`, `Video`, `AudioPlayer`, `Row`, `Column`, `List`,
`Card`, `Divider`, `Tabs` and `Modal`, and the components a person uses: `Button`, `TextField`, `CheckBox`,
`ChoicePicker`, `Slider` and `DateTimeInput`. To draw one of them another way, replace its builder; the agent still
writes the component as A2UI describes it, and the renderer takes the catalog:

```dart
final catalog = A2UICatalog.basic.replacing('Card', (context, scope) {
  final child = scope.child();
  return BrandCard(child: child == null ? null : scope.build(child));
});
final renderer = A2UIRenderer(catalog: catalog);
```

A builder of a component a person uses writes what they enter to the surface's data model, and runs the component's
action when they use it:

```dart
final catalog = A2UICatalog.basic.replacing('CheckBox', (context, scope) {
  return Switch(
    value: scope.boolean('value') ?? false,
    onChanged: (value) => scope.write('value', value),
  );
});
```

The [example](example) shows a conversation whose replies are A2UI, one of them written part by part as an agent
would, and a gallery of the examples published with A2UI's basic catalog. Both list each action the agent would get,
and the gallery also lists each link that would open.

## Video and audio

A `Video` shows its poster and an `AudioPlayer` its description; neither loads its media until the person taps play.
Media loads only from web links, unless the renderer is given another `mediaUrl`. An app that plays media needs the
`INTERNET` permission in its Android manifest (Flutter adds it only to debug and profile builds), and a sandboxed macOS
app needs the `com.apple.security.network.client` entitlement. Media over `https` needs nothing more. Media over plain
`http` also needs `android:usesCleartextTraffic="true"` on the Android manifest's `<application>`, and
`NSAllowsArbitraryLoadsForMedia` under `NSAppTransportSecurity` in the `Info.plist` of an iOS or macOS app. That
covers the video and audio, not a video's poster or an `Image`, which need an ATS exception for their domain.

A player is let go, and starts again from the beginning, when another screen is pushed over it, but it plays on under a
bottom sheet or a dialog, such as a `Modal`.
Players don't pause each other. When the app goes to the background, a video pauses; audio keeps playing on Android,
and on iOS follows the app's audio session and background modes.

## Tests

The A2UI conformance suites it is tested against are vendored, unchanged, under
[`test/conformance/upstream`](test/conformance/upstream), with their license. The examples published with the basic
catalog are under [`test/fixtures/upstream_examples`](test/fixtures/upstream_examples). Why the suites are kept is in
[`test/conformance/README.md`](test/conformance/README.md).
