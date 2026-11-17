# OpenUI example

A conversation whose replies are OpenUI, shown by `stream_chat_flutter_ai_openui`'s `OpenUIRenderer` in light and dark.

A reply from history shows a booking card at once. Below it, the Ohrid trip example the Stream agent backend gives its
model is written line by line, as an agent streams it, through the custom data the backend writes on the message
(`AIUIDocument.fromCustomData`). Its places are the app's own `place_card` component; `TripMap` and `CalendarCheck`
aren't the app's, so the renderer reports them.

The Gallery tab draws the example programs the library's prompts teach the model with (`assets/gallery`), and one
with every chart type, one at a time. The replay button writes the chosen example line by line.

Below each, the app lists each action an agent would get, with its label and payload, and each problem the
renderer reports. Links open outside the app.

```bash
flutter run
```
