# Flutter AI components by [Stream](https://getstream.io/chat/sdk/flutter/)

[![Pub](https://img.shields.io/pub/v/stream_chat_flutter_ai.svg)](https://pub.dev/packages/stream_chat_flutter_ai)
[![CI](https://github.com/GetStream/stream-chat-flutter-ai/actions/workflows/stream_flutter_ai_workflow.yml/badge.svg?branch=main)](https://github.com/GetStream/stream-chat-flutter-ai/actions/workflows/stream_flutter_ai_workflow.yml)

This repository holds `stream_chat_flutter_ai` — a standalone set of Flutter components for
building LLM-driven chat experiences: streaming text, animated typing indicators,
syntax-highlighted code blocks, charts, a purpose-built AI composer, and speech-to-text input.

The package has **no dependency on `stream_chat`, `stream_chat_flutter`, or any other Stream Chat
package** — every widget operates on plain strings, callbacks, and controllers, so it can be
dropped into any Flutter app or paired with any backend/LLM provider. Wiring it up to a Stream Chat
channel is documented as an optional integration.

**Quick Links**

- [Register](https://getstream.io/chat/trial/) to get an API key for Stream Chat
- [Flutter AI Assistant Tutorial](https://getstream.io/blog/flutter-assistant/)
- [Flutter Chat Tutorial](https://getstream.io/chat/flutter/tutorial/)
- [Sample apps](https://github.com/GetStream/chat-ai-samples) — backend-connected samples across
  Flutter, React, React Native, iOS and Android

## Packages

| Package | Pub | Description |
| --- | --- | --- |
| [`stream_chat_flutter_ai`](packages/stream_chat_flutter_ai) | [![Pub](https://img.shields.io/pub/v/stream_chat_flutter_ai.svg)](https://pub.dev/packages/stream_chat_flutter_ai) | AI chat UI components: `StreamingMessageView`, `ChatComposer`, `AITypingIndicatorView`, `ChartView`, `CodeBlockView` and more. |

See the [package README](packages/stream_chat_flutter_ai/README.md) for the full component
reference, and [`ROADMAP.md`](packages/stream_chat_flutter_ai/ROADMAP.md) for what's planned.

## Getting Started

Add the package to your app:

```yaml
dependencies:
  stream_chat_flutter_ai: ^0.0.1
```

Then render a streaming AI response:

```dart
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

StreamingMessageView(
  text: markdownText, // updated in real time as chunks arrive
  typingSpeed: const Duration(milliseconds: 10),
);
```

There is a runnable showcase app in
[`packages/stream_chat_flutter_ai/example`](packages/stream_chat_flutter_ai/example) — it needs no
API key.

## Repository layout

This is a [Melos](https://melos.invertase.dev) monorepo built on
[Dart pub workspaces](https://dart.dev/tools/pub/workspaces), so there is a single shared
dependency resolution and one `pubspec.lock` at the root.

```bash
dart pub global activate melos   # requires Dart >= 3.9
melos bootstrap                  # resolves the workspace
melos run analyze                # dart analyze --fatal-infos across the workspace
melos run format                 # dart format --set-exit-if-changed
melos run test:all               # flutter test --coverage
melos run update:goldens         # regenerate golden files
```

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). We're also
[hiring](https://getstream.io/team/#jobs)!
