# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Overview

This repository's main package is `stream_chat_flutter_ai` — Flutter UI components
for LLM-driven chat: streaming markdown text, typing indicators, code blocks, charts, an AI
composer, and speech-to-text input.

**The package has no dependency on `stream_chat`, `stream_chat_flutter`, or any other Stream Chat
or backend package, by design.** Every widget operates on plain strings, callbacks and controllers.
Do not add a Stream Chat dependency — that would change the package's core premise. If a task seems
to need one, raise it rather than doing it.

It **is** built on Stream's design system,
[`stream_core_flutter`](https://github.com/GetStream/stream-core-flutter), which has no client or
backend dependency: defaults come from `StreamTheme` tokens (`context.streamColorScheme`,
`context.streamTextTheme`, `context.streamSpacing`, `context.streamRadius`, `context.streamIcons`),
not Material's `ColorScheme`/`TextTheme`; buttons, sheets, list tiles, spinners and most icons are core's
components (`StreamButton`, `StreamSheetHeader`, `StreamListTile`, `StreamLoadingSpinner`,
`StreamIcons`, …) rather than Material ones; and replaceable components register with core's
`StreamComponentFactory` through `streamAIComponentBuilders(...)`, keyed by props type. Import
`package:stream_core_flutter/core.dart` (`chat.dart` only where a chat-only component such as
`StreamMessageComposerMediaAttachment` is used). The barrel re-exports a `show` allowlist from core
(theme, tokens, factory types), not the whole of it. Its constraint must overlap the one `stream_chat_flutter`
uses, so a core minor bump is released in step with chat.

A second package, `stream_chat_flutter_ai_a2ui` (private until it is released), is the A2UI renderer
plugin for the core package's generative UI. It uses only the core package's public API, and hides
`a2ui_core` (the A2UI protocol library) inside `lib/src/core/`: no other file imports it, and no
`a2ui_core` type appears in its API, so the protocol library can be replaced. The same holds for
`json_schema_builder`, the schema library `a2ui_core`'s catalogs are written in.

Another, `stream_chat_flutter_ai_ondevice`, is a Flutter plugin (Kotlin + Swift, Pigeon channels) whose
`AIOnDeviceModel` implements core's `AILocalModel` with Gemini Nano (Android) and Apple's Foundation Models
(iOS/macOS 26). It depends on core and on no Stream Chat package either.

The Stream Chat SDK itself lives in the separate
[GetStream/stream-chat-flutter](https://github.com/GetStream/stream-chat-flutter) repo, and
backend-connected samples live in
[GetStream/chat-ai-samples](https://github.com/GetStream/chat-ai-samples). Neither is vendored here.

## Repository layout

This is a [Melos 8](https://melos.invertase.dev) monorepo built on
[Dart pub workspaces](https://dart.dev/tools/pub/workspaces).

```
pubspec.yaml                                 # workspace root: `workspace:` member list + `melos:` config
analysis_options.yaml                        # lint + formatter config for every member
packages/stream_chat_flutter_ai/             # the core published package
packages/stream_chat_flutter_ai/example      # showcase app, publish_to: none
packages/stream_chat_flutter_ai_a2ui/        # the A2UI renderer plugin, publish_to: none until released
packages/stream_chat_flutter_ai_a2ui/example # A2UI component gallery, publish_to: none
packages/stream_chat_flutter_ai_ondevice/    # published plugin: on-device model (Gemini Nano / Apple Foundation Models)
```

The published packages are versioned in lockstep — see [Releasing](#releasing). The CI and release tooling
treat every `packages/*/` whose pubspec isn't `publish_to: none` as publishable.

Consequences worth remembering:

- There is **no `melos.yaml`** — Melos 7 removed it in favour of the `melos:` key in the root
  `pubspec.yaml`. (The `stream-chat-flutter` repo is still on Melos 6 and *does* have one, so don't
  copy its layout over.)
- Every member declares `resolution: workspace`. This is fine to publish — pub.dev accepts it.
- There is exactly **one `pubspec.lock`** and one `.dart_tool/package_config.json`, both at the
  root. A lockfile inside a package directory is stale; delete it.
- Adding a package means adding its path to the root `workspace:` list (pub requires explicit
  paths — globs don't work there).
- The ondevice plugin's Swift is shared by iOS and macOS (`darwin/`, `sharedDarwinSource: true`).
  Generated `*.g.*` files come from `melos run generate:pigeon` — never edit them by hand.

## Common commands

```bash
melos bootstrap          # resolve the workspace (equivalent of flutter pub get)
melos run analyze        # dart analyze --fatal-infos . — covers all members in one pass
melos run format         # dart format --set-exit-if-changed .
melos run lint:all       # analyze + format
melos run test:all       # flutter test --coverage
melos run lint:pub       # flutter pub publish -n (skips the example, which is private)
melos run update:goldens # regenerate golden files
melos run generate:pigeon # regenerate the ondevice plugin's channels from pigeons/messages.dart
melos run release:pub    # flutter pub publish -f — CI only (release_publish), never run locally
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

Other workflows: `legacy_version_analyze` / `beta_version_analyze` (the minimum supported Flutter, 3.44.0, and beta,
sharing `.github/actions/package_analysis`), `pr_title` (conventional-commit enforcement),
`update_goldens` (manual), and the two release workflows below.

## Releasing

Releases follow the same flow as `stream-chat-flutter` and `stream-feeds-flutter`. The published packages
(`stream_chat_flutter_ai`, `stream_chat_flutter_ai_ondevice` and, once released, `stream_chat_flutter_ai_a2ui`)
are released **in lockstep**: they always share one `version:`, one `v<version>` tag publishes all of them, and the
other packages depend on `stream_chat_flutter_ai: ^<version>`, which lives in the root `melos.command.bootstrap` list like every other
constraint and is copied into the package by `melos bootstrap`. Until its first
release PR drops `publish_to: none`, the A2UI package is private and the release tooling skips it.

1. `/release-pr <version>` (`.claude/skills/release-pr/SKILL.md`) bumps every package's version and the lockstep
   constraint, promotes `## Upcoming` to `## <version>` in every CHANGELOG and opens a
   `chore(repo): release v<version>` PR.
2. The PR is **squash-merged**, so that title becomes the tip commit on `main`.
3. `release_tag.yml` reads `v<version>` from that commit, checks it matches every publishable pubspec
   (`.github/workflows/scripts/verify-release-versions.sh`) and isn't tagged yet, and pushes the tag with
   `BOT_GITHUB_API_TOKEN` (a `GITHUB_TOKEN` push wouldn't trigger the next workflow).
4. `release_publish.yml` runs on the tag, publishes over pub.dev OIDC — core first, since the other
   uploads need core `<version>` on pub.dev — and creates the GitHub Release.

Nobody's pub.dev account publishes — pub.dev trusts this repo's tag pushes instead. That needs one-time
setup outside git: automated publishing enabled on **each** package's pub.dev admin page (repository
`GetStream/stream-chat-flutter-ai`, tag pattern `v{{version}}`, "Require GitHub Actions environment" left empty) and the
`BOT_GITHUB_API_TOKEN` repo secret. Any `v*` tag push publishes from that ref's workflow, so a tag ruleset limiting
`refs/tags/v*` to the bot is worth adding too. pub.dev can't create a package through automated publishing,
so a new package's first version is uploaded by hand by a publisher member before its admin page offers the
setting; a release tag after that skips it if that version is already live.

Running `release_publish` manually (`workflow_dispatch`) is a dry run: it validates every publishable package but
skips the publish and the GitHub Release. Below `1.0.0` a breaking release bumps the minor version
(`0.1.0` → `0.2.0`), and a feature or fix release the patch. Versions are always `X.Y.Z` — the
workflows can't tag or publish a `+build` version.

## Code style

- Lint rules live in the root `analysis_options.yaml`; `--fatal-infos` means infos fail the build.
- Formatter is configured there too: `page_width: 120`, `trailing_commas: preserve`.
- `public_member_api_docs` is on for the package — every public member needs a doc comment. The
  example app opts out via its own `analysis_options.yaml`.
- Imports inside `lib/` use `package:stream_chat_flutter_ai/...` (`always_use_package_imports`),
  not relative paths.
- New public widgets get exported from `lib/stream_chat_flutter_ai.dart`.
- Customers should `implement` `AITranslations`, not extend `DefaultAITranslations`, so a new
  string shows up as a compile error. Adding a string still isn't a breaking change: list it under
  `✅ Added`, not `💥 Breaking`.

## PR & commit conventions

PR titles are enforced as `<type>(<scope>): <description>` with a required scope from:
`ai`, `a2ui`, `ondevice`, `repo`, `docs`, `deps`. A PR scoped `ai` must also update
`packages/stream_chat_flutter_ai/CHANGELOG.md`, one scoped `a2ui`
`packages/stream_chat_flutter_ai_a2ui/CHANGELOG.md`, and one scoped `ondevice`
`packages/stream_chat_flutter_ai_ondevice/CHANGELOG.md` — CI checks this. Changelog entries go under the
existing emoji headings: `💥 Breaking` (first, one line per breaking change), `✅ Added`, `🔄 Changed`,
`🐞 Fixed`, `🚀 Performance`.
