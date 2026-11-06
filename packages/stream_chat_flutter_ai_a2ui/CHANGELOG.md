## Upcoming

✅ Added

- New package for A2UI 1.0, the protocol an agent writes interactive UI in.
- The look and components of a reply's A2UI: `A2UITheme` with `A2UIThemeData` overrides that default to the app's
  Stream theme with six heading levels in five sizes, and `A2UICatalog`, whose builders read a component through
  `A2UIComponentScope`.
- The components a person uses, in `A2UICatalog.basic`: `Button`, `TextField`, `CheckBox`, `ChoicePicker`,
  `Slider`, `DateTimeInput` and `Modal`.
- `A2UIRenderer`, which shows a reply's A2UI in the conversation's generative UI when added to an `AIUIHost`, with
  `A2UIError` for the problems with a reply's A2UI.
- A function that fails or that no tool answers is reported as an expression error, a catalog function that fails
  while an action runs as an execution error, and a call whose surface is deleted before it's answered isn't reported. A path
  in an event's context that can't be read is an expression error too.
- `A2UIRenderer` places the app's components (`AIUIHost.components`) in A2UI replies: the agent names one in
  PascalCase, such as `PlaceCard` for `place_card`, and its events are sent as actions whose payload names the
  component, its surface and its id. Values that don't fit a finished reply, and errors the component throws, are
  reported through `onError`.
- `A2UIRenderer.instructions` and the `instructions` of its `capabilities`: what the agent's model needs to write
  A2UI with the app's catalog, its components and the host's tools, after the app's own instructions. A component
  taken out with `A2UICatalog.removing` is left out of it, and reported as unknown when the agent writes it anyway.
- A2UI's buttons, check boxes, fields, images and sheets are drawn with Stream's design system, styled with the
  renderer's `A2UITheme`; an app's component themes apply to them, and its `StreamComponentFactory` builders for
  buttons, check boxes, text inputs and network images draw them.
- `A2UICatalog.basic` draws `Video`, with its poster until it plays, and `AudioPlayer`, with its description. Neither
  plays until the person taps play.
- `A2UIMediaUrl`, the signature of `A2UIRenderer.mediaUrl`.
