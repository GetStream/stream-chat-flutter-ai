# OpenUI Lang 1.0 reference outputs (vendored)

What OpenUI's own TypeScript implementation, `@openuidev/lang-core` 1.0.1, gives for a corpus of programs, recorded so
the package can be compared with it. Each file is unchanged from what produced it.

They were produced by stream-chat-swift's `Scripts/openui-fixtures/generate.sh` and `spec-fixtures.py` (`develop` @
`be3e9db9a5ad93a36f4b6e2ddfe45c63edc1e4d9`), run with Node 23.11 and `zod@4.4.3` against
[thesysdev/openui](https://github.com/thesysdev/openui) at `729ac8bbdf60a1cfe914f4a02683bce6262fe245` (MIT, see
[`../upstream/LICENSE`](../upstream/LICENSE)). They are byte-identical to the copies in stream-chat-swift
(`Tests/StreamChatOpenUITests/Fixtures/`) and stream-chat-android (`stream-chat-android-ai-openui/src/test/resources/fixtures/`
@ `3b306dc`).

- `parser-conformance.json` — 193 programs (79 for the chat library, 32 for the standard library, 17 for a minimal
  library, 65 for the specification's test library), each with its one-shot parse result, the chunks it is streamed in,
  the results at checkpoints of the stream, and the result once the stream completes.
- `evaluator-conformance.json` — 190 programs with their evaluated root, state, queries, references and runtime errors.
- `prompt-goldens.json` — 14 system prompts generated from the libraries with different options.
- `spec-interactions.json` — the 12 cases of the specification with interactions.
- `upstream-chat-library.spec.json`, `upstream-playground-library.spec.json` — the chat library (84 components, root
  `Card`) and the standard library (82 components, root `Stack`) as `library.toSpec()` writes them.
- `spec-library.json` — the specification's test library (root `Stack`, 12 components).
