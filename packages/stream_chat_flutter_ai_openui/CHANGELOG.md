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
