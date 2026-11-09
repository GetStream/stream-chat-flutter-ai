# A2UI for Stream Chat AI Flutter components

Shows the interactive UI that an agent writes in [A2UI](https://a2ui.org) 1.0 in its replies, through the
generative UI of [`stream_chat_flutter_ai`](../stream_chat_flutter_ai).

This package is in development and isn't published. It has the components a reply's A2UI is drawn with, and their
look, but can't show a reply's A2UI in a conversation yet: the renderer that does, and that takes the theme and catalog
below, comes in a later version.

## The look

A reply's A2UI is drawn with the app's Stream design system, so it follows light and dark mode. An `A2UITheme` overrides
any of its values; the ones it leaves unset still come from the Stream theme:

```dart
A2UITheme(
  data: A2UIThemeData(accent: const Color(0xFFE65100), cornerRadius: 8),
  child: child,
);
```

## The components

`A2UICatalog.basic` draws A2UI's basic `Text`, `Image`, `Icon`, `Row`, `Column`, `List`, `Card`, `Divider`, `Tabs`
and `Modal`, and the components a person uses: `Button`, `TextField`, `CheckBox`, `ChoicePicker`, `Slider` and
`DateTimeInput`. To draw one of them another way, replace its builder; the agent still writes the component as A2UI
describes it:

```dart
final catalog = A2UICatalog.basic.replacing('Card', (context, scope) {
  final child = scope.child();
  return BrandCard(child: child == null ? null : scope.build(child));
});
```

A builder of a component a person uses writes what they enter to the surface's data model, and runs the component's
action when they use it:

```dart
final catalog = A2UICatalog.basic.replacing('CheckBox', (context, scope) {
  return Switch(
    value: scope.boolean('value') ?? false,
    onChanged: (value) => scope.write('value', value),
  );
});
```

The [example](example) is a gallery of the examples published with A2UI's basic catalog, which lists what a person's
actions in them do: each event an agent would get, with its values, and each link that would open.

## Tests

The A2UI conformance suites it is tested against are vendored, unchanged, under
[`test/conformance/upstream`](test/conformance/upstream), with their license. The examples published with the basic
catalog are under [`test/fixtures/upstream_examples`](test/fixtures/upstream_examples).
