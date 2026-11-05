## Upcoming

✅ Added

- New package for A2UI 1.0, the protocol an agent writes interactive UI in. In development: no public API yet.
- The look and components of a reply's A2UI: `A2UITheme`, made from the app's Stream theme with
  `A2UITheme.fromStream`, and `A2UICatalog`, whose builders read and write a component through
  `A2UIComponentScope` (`write`, `performAction`, `hasAction`, `validationErrors`, `isValid`).
- The components a person uses, in `A2UICatalog.basic`: `Button`, `TextField`, `CheckBox`, `ChoicePicker`,
  `Slider`, `DateTimeInput` and `Modal`. What a person types into an obscured field is never sent to the agent.
