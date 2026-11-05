## Upcoming

✅ Added

- New package that shows the interactive UI an agent writes in [A2UI](https://a2ui.org) 1.0 in its replies, through
  the generative UI of `stream_chat_flutter_ai`. Released in lockstep with it.
- `A2UIRenderer`, added to the conversation's `AIUIHost`, shows a reply's A2UI surfaces in place of its text, part by
  part while the agent writes it. It takes a `catalog`, `catalogId`, `theme`, `mediaUrl` and `onError`, and exposes
  `A2UIRenderer.version`, `fence`, `defaultCatalogId`, `basicCatalogId` and `webUrl`.
- `A2UICatalog.basic` draws A2UI's basic components: `Text`, `Image`, `Icon`, `Video`, `AudioPlayer`, `Row`,
  `Column`, `List`, `Card`, `Divider`, `Tabs` and `Modal`, and the components a person uses, `Button`, `TextField`,
  `CheckBox`, `ChoicePicker`, `Slider` and `DateTimeInput`. A catalog's components are replaced with
  `A2UICatalog.replacing` and removed with `removing`; an `A2UIComponentBuilder` reads its component, writes to the
  surface's data and runs its action through `A2UIComponentScope`, and builds its children from `A2UIChild`.
- `A2UITheme`, made from the app's Stream theme with `A2UITheme.fromStream` and changed with `copyWith`. Buttons,
  check boxes, fields, images and sheets are drawn with Stream's design system, so the app's component themes and its
  `StreamComponentFactory` builders for buttons, check boxes, text inputs and network images apply to them. The
  components' look matches the iOS and Android A2UI renderers.
- What the person does reaches the host: a button's event is sent as an `AIUIAction` labeled with the button's text,
  or else its event's name in words, with what the action asked for in its payload. Links open through the host's
  `open`, and functions the catalog doesn't have run as the host's `tools`.
- The app's components (`AIUIHost.components`) can be placed in A2UI replies: the agent names one in PascalCase, such
  as `PlaceCard` for `place_card`, and its events are sent as actions whose payload names the component.
- `A2UIError`, `A2UIErrorCode` and `A2UIErrorHandler`: the problems with a reply's A2UI, such as a component the
  catalog doesn't have or a function that fails, given to the renderer's `onError` with the reply's message id.
- `Video` shows its poster and `AudioPlayer` its description until the person taps play; media loads only from web
  links unless the renderer is given another `mediaUrl`.
