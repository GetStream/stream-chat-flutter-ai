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

A case or area that isn't run is listed, with its reason, in
[`test/openui_conformance_skips.dart`](test/openui_conformance_skips.dart); `upstream_spec_conformance_test.dart`
fails if an area of the vendored specification is neither run nor skipped there.

## Why the OpenUI package keeps its conformance tests

The core is a port of `@openuidev/lang-core`, so these suites are its regression net: any change to the parser,
evaluator or prompts is checked against what OpenUI's own implementation gives, and a replacement core has to pass
the same suites.

## What is vendored

- [`test/upstream`](test/upstream) — the OpenUI Lang 1.0 specification and its fixtures, unchanged, with their
  license (MIT).
- [`test/generated`](test/generated) — what OpenUI's own implementation gives for a corpus of programs; its README
  says how they were produced.
