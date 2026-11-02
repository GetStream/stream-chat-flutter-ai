import Foundation

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#endif

#if canImport(FoundationModels)
  import FoundationModels
#endif

/// Apple's on-device model (Foundation Models), on iOS 26 and macOS 26 and later with Apple
/// Intelligence turned on.
///
/// The Dart side fits the conversation to the context this reports, so this only checks the model, builds the transcript and streams the
/// answer. Each reply runs in its own task, stopped by `cancelReply`.
public class StreamChatFlutterAiOndevicePlugin: NSObject, FlutterPlugin, OnDeviceModelHostApi {
  /// The context Apple's model had before `contextSize` arrived in the iOS 26.4 SDK.
  static let defaultContextSize = 4096

  private let replyEvents = EventSinkHolder<ReplyEvent>()
  private let downloadEvents = EventSinkHolder<DownloadEvent>()
  /// The replies in progress. The token tells a reply apart from a later one under the same id.
  private var replies: [String: (token: UUID, task: Task<Void, Never>)] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let instance = StreamChatFlutterAiOndevicePlugin()
    // Flutter calls `detachFromEngine(for:)` only on a published plugin (on iOS; macOS never does).
    registrar.publish(instance)
    OnDeviceModelHostApiSetup.setUp(binaryMessenger: messenger, api: instance)
    ReplyEventsStreamHandler.register(with: messenger, streamHandler: ReplyEventsListener(instance.replyEvents))
    DownloadEventsStreamHandler.register(with: messenger, streamHandler: DownloadEventsListener(instance.downloadEvents))
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    replies.values.forEach { $0.task.cancel() }
    replies = [:]
  }

  func modelInfo() async throws -> ModelInfoMessage {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, *) {
        let model = SystemLanguageModel.default
        return ModelInfoMessage(status: Self.status(of: model), contextSize: Int64(Self.contextSize(of: model)))
      }
    #endif
    return ModelInfoMessage(status: .unavailable, contextSize: Int64(Self.defaultContextSize))
  }

  func startReply(requestId: String, request: ReplyRequestMessage) throws {
    // Replies from another session were started before a hot restart, and nobody waits for them.
    let session = requestId.prefix(while: { $0 != "-" })
    for (id, reply) in replies where id.prefix(while: { $0 != "-" }) != session {
      reply.task.cancel()
      replies[id] = nil
    }
    replies.removeValue(forKey: requestId)?.task.cancel()
    let token = UUID()
    let task = Task { @MainActor [weak self] in
      await self?.reply(requestId, request)
      if self?.replies[requestId]?.token == token { self?.replies[requestId] = nil }
    }
    replies[requestId] = (token, task)
  }

  func cancelReply(requestId: String) throws {
    replies.removeValue(forKey: requestId)?.task.cancel()
  }

  func startDownload() throws {
    // Apple downloads its model by itself: there is nothing to start.
    Task { @MainActor [weak self] in
      guard let self else { return }
      let info = try? await self.modelInfo()
      if info?.status == .available {
        self.downloadEvents.send(DownloadCompleted(done: true))
      } else {
        self.downloadEvents.send(
          DownloadFailed(
            reason: "unavailable",
            code: "systemManaged",
            message: "Apple's model is downloaded by the system once Apple Intelligence is turned on."
          )
        )
      }
    }
  }

  func cancelDownload() throws {}

  @MainActor
  private func reply(_ requestId: String, _ request: ReplyRequestMessage) async {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, *) {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
          return fail(requestId, reason: "unavailable", code: "notAvailable", message: "The on-device model is unavailable.")
        }
        guard let question = request.turns.last, question.role == .user else {
          return fail(
            requestId,
            reason: "invalidConversation",
            code: "noQuestion",
            message: "The conversation must end with the person's question."
          )
        }
        do {
          let session = LanguageModelSession(
            model: model,
            transcript: TranscriptBuilder.transcript(instructions: request.instructions, history: request.turns.dropLast())
          )
          let options = GenerationOptions(maximumResponseTokens: Int(request.maximumResponseTokens))
          for try await snapshot in session.streamResponse(to: question.text, options: options) {
            if Task.isCancelled { return }
            replyEvents.send(ReplyText(requestId: requestId, text: snapshot.content))
          }
          if !Task.isCancelled { replyEvents.send(ReplyDone(requestId: requestId)) }
        } catch is CancellationError {
          // Stopped from Dart, which has already let go of this reply.
        } catch {
          if Task.isCancelled { return }
          let failure = GenerationErrorMapper.failure(for: error)
          fail(requestId, reason: failure.reason, code: failure.code, message: error.localizedDescription)
        }
        return
      }
    #endif
    fail(requestId, reason: "unavailable", code: "unsupportedOS", message: "Apple's on-device model needs iOS 26 or macOS 26.")
  }

  private func fail(_ requestId: String, reason: String, code: String, message: String) {
    replyEvents.send(ReplyFailed(requestId: requestId, reason: reason, code: code, message: message))
  }

  #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    static func status(of model: SystemLanguageModel) -> ModelStatusMessage {
      switch model.availability {
      case .available:
        return .available
      case .unavailable(.modelNotReady):
        // The system is still getting the model ready, such as downloading it.
        return .downloading
      default:
        return .unavailable
      }
    }

    // `contextSize` arrived in the iOS 26.4 SDK (Swift 6.3); older SDKs fall back to the model's 4096 tokens.
    @available(iOS 26.0, macOS 26.0, *)
    static func contextSize(of model: SystemLanguageModel) -> Int {
      #if compiler(>=6.3)
        model.contextSize
      #else
        defaultContextSize
      #endif
    }
  #endif
}

/// The sink an event channel's listener handed over, while Dart listens.
final class EventSinkHolder<Event> {
  var sink: PigeonEventSink<Event>?

  func send(_ event: Event) {
    DispatchQueue.main.async { [weak self] in self?.sink?.success(event) }
  }
}

final class ReplyEventsListener: ReplyEventsStreamHandler {
  private let holder: EventSinkHolder<ReplyEvent>

  init(_ holder: EventSinkHolder<ReplyEvent>) { self.holder = holder }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<ReplyEvent>) { holder.sink = sink }

  override func onCancel(withArguments arguments: Any?) { holder.sink = nil }
}

final class DownloadEventsListener: DownloadEventsStreamHandler {
  private let holder: EventSinkHolder<DownloadEvent>

  init(_ holder: EventSinkHolder<DownloadEvent>) { self.holder = holder }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<DownloadEvent>) { holder.sink = sink }

  override func onCancel(withArguments arguments: Any?) { holder.sink = nil }
}
