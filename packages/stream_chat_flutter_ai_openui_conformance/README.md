# OpenUI conformance suites

The OpenUI Lang 1.0 conformance suites, run against `stream_chat_flutter_ai_openui`. This package holds only those
tests, so they stay out of the published package. It isn't published.

```bash
flutter test                      # every suite, from this directory
flutter test --tags conformance   # the same, as the suites are tagged
```

## What they check

Each case reads a program and compares what the package's core gives with what OpenUI's own TypeScript implementation
gave for it: the parse result, streamed and in one piece, the evaluated tree, the generated prompts, the library
definitions and the specification's interaction fixtures.

The suites go through the core in `stream_chat_flutter_ai_openui`'s `lib/src/core/`, and, for the cases an app never
reaches on its own, through its test interface in `lib/src/core/openui_test_interface.dart`.

## What is vendored

- [`test/upstream`](test/upstream) — the OpenUI Lang 1.0 specification and its fixtures, unchanged, with their
  license (MIT).
- [`test/generated`](test/generated) — what OpenUI's own implementation gives for a corpus of programs; its README
  says how they were produced.
