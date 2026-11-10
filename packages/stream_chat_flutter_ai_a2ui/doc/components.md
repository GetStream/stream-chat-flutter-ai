# Components

What each component of `A2UICatalog.basic` supports, as the renderer draws it: the properties the agent writes, what
the component writes back to the surface's data model, what it does when a person uses it, how it is drawn with the
Stream design system, and how it behaves when what the agent wrote is incomplete.

The agent writes the components as [A2UI 1.0's basic catalog](https://a2ui.org) describes them. This page covers
what that catalog leaves to the renderer. Every example below is a copy of a page in the
[example app's gallery](../example#components) (the file is linked from each component), where each one runs.

- [Common to every component](#common-to-every-component)
- Content: [Text](#text), [Image](#image), [Icon](#icon), [Video](#video), [AudioPlayer](#audioplayer)
- Layout: [Row](#row), [Column](#column), [List](#list), [Card](#card), [Divider](#divider), [Tabs](#tabs),
  [Modal](#modal)
- Input: [Button](#button), [TextField](#textfield), [CheckBox](#checkbox), [ChoicePicker](#choicepicker),
  [Slider](#slider), [DateTimeInput](#datetimeinput)
- [The app's components](#the-apps-components)
- [Agent functions](#agent-functions)

## Common to every component

**Values.** A property that takes a "dynamic" value is written as the value itself, as a binding to the data model,
`{"@path": "/name"}`, or as a call of a function, `{"@call": "formatString", "args": {...}}`. The component reads
it again when the data model changes. A component of the catalog that is missing a required property, or has one of
the wrong type, is not drawn, and the problem is reported to the renderer's `onError`. Properties that only choose how a
component looks, such as `variant`, `fit`, `justify`, `align`, `direction`, `axis` and `displayStyle`, never drop the
component: a value the catalog doesn't list is drawn in the property's default style.

**`weight`.** A child of a `Row` or `Column` may carry a `weight`, its share of the free space along the container, as
CSS's `flex-grow`. See [Row](#row).

**`accessibility`.** Any component may carry `{"label": ..., "description": ..., "hidden": ..., "live": ...}`, each value
a string, a binding, or (for `hidden`) a boolean. The label and description are what assistive technologies read, in
place of the text inside the component and after it. A hidden component is skipped by assistive technologies. With
`"live": "polite"` or `"assertive"`, the component's label, or else its text, is announced when it changes. For the
components a person uses, the label and description go on the part the person interacts with.

**`checks`.** The components a person uses (`Button`, `TextField`, `CheckBox`, `ChoicePicker`, `Slider` and
`DateTimeInput`) may carry `checks`, a list of `{"condition": ..., "message": ...}`. A check fails when its condition is
false. A condition that reads nothing yet, such as data still on its way, passes, so a form isn't blocked while it
streams in. A condition that can't be evaluated fails with the check's message, or "This value could not be checked.".
A condition may also be a function's result `{"valid": ..., "message": ..., "severity": ...}`, whose `severity` is
`error` (the default), `warning` or `info`. Every failing check's message shows below the component, in the theme's
error, warning or secondary text color, in the order the agent wrote them. Only an `error` blocks: a `Button` stays
disabled while one of its checks fails with an error.

**Look.** Each component takes its colors, text styles and corner radii from the Stream theme, through
[`A2UIThemeData`](../lib/src/catalog/a2ui_theme.dart) when the app overrides any of them. Where a component is
drawn by a Stream design system component, the app's own builder for it, registered with `StreamComponentFactory`,
draws it in A2UI replies too; each section names the hook. To draw a component another way altogether, replace its
builder in the catalog; see the [README](../README.md#replace-or-remove-a-component).

## Text

Shows `text` as Markdown.

| Property | Type | Notes |
| --- | --- | --- |
| `text` | dynamic string, required | Markdown without HTML, images or links. |
| `variant` | `body` (default), `caption` | The caption is smaller, in the secondary text color. |

- **Data model.** Reads `text`; writes nothing. It follows the data model as it changes.
- **Markdown.** Headings, emphasis, lists, quotes, code and rules show as Markdown does, in the theme's body and
  heading styles. A link shows as its text and opens nothing; an image shows as its description. Text with none of the
  characters Markdown is written with is drawn as it is, without parsing it.
- **Look.** The theme's `body`, `caption` and `headings` styles, `secondaryText`, `subtleSurface` (code) and `border`.
- **Edge cases.** A `Text` whose `text` reads nothing, such as a binding to data that hasn't arrived, shows nothing.

```json
[
  {"id": "root", "component": "Column", "children": ["body", "caption"]},
  {"id": "body", "component": "Text", "text": "Body text is the default.", "variant": "body"},
  {"id": "caption", "component": "Text", "text": "Caption text is smaller and quieter.", "variant": "caption"}
]
```

More: [`text.json`](../example/assets/components/text.json): Markdown, and text bound through `formatString`.

## Image

Shows the image at `url`, in a box whose size the `variant` sets.

| Property | Type | Notes |
| --- | --- | --- |
| `url` | dynamic string, required | Must be a URL with a scheme. |
| `description` | dynamic string | The accessibility label. |
| `variant` | `icon` (24), `avatar` (48, a circle), `smallFeature` (72), `mediumFeature` (160, default), `largeFeature` (240), `header` (full width, 200 tall) | Sizes in logical pixels. An unknown variant is a `mediumFeature`. |
| `fit` | `fill` (default), `contain`, `cover`, `none`, `scaleDown` | As CSS's `object-fit`. |

- **Data model.** Reads its properties; writes nothing.
- **Box.** The box's size depends on the variant alone, never on the image, so an image never moves the layout around
  it. While the image loads the box shows the subtle surface color and a spinner. The image is decoded at the width
  its box needs, never above 2048 pixels.
- **Look.** Drawn with the design system's `StreamNetworkImage`, so the app's `networkImage` builder loads it instead;
  a builder that ignores the `errorBuilder` draws its own failure. Corners follow `controlCornerRadius`.
- **Edge cases.** An image that can't load, whose URL has no scheme, or whose URL the renderer's `mediaUrl` function
  refuses leaves the box empty; in debug builds the reason is logged once. Without a `description` (or an
  `accessibility` label) assistive technologies skip the image.

```json
[
  {"id": "root", "component": "List", "direction": "horizontal", "align": "center", "children": ["i1", "i2", "i3", "i4"]},
  {"id": "i1", "component": "Image", "url": "https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=200&h=300&fit=crop", "description": "A film poster", "variant": "icon"},
  {"id": "i2", "component": "Image", "url": "https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=200&h=300&fit=crop", "description": "A film poster", "variant": "avatar"},
  {"id": "i3", "component": "Image", "url": "https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=200&h=300&fit=crop", "description": "A film poster", "variant": "smallFeature"},
  {"id": "i4", "component": "Image", "url": "https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=200&h=300&fit=crop", "description": "A film poster", "variant": "mediumFeature"}
]
```

More: [`image.json`](../example/assets/components/image.json): fits, and a header with a URL that isn't one.

## Icon

Shows a named icon, or a shape the agent draws.

| Property | Type | Notes |
| --- | --- | --- |
| `name` | a name, `{"svgPath": ...}`, or a binding, required | One of the basic catalog's icon names, such as `home`, `search` or `favorite`; or an SVG path in a 24 by 24 box. |

- **Data model.** Reads `name`; writes nothing.
- **Look.** The names are rounded Material icons. The icon is drawn in the color of the surrounding `IconTheme`, so
  inside a `Button` it follows the button's text color. A drawn shape is filled in that color.
- **Edge cases.** A name the catalog doesn't have, a missing name and a path that can't be drawn show a help icon; in
  debug builds a path that can't be drawn is logged. A named icon's name is its accessibility label; a drawn shape has
  none.

```json
[
  {"id": "root", "component": "Row", "children": ["home", "search", "favorite"], "justify": "spaceBetween"},
  {"id": "home", "component": "Icon", "name": "home"},
  {"id": "search", "component": "Icon", "name": "search"},
  {"id": "favorite", "component": "Icon", "name": "favorite"}
]
```

More: [`icon.json`](../example/assets/components/icon.json): an `svgPath`, and an unknown name.

## Video

Shows a poster with a play button; the video plays when the person taps it.

| Property | Type | Notes |
| --- | --- | --- |
| `url` | dynamic string, required | Loaded only when the person taps play, and only from a web link unless the renderer is given another `mediaUrl`. |
| `posterUrl` | dynamic string | The only thing that loads before play. |

- **Data model.** Reads its properties; writes nothing.
- **Box.** 200 logical pixels tall and as wide as it is given (16 by 9 where nothing limits the width). It never plays
  on its own; while it plays, a tap pauses it.
- **Lifecycle.** The player is let go, and where it had played to is lost, when the component leaves the tree, when its
  `url` changes, and when a screen pushed over the conversation covers it. It plays on under a bottom sheet or dialog,
  such as a `Modal`. Players don't pause each other. See [Video and audio](../README.md#video-and-audio) for the
  platform setup media needs.
- **Edge cases.** A `url` that is missing, has no scheme, or is refused by `mediaUrl` shows the box with a sign that it
  can't play, and no play button. A video that fails to load or play shows the play button again, so a tap tries again;
  the failure goes to `FlutterError.reportError`.

```json
[
  {"id": "root", "component": "Video", "url": "https://www.w3schools.com/html/mov_bbb.mp4", "posterUrl": "https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=200&h=300&fit=crop"}
]
```

More: [`video.json`](../example/assets/components/video.json): a video with no URL.

## AudioPlayer

A play and pause button for the audio at `url`, with its `description` as a caption.

| Property | Type | Notes |
| --- | --- | --- |
| `url` | dynamic string, required | Loaded only when the person taps play, from a web link unless the renderer is given another `mediaUrl`. |
| `description` | dynamic string | The caption, one line in the box's bottom corner. |

- **Data model.** Reads its properties; writes nothing.
- **Box.** 80 logical pixels tall and as wide as it is given. It never plays on its own; when it ends it goes back to
  the start. The player's lifecycle is [the video's](#video).
- **Edge cases.** A `url` that is missing, has no scheme, or is refused by `mediaUrl` shows the box with a speaker and
  no button. Audio that fails to load or play shows the play button again, so a tap tries again.

```json
[
  {"id": "root", "component": "AudioPlayer", "url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3", "description": "SoundHelix Song 1"}
]
```

More: [`audio_player.json`](../example/assets/components/audio_player.json): audio with no URL.

## Row

Its children side by side, filling the width it is given.

| Property | Type | Notes |
| --- | --- | --- |
| `children` | list of ids, or a template, required | A template `{"componentId": ..., "path": ...}` makes one child for each item of the list at `path`. |
| `justify` | `start` (default), `center`, `end`, `spaceBetween`, `spaceAround`, `spaceEvenly`, `stretch` | Along the row. |
| `align` | `stretch` (default), `start`, `center`, `end` | Across the row. |

A child may carry a `weight`.

- **Weights.** Children without a weight keep their natural width, all shrinking in proportion when they don't fit.
  Children with a weight above 0 share what is left, in proportion to their weights. Only the proportions count.
- **Children that fill the width.** A `TextField`, `Slider` or `DateTimeInput`, or a `ChoicePicker` with a filter,
  that has no weight shares the free space of a row with a width as if its weight were 1. Where a row has no width
  limit, such as in a `List` that scrolls sideways, they are 280 logical pixels wide.
- **Look.** Children are 8 logical pixels apart.
- **Edge cases.** A vertical `Divider` in a row is as tall as the row, whatever its `align`.

```json
[
  {"id": "root", "component": "Row", "children": ["a", "b"]},
  {"id": "a", "component": "Card", "child": "a_t", "weight": 1},
  {"id": "b", "component": "Card", "child": "b_t", "weight": 2},
  {"id": "a_t", "component": "Text", "text": "Weight 1"},
  {"id": "b_t", "component": "Text", "text": "Weight 2"}
]
```

More: [`row.json`](../example/assets/components/row.json): `justify` and `align`.

## Column

Its children one below the other, with `justify`, `align` and weights as a [Row](#row) has them (`align` is across,
horizontally).

| Property | Type | Notes |
| --- | --- | --- |
| `children` | list of ids, or a template, required | As a `Row`'s. |
| `justify` | as a `Row` | Down the column. |
| `align` | `stretch` (default), `start`, `center`, `end` | Across the column. |

- **Edge cases.** A column in a conversation has no height of its own, so its weights only count when it is
  given a height.

```json
[
  {"id": "root", "component": "Column", "children": ["a", "b"], "align": "center"},
  {"id": "a", "component": "Text", "text": "A short line"},
  {"id": "b", "component": "Text", "text": "A somewhat longer second line"}
]
```

More: [`column.json`](../example/assets/components/column.json).

## List

Its children one below the other, or side by side in a row that scrolls.

| Property | Type | Notes |
| --- | --- | --- |
| `children` | list of ids, or a template, required | As a `Row`'s. |
| `direction` | `vertical` (default), `horizontal` | |
| `align` | `stretch` (default), `start`, `center`, `end` | Across the list. |

- **Scrolling.** A vertical list grows with its children and doesn't scroll; the conversation around it does. A
  horizontal one scrolls sideways.
- **Templates.** With a template, the list shows one child for each item of the list in the data model, and follows
  the list as it changes. Inside the template, a path that doesn't start with `/` reads the item.
- **Edge cases.** A surface whose components expand to more than 5,000, counting a template's once for each item, or
  that nest more than 50 levels deep, shows nothing until it fits, and is reported once as `RECURSION_LIMIT_EXCEEDED`.
  A modal with its sheet open stays while a list it is in scrolls it out of view.

```json
[
  {"id": "root", "component": "List", "children": {"componentId": "item", "path": "/places"}},
  {"id": "item", "component": "Text", "text": {"@path": "name"}}
]
```

```json data
{"places": [{"name": "Lake Ohrid"}, {"name": "Saint Naum"}, {"name": "Samuel's Fortress"}]}
```

More: [`list.json`](../example/assets/components/list.json): a horizontal list.

## Card

A child on the surface color, with rounded corners, across the width it is given.

| Property | Type | Notes |
| --- | --- | --- |
| `child` | id, required | Exactly one; wrap several in a `Column`. |

- **Layout.** The child has 12 logical pixels of space around it, keeps its own size and sits at the card's start.
- **Look.** The theme's `surface` and `cornerRadius`.
- **Edge cases.** A card whose child hasn't arrived yet is drawn empty.

```json
[
  {"id": "root", "component": "Card", "child": "text"},
  {"id": "text", "component": "Text", "text": "A card holds exactly one child."}
]
```

More: [`card.json`](../example/assets/components/card.json): a card of a column with a button.

## Divider

A line across the width it is given, or down the height it is given.

| Property | Type | Notes |
| --- | --- | --- |
| `axis` | `horizontal` (default), `vertical` | |

- **Look.** One logical pixel thick, in the theme's `border` color.
- **Edge cases.** A vertical divider needs a height: in a `Row` it is as tall as the row.

```json
[
  {"id": "root", "component": "Column", "children": ["above", "line", "below"]},
  {"id": "above", "component": "Text", "text": "Above"},
  {"id": "line", "component": "Divider"},
  {"id": "below", "component": "Text", "text": "Below"}
]
```

More: [`divider.json`](../example/assets/components/divider.json): a vertical divider in a row.

## Tabs

A row of titles over the child of the selected tab.

| Property | Type | Notes |
| --- | --- | --- |
| `tabs` | list of `{"title": dynamic string, "child": id}`, at least one, required | |

- **Selection.** The first tab is selected until the person taps another. The selection is kept by the widget; it is not
  written to the data model and not sent to the agent.
- **Titles.** The row of titles scrolls sideways when they don't fit. Each is at least 48 logical pixels tall to tap.
- **Look.** The selected title is in the theme's `accent`, on a faint accent capsule; the others in `secondaryText`.
- **Edge cases.** The agent may send fewer tabs than there were: the selection stays in range. A tab whose child shows
  nothing, such as one that hasn't arrived yet, shows its title over nothing. Without tabs the component shows nothing.

```json
[
  {"id": "root", "component": "Tabs", "tabs": [{"title": "Overview", "child": "overview"}, {"title": "Details", "child": "details"}]},
  {"id": "overview", "component": "Text", "text": "A weekend in Ohrid."},
  {"id": "details", "component": "Text", "text": "Two nights, a boat trip and a monastery."}
]
```

More: [`tabs.json`](../example/assets/components/tabs.json): enough tabs to scroll.

## Modal

A `trigger` in place, which opens its `content` in a sheet from the bottom of the screen.

| Property | Type | Notes |
| --- | --- | --- |
| `trigger` | id, required | Usually a `Button`. |
| `content` | id, required | Shown in the sheet. |

- **Opening.** A `Button` trigger opens the sheet when tapped, and still runs its own `action`; a disabled button opens
  nothing. A trigger that isn't a button opens the sheet when the person taps it, read by assistive technologies as a button.
  What a button in the trigger holds doesn't open the sheet again.
- **The sheet.** The design system's sheet, with its close button at the top. It scrolls when its content is taller, and
  closes with the close button, a swipe down, or a tap outside it. It also closes when the modal leaves the surface. The
  modal's `content` keeps updating while the sheet is open.
- **Data model.** Writes nothing.
- **Look.** `StreamSheetRoute` and the app's `StreamSheetTheme`; the app's `StreamComponentFactory` builders apply
  inside the sheet too.
- **Edge cases.** A modal with no trigger shows nothing. Without a `Navigator` above the surface the sheet can't open,
  and this is reported once. A modal with its sheet open stays while a list it is in scrolls it out of view.

```json
[
  {"id": "root", "component": "Modal", "trigger": "open", "content": "sheet"},
  {"id": "open", "component": "Button", "child": "open_label", "action": {"event": {"name": "opened_details", "context": {}}}},
  {"id": "open_label", "component": "Text", "text": "Details"},
  {"id": "sheet", "component": "Text", "text": "The sheet scrolls when its content is taller than it."}
]
```

More: [`modal.json`](../example/assets/components/modal.json): a text trigger.

## Button

Its `child` in a button that runs its `action` when tapped.

| Property | Type | Notes |
| --- | --- | --- |
| `child` | id, required | Usually a `Text`; an `Icon` alone makes an icon button. |
| `action` | an action, required | `{"event": {...}}` or `{"functionCall": {...}}`. |
| `variant` | `default`, `primary`, `borderless` | A solid button on the subtle surface, a solid button in the accent color, or the child in the accent color with no background. |
| `checks` | list of checks | While one fails with an error, the button is disabled and the messages show below it. |

- **Actions.** An `event` action sends the host an `AIUIAction` named after the event, with the `context` read from
  the data model at the tap, the agent's `userMessage` when it wrote one, and the surface's `dataModel` when the
  surface was created with `sendDataModel`. The action's label (the person's message) is the text of the button's
  child, else the event's name in words. A `functionCall` action runs the function: `openUrl` opens the link through
  the host; a function no catalog has runs as one of the host's tools (see [Agent functions](#agent-functions)).
- **Taps.** A tap closes the keyboard of a field being typed in, and runs the action. Each tap runs it, so a second tap
  while the first one's action runs sends a second event.
- **Data model.** Writes nothing; reads `context`, and the checks' conditions.
- **Look.** The design system's `StreamButton`, so the app's `button` builder draws it. A button of only an `Icon` is
  the design system's icon button, with the `accessibility` label as its tooltip.
- **Edge cases.** A button with no child is drawn with nothing in it. A button whose checks fail with a warning or info is not
  blocked.

```json
[
  {"id": "root", "component": "Row", "children": ["b1", "b2", "b3"], "justify": "spaceBetween"},
  {"id": "b1", "component": "Button", "child": "t1", "action": {"event": {"name": "default_tapped", "context": {}}}},
  {"id": "t1", "component": "Text", "text": "Default"},
  {"id": "b2", "component": "Button", "child": "t2", "variant": "primary", "action": {"event": {"name": "primary_tapped", "context": {}}}},
  {"id": "t2", "component": "Text", "text": "Primary"},
  {"id": "b3", "component": "Button", "child": "t3", "variant": "borderless", "action": {"event": {"name": "borderless_tapped", "context": {}}}},
  {"id": "t3", "component": "Text", "text": "Borderless"}
]
```

More: [`button.json`](../example/assets/components/button.json): an icon button, and one a check disables while a name
field is empty, with `userMessage` and `sendDataModel`.

## TextField

A `label` over a field that writes each change the person makes to its `value`.

| Property | Type | Notes |
| --- | --- | --- |
| `label` | dynamic string, required | |
| `value` | dynamic string, required | Bind it to the data model, or the field is read-only. |
| `placeholder` | dynamic string | Shown while the field is empty. |
| `variant` | `shortText` (default), `longText`, `number`, `obscured` | One line; several lines (at least three, growing); a number keyboard that allows a sign and a decimal point; a secret. |
| `checks` | list of checks | |

- **Data model.** Writes the text to the path `value` is bound to, on every change, as typed (the field never changes
  case, formats or corrects it). A `number` field writes a string too.
- **Typing.** While the person types, the field keeps what they typed; a change from elsewhere, such as from the agent,
  replaces it once the field isn't being typed in.
- **Checks.** They show only while the field holds text, so an empty form isn't covered in errors: a failing check
  outlines the field in the error color and its messages show below it.
- **Secret fields.** An `obscured` field hides its text and is never suggested or corrected. It is never given to the
  app's `textInput` builder, so a secret stays hidden, and is drawn in the same style. Its label shows when it has no
  placeholder. Its text is written to the data model like any other, so an action's `context` or a `sendDataModel`
  surface that includes it sends it; the renderer only keeps it out of the label of a button whose text is bound to it.
- **Look.** The design system's `StreamTextInput`, so the app's `textInput` builder and text input theme apply.
- **Edge cases.** A `value` that isn't bound shows read-only and fainter, and is reported once.

```json
[
  {"id": "root", "component": "Column", "children": ["name", "guests"]},
  {"id": "name", "component": "TextField", "label": "Name", "placeholder": "Jane Doe", "value": {"@path": "/name"}},
  {"id": "guests", "component": "TextField", "label": "Guests", "variant": "number", "value": {"@path": "/guests"}}
]
```

```json data
{"name": "", "guests": "2"}
```

More: [`text_field.json`](../example/assets/components/text_field.json): a long field, a secret with a failing check, and
one with no binding.

## CheckBox

The design system's check box beside its `label`; a tap on either writes the other value.

| Property | Type | Notes |
| --- | --- | --- |
| `label` | dynamic string, required | |
| `value` | dynamic boolean, required | Bind it to the data model, or the check box is read-only. |
| `checks` | list of checks | Their messages show below it. |

- **Data model.** Writes `true` or `false` to the path `value` is bound to. The whole row is one tap target, at least
  48 logical pixels tall, and is one node for assistive technologies, labelled by the `accessibility` label or the
  visible one.
- **Look.** `StreamCheckbox`, checked in the theme's accent, so the app's `checkbox` builder draws the box. With no
  value to write it is drawn disabled, so an app's builder draws it read-only too.
- **Edge cases.** A `value` that isn't bound shows fainter, a tap does nothing, and it is reported once.

```json
[
  {"id": "root", "component": "CheckBox", "label": "Email me the itinerary", "value": {"@path": "/email"}}
]
```

```json data
{"email": true}
```

More: [`check_box.json`](../example/assets/components/check_box.json): one with no binding, and a check that fails until
it is checked.

## ChoicePicker

A `label` over `options`, of which the person picks one, or several.

| Property | Type | Notes |
| --- | --- | --- |
| `label` | dynamic string | |
| `options` | list of `{"label": dynamic string, "value": string}`, required | |
| `value` | dynamic list of strings, required | The picked values. Bind it to the data model, or the picker is read-only. |
| `variant` | `mutuallyExclusive` (default), `multipleSelection` | |
| `displayStyle` | `checkbox` (default), `chips` | Rows with a radio button, or a check box when several can be picked; or capsules. |
| `filterable` | boolean, default `false` | Adds a search field above the options. |
| `checks` | list of checks | |

- **Data model.** Writes the picked values, as a list, to the path `value` is bound to. Picking the picked option of a
  single choice keeps it picked. When several can be picked, a pick that isn't among the options, which the person
  can't see, is dropped once they pick.
- **Filter.** The search field shows only the options whose label holds what the person typed, in any capitalization.
  It is the design system's `StreamTextInput`, with the app's builder and theme.
- **Look.** Picked chips are in the theme's accent; a multiple-choice row uses `StreamCheckbox`. The options are read
  as one group, named by the `accessibility` label or the `label`.
- **Edge cases.** An option shows its `label`, or its `value` while a label bound to the data model isn't there yet.
  A picker whose `value` isn't bound shows fainter and picks nothing. A filterable picker fills the width it is given.

```json
[
  {"id": "root", "component": "ChoicePicker", "label": "Pick several", "variant": "multipleSelection", "displayStyle": "chips", "value": {"@path": "/picked"},
   "options": [{"label": "Boat trip", "value": "boat"}, {"label": "Old town", "value": "town"}, {"label": "Beach", "value": "beach"}]}
]
```

```json data
{"picked": ["boat", "beach"]}
```

More: [`choice_picker.json`](../example/assets/components/choice_picker.json): radio rows, and a filterable picker with
a check.

## Slider

A `label` and the current `value` over a slider from `min` to `max`.

| Property | Type | Notes |
| --- | --- | --- |
| `label` | dynamic string | |
| `value` | dynamic number, required | Bind it to the data model, or the slider can't be moved. |
| `min` | dynamic number, default 0 | |
| `max` | dynamic number, required | |
| `steps` | integer of at least 1 | The number of equal divisions; the slider snaps to them. |
| `checks` | list of checks | |

- **Data model.** Writes the picked number to the path `value` is bound to, as a whole number without a fraction when
  it is one. With `steps`, a division of whole ends is a whole number.
- **Range.** A `min` that isn't a number is 0, and a `max` that isn't above the `min` is one more than it. Both are kept
  within ±10¹⁵.
- **Value outside the range.** It shows at the nearer end, but is left as the agent wrote it, since the range may
  still be on its way, such as a bound `max` that a later data update fills; it changes once the person moves the
  slider.
- **Missing value.** Once the slider shows, a value that isn't there yet is written as `min`, as is one that isn't a
  number, which is also reported.
- **Look.** Drawn with the theme's accent and border colors, as a Material `Slider`; it has no design system hook.
- **Edge cases.** A `value` that isn't bound shows fainter, can't be moved, and is reported once.

```json
[
  {"id": "root", "component": "Slider", "label": "Guests", "min": 0, "max": 10, "steps": 5, "value": {"@path": "/guests"}}
]
```

```json data
{"guests": 4}
```

More: [`slider.json`](../example/assets/components/slider.json): a slider with no binding, and a value above `max`.

## DateTimeInput

A `label` over a field showing its `value` in the device's own format, which opens a date picker, a time picker, or
both.

| Property | Type | Notes |
| --- | --- | --- |
| `value` | dynamic string, required | ISO 8601. Bind it to the data model, or a tap opens nothing. |
| `label` | dynamic string | |
| `enableDate` | boolean, default `false` | |
| `enableTime` | boolean, default `false` | |
| `min`, `max` | dynamic string | ISO 8601 bounds. |
| `checks` | list of checks | |

- **What it picks.** A date picker for `enableDate`, a time picker for `enableTime`, the date picker and then the time
  picker for both. With neither, it picks a date.
- **Data model.** Writes ISO 8601 to the path `value` is bound to, once the person picks (nothing is written before):
  a date such as `2026-10-02`, a time such as `19:30:00`, or a date and time with the device's offset from UTC, such as
  `2026-10-02T19:30:00+02:00`, or `Z` for UTC.
- **Reading a value.** A date and time written with an offset, such as `2026-10-02T17:30:00Z`, shows as the same
  moment on the device's clock; one written without an offset shows as written. A value that isn't a date or time
  shows as the agent wrote it.
- **Bounds.** What the person picks stays from `min` to `max`: the date picker offers only the days between them, and
  a time picked before `min` or after `max` on those days becomes that bound. A time input needs bounds that are times,
  and the others bounds that are dates or dates and times. A bound that isn't one, or a `min` after the `max`, limits
  nothing, and is reported.
- **Look.** The frame of the design system's text input, drawn from its theme (no builder hook), with a calendar or
  clock icon.
- **Edge cases.** A `value` that isn't bound shows fainter and a tap opens nothing.

```json
[
  {"id": "root", "component": "DateTimeInput", "label": "Check-in", "enableDate": true, "enableTime": true, "min": "2026-10-01T00:00:00Z", "max": "2026-10-31T23:59:00Z", "value": {"@path": "/checkin"}}
]
```

```json data
{"checkin": "2026-10-02T17:30:00Z"}
```

More: [`date_time_input.json`](../example/assets/components/date_time_input.json): a date, and a time with a check.

## The app's components

The host's `components` are placed by the agent as PascalCase types, such as `PlaceCard`, with the component's
parameters as properties. They are not part of `A2UICatalog.basic`, hold no other components and no `action`, and are
described in the [README](../README.md#place-your-apps-components). The gallery's `place_card` is in the example app's
[Ohrid example](../example/assets/ohrid_prompt_example.jsonl).

## Agent functions

An action or a check may call a function with `{"@call": "name", "args": {...}}`. The basic catalog has `required`,
`regex`, `length`, `numeric`, `email`, `formatString`, `formatNumber`, `formatCurrency`, `formatDate`, `pluralize`,
`openUrl`, `and`, `or` and `not`; the renderer runs them. A function no catalog has is sent to the host as one of its
`tools`, with its arguments read from the data model: a read-only tool when the surface calls it, any other only from a
person's tap on a component whose action calls it. `openUrl` doesn't run in the renderer: an `http`, `https`, `mailto` or `tel` link goes to the
host's `open`, which decides whether it opens. See [`link_example.json`](../example/assets/link_example.json).
