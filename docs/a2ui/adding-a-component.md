# Adding a component to the catalog

`A2UICatalog.basic` holds one builder for each component of A2UI 1.0's basic catalog. A new component is rare (the
catalog is A2UI's, not ours) but a replaced or reworked builder follows the same steps. Read
[architecture](architecture.md) first.

1. **Builder.** Add `lib/src/catalog/basic/a2ui_<name>.dart` with a top-level `Widget buildA2UI<Name>(BuildContext,
   A2UIComponentScope)` marked `@internal`. Read properties through the scope (`string`, `boolean`, `number`, `value`,
   `hint` for a style property, `child`, `children`), and for an input write with `scope.write` and run an action with
   `scope.performAction`. Don't import `a2ui_core` (the import guard test fails). Take colors, text styles and radii
   from `A2UISurfaceScope.of(context).theme`, and use the design system's components, with their `StreamComponentFactory`
   hooks, where one exists.
2. **Register it** in `A2UICatalog.basic` (`lib/src/catalog/a2ui_catalog.dart`), and in the list in that field's
   dartdoc. The catalogs the agent is told about follow the registered types.
3. **Dartdoc.** Document the builder as the others are: what it shows, what it writes, what an input does when it has
   no binding, and the edge cases. The component reference is written from this, so it has to be exact.
4. **Inputs.** Follow the other inputs. `a2ui_component_scope.dart` has `a2uiCanEdit` (a value not bound to the data
   model is read-only, fainter, and reported once) and `a2ui_node_view.dart` has `a2uiCheckFailuresOf` and
   `a2uiAccessibilityOf` (the label and description). `a2ui_input.dart` has `A2UIValidationMessages` for checks and
   `A2UIPressable` for tap targets. Add the type to `_interactiveTypes` in `a2ui_node_view.dart` so the label goes on
   the part the person uses, and to `a2uiFillsWidth` there if it fills its width.
5. **Tests.** Add `test/src/catalog/basic/a2ui_<name>_test.dart` (see [testing](testing.md)): properties, bound and
   unbound, edge cases, accessibility. Add the component to `a2ui_components_golden_test.dart` or
   `a2ui_inputs_golden_test.dart` for its look. Never generate the CI goldens locally.
6. **Gallery.** Add `packages/stream_chat_flutter_ai_a2ui/example/assets/components/<snake_name>.json` with one to three
   captioned variants, including its edge cases. The file name is the type in snake case (`AudioPlayer` is
   `audio_player.json`). If a variant reports on purpose, such as an unbound input, list the report in
   `test/src/examples/a2ui_component_examples_test.dart`.
7. **Reference.** Add a `## <Name>` section to `doc/components.md` with its properties, data model behaviour, action and
   checks, Stream hook and edge cases, and a JSON snippet that links the gallery file. Add a row to the README's table.
   `test/src/a2ui_docs_test.dart` fails until the section, the example and a rendering snippet exist.
8. **Changelog.** Add an entry under `✅ Added` to the package's `CHANGELOG.md`, under `## Upcoming`.
9. **Verify.** `melos run lint:all`, the package tests, and the gallery page on a device.
