## Upcoming

✅ Added

- New package for A2UI 1.0, the protocol an agent writes interactive UI in.
- The look and components of a reply's A2UI: `A2UITheme` with `A2UIThemeData` overrides that default to the app's
  Stream theme, and `A2UICatalog`, whose builders read a component through `A2UIComponentScope`.
- The components a person uses, in `A2UICatalog.basic`: `Button`, `TextField`, `CheckBox`, `ChoicePicker`,
  `Slider`, `DateTimeInput` and `Modal`.
- `A2UIRenderer`, which shows a reply's A2UI in the conversation's generative UI when added to an `AIUIHost`, with
  `A2UIError` for the problems with a reply's A2UI.
- A function that fails or that no tool answers is reported as an expression error, a catalog function that fails
  while an action runs as an execution error, and a call whose surface is deleted before it's answered isn't reported.
- `A2UIRenderer` places the app's components (`AIUIHost.components`) in A2UI replies: the agent names one in
  PascalCase, such as `PlaceCard` for `place_card`, and its events are sent as actions whose payload names the
  component.
- `A2UICatalog.basic` draws `Video`, with its poster until it plays, and `AudioPlayer`, with its description. Neither
  plays until the person taps play.

