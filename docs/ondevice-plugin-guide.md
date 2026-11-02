# Building `stream_chat_flutter_ai_ondevice` by hand

This guide is for a developer who wants to build or change the on-device model plugin without help.
It walks through how the package is put together, in the order you would build it. The finished
package is in `packages/stream_chat_flutter_ai_ondevice`.

## What it is

`stream_chat_flutter_ai` defines `AILocalModel`, an interface for a model on the device that can
answer when the AI agent can't:
- `isAvailable`
- `reply(instructions, turns)`, which streams the whole answer so far

This plugin implements that interface with the model built into the device, matching Stream's
native SDKs:

| Platform | Model | Native reference |
| --- | --- | --- |
| Android | Gemini Nano, through ML Kit `com.google.mlkit:genai-prompt:1.0.0-beta4` | `stream-chat-android-ai-ondevice/.../AIOnDeviceModel.kt` in GetStream/stream-chat-android |
| iOS, macOS 26+ | Apple's Foundation Models | `Sources/StreamChatAI/AI/LocalModel/AIOnDeviceModel.swift` in GetStream/stream-chat-swift |

No Dart-only route reaches these models. Firebase AI Logic's Dart SDK has no on-device mode, the
community ML Kit and Foundation Models plugins don't cover the API this needs, and Dart's Swift
interop can't call `streamResponse`. So this is a plugin with Kotlin and Swift code. It follows the
layout of `stream_thumbnail` in GetStream/stream-core-flutter.

## 1. Prerequisites

- Flutter 3.41 or later, and Melos 8 (`dart pub global activate melos`).
- Xcode 26 or later, for the FoundationModels SDK.
- Android SDK 36 and JDK 17.
- To see real answers, you need one of:
  - an iPhone or a Mac on 26.x with Apple Intelligence turned on;
  - an Android phone whose AICore offers Gemini Nano (Pixel 9 or Galaxy S25 class).

Simulators and emulators report the model as unavailable. The iOS Simulator is a trap: it reports
the model as available, then refuses to run it.

## 2. Create the plugin

```bash
flutter create --template=plugin --platforms=android,ios,macos --org io.getstream \
  -a kotlin -i swift --project-name stream_chat_flutter_ai_ondevice /tmp/pkg
rsync -a --exclude example --exclude .dart_tool --exclude pubspec.lock --exclude '*.iml' \
  --exclude local.properties /tmp/pkg/ packages/stream_chat_flutter_ai_ondevice/
```

Then clean up what the template generated:
- Delete the template's Dart, Kotlin and Swift sample code, and its `PrivacyInfo.xcprivacy` files.
  The plugin uses no required-reason APIs.
- Copy `LICENSE` from the core package.

Keep both `ios/stream_chat_flutter_ai_ondevice/` and `macos/stream_chat_flutter_ai_ondevice/`. Each
is its own SwiftPM package. SwiftPM rejects a target `path:` outside its package root, so iOS and
macOS can't share one source folder. Each keeps an identical copy of the Swift files, and CI checks
that the copies match.

## 3. Join the workspace

In `packages/stream_chat_flutter_ai_ondevice/pubspec.yaml`:
- set `resolution: workspace`;
- use the same `environment` as the core package;
- add the dependencies `flutter`, `plugin_platform_interface` and `stream_chat_flutter_ai: ^<core version>`;
- add the dev dependencies `flutter_test` and `pigeon`;
- add the plugin block:

```yaml
flutter:
  plugin:
    platforms:
      android:
        package: io.getstream.stream_chat_flutter_ai_ondevice
        pluginClass: StreamChatFlutterAiOndevicePlugin
      ios:
        pluginClass: StreamChatFlutterAiOndevicePlugin
      macos:
        pluginClass: StreamChatFlutterAiOndevicePlugin
```

In the root `pubspec.yaml`:
- add the package to `workspace:`;
- add `plugin_platform_interface` and `pigeon` to `melos.command.bootstrap`;
- add the `generate:pigeon` script, copied from stream-core-flutter's `melos.yaml`. It runs Pigeon
  once per Apple platform with `--swift_out`, then formats the Dart output.

Then run `melos bootstrap`.

Don't add `stream_chat_flutter_ai` to the root bootstrap list. Melos would then rewrite the
example's `stream_chat_flutter_ai: any`. The packages are released in lockstep, so bump the
constraint by hand with each release.

## 4. Define the platform channel with Pigeon

`pigeons/messages.dart` is the contract between Dart, Kotlin and Swift. Its pieces:

