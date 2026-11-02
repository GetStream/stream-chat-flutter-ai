#if canImport(FoundationModels)
  import FoundationModels

  /// The conversation before the question, as the transcript a `LanguageModelSession` starts from.
  ///
  /// Ported from stream-chat-swift's `AIOnDeviceModel.transcript`. This file is shared by the iOS
  /// and macOS packages: edit both copies together.
  @available(iOS 26.0, macOS 26.0, *)
  enum TranscriptBuilder {
    static func transcript(instructions: String, history: ArraySlice<TurnMessage>) -> Transcript {
      func text(_ content: String) -> [Transcript.Segment] { [.text(Transcript.TextSegment(content: content))] }
      var entries: [Transcript.Entry] = []
      if !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        entries.append(.instructions(Transcript.Instructions(segments: text(instructions), toolDefinitions: [])))
      }
      for turn in history {
        switch turn.role {
        case .user: entries.append(.prompt(Transcript.Prompt(segments: text(turn.text))))
        case .assistant: entries.append(.response(Transcript.Response(assetIDs: [], segments: text(turn.text))))
        }
      }
      return Transcript(entries: entries)
    }
  }
#endif
