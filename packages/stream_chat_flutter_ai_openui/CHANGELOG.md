## Upcoming

✅ Added

- New package: `OpenUIRenderer` shows the [OpenUI Lang](https://github.com/thesysdev/openui) 1.0 UI an agent writes
  in its replies, through the generative UI of `stream_chat_flutter_ai`, as the reply streams in. It places the app's
  components in it, loads media through `OpenUIMediaUrl`, and gives the agent's model the instructions to write it.
- `OpenUILibrary.chat` and `OpenUILibrary.standard` with OpenUI's chat and standard components, drawing their content,
  data display, card, layout, list, table, form, button and chart components. Replace or remove components with
  `OpenUILibrary.replacing` and `removing`, and build your own with `OpenUIComponentBuilder`.
- `OpenUITheme` and `OpenUIThemeData`, which default to the app's Stream theme and follow light and dark mode.
- `OpenUIError`, `OpenUIErrorSource` and `OpenUIErrorCode`, given to the renderer's `onError`.
