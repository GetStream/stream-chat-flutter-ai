# Why the A2UI package keeps its conformance tests

**Short version:** we don't implement the protocol ourselves, but our renderer is still on the hook for it. The
upstream suites are the cheapest way to prove that, and they've already caught breakage nothing else did.

## What they check here
iOS (`StreamChatA2UI`) and Android (`stream-chat-android-ai-a2ui`) implement A2UI by hand, so their conformance tests
check their own engine: Android runs the vendored upstream suites data-driven, iOS hand-ports selected cases.

Flutter builds on `a2ui_core`, the A2UI project's own Dart core. So our run checks **our adapter plus the pinned core**
against the spec, through the adapter in `lib/src/core/`, never the core directly. Much of each pass re-tests the core,
and that's expected. What is ours: the version handling, error-code mapping, default catalog, secrets kept out of what
goes to the agent, action events, and how all of that behaves with the exact core release we ship.

## Why they pay off
They are the regression net for core bumps and adapter changes. Moving to `a2ui_core` 0.5.0 alone, they caught:
- the `"1.0"`→`"v1.0"` shim breaking every message (1,032 failures) while the analyzer was clean;
- the new error codes and the catalog's user-activation rule;
- 17 stale "core gap" skips and one stale example skip;
- a new upstream suite (`agent_function_routing`) that would have gone unrun. A guard test now makes every vendored
  suite either run or skipped with a reason.

They also keep the adapter honest if the core is ever replaced (by `a2ui_flutter`'s or our own): the replacement has to
pass the same suite.

## Keeping them cheap
If they ever need slimming, drop the suites that only re-test core internals first (expression parsing, function
evaluation, path resolution); keep the ones that go through what the adapter adds.
