![Integrating Stream Chat with AI](/assets/repo_cover.png)

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
reference.

## Getting Started

Add the package to your app:

```yaml
dependencies:
  stream_chat_flutter_ai: ^0.1.0
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

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## 🛥 What is Stream?

Stream allows developers to rapidly deploy scalable feeds, chat messaging and video with an industry
leading 99.999% uptime SLA guarantee.

Stream provides UI components and state handling that make it easy to build real-time chat and video
calling for your app. Stream runs and maintains a global network of edge servers around the world,
ensuring optimal latency and reliability regardless of where your users are located.

## 📕 Tutorials

Stream's Chat SDK is natively supported across
[React](https://getstream.io/chat/react-chat/tutorial/),
[React Native](https://getstream.io/chat/react-native-chat/tutorial/),
[Angular](https://getstream.io/chat/angular/tutorial/),
[Jetpack Compose](https://getstream.io/tutorials/android-chat/),
[SwiftUI](https://getstream.io/tutorials/ios-chat/),
[Flutter](https://getstream.io/chat/flutter/tutorial/) and
[Javascript](https://getstream.io/chat/docs/javascript/). The sibling AI component libraries live in
[stream-chat-android-ai](https://github.com/GetStream/stream-chat-android-ai) and
[stream-chat-swift-ai](https://github.com/GetStream/stream-chat-swift-ai).

## 👩‍💻 Free for Makers 👨‍💻

Stream is free for most side and hobby projects. To qualify, your project/company needs to have
< 5 team members and < $10k in monthly revenue. For more details, check out the
[Maker Account](https://getstream.io/maker-account).

## 💼 We are hiring!

We've recently closed a [\$38 million Series B funding round](https://techcrunch.com/2021/03/04/stream-raises-38m-as-its-chat-and-activity-feed-apis-power-communications-for-1b-users/)
and we keep actively growing. Check out our current openings and apply via
[Stream's website](https://getstream.io/team/#jobs).

## License

Released under the Stream Source Code License Agreement. See [`LICENSE`](LICENSE) for the full
text.
