import Cocoa
import FlutterMacOS
import XCTest

#if canImport(FoundationModels)
  import FoundationModels
  @testable import stream_chat_flutter_ai_ondevice
#endif

// Tests for the on-device model plugin's Swift. The iOS and macOS copies of its sources are
// identical, so they run here, on the Mac.
class RunnerTests: XCTestCase {

  #if canImport(FoundationModels)
    func testTranscriptStartsWithTheInstructionsThenTheHistory() throws {
      guard #available(macOS 26.0, *) else { throw XCTSkip("Foundation Models needs macOS 26.") }
      let transcript = TranscriptBuilder.transcript(
        instructions: "Be brief.",
        history: [
          TurnMessage(role: .user, text: "Hi?"),
          TurnMessage(role: .assistant, text: "Hello!"),
        ][...]
      )
      let entries = Array(transcript)
      XCTAssertEqual(entries.count, 3)
      guard case .instructions = entries[0], case .prompt = entries[1], case .response = entries[2] else {
        return XCTFail("Unexpected entries: \(entries)")
      }
    }

    func testTranscriptLeavesOutBlankInstructions() throws {
      guard #available(macOS 26.0, *) else { throw XCTSkip("Foundation Models needs macOS 26.") }
      let transcript = TranscriptBuilder.transcript(
        instructions: " \n",
        history: [TurnMessage(role: .user, text: "Hi?")][...]
      )
      let entries = Array(transcript)
      XCTAssertEqual(entries.count, 1)
      guard case .prompt = entries[0] else { return XCTFail("Unexpected entries: \(entries)") }
    }

    func testGenerationErrorsMapToTheirReasons() throws {
      guard #available(macOS 26.0, *) else { throw XCTSkip("Foundation Models needs macOS 26.") }
      typealias GenerationError = LanguageModelSession.GenerationError
      let context = GenerationError.Context(debugDescription: "")
      let cases: [(GenerationError, String, String)] = [
        (.exceededContextWindowSize(context), "contextExceeded", "exceededContextWindowSize"),
        (.assetsUnavailable(context), "unavailable", "assetsUnavailable"),
        (.rateLimited(context), "unavailable", "rateLimited"),
        (.concurrentRequests(context), "unavailable", "concurrentRequests"),
        (.guardrailViolation(context), "failed", "guardrailViolation"),
        (.unsupportedLanguageOrLocale(context), "failed", "unsupportedLanguageOrLocale"),
        (.decodingFailure(context), "failed", "decodingFailure"),
      ]
      for (error, reason, code) in cases {
        XCTAssertEqual(GenerationErrorMapper.failure(for: error), .init(reason: reason, code: code), "\(error)")
      }
    }

    func testAnUnknownErrorFails() throws {
      guard #available(macOS 26.0, *) else { throw XCTSkip("Foundation Models needs macOS 26.") }
      XCTAssertEqual(GenerationErrorMapper.failure(for: CocoaError(.featureUnsupported)), .init(reason: "failed", code: "unknown"))
    }
  #endif

}
