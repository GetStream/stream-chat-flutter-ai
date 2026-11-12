# Testing the A2UI package

All of it runs with `melos run test:all`. The package's own tests run with `flutter test` in
`packages/stream_chat_flutter_ai_a2ui`, and the conformance suites with `flutter test` in
`packages/stream_chat_flutter_ai_a2ui_conformance`.

| What | Where | Notes |
| --- | --- | --- |
| Conformance | `packages/stream_chat_flutter_ai_a2ui_conformance/` | The vendored upstream A2UI suites, in a private package of their own so they don't ship with the renderer. They run against the adapter and the pinned `a2ui_core`, through `lib/src/core/` and its test interface, `lib/src/core/a2ui_test_interface.dart`. Why they are kept, and how a skipped case is recorded: [its README](../../packages/stream_chat_flutter_ai_a2ui_conformance/README.md). Tagged `conformance`: `flutter test --tags conformance`. |
| Fixtures | `test/fixtures/` | Reference data for the splitting, layout and date logic, and the upstream examples: [`test/fixtures/README.md`](../../packages/stream_chat_flutter_ai_a2ui/test/fixtures/README.md). |
| Core adapter | `test/src/core/` | Processor, surfaces, nodes, checks, versions, stream splitting. Plain tests of the package's own types. |
| Engine | `test/src/engine/` | Actions and their labels, app components, errors, streaming, topology, agent functions, instructions. |
| Surface | `test/src/surface/` | The surface view, entrance animation, accessibility, media URLs, the Stream theme. |
| Catalog | `test/src/catalog/` | The scope, the theme, and one test file for each builder in `basic/`. |
| Goldens | `test/src/a2ui_*_golden_test.dart` | Components in light and dark. |
| Examples | `test/src/examples/` | The published examples, and the gallery's component examples, build and show their surfaces. |
| Documentation | `test/src/a2ui_docs_test.dart` | See below. |
| Guards | `a2ui_barrel_exports_test.dart`, `a2ui_core_import_guard_test.dart` | The public API is exactly the barrel's `show` list; only `core/a2ui_adapter.dart` imports `a2ui_core`. |

## Writing a component test

`test/src/a2ui_test_app.dart` has the harness: `pumpSurface(tester, components: [...], data: {...}, errors: [...],
events: [...], onOpenLink: ...)` makes a processor, creates surface `s` and shows it under a Stream theme, returning the
processor so the test can send more messages (`updateData`, `updateComponents`). Collect `errors` and `events` to assert
what was reported and what the person's action sent. `inColumn(...)` wraps children in a root column; `lightTheme()`
gives the resolved theme to compare colors with. Prefer testing behaviour (what is written, what is reported, what a
screen reader finds) to widget trees.

## Goldens

Alchemist keeps two sets, switched on the `CI` / `GITHUB_ACTIONS` environment variables in
`test/flutter_test_config.dart`:

- `test/src/goldens/macos/` has real text and is for local runs. It is untracked; regenerate with
  `melos run update:goldens`.
- `test/src/goldens/ci/` has the text obscured into rectangles so it is stable across hosts. It is committed, and is what
  CI compares against. It has to be rendered on a Linux runner, so never generate it locally: run the `update_goldens`
  workflow (`workflow_dispatch`) on the branch, and it commits the files back.

To see what CI will see: `CI=true melos run test:all`.

## Documentation tests

`test/src/a2ui_docs_test.dart` keeps the documents in step with the catalog. For every key of `A2UICatalog.basic` it needs:

- a `## <Name>` section in `doc/components.md`;
- an example at `example/assets/components/<snake_name>.json`, which `test/src/examples/a2ui_component_examples_test.dart`
  builds and shows, failing on any report that isn't listed as intended;
- a section whose `json` blocks (a components array, optionally followed by a `json data` block with the data model)
  show without reporting anything.

It also fails on a relative link in the README, the component reference, the example README or these documents that
leads nowhere.

## Mutation checks

For logic with many small branches (the flex math, date handling, checks), change the source in small ways one at a
time and run only the targeted test file: every change should fail a test. Restore the file after each.
