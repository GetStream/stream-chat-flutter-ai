## Upcoming

✅ Added

- New package for the interactive UI an agent writes in OpenUI Lang 1.0 with OpenUI's chat and standard component
  libraries. It has no public API yet.
- OpenUI Lang replies are read as they stream in and run: their values, state, forms, queries, mutations and actions,
  ready for the renderer that will draw them; still no public API.
- `OpenUITheme` gives OpenUI components the look in an `OpenUIThemeData`: `OpenUIColors`, `OpenUISpacing`,
  `OpenUIRadius` and `OpenUITextStyles`, each value optional, with `copyWith`, `merge` and `lerp`. Values left `null`
  come from the app's Stream theme; `OpenUITheme.of` gives them all filled in. The Stream design system components
  inside OpenUI take its colors, spacing, radii and text styles, and still use the app's `StreamComponentFactory`
  builders.
- `OpenUILibrary.chat` and `OpenUILibrary.standard` hold OpenUI's chat and standard component libraries, with `types`,
  `operator []`, `replacing` and `removing`; `OpenUIComponentName` names their components. An
  `OpenUIComponentBuilder` draws a component from an `OpenUIComponentScope` (`type`, `isStreaming`, `value`, `string`,
  `text`, `number`, `boolean`, `stringList`, `numberList`, `buildProp`, `buildDefault`). The chat `Card`, `CardHeader`
  and `TextContent` are drawn so far.
- Content components of both libraries are drawn: `MarkDownRenderer`, `Callout` (its `visible` binding and the 3
  second dismiss included), `TextCallout`, `Separator`, `InlineHeader`, `Label`, `Image`, `ImageBlock`, `ImageGallery`
  (with a preview of its images) and `CodeBlock`. Images show their `alt` text while they load or when they can't.
  `CardHeader` shows inline Markdown and links.
- The chat `Card` shows its `sources` as a strip of numbered sources that open on a tap, and `[n]` in the text of
  `TextContent` and `MarkDownRenderer` links to the nth source.
- Data display components are drawn: `Tag`, `TagBlock`, `Icon` (Lucide names, with the icons of the Stream design
  system) and `EntityList`.
- Card components are drawn: `Text`, `BoldText`, `IconText`, `ImageText`, `ImageTextLarge`, `MetricIndicatorInline`,
  `MetricIndicatorWithStrikethrough`, and the `SnippetCardBlock`, `OverviewCardBlock`, `ContextCardBlock`,
  `CompositeCardBlock` and `VisualCardBlock` that lay out their items as a grid or a carousel. A block's `action` runs
  when an item is tapped, with what the item shows merged in.
- Layout components are drawn: the standard `Stack` and `Card` (column, row, wrapping row or grid, with `gap`, `align`
  and `justify`), `Tabs`, `Accordion`, the chat `SectionBlock`, `Steps`, `Carousel` and the standard `Modal`, a sheet
  that opens and closes with its `open` binding.
- Lists and tables are drawn: `ListBlock` and the chat `FollowUpBlock`, whose items can be tapped, `Table` (paged ten
  rows at a time) and `EditableTable`, whose edits can be reset or saved.
- Forms are drawn: `Form`, `FormControl` (with its required mark, hint and validation error), `Input`, `TextArea`,
  `Select`, `DatePicker`, `Slider`, `CheckBoxGroup`, `SwitchGroup`, `RadioGroup`, `Chips` and `OptionCards`. Fields
  show and write the reply's state and their `$variable` bindings, check their `rules`, keep their defaults once the
  reply ends and can't be changed while it streams; a password never leaves the reply's state.
- Buttons are drawn: `Button`, `Buttons` and `IconButton`. They run their actions once the reply has ended, and a
  primary button checks its form first.
- `OpenUIRenderer` shows OpenUI replies in a conversation: added to an `AIUIHost`, it draws a reply's program as it
  streams, keeps what the person entered while the host keeps the reply, sends a tap as an `AIUIAction` (its label,
  context, message, form and values, never a password), opens web and email links with the host's `open`, and runs
  queries and mutations as the host's tools. It takes a `library`, `instructions`, a `theme`, a `mediaUrl` and an
  `onError`, which gets each `OpenUIError` with the reply's message id; `OpenUIError`, `OpenUIErrorSource` and
  `OpenUIErrorCode` are public.
- The renderer's `capabilities` give the agent's backend the `openui-lang` fence and the instructions its model needs:
  the library's system prompt with the app's components and tools.
- The app's own components, the host's `components`, can be placed by the agent wherever the library's content goes,
  by their name in PascalCase; their events are sent with the component's name.
- A program whose closing fence wasn't a bare line, such as one ending in ```` ```Enjoy! ````, keeps its card.
- The charts are drawn with the core package's `ChartView`: `BarChart`, `HorizontalBarChart`, `LineChart`,
  `AreaChart`, `RadarChart`, `PieChart` (with `donut` and `semiCircular`), `RadialChart`, `SingleStackedBarChart`
  and `ScatterChart`, in the colors of the theme's chart palette. Values that aren't finite are left out and the rest
  are kept within ±1e15; a `height` sets the plot's height, between 60 and 1000. Parts of a whole with no value above zero, and a radar with fewer than three spokes, draw
  nothing.
- The example has a gallery of the programs the library's prompts teach the model with, and one with every chart type,
  each drawn, written again line by line on a tap, with the actions it would send listed below.
