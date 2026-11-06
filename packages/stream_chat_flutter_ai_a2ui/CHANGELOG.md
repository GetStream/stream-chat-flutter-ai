## Upcoming

✅ Added

- New package for A2UI 1.0, the protocol an agent writes interactive UI in.
- `A2UIRenderer`, which shows a reply's A2UI in the conversation's generative UI when added to the `AIUIHost`, with
  its `catalog`, `catalogId`, `theme`, `mediaUrl` and `onError`, and `A2UIRenderer.version`, `fence`,
  `defaultCatalogId`, `basicCatalogId` and `webUrl`.
- A button's event reaches the host as an `AIUIAction` labeled with the button's text, or else its event's name in
  words, with what the action asked for in its payload. Links open through the host, and functions the catalog
  doesn't have run as the host's tools.
- `A2UIRenderer` places the app's components (`AIUIHost.components`) in A2UI replies: the agent names one in
  PascalCase, such as `PlaceCard` for `place_card`, and its events are sent as actions whose payload names the
  component.
- `A2UIError`, `A2UIErrorCode` and `A2UIErrorHandler`: the problems with a reply's A2UI, given to the renderer's
  `onError` with the reply's message id. A function that fails or that no tool answers is reported as an expression
  error, a catalog function that fails while an action runs as an execution error, and a call whose surface is
  deleted before it's answered isn't reported.
- The look and components of a reply's A2UI: `A2UITheme` with `A2UIThemeData` overrides that default to the app's
  Stream theme with six heading sizes, and `A2UICatalog`, whose builders read a component through
  `A2UIComponentScope`.
- The components a person uses, in `A2UICatalog.basic`: `Button`, `TextField`, `CheckBox`, `ChoicePicker`,
  `Slider`, `DateTimeInput` and `Modal`.
- A2UI's buttons, check boxes, fields, images and sheets are drawn with Stream's design system, styled with the
  renderer's `A2UITheme`; an app's component themes apply to them, and its `StreamComponentFactory` builders for
  buttons, check boxes, text inputs and network images draw them. Date inputs and search fields are outlined as text
  fields are, and a sheet closes with the close button at its top.
- `A2UICatalog.basic` draws `Video`, with its poster until it plays, and `AudioPlayer`, with its description. Neither
  plays until the person taps play.
