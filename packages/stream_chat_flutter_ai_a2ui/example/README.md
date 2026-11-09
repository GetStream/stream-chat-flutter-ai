# A2UI gallery

A conversation whose replies are A2UI, and a gallery of the examples published with A2UI's basic catalog and of the
Ohrid trip example the Stream agent backend gives its model, all shown by `stream_chat_flutter_ai_a2ui`'s
`A2UIRenderer` in light and dark.

"Conversation" writes the Ohrid reply line by line, as an agent streams it, below four replies from history that show
at once. Tapping a button sends the action as the person's next message, and "Read about Ohrid" opens its web page
outside the app.

In the gallery, an example that uses components neither the basic catalog nor the app has, such as the Ohrid example's
`TripMap` and `CalendarCheck`, says which. "Replay" writes an example
message by message, so components come in as they arrive.

Below both, the app lists what a person's actions did: each action an agent would get, with its label and payload.
The gallery also lists each link that would open.

```bash
flutter run
```
