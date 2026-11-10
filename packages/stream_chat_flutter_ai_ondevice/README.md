# On-device model for Stream Chat AI Flutter components

The language model built into the device, as an
[`AILocalModel`](https://pub.dev/documentation/stream_chat_flutter_ai/latest/stream_chat_flutter_ai/AILocalModel-class.html):
an answer for when your AI agent can't give one, because the person is offline or the agent reached
its usage limit. Gemini Nano on Android, Apple's Foundation Models on iOS and macOS.

This package is a companion to
[`stream_chat_flutter_ai`](https://pub.dev/packages/stream_chat_flutter_ai). The conversation never
leaves the device. It is a small model with a context of a few thousand tokens, good for short
answers and for working with what is in the conversation, and it has none of your agent's tools.

- [Installation](#installation)
- [Quickstart](#quickstart)
- [Options](#options)
- [Errors](#errors)
- [Status and download](#status-and-download)
- [Requirements](#requirements)
- [Limits](#limits)
- [More](#more)

## Installation

```yaml
dependencies:
  stream_chat_flutter_ai: ^0.1.0
  stream_chat_flutter_ai_ondevice: ^0.1.0
```

Both packages are released together, with the same version.

On Android, raise the app's `minSdk` to 26 in `android/app/build.gradle(.kts)`. ML Kit's GenAI
libraries are built against Kotlin 2.3, so an app on a much older Kotlin Gradle plugin may need to
update it.

On iOS and macOS the plugin is a Swift package, so the app needs Swift Package Manager. Flutter
uses it by default from 3.44; on older versions, turn it on with
`flutter config --enable-swift-package-manager`. CocoaPods isn't supported.

## Quickstart

Fall back only when the agent didn't take the message — offline, out of quota, or the service
unreachable — not when it may have, or the question is answered twice. Messages with attachments
are better left to the agent: the model reads text only.

```dart
const model = AIOnDeviceModel();

try {
  await backend.send(text);
} on Exception catch (error) {
  if (!isOfflineOrOverQuota(error) || !await model.isAvailable) rethrow;
  // Create the stream once, when the question is sent — never in `build`.
  setState(() {
    _localAnswer = model.reply(
      instructions: "You are a helpful assistant answering on the person's device, without a "
          'connection to the server. Answer briefly. You have no tools.',
      turns: [...history, AIConversationTurn.user(text)],
    );
  });
}
```

What the person sees:

- Each event is the **whole answer so far** — pass it to `StreamingMessageView.text`.
- Cancelling the subscription stops the model.
- The answer exists only on the device: keep it there, or send it yourself.

`history` is the conversation so far, oldest first: the person's messages as
`AIConversationTurn.user`, the agent's answers (not its working steps) as
`AIConversationTurn.assistant`. Other people's messages can go in as user turns prefixed with their
name. The newest turns that fit the model's context are sent, always with the question.

## Options

| Option | What it does | Default | Change it to |
| --- | --- | --- | --- |
| `AIOnDeviceModel.maximumResponseTokens` | The longest answer, in tokens. | `1000` | Shorten answers, or allow longer ones on iOS and macOS. Gemini Nano writes at most 256, so Android caps it. |
| `reply(instructions:)` | The system prompt the model answers under. | required | Tell it to answer briefly, that it has no tools, and in which language. |
| `reply(turns:)` | The conversation so far, ending with the person's question. | required | Pass the history; the newest turns that fit the context are kept. |

## Errors

Failures arrive as an `AILocalModelException`:

| `reason` | Means |
| --- | --- |
| `unavailable` | The model can't answer now: missing, switched off, busy, out of its battery quota, or the app is in the background (Android answers only in the foreground). Try again later. |
| `contextExceeded` | The question alone is longer than the model's context. |
| `invalidConversation` | The turns are empty or don't end with the person's question. |
| `failed` | The model started but failed, such as refusing the content. |

Its `cause` is an `AIOnDeviceError` with the platform's own code, for logs.

A model that reports itself available can still fail: in the iOS Simulator, Apple's model reads as
available but refuses to run. Test on a device, or on a Mac with Apple Intelligence on.

## Status and download

```dart
switch (await model.status()) {
  case AIOnDeviceStatus.available:
    // Ready.
  case AIOnDeviceStatus.downloadable:
    // From a tap: the person asked for it.
    model.download().listen((event) => switch (event) {
      AIOnDeviceDownloadProgress(:final bytesDownloaded) => showProgress(bytesDownloaded),
      AIOnDeviceDownloadFailed(:final error) => showError(error),
      _ => null,
    });
  case AIOnDeviceStatus.downloading:
    // This can take hours: the system may wait until the device is idle and on Wi-Fi.
  default:
    // Unavailable: this device can't answer. New statuses may be added, so a switch needs a default.
}
```

- On Android, AICore can keep reporting `downloadable` until it actually starts the download it was
  asked for; keep showing the download as under way until the status moves on.
- On iOS and macOS the system downloads Apple's model by itself once Apple Intelligence is on, so
  there is nothing to start: `download()` completes at once when the model is available and fails
  otherwise.

## Requirements

| Platform | Model | Needs |
| --- | --- | --- |
| Android | Gemini Nano in AICore, through ML Kit's GenAI Prompt API | `minSdk 26`, a device whose AICore offers Gemini Nano (recent Pixel, Samsung and other flagship phones). Not emulators. |
| iOS, macOS | Apple's Foundation Models | iOS 26 or macOS 26, a device that supports Apple Intelligence, with it turned on. |
| Others | — | `status()` reports `unavailable`. |

## Limits

- Gemini Nano writes at most 256 tokens per answer; `maximumResponseTokens` is capped to it on
  Android.
- The context is a few thousand tokens, as each model reports it. Apple's is 4096 when the app is
  built with an SDK older than iOS 26.4, which can't ask the model.
- The plugin keeps one native model per Flutter engine and frees it when the engine goes away;
  `AIOnDeviceModel` itself holds nothing, so there is nothing to close.
- ML Kit's Prompt API is in beta (`com.google.mlkit:genai-prompt:1.0.0-beta4`).

## More

- The [example app](https://github.com/GetStream/stream-chat-flutter-ai/tree/main/packages/stream_chat_flutter_ai/example):
  its app bar switches between the cloud and the device, and shows the model's status and download.
- [`AILocalModel`](https://pub.dev/documentation/stream_chat_flutter_ai/latest/stream_chat_flutter_ai/AILocalModel-class.html),
  the interface this implements, and how to show its answer.
- The same model ships in Stream's native SDKs: `AIOnDeviceModel` in `StreamChatAI` (iOS) and in
  `stream-chat-android-ai-ondevice` (Android).
