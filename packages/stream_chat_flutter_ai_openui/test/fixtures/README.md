# Test fixtures

- `json_probe_inputs.json` — 21 JSON texts that tell JSON readers apart: a repeated key, big and negative-zero numbers,
  invalid literals, control characters and lone surrogates. What reads them:
  - `node_json_parse.txt` — Node 23.11's `JSON.parse`, the behaviour OpenUI Lang is defined by;
  - `ios_openui_json.txt` — StreamChatOpenUI's `OpenUIJSON.parse`, produced by running it (stream-chat-swift `develop`
    @ `be3e9db`, `Sources/StreamChatOpenUI/Lang/Values/JSONParser.swift`, the module copied unchanged into a Swift
    driver);
  - `dart_json_decode.txt` — Dart 3.47.1's `jsonDecode`.
- `number_to_string_inputs.txt` — 32 numbers; `node_number_to_string.txt` holds Node 23.11's `String(n)` for each, and
  `ios_number_to_string.txt` StreamChatOpenUI's `JS.numberToString`, produced by running it (`be3e9db`,
  `Lang/Values/JSCompat.swift`); the two are equal.
- `to_number_inputs.json` — 39 strings; `node_to_number.txt` holds Node 23.11's `Number(s)` for each, and
  `ios_to_number.txt` StreamChatOpenUI's `JS.stringToNumber`, produced by running it (`be3e9db`); the two are equal.
- `ios_depth_boundaries.txt` — what StreamChatOpenUI's `OpenUIParser` gives (`be3e9db`, run) for operator chains
  `root = Title("a" + "b" + …)` and bracket nesting `root = Stack([[…1…]])` around its limit of 256, and for chains
  of references `r0 = [r1]`, `r1 = [r2]`, … ending in `Title("end")`, with the minimal library of the parser
  conformance cases.
- `ohrid_prompt_example.oui` — the OpenUI Lang block of the Ohrid weekend example in the prompt the Stream agent
  backend gives its model (GetStream/Vision-Agents `accelerate` @ `3b7a53f977`,
  `examples/voice_agents/swift_assistant/openui/instructions.md`, lines 157–179), unchanged.
- `ohrid_app_components.json` — the app components that example uses, `place_card`, `trip_map` and `calendar_check`
  (same commit, `examples/voice_agents/swift_assistant/app/SwiftAssistant/UIComponents.json`), unchanged.

The tests read the Node outputs (each line holds its input), `ios_depth_boundaries.txt` and the Ohrid files. The
`*_inputs` files, `ios_number_to_string.txt`, `ios_to_number.txt`, `ios_openui_json.txt` and `dart_json_decode.txt` are
reference data no test reads: they record the inputs, that StreamChatOpenUI agrees with Node (for JSON, except on lone
surrogates) and how far `jsonDecode` is from both. `node_to_number.txt`, for example, is regenerated from this folder
with:

```bash
node -e 'for (const s of require("./to_number_inputs.json")) { const n = Number(s); console.log(JSON.stringify(s), "=>", Object.is(n, -0) ? "-0" : String(n)) }'
```

The system prompt of the Stream agent backend's trip assistant (GetStream/Vision-Agents `accelerate` @ `4ff3a65a45`,
`examples/voice_agents/swift_assistant/openui/`, unchanged), which its generator writes from the chat library and the
app's components above:

- `vision_agents_prompt.json` — what the generator is given (`prompt.json`): the chat components to keep, the
  preamble, the notes on the app's components, the extra rules and the examples. Its `components` path,
  `../app/SwiftAssistant/UIComponents.json`, is the file vendored here as `ohrid_app_components.json`, which is the same
  at both commits.
- `vision_agents_instructions.md` — the prompt it wrote (`instructions.md`), which
  `test/src/core/library/vision_agents_instructions_test.dart` generates again and compares.
