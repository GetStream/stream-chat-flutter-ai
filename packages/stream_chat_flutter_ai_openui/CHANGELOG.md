## Upcoming

✅ Added

- New package for the interactive UI an agent writes in OpenUI Lang 1.0 with OpenUI's chat and standard component
  libraries. It has no public API yet.
- OpenUI Lang replies are read as they stream in and run: their values, state, forms, queries, mutations and actions,
  ready for the renderer that will draw them; still no public API.
- `OpenUITheme` gives OpenUI components the look in an `OpenUIThemeData`: flat, nullable colors (`accent`, `text`,
  `surface`, `error`, `chartPalette`, …), spacing (`mSpacing`, …), corner radii (`cornerRadius`, …) and text styles
  (`title`, `body`, …), with `copyWith`, `merge`, `lerp` and `OpenUITheme.merge`, like `A2UIThemeData`. Values left
  `null` come from the app's Stream theme; `OpenUITheme.of` gives them all filled in. The Stream design system
  components inside OpenUI take its colors, spacing, radii and text styles, and still use the app's
  `StreamComponentFactory` builders.
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
