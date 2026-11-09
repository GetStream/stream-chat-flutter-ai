# Test fixtures

- `ios_a2ui_stream_messages.json` — the reference splits: the messages StreamChatA2UI's `A2UIStream.messages` finds in 33 texts,
  produced by running it (stream-chat-swift `develop` @ `be3e9db`,
  `Sources/StreamChatA2UI/Facade/A2UIStream.swift`, copied unchanged into a Swift driver). Each case holds its
  `input` and the `messages` found.
- `ohrid_prompt_example.jsonl` — the A2UI block of the Ohrid weekend example in the prompt the Stream agent
  backend gives its model (GetStream/Vision-Agents `accelerate` @ `4ff3a65`,
  `examples/voice_agents/swift_assistant/a2ui/prompt.json`, `examples[0]`), unchanged.
