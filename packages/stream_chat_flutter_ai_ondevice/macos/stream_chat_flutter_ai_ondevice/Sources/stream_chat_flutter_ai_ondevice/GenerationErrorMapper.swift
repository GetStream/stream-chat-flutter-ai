#if canImport(FoundationModels)
  import FoundationModels

  /// Foundation Models' errors, as the `AILocalModelErrorReason` names the Dart side understands.
  ///
  /// stream-chat-swift passes them on unmapped; telling them apart lets the app say whether
  /// trying again later can work. This file is shared by the iOS and macOS packages: edit both
  /// copies together.
  @available(iOS 26.0, macOS 26.0, *)
  enum GenerationErrorMapper {
    struct Failure: Equatable {
      let reason: String
      let code: String
    }

    static func failure(for error: Error) -> Failure {
      #if compiler(>=6.4)
        // The iOS 27 SDK replaces `GenerationError` with these.
        if #available(iOS 27.0, macOS 27.0, *) {
          if let error = error as? LanguageModelError {
            switch error {
            case .contextSizeExceeded: return Failure(reason: "contextExceeded", code: "contextSizeExceeded")
            case .rateLimited: return Failure(reason: "unavailable", code: "rateLimited")
            case .timeout: return Failure(reason: "unavailable", code: "timeout")
            case .guardrailViolation: return Failure(reason: "failed", code: "guardrailViolation")
            case .refusal: return Failure(reason: "failed", code: "refusal")
            case .unsupportedLanguageOrLocale: return Failure(reason: "failed", code: "unsupportedLanguageOrLocale")
            default: return Failure(reason: "failed", code: "languageModelError")
            }
          }
          if error is SystemLanguageModel.Error {
            return Failure(reason: "unavailable", code: "assetsUnavailable")
          }
          if let error = error as? LanguageModelSession.Error, error == .concurrentRequests {
            return Failure(reason: "unavailable", code: "concurrentRequests")
          }
          if error is GeneratedContent.ParsingError {
            return Failure(reason: "failed", code: "parsingError")
          }
        }
      #endif
      // An app built with an older SDK can't name iOS 27's errors: they read as `failed`.
      guard let error = error as? LanguageModelSession.GenerationError else {
        return Failure(reason: "failed", code: "unknown")
      }
      switch error {
      case .exceededContextWindowSize: return Failure(reason: "contextExceeded", code: "exceededContextWindowSize")
      case .assetsUnavailable: return Failure(reason: "unavailable", code: "assetsUnavailable")
      case .rateLimited: return Failure(reason: "unavailable", code: "rateLimited")
      case .concurrentRequests: return Failure(reason: "unavailable", code: "concurrentRequests")
      case .guardrailViolation: return Failure(reason: "failed", code: "guardrailViolation")
      case .refusal: return Failure(reason: "failed", code: "refusal")
      case .unsupportedLanguageOrLocale: return Failure(reason: "failed", code: "unsupportedLanguageOrLocale")
      case .unsupportedGuide: return Failure(reason: "failed", code: "unsupportedGuide")
      case .decodingFailure: return Failure(reason: "failed", code: "decodingFailure")
      @unknown default: return Failure(reason: "failed", code: "unknown")
      }
    }
  }
#endif
