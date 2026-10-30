# stream_chat_flutter_ai_example

A minimal showcase app for [`stream_chat_flutter_ai`](../README.md).

It wires up the package's main components against a canned reply — there is no
backend, no API key and no LLM provider involved:

- `ChatComposer` (with `ChatComposerController`, two `ChatOption`s and
  `enableSpeechToText: true`) — try the **+** button for the attachment sheet
  and the mic for dictation.
- `AISuggestionsView` — the quick-reply chips on the empty "new chat" screen.
- `AIConversationView` — lays out the conversation, scrolling each question to
  the top and leaving the list alone while you scroll. It shows when the fake
  assistant is "thinking", its reasoning and tool calls as steps, and types the
  reply out through `StreamingMessageView`, rendering markdown, a fenced code
  block (`CodeBlockView`) and a chart fence (`ChartView`).

## Running it

This app is a member of the repository's pub workspace, so bootstrap from the
repository root first:

```bash
melos bootstrap
cd packages/stream_chat_flutter_ai/example
flutter run
```

For a fuller, backend-connected sample see
[GetStream/chat-ai-samples](https://github.com/GetStream/chat-ai-samples).
