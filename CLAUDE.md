# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Overview

This repository holds a single published package, `stream_chat_flutter_ai` — Flutter UI components
for LLM-driven chat: streaming markdown text, typing indicators, code blocks, charts, an AI
composer, and speech-to-text input.

**The package has no dependency on `stream_chat`, `stream_chat_flutter`, or any other Stream Chat
package, by design.** Every widget operates on plain strings, callbacks and controllers. Do not add
a Stream Chat dependency — that would change the package's core premise. If a task seems to need
one, raise it rather than doing it.

The Stream Chat SDK itself lives in the separate
[GetStream/stream-chat-flutter](https://github.com/GetStream/stream-chat-flutter) repo, and
backend-connected samples live in
[GetStream/chat-ai-samples](https://github.com/GetStream/chat-ai-samples). Neither is vendored here.

## Repository layout

This is a [Melos 8](https://melos.invertase.dev) monorepo built on
[Dart pub workspaces](https://dart.dev/tools/pub/workspaces).

```
pubspec.yaml                            # workspace root: `workspace:` member list + `melos:` config
analysis_options.yaml                   # lint + formatter config for every member
packages/stream_chat_flutter_ai/        # the published package
packages/stream_chat_flutter_ai/example # showcase app, publish_to: none
```

Consequences worth remembering:

- There is **no `melos.yaml`** — Melos 7 removed it in favour of the `melos:` key in the root
  `pubspec.yaml`. (The `stream-chat-flutter` repo is still on Melos 6 and *does* have one, so don't
  copy its layout over.)
- Every member declares `resolution: workspace`. This is fine to publish — pub.dev accepts it.
- There is exactly **one `pubspec.lock`** and one `.dart_tool/package_config.json`, both at the
  root. A lockfile inside a package directory is stale; delete it.
- Adding a package means adding its path to the root `workspace:` list (pub requires explicit
  paths — globs don't work there).

## Common commands

```bash
melos bootstrap          # resolve the workspace (equivalent of flutter pub get)
melos run analyze        # dart analyze --fatal-infos . — covers all members in one pass
melos run format         # dart format --set-exit-if-changed .
melos run lint:all       # analyze + format
melos run test:all       # flutter test --coverage
melos run lint:pub       # flutter pub publish -n (skips the example, which is private)
melos run update:goldens # regenerate golden files
```

`melos run analyze` is a single root `dart analyze`, not a per-package loop — that works because
pub workspaces give the analyzer one resolution for the whole tree.

## Dependency versions

Dependency versions and SDK constraints are managed centrally under `melos.command.bootstrap` in
the root `pubspec.yaml`. **Don't hand-edit versions in a package's `pubspec.yaml`** — change the
root and run `melos bootstrap`. When adding a genuinely new dependency, add it to both the
package's `pubspec.yaml` and the root list.

## Golden tests

Alchemist keeps two golden sets (see
`packages/stream_chat_flutter_ai/test/flutter_test_config.dart`, which switches on the `CI` /
`GITHUB_ACTIONS` env vars):

- `goldens/macos/` — real text, used for local runs. **Untracked** (see `.gitignore`). Regenerate
  with `melos run update:goldens`.
- `goldens/ci/` — text obscured into rectangles for host stability. **Committed**, and what CI
  compares against. These must be rendered on a Linux runner, so never generate them locally — run
  the `update_goldens` workflow (`workflow_dispatch`) on the branch and it commits them back.

To see what CI will see: `CI=true melos run test:all`.

## CI

`.github/workflows/stream_flutter_ai_workflow.yml` is the main workflow — a `gate` job (path
filter + draft-PR check) feeding `analyze`, `format` and `test`. Jobs are skipped via
`if: needs.gate.outputs.should_run` rather than `on.paths`, so skipped jobs still report success to
branch protection.

Other workflows: `legacy_version_analyze` / `beta_version_analyze` (N-1 stable and beta Flutter,
sharing `.github/actions/package_analysis`), `pr_title` (conventional-commit enforcement),
`update_goldens` (manual). There are deliberately **no release/publish workflows yet**.

## Code style

- Lint rules live in the root `analysis_options.yaml`; `--fatal-infos` means infos fail the build.
- Formatter is configured there too: `page_width: 120`, `trailing_commas: preserve`.
- `public_member_api_docs` is on for the package — every public member needs a doc comment. The
  example app opts out via its own `analysis_options.yaml`.
- Imports inside `lib/` use `package:stream_chat_flutter_ai/...` (`always_use_package_imports`),
  not relative paths.
- New public widgets get exported from `lib/stream_chat_flutter_ai.dart`.

## PR & commit conventions

PR titles are enforced as `<type>(<scope>): <description>` with a required scope from:
`ai`, `repo`, `docs`, `deps`. A PR scoped `ai` must also update
`packages/stream_chat_flutter_ai/CHANGELOG.md` — CI checks this. Changelog entries go under the
existing emoji headings: `✅ Added`, `🔄 Changed`, `🐞 Fixed`, `🚀 Performance`.
