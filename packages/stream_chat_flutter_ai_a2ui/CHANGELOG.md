## Upcoming

✅ Added

- New package for A2UI 1.0, the protocol an agent writes interactive UI in. In development.
- `A2UIRenderer`, which shows a reply's A2UI in the conversation's generative UI when added to the `AIUIHost`, with
  its `catalog`, `catalogId`, `theme`, `mediaUrl` and `onError`, and `A2UIRenderer.version`, `fence`,
  `defaultCatalogId`, `basicCatalogId` and `webUrl`.
- A button's event reaches the host as an `AIUIAction` labeled with the button's text, or else its event's name in
  words, with what the action asked for in its payload. Links open through the host, and functions the catalog
  doesn't have run as the host's tools.
- `A2UIError`, `A2UIErrorCode` and `A2UIErrorHandler`: the problems with a reply's A2UI, given to the renderer's
  `onError` with the reply's message id.
- The look and components of a reply's A2UI: `A2UITheme`, made from the app's Stream theme with
  `A2UITheme.fromStream`, and `A2UICatalog`, whose builders read a component through `A2UIComponentScope`.
- The components a person uses, in `A2UICatalog.basic`: `Button`, `TextField`, `CheckBox`, `ChoicePicker`,
  `Slider`, `DateTimeInput` and `Modal`.
- `A2UICatalog.basic` draws `Video`, with its poster until it plays, and `AudioPlayer`, with its description. Neither
  plays until the person taps play.
