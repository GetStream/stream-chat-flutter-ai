Welcome to Stream’s Flutter AI repository. Thank you for taking the time to contribute to our codebase. 🎉

This document outlines a set of guidelines for contributing to `stream_chat_flutter_ai`. These are mostly guidelines, not necessarily a fixed set of rules. Please use your best judgment and feel free to propose changes to this document in a pull request.

---

# If I have a question, do I need to read this guide? 💬

Probably not. If you are having doubts around a specific API, please create an issue on this repository with the label "Question". Community members or team members would be happy to assist.

In cases where you suspect the issue may be a defect or bug, please use one of our pre-made templates to file an issue. Be sure to include as many details as possible to help our team reproduce the error. A good bug report should have clear and consistent instructions for reproducing, screenshots or videos of the bug if applicable, and information on your environment setup and Flutter version.

You can include the output of `flutter doctor --verbose` when filing an issue.

🔗: [https://github.com/GetStream/stream-chat-flutter-ai/issues](https://github.com/GetStream/stream-chat-flutter-ai/issues)

---

# What should I know before diving into code? 🤔

### Project Structure 🧱

`.github` — GitHub files including issue templates, pull request templates, and GitHub Action workflows.

`packages/stream_chat_flutter_ai` — the package source. This is the only published package in this repository.

`packages/stream_chat_flutter_ai/example` — a minimal showcase app for the components. It needs no API key and no backend. For a backend-connected sample, see [GetStream/chat-ai-samples](https://github.com/GetStream/chat-ai-samples).

`analysis_options.yaml` — the lint and formatter configuration for the whole workspace.

`pubspec.yaml` — the workspace root. It holds both the pub `workspace:` member list and the [Melos](https://melos.invertase.dev) configuration under the `melos:` key.

`CODE_OF_CONDUCT.md` — our values, approach to writing code, and expectations for Stream developers and contributors.

`LICENSE` — legal. Feast your eyes on the fine print.

### Relationship to `stream-chat-flutter`

This package deliberately has **no dependency** on `stream_chat`, `stream_chat_flutter`, or any other Stream Chat package — every widget operates on plain strings, callbacks, and controllers. Please keep it that way: a change that introduces a Stream Chat dependency is a change to the package's core premise and needs discussion first.

The Stream Chat SDK itself lives in [GetStream/stream-chat-flutter](https://github.com/GetStream/stream-chat-flutter). Note that it is still on Melos 6 with a separate `melos.yaml`, whereas this repository uses Melos 8 with pub workspaces — so its setup instructions don't transfer directly.

### Local Setup

Congratulations 🎉 — you've successfully cloned our repository, and you are ready to make your first contribution. Before you can start making code changes, there are a few things to configure.

**Flutter version**

We pin the Flutter version with [fvm](https://fvm.app) — see `.fvmrc`. Any Flutter release with Dart 3.9 or newer works, since pub workspaces need it.

**Melos setup**

This repository is a [Dart pub workspace](https://dart.dev/tools/pub/workspaces) managed with [Melos](https://melos.invertase.dev). Install Melos with:

```bash
dart pub global activate melos
```

Once activated, bootstrap your local clone:

```bash
melos bootstrap
```

Because this is a pub workspace, bootstrap resolves *every* member package in one pass, producing a single `pubspec.lock` and a single `.dart_tool/package_config.json` — both at the repository root. If you see a `pubspec.lock` inside a package directory, it's stale and safe to delete.

Dependency versions and the SDK constraints are managed centrally, under `melos.command.bootstrap` in the root `pubspec.yaml` — don't edit them by hand in a package's `pubspec.yaml`. To change a version, update the root and re-run `melos bootstrap`. To add a *new* dependency, add it to the package's `pubspec.yaml` **and** to the root list so future updates stay in sync.

Bonus tip: our team uses Melos scripts for testing, lints, and more. Run one with `melos run <script name>`, or `melos run` on its own to see the list.

---

# How can I contribute?

## Filing bugs 🐛

Before filing bugs, take a look at our existing backlog — for common bugs, there might be an existing ticket on GitHub.

Didn't find an existing issue? Go ahead and file a new bug using one of our pre-made issue templates. Be sure to provide as much information as possible: a good issue has steps to reproduce, information on your development environment, and the expected behavior. Screenshots and GIFs are always welcome :)

## Feature Request 💡

Have an idea for a new feature? We would love to hear about it. Before opening a new topic, please check our existing issues and pull requests to ensure the feature you are suggesting is not already in progress.

[`ROADMAP.md`](packages/stream_chat_flutter_ai/ROADMAP.md) tracks planned work, largely parity with [`stream-chat-swift-ai`](https://github.com/GetStream/stream-chat-swift-ai) — it's worth a look before filing.

## Pull Request 🎉

Thank you for taking the time to submit a patch and contribute to our codebase. You rock.

Before we can land your pull request, please don't forget to [sign Stream's CLA (Contributor License Agreement)](https://docs.google.com/forms/d/e/1FAIpQLScFKsKkAJI7mhCr7K9rEIOpqIDThrWxuvxnwUq2XkHyG154vQ/viewform). 📝

### PR Semantics 🦄

Our team uses [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). While we don't expect developers to follow the specification down to every commit message, we **do** enforce semantics on PR titles — see `.github/workflows/pr_title.yml`.

PR titles must follow the format:

```
<type>(<scope>): <description>
```

A scope is required. The allowed scopes are:

| Scope | Use for | CHANGELOG entry required? |
| --- | --- | --- |
| `ai` | changes to `packages/stream_chat_flutter_ai` | ✅ yes |
| `repo` | CI, tooling, workspace and repository config | no |
| `docs` | README, CONTRIBUTING and other documentation | no |
| `deps` | dependency bumps (what Dependabot uses) | no |

Common types: `fix:` (patches a bug — `PATCH` in semver), `feat:` (adds a feature — `MINOR`), plus `build:`, `chore:`, `ci:`, `docs:`, `style:`, `refactor:`, `perf:` and `test:`. A commit with a `BREAKING CHANGE:` footer, or a `!` after the type/scope, introduces a breaking API change (`MAJOR`).

### CHANGELOG.md Updates 📝

Any PR scoped `ai` must update `packages/stream_chat_flutter_ai/CHANGELOG.md`. CI enforces this. We group entries under the emoji headings already used in the file: `✅ Added`, `🔄 Changed`, `🐞 Fixed`, `🚀 Performance`.

### Testing

At Stream, we value testing. Every PR should include passing tests for existing and new features. To run the test suite locally:

```bash
melos run test:all
```

### Golden tests 🖼️

The package uses [Alchemist](https://pub.dev/packages/alchemist) for golden tests, which keeps two sets of goldens (see `packages/stream_chat_flutter_ai/test/flutter_test_config.dart`):

- **`goldens/macos/`** — real text rendering, used when you run tests locally. These are **not** committed (see `.gitignore`); regenerate them with `melos run update:goldens` whenever a widget's appearance changes intentionally.
- **`goldens/ci/`** — text obscured into rectangles for cross-host stability. These **are** committed, and they are the ones CI compares against. They must be rendered on a Linux runner to be byte-stable, so don't generate them locally — run the **`update_goldens`** workflow (`workflow_dispatch`) against your branch instead. It regenerates them and commits the result back, which retriggers CI.

To check what CI will see before pushing:

```bash
CI=true melos run test:all
```

---

# Versioning Policy

`stream_chat_flutter_ai` follows [semantic versioning](https://semver.org/).

---

# Styleguides 💅

We use style guides and lint checks to keep our code consistent and maintain best practices, via Dart's built-in analyzer. The full rule list lives in [`analysis_options.yaml`](analysis_options.yaml) at the repository root — it is shared by every workspace member (the example app relaxes a few rules that only make sense for a published API).

Because `dart analyze` resolves the whole pub workspace in one pass, a single command covers everything:

```bash
melos run analyze   # dart analyze --fatal-infos .
melos run format    # dart format --set-exit-if-changed .
melos run lint:all  # both of the above
```

Note that `--fatal-infos` means lint *infos* fail the build, and formatting is checked in CI — so run `melos run lint:all` before pushing.
