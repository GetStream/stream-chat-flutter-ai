## 0.2.0

✅ Added

- New package: `A2UIRenderer` shows the [A2UI](https://a2ui.org) 1.0 UI an agent writes in its replies, through
  the generative UI of `stream_chat_flutter_ai`, places the app's components in it, loads media through
  `A2UIMediaUrl`, and gives the agent's model the instructions to write it. A link the agent's `openUrl` opens goes
  to the host's `open`, which by default opens web and email links.
- `A2UICatalog.basic` with A2UI's basic components. Replace or remove components with `A2UICatalog.replacing` and
  `removing`, and build your own with `A2UIComponentBuilder`.
- `A2UITheme` and `A2UIThemeData`, which default to the app's Stream theme and follow light and dark mode.
- `A2UIError`, `A2UIErrorCode` and `A2UIErrorHandler`, given to the renderer's `onError`.