| Piece | What it is |
| --- | --- |
| `ModelStatusMessage` | `unavailable`, `downloadable`, `downloading`, `available` |
| `TurnMessage` | `role` + `text` |
| `ModelInfoMessage` | `status`, `contextSize`, `maxResponseTokens?` |
| `ReplyRequestMessage` | `instructions`, the fitted `turns`, `maximumResponseTokens` |
| `ReplyEvent` (sealed) | `ReplyText`, `ReplyDone` and `ReplyFailed`, each carrying a `requestId` |
| `DownloadEvent` (sealed) | `DownloadStarted`, `DownloadProgress` (bytes and/or fraction), `DownloadCompleted`, `DownloadFailed` |
| `@HostApi OnDeviceModelHostApi` | `@async modelInfo()`, `startReply(id, request)`, `cancelReply(id)`, `startDownload()`, `cancelDownload()` |
| `@EventChannelApi OnDeviceModelEventApi` | `replyEvents()`, `downloadEvents()` |

Pigeon's event channels take no arguments. So `startReply` starts a reply under an id, and every
reply's events come back on one shared `replyEvents()` stream, tagged with that id.

To generate the bindings, run `melos run generate:pigeon`. That writes:
- `lib/src/messages.g.dart`
- `android/.../Messages.g.kt`
- `ios|macos/<pkg>/Sources/<pkg>/Messages.g.swift`

## 5. The Dart side

- `AIOnDeviceModelPlatform` (`plugin_platform_interface`) has three members:
  - `modelInfo()`
  - `reply(instructions, turns, maximumResponseTokens)`, which emits the whole answer so far and
    errors with `AILocalModelException`
  - `download()`
- `MethodChannelAIOnDeviceModel` is the default implementation:
  - It numbers each reply and keeps a `StreamController` per id.
  - It listens to `replyEvents()` only while a reply is in progress. It subscribes before calling
    `startReply`, so the first chunk isn't missed: messages on one channel reach the platform in
    order.
  - It routes `ReplyText`, `ReplyDone` and `ReplyFailed` to their reply by id. Cancelling a reply
    calls `cancelReply`.
  - It turns `MissingPluginException` (no plugin on this platform) into `unavailable`.
- `AIOnDeviceModel extends AILocalModel` replies in four steps:
  1. Read `modelInfo()`. If the model isn't `available`, fail with `unavailable`.
  2. Work out the answer length: `min(maximumResponseTokens, info.maxResponseTokens)`.
  3. Fit the conversation with
     `AIConversationTurn.fitToBudget(turns, maxTokens: contextSize - responseTokens - 50, instructions:)`.
     If the result is empty or doesn't end with the user's question, fail with
     `invalidConversation`. If the budget is 0 or less, fail with `contextExceeded`.
  4. Stream the platform's reply. Cancelling the subscription before step 4 means the reply never
     starts.
- `status()` never throws: any error reads as `unavailable`. `isAvailable` is
  `status() == available`.

## 6. The Kotlin side (Android)

In `android/build.gradle.kts`:
- set `minSdk = 26`;
- add `implementation("com.google.mlkit:genai-prompt:1.0.0-beta4")`;
- add `implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")`, which the
  generated code dispatches `@async` calls on.

ML Kit's own manifest already declares the AICore `<queries>` entry and the service binding, so the
plugin's manifest stays empty.

The files:
- **`OnDevicePrompt.kt`** — a verbatim port of the Android SDK's prompt builder:
  `Conversation so far:\nUser: …\nAssistant: …\n\nAnswer the user's last message.\n\nUser: <q>`.
- **`GenAiErrors.kt`** — maps ML Kit's `GenAiException.ErrorCode` to a reason:
  - `REQUEST_TOO_LARGE` → `contextExceeded`
  - `NOT_AVAILABLE`, `NOT_SUPPORTED`, `BUSY`, `PER_APP_BATTERY_USE_QUOTA_EXCEEDED`,
    `BACKGROUND_USE_BLOCKED`, `NOT_ENOUGH_DISK_SPACE`, `NEEDS_SYSTEM_UPDATE`, `AICORE_INCOMPATIBLE`
    → `unavailable`
  - everything else → `failed`
