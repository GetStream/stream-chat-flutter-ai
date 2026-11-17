## Upcoming

✅ Added

- New package: `OpenUIRenderer` shows the [OpenUI Lang](https://github.com/thesysdev/openui) 1.0 UI an agent writes
  in its replies, through the generative UI of `stream_chat_flutter_ai`, as the reply streams in. It places the app's
  components in it, loads media through `OpenUIMediaUrl`, and gives the agent's model the instructions to write it.
- `OpenUILibrary.chat` and `OpenUILibrary.standard` with OpenUI's chat and standard components, drawing their content,
  data display, card, layout, list, table, form, button and chart components. Replace or remove components with
  `OpenUILibrary.replacing` and `removing`, and build your own with `OpenUIComponentBuilder`.
- Images load only from links contained in the agent's program or returned by the app's tools, and a web, email or
  phone link the UI opens goes to the host's `open`, which decides whether it opens.
- `OpenUITheme` and `OpenUIThemeData`, which default to the app's Stream theme and follow light and dark mode.
- `OpenUIError`, `OpenUIErrorSource` and `OpenUIErrorCode`, given to the renderer's `onError`.
- A `Modal` of `size` `sm` keeps its sheet to at most half the screen, and an `IconButton` draws its `shape`: a circle
  for `circle`, otherwise a rounded square. A modal's content stays above the keyboard.
- A form field checks its `pattern` rule, in time linear in the value, so a pattern can't freeze the app.
- `OpenUITranslations`, `DefaultOpenUITranslations`, `OpenUITranslationsScope` and `OpenUITranslationsDelegate` translate
  the texts the components draw and read out themselves, including a form's errors.
