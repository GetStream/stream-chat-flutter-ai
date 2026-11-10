## Upcoming

✅ Added

- New package for the interactive UI an agent writes in OpenUI Lang 1.0 with OpenUI's chat and standard component
  libraries. It has no public API yet.
- OpenUI Lang replies are read as they stream in and run: their values, state, forms, queries, mutations and actions,
  ready for the renderer that will draw them; still no public API.
- `OpenUITheme` and `OpenUIThemeData` give OpenUI components their colors, spacing, corner radii and text styles, with
  `copyWith`, `merge`, `lerp` and `OpenUITheme.merge`; values left `null` come from the app's Stream theme.
- `OpenUILibrary.chat` and `OpenUILibrary.standard` hold OpenUI's chat and standard component libraries, with `types`,
  `operator []`, `replacing` and `removing`; `OpenUIComponentName` names their components. An
  `OpenUIComponentBuilder` draws a component from an `OpenUIComponentScope` (`type`, `isStreaming`, `value`, `string`,
  `text`, `number`, `boolean`, `stringList`, `numberList`, `buildProp`, `buildDefault`). The chat `Card`, `CardHeader`
  and `TextContent` are drawn so far.
- Content, data display and card components of both libraries are drawn: `MarkDownRenderer`, `Callout`, `TextCallout`,
  `Separator`, `InlineHeader`, `Label`, `Image`, `ImageBlock`, `ImageGallery` (with a viewer of its images), `CodeBlock`,
  `Tag`, `TagBlock`, `Icon` (Lucide names, with the icons of the Stream design system), `EntityList`, `Text`,
  `BoldText`, `IconText`, `ImageText`, `ImageTextLarge`, the metric indicators and the five card blocks; the chat
  `Card` shows its `sources` as a strip that opens on a tap, and `[n]` in text links to the nth source. Their `action`
  and a `Button` in a card do nothing yet.
- Layout, list, table, form and button components of both libraries are drawn, with their state, `$variable` bindings, validation and actions; forms check their required fields and keep their defaults once the reply ends; the actions of cards and buttons run.