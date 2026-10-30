---
name: release-pr
description: >
  Open a release PR for stream_chat_flutter_ai: bump the package version and the README install snippets, finalise
  the CHANGELOG, and open a PR against main with auto-generated release notes.
disable-model-invocation: true
argument-hint: "[version]"
arguments: [version]
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
  - Bash(melos *)
  - Bash(which *)
  - Bash(grep *)
  - Bash(sed *)
  - Read
  - Edit
  - Write
---

# release-pr

Opens a release PR for stream_chat_flutter_ai. Branch `release/v<X.Y.Z>` → base `main` → title
`chore(repo): release v<X.Y.Z>`.

**This skill only opens the PR.** After merge, tagging and pub.dev publishing are automatic:
[`release_tag.yml`](../../../.github/workflows/release_tag.yml) extracts `vX.Y.Z` from the commit message and
pushes the tag; [`release_publish.yml`](../../../.github/workflows/release_publish.yml) publishes over OIDC and
creates the GitHub Release. See the "Releasing" section of `CLAUDE.md`.

If `$version` is provided (e.g. `/release-pr 0.2.0`), use it. Strip any leading `v`. Otherwise derive and confirm
per [Choosing the version](#choosing-the-version).

## Key facts for this repo

- **One publishable package:** `packages/stream_chat_flutter_ai`. The example app is `publish_to: none`, and the
  workspace root is private. Nothing depends on the package inside the repo except the example, which uses
  `any`, so there are no intra-repo constraints to bump.
- **The title is load-bearing.** `release_tag.yml` only fires on a tip commit starting with
  `chore(repo): release v`, and refuses to tag unless the version in it matches the pubspec. `repo` is also the
  scope `pr_title.yml` doesn't map to a CHANGELOG, so the changelog check doesn't apply — this skill edits the
  CHANGELOG anyway.
- **The CHANGELOG is hand-curated.** Never run `melos version` — it regenerates entries from commit messages and
  clobbers the curated `## Upcoming` bullets. Releasing means *promoting* `## Upcoming` to `## X.Y.Z`.
- **Stable releases from `main` only.** No beta train exists; if the user asks for a `-suffix` version, stop and
  ask how they want it handled.

## Inputs

1. **Version** (`X.Y.Z`). Use `$version` if supplied; otherwise derive it below and confirm with the user. Don't
   silently infer.
2. **Previous tag** for the release-notes diff — the highest stable `vX.Y.Z` tag on the remote:

   ```bash
   git ls-remote --tags --refs origin 'refs/tags/v*' | sed 's|.*refs/tags/||' | sed '/-/d' | sort -V | tail -1
   ```

   Tags, not `gh release list`: a tag can exist without a GitHub Release. Empty output means there is no previous
   tag (true for the first automated release — 0.1.0 was published by hand and never tagged).

A release is warranted when `packages/stream_chat_flutter_ai/CHANGELOG.md` has a non-empty `## Upcoming` section.
If it doesn't, say so and stop — there is nothing to release.

## Choosing the version

Two steps: classify the release from the CHANGELOG, then map that onto the current version.

**1. Classify.** Read the curated `## Upcoming` section — the same bullets that become the release notes, so they
are the authority on what the release contains:

```bash
sed -n '/^## Upcoming/,/^## [0-9]/p' packages/stream_chat_flutter_ai/CHANGELOG.md
```

The sub-headings are plain emoji lines, not markdown headings: `💥 Breaking`, `✅ Added`, `🔄 Changed`,
`🐞 Fixed`, `🚀 Performance`. They're a strong signal but still read the bullets:

- **breaking** — anything under `💥 Breaking`, or an existing API removed, renamed without a compatible alias,
  changed in signature, or changed in behaviour in a way that breaks callers (check `🔄 Changed` for these).
- **compatible, adds API** — new widgets, fields, methods, optional parameters (usually `✅ Added`).
- **no public API change** — internal fixes, docs, dependency bumps.

**Deprecations are not breaking** — a deprecated API still works. A rename **without** an alias is breaking.
Adding a string to `AITranslations` is not breaking either (see `CLAUDE.md`).

**2. Map onto the current version.** Per the Dart community convention in
[Package versioning](https://dart.dev/tools/pub/versioning#semantic-versions), below `1.0.0` a breaking release and a
feature release each shift down one slot. A release with no public API change still bumps the patch: the release
workflows only take `vX.Y.Z` and `vX.Y.Z-suffix` tags, so a build number (`+1`) can't be released.

```bash
grep '^version:' packages/stream_chat_flutter_ai/pubspec.yaml
```

| Release | at/above `1.0.0` | below `1.0.0` |
| --- | --- | --- |
| breaking | major | minor |
| compatible, adds API | minor | patch |
| no public API change | patch | patch |

A caret constraint stops at the leading significant digit: `^0.1.0` means `>=0.1.0 <0.2.0`. Bumping that slot
strands every consumer on the old caret until they hand-edit their pubspec — so bump it only for a genuinely
breaking release.

State the proposed version, what in `## Upcoming` drove the classification, and which column you used; then ask
the user to confirm — **they still decide**. If they supply a version that disagrees with the derivation, say so
once, then use theirs.

> There is no undo: pub.dev cannot delete a published version. Get the bump right before merge.

## Pre-flight

Run these checks. **If any fail, stop, surface the failing check to the user, and do not try to auto-fix** (no
stashing uncommitted work, no force-pulling, no killing processes).

- `git status --short -uno` clean after `git checkout main` + `git pull --ff-only`.
- `which melos` and `gh auth status` succeed.
- `gh pr list --head release/v<version> --state all --json number` returns `[]`.
- `v<version>` isn't tagged yet: `git ls-remote --tags origin refs/tags/v<version>` prints nothing.
- Latest CI on `main` is green: `gh run list --branch main --limit 5` — no failures on the most recent runs.
- **No `git:` or `path:` entry under `dependencies`** — pub.dev rejects both:

  ```bash
  grep -n -B2 -A4 -E '^\s+(git|path):' pubspec.yaml packages/stream_chat_flutter_ai/pubspec.yaml
  ```

  An entry under `dev_dependencies` is fine — pub ignores those when publishing. Only a real `dependencies`
  entry (in the package, or in the root `melos.command.bootstrap.dependencies` block that bootstrap copies into
  it) blocks. Surface it and stop — don't pick the constraint yourself. Once the user gives you one, set it in
  the root `pubspec.yaml` block only and let bootstrap propagate it in step 2.

## Steps

### 1. Branch off main

Pre-flight already left you on `main` with latest:

```bash
git checkout -b release/v<version>
```

### 2. Bump the version

Edit by hand:

- **`packages/stream_chat_flutter_ai/pubspec.yaml`** — set `version: <version>`. This is the package's own
  version, the one thing in it bootstrap doesn't manage. Change nothing else.
- **The install snippets** — `stream_chat_flutter_ai: ^<version>` in `README.md` and
  `packages/stream_chat_flutter_ai/README.md` (find them with
  `grep -n 'stream_chat_flutter_ai: \^' README.md packages/stream_chat_flutter_ai/README.md`). The package README
  is what pub.dev shows, so a stale caret there tells new users to install the old version.

Leave `packages/stream_chat_flutter_ai/example/pubspec.yaml` alone — it depends on `any` and resolves through the
workspace.

Then run:

```bash
melos bootstrap
```

Check the diff shape:

```bash
git diff --stat
```

Only `packages/stream_chat_flutter_ai/pubspec.yaml` and the two READMEs should appear (the CHANGELOG comes next).

`pubspec.lock` may show up too, but the bump itself never changes it — workspace members aren't listed in it. A
lockfile diff means the local Flutter SDK resolved transitive packages differently from the one that wrote it (it
can silently *downgrade* them). Ignore it here; step 4 restores it right before committing, because every later
`melos`/`dart` command re-resolves and would rewrite it again. Anything else in the diff means bootstrap changed
something unexpected — surface it and stop.

### 3. Finalise the CHANGELOG

Rename `## Upcoming` to `## <version>` in `packages/stream_chat_flutter_ai/CHANGELOG.md`. Keep the curated bullets
and sub-headings exactly as they are — don't add, rewrite, reorder or regenerate them.

Don't write fresh bullets from `git log`. An unreleased user-facing change that never got an `## Upcoming` bullet
is a gap to raise with the user, not one for this step to fill in.

### 4. Analyze, then commit

```bash
melos run analyze
```

If it fails, surface to the user and stop.

```bash
git checkout pubspec.lock   # drop local re-resolution churn (see step 2)
git status --short          # exactly the pubspec, CHANGELOG and two READMEs; nothing untracked is release material
git add -u                  # tracked modifications only
git commit -m "chore(repo): release v<version>"
```

If you restored a changed lockfile, mention it to the user — a release must not carry an unrelated lockfile change.
`lint:pub` in step 5 will dirty it again; that's fine, because pub only checks git status inside the package
directory and the root lockfile isn't published.

`git add -u`, not `-A`: pre-flight's `git status --short -uno` ignores untracked files, so `-A` would sweep local
artifacts into the release commit.

Single commit. **The message format is load-bearing** — `release_tag.yml` parses `vX.Y.Z` out of it, and gates on
the tip commit of `main`, so the PR must be **squash-merged**. The repo only allows squash merges, which keeps the
PR title as the tip commit; the title must therefore stay exactly `chore(repo): release v<version>`.

`melos run lint:pub` is deliberately **not** in this step: `pub publish --dry-run` fails any dirty tree with
"N checked-in files are modified in git". It can only pass once the release commit exists — hence step 5.

### 5. Verify publishability, then push

```bash
melos run lint:pub
```

This is the real publish gate, and it now covers the package: `lint:pub` skips versions already on pub.dev, and
`<version>` isn't. Confirm the output shows `stream_chat_flutter_ai` being validated — if melos reports no
packages, the version bump didn't take. Read failures carefully — pub reports two severities and only one blocks:

- **"Package validation found the following error"** — blocks. `release_publish.yml` runs `pub publish -f`, and
  `-f` does **not** bypass errors. Must be fixed before merge.
- **"potential issue" / "Package has N warnings"** — `-f` publishes through these. Worth fixing, not blocking.

A common error is a `lib/` or `test/` file importing a package absent from the package's own `dependencies` /
`dev_dependencies`; it resolves locally through a transitive dep and only `pub publish` catches it. Fix at the
import or by declaring the dep (in both the package pubspec and the root list), and tell the user the release PR
now carries a source change.

If it fails, surface to the user and stop — don't push.

```bash
git push -u origin release/v<version>
```

### 6. Generate the PR body

`release_publish.yml` creates the GitHub Release with `generate_release_notes: true`, so the PR body should be
**exactly** what GitHub's release UI produces — no template wrapper, no extra description, no CLA checkboxes.

```bash
gh api repos/GetStream/stream-chat-flutter-ai/releases/generate-notes \
  -f tag_name=v<version> \
  -f previous_tag_name=v<previous> \
  -f target_commitish=main \
  --jq .body > <scratchpad>/release-notes.md
```

- `tag_name`: the tag that will be created (need not exist yet).
- `previous_tag_name`: from [Inputs](#inputs). **If there is no previous tag, drop this line** and tell the user
  the notes cover the repository's full history.
- `target_commitish`: `main`, not the release branch — the notes should cover every commit between the previous
  tag and where the tag will land after merge.
- Write the file to your scratchpad directory, not `/tmp`.

Read the file once to skim. If a PR title looks wrong, fix it on the originating PR and re-run the API call;
don't hand-edit the notes.

### 7. Open the PR

```bash
gh pr create \
  --base main \
  --head release/v<version> \
  --title "chore(repo): release v<version>" \
  --body-file <scratchpad>/release-notes.md
```

Return the PR URL. **Tell the user to squash-merge it**, without editing the title (see step 4).

## After merge (FYI)

`release_tag.yml` checks that `v<version>` matches the pubspec and isn't tagged yet, then pushes the tag with the
bot PAT. `release_publish.yml` fires on that tag push, runs a dry run, then `melos run release:pub` (OIDC), and
creates the GitHub Release. `lint:pub` and `release:pub` skip versions already on pub.dev, so a re-run after a
failure is a clean no-op for anything already live.

## Don't

- **Never bump the breaking slot without a breaking change** in `## Upcoming` — below `1.0.0` that slot is the
  **minor**, and bumping it strands every consumer on the old caret.
- **Never run `melos version`** — it clobbers the hand-curated CHANGELOG.
- **Never create a GitHub release** (`gh release create`, `POST /repos/.../releases`). Step 6 uses
  `generate-notes`, which is read-only; the release itself is created by `release_publish.yml`.
- **Never push a tag** — `release_tag.yml` does it on merge.
- **Never run `melos run release:pub`** or `flutter pub publish` without `--dry-run`/`-n` — publishing happens in
  `release_publish.yml` on tag push. Even if the user asks, refuse: running it locally publishes from an
  unreviewed working tree.
- **Never merge the PR.** Return the URL and stop.