- **`StreamChatFlutterAiOndevicePlugin.kt`** — a `FlutterPlugin` and `OnDeviceModelHostApi`:
  - In `onAttachedToEngine`, call `OnDeviceModelHostApi.setUp(...)` and register the reply and
    download stream handlers, keeping each sink.
  - `modelInfo`: check the AICore package (`getPackageInfo`), then `checkStatus()`,
    `getTokenLimit()` (falling back to 4000) and `maxResponseTokens = 256`.
  - `startReply`: launch a job, kept per id. It re-checks the status and calls
    `isSystemPromptAvailable()` to choose between a `SystemInstruction` and inlining the
    instructions. It then runs `generateContentStream`, appends each chunk's text and sends the
    accumulated text, then `ReplyDone`. A `GenAiException` becomes `ReplyFailed`.
  - `cancelReply` cancels the job.
  - `startDownload` collects `model.download()` and maps each status to an event, catching errors
    (the Android SDK doesn't).

Test with:

```bash
cd packages/stream_chat_flutter_ai/example && flutter build apk --debug
cd android && ./gradlew :stream_chat_flutter_ai_ondevice:testDebugUnitTest
```

## 7. The Swift side (iOS and macOS)

Write the files once under `ios/<pkg>/Sources/<pkg>/` and copy them to `macos/`. Import Flutter
like this:

```swift
#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#endif
#if canImport(FoundationModels)
  import FoundationModels
#endif
```

Wrap every use of Foundation Models in `if #available(iOS 26.0, macOS 26.0, *)`. The podspecs set
`s.weak_frameworks = 'FoundationModels'`, so the app still runs on iOS 13–25, where the model reads
as unavailable.

The files:
- **`TranscriptBuilder.swift`** — a port of the iOS SDK's transcript:
  - an `.instructions` entry, skipped when the instructions are blank;
  - then `.prompt` for user turns and `.response` for assistant turns.
- **`GenerationErrorMapper.swift`** — maps `LanguageModelSession.GenerationError` (iOS 26). On
  `#if compiler(>=6.4)` it also maps iOS 27's `LanguageModelError`,
  `SystemLanguageModel.Error` and `LanguageModelSession.Error`:

  | Error | Reason |
  | --- | --- |
  | context exceeded | `contextExceeded` |
  | assets unavailable, rate limited, concurrent requests, timeout | `unavailable` |
  | anything else | `failed` |
- **`StreamChatFlutterAiOndevicePlugin.swift`**:
  - `register(with:)` sets up the host API and both stream handlers. The messenger is
    `registrar.messenger()` on iOS and `registrar.messenger` on macOS.
  - `modelInfo` maps `availability`: `.available` → available, `.unavailable(.modelNotReady)` →
    downloading, anything else → unavailable. It reads `contextSize` under `#if compiler(>=6.3)`
    and falls back to 4096 otherwise.
  - `startReply` runs a `Task`, kept per id. It builds a
    `LanguageModelSession(model:transcript:)` and iterates
    `streamResponse(to: question, options: GenerationOptions(maximumResponseTokens:))`, sending
    each snapshot's `content` (already the whole answer) and then `ReplyDone`. `cancelReply`
    cancels the task.
  - `startDownload` emits `DownloadCompleted` when the model is available and otherwise
    `DownloadFailed(unavailable, systemManaged)`. Apple downloads its model by itself.

Test with:

```bash
cd packages/stream_chat_flutter_ai/example
flutter build ios --simulator --debug
flutter build macos --debug
```

## 8. Tests

In `packages/stream_chat_flutter_ai_ondevice/test/`:
- `ai_on_device_model_test.dart` uses a fake `AIOnDeviceModelPlatform`. It covers:
  - status mapping
  - fitting and the answer cap
  - each failure reason
  - cancelling, including before the model is checked
  - download pass-through
- `ai_on_device_model_method_channel_test.dart` uses a fake `OnDeviceModelHostApi` and stream
  controllers. It covers:
  - routing replies by id
  - failure mapping
  - listening only while a reply is in progress
  - download events
  - one round trip through the real generated channels, using
    `TestDefaultBinaryMessengerBinding` and `pigeonMethodCodec`

Run them with `flutter test` in the package, or `melos run test:all`.

## 9. Wire it into an app

- Add the dependency, and on Android set `minSdk = 26`.
- Use `const AIOnDeviceModel()` wherever an `AILocalModel` is expected.
- For a status and download control, see the example's `lib/on_device_status.dart`. It keeps
  showing the download as under way while AICore still reports `downloadable`.

## 10. Check on devices

| Where | What to check |
| --- | --- |
| Mac on macOS 26 with Apple Intelligence | Run `flutter run -d macos` in the example, turn the cloud off and ask something. The answer should stream, and tapping stop should halt it. With Apple Intelligence off, the app should say the model isn't available. |
| iOS Simulator on iOS 18 | The app launches (proving the weak link) and reports the model unavailable. |
| iPhone on iOS 26 | Streaming, stop, a long conversation being trimmed, an over-long question giving `contextExceeded`, and airplane mode. |
| AICore phone | `downloadable` → download progress → `available`; streaming and stop; putting the app in the background mid-reply giving `unavailable`. Also check that `flutter build apk --release` passes R8. |

## 11. Ship

- Update the package's `CHANGELOG.md` under `## Upcoming`, and add a pointer line in the core
  package's CHANGELOG.
- Run `melos run lint:all && melos run test:all && melos run lint:pub`.
- Title the PR `feat(ondevice): …`.
- The two packages are released in lockstep: the release bumps both versions and the
  `stream_chat_flutter_ai` constraint.
