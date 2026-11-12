# A2UI gallery

A conversation whose replies are A2UI, a page of examples for each component of the basic catalog, and a gallery of
the examples published with A2UI's basic catalog and of the Ohrid trip example the Stream agent backend gives its
model, all shown by `stream_chat_flutter_ai_a2ui`'s `A2UIRenderer` in light and dark.

"Conversation" writes the Ohrid reply line by line, as an agent streams it, below four replies from history that show
at once. Tapping a button sends the action as the person's next message, and "Read about Ohrid" opens its web page
outside the app.

## Components

One page for each of the 18 components of `A2UICatalog.basic`, from `assets/components/<name>.json` (`audio_player` for
`AudioPlayer`). A page shows one to three surfaces, each captioned with what it shows: the component's variants, and
the cases that need care, such as a secret `TextField`, a `Slider` whose `value` isn't bound to the data model, and a
`Button` that a failing check disables. The [component reference](../doc/components.md) links each page, and a test
keeps them in step.

Each page is a file of the same shape as the published examples: a `name`, a `description` and the A2UI `messages`.

## Examples

The examples published with A2UI's basic catalog, and the Ohrid example, listed after the components. An example that
uses components neither the basic catalog nor the app has, such as the Ohrid example's `TripMap` and `CalendarCheck`,
says which.

"Replay", on a component's page and on an example's, writes its messages one by one, so components come in as they
arrive.

Below each page, the app lists what a person's actions did: each action an agent would get, with its label and
payload. The gallery also lists each link that would open, and each problem the renderer reports, such as the
`Slider` that isn't bound.

```bash
flutter run
```
