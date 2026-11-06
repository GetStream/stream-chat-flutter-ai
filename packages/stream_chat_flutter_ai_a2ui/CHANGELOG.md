## Upcoming

✅ Added

- New package for A2UI 1.0, the protocol an agent writes interactive UI in.
- The look and components of a reply's A2UI: `A2UITheme` with `A2UIThemeData` overrides that default to the app's
  Stream theme, and `A2UICatalog`, whose builders read a component through `A2UIComponentScope`.
- The components a person uses, in `A2UICatalog.basic`: `Button`, `TextField`, `CheckBox`, `ChoicePicker`,
  `Slider`, `DateTimeInput` and `Modal`.
- `A2UICatalog.basic` draws `Video`, with its poster until it plays, and `AudioPlayer`, with its description. Neither
  plays until the person taps play.
