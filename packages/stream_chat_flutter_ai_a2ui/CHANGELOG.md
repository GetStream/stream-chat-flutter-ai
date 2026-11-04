## Upcoming

✅ Added

- New package for A2UI 1.0, the protocol an agent writes interactive UI in. In development: no public API yet.
- The look and components of a reply's A2UI: `A2UITheme`, made from the app's Stream theme with
  `A2UITheme.fromStream`, and `A2UICatalog`, whose builders read a component through `A2UIComponentScope`.
- The components a person uses, in `A2UICatalog.basic`: `Button`, `TextField`, `CheckBox`, `ChoicePicker`,
  `Slider`, `DateTimeInput` and `Modal`.
- `A2UICatalog.basic` draws `Video`, with its poster until it plays, and `AudioPlayer`, with its description. Neither
  plays until the person taps play.
