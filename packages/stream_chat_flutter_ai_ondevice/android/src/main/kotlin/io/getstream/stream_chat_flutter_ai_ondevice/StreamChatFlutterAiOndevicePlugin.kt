package io.getstream.stream_chat_flutter_ai_ondevice

import android.content.Context
import android.content.pm.PackageManager
import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.prompt.GenerateContentRequest
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.SystemInstruction
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateContentRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Gemini Nano, the model in Android's AICore, through ML Kit's GenAI Prompt API.
 *
 * Ported from stream-chat-android's `AIOnDeviceModel`. The Dart side fits the conversation to
 * the context this reports, so this only checks the model, writes the prompt and streams the
 * answer. Each reply runs in its own job, stopped by `cancelReply`.
 */
class StreamChatFlutterAiOndevicePlugin : FlutterPlugin, OnDeviceModelHostApi {

    private var context: Context? = null
    private var scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var model: GenerativeModel? = null

    private var replySink: PigeonEventSink<ReplyEvent>? = null
    private var downloadSink: PigeonEventSink<DownloadEvent>? = null
    private val replies = mutableMapOf<String, Job>()
    private var download: Job? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        OnDeviceModelHostApi.setUp(binding.binaryMessenger, this)
        ReplyEventsStreamHandler.register(
            binding.binaryMessenger,
            object : ReplyEventsStreamHandler() {
                override fun onListen(p0: Any?, sink: PigeonEventSink<ReplyEvent>) {
                    replySink = sink
                }

                override fun onCancel(p0: Any?) {
                    replySink = null
                }
            },
        )
        DownloadEventsStreamHandler.register(
            binding.binaryMessenger,
            object : DownloadEventsStreamHandler() {
                override fun onListen(p0: Any?, sink: PigeonEventSink<DownloadEvent>) {
                    downloadSink = sink
                }

                override fun onCancel(p0: Any?) {
                    downloadSink = null
                }
            },
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        OnDeviceModelHostApi.setUp(binding.binaryMessenger, null)
        scope.cancel()
        replies.clear()
        download = null
        model?.close()
        model = null
        context = null
    }

    private fun model(): GenerativeModel = model ?: Generation.getClient().also { model = it }

    override suspend fun modelInfo(): ModelInfoMessage = ModelInfoMessage(
        status = status(),
        contextSize = contextTokens().toLong(),
        maxResponseTokens = MODEL_MAXIMUM_RESPONSE_TOKENS.toLong(),
    )

    override fun startReply(requestId: String, request: ReplyRequestMessage) {
        replies[requestId] = scope.launch {
            try {
                if (status() != ModelStatusMessage.AVAILABLE) {
                    fail(requestId, GenAiErrors.UNAVAILABLE, "NOT_AVAILABLE", "The on-device model is unavailable.")
                    return@launch
                }
                val question = request.turns.lastOrNull()?.takeIf { it.role == TurnRoleMessage.USER }
                if (question == null) {
                    fail(
                        requestId,
                        GenAiErrors.INVALID_CONVERSATION,
                        "NO_QUESTION",
                        "The conversation must end with the person's question.",
                    )
                    return@launch
                }
                val answer = StringBuilder()
                model().generateContentStream(request(request, question.text)).collect { chunk ->
                    val piece = chunk.candidates.firstOrNull()?.text.orEmpty()
                    if (piece.isNotEmpty()) {
                        answer.append(piece)
                        replySink?.success(ReplyText(requestId, answer.toString()))
                    }
                }
                replySink?.success(ReplyDone(requestId))
            } catch (cancellation: CancellationException) {
                // Stopped from Dart, which has already let go of this reply.
                throw cancellation
            } catch (error: GenAiException) {
                fail(
                    requestId,
                    GenAiErrors.reason(error.errorCode),
                    GenAiErrors.name(error.errorCode),
                    error.message ?: "The on-device model failed to answer.",
                )
            } catch (@Suppress("TooGenericExceptionCaught") error: Exception) {
                fail(requestId, GenAiErrors.FAILED, error.javaClass.simpleName, error.message ?: "$error")
            } finally {
                replies.remove(requestId)
            }
        }
    }

    override fun cancelReply(requestId: String) {
        replies.remove(requestId)?.cancel()
    }

    override fun startDownload() {
        download?.cancel()
        download = scope.launch {
            try {
                model().download().collect { status ->
                    val event = when (status) {
                        is DownloadStatus.DownloadStarted -> DownloadStarted(bytesToDownload = status.bytesToDownload)
                        is DownloadStatus.DownloadProgress -> DownloadProgress(bytesDownloaded = status.totalBytesDownloaded)
                        is DownloadStatus.DownloadCompleted -> DownloadCompleted(done = true)
                        is DownloadStatus.DownloadFailed -> downloadFailed(status.e)
                        else -> null
                    }
                    if (event != null) downloadSink?.success(event)
                }
            } catch (cancellation: CancellationException) {
                throw cancellation
            } catch (error: GenAiException) {
                downloadSink?.success(downloadFailed(error))
            } catch (@Suppress("TooGenericExceptionCaught") error: Exception) {
                downloadSink?.success(
                    DownloadFailed(GenAiErrors.FAILED, error.javaClass.simpleName, error.message ?: "$error"),
                )
            }
        }
    }

    override fun cancelDownload() {
        download?.cancel()
        download = null
    }

    private fun fail(requestId: String, reason: String, code: String, message: String) {
        replySink?.success(ReplyFailed(requestId, reason, code, message))
    }

    private fun downloadFailed(error: GenAiException): DownloadFailed = DownloadFailed(
        reason = GenAiErrors.reason(error.errorCode),
        code = GenAiErrors.name(error.errorCode),
        message = error.message ?: "The model could not be downloaded.",
    )

    /**
     * The request for [turns][ReplyRequestMessage.turns], already fitted to the context, with the
     * instructions as the system prompt when the model takes one.
     */
    private suspend fun request(request: ReplyRequestMessage, question: String): GenerateContentRequest {
        val responseTokens = request.maximumResponseTokens.toInt().coerceIn(1, MODEL_MAXIMUM_RESPONSE_TOKENS)
        val systemPrompt = supportsSystemPrompt()
        val prompt = TextPart(
            OnDevicePrompt.text(
                instructions = request.instructions.takeUnless { systemPrompt },
                history = request.turns.dropLast(1),
                question = question,
            ),
        )
        return if (systemPrompt && request.instructions.isNotBlank()) {
            generateContentRequest(SystemInstruction(request.instructions), prompt) { maxOutputTokens = responseTokens }
        } else {
            generateContentRequest(prompt) { maxOutputTokens = responseTokens }
        }
    }

    /** Where the model is on this device. A device without AICore, or an error, reads as unavailable. */
    @Suppress("TooGenericExceptionCaught")
    private suspend fun status(): ModelStatusMessage {
        if (!hasAICore()) return ModelStatusMessage.UNAVAILABLE
        return try {
            when (model().checkStatus()) {
                FeatureStatus.AVAILABLE -> ModelStatusMessage.AVAILABLE
                FeatureStatus.DOWNLOADABLE -> ModelStatusMessage.DOWNLOADABLE
                FeatureStatus.DOWNLOADING -> ModelStatusMessage.DOWNLOADING
                else -> ModelStatusMessage.UNAVAILABLE
            }
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (_: Exception) {
            ModelStatusMessage.UNAVAILABLE
        }
    }

    private fun hasAICore(): Boolean = try {
        context?.packageManager?.getPackageInfo(AICORE_PACKAGE, 0) != null
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    @Suppress("TooGenericExceptionCaught", "SwallowedException")
    private suspend fun contextTokens(): Int = try {
        if (hasAICore()) model().getTokenLimit() else DEFAULT_CONTEXT_TOKENS
    } catch (cancellation: CancellationException) {
        throw cancellation
    } catch (_: Exception) {
        DEFAULT_CONTEXT_TOKENS
    }

    @Suppress("TooGenericExceptionCaught", "SwallowedException")
    private suspend fun supportsSystemPrompt(): Boolean = try {
        model().isSystemPromptAvailable()
    } catch (cancellation: CancellationException) {
        throw cancellation
    } catch (_: Exception) {
        false
    }

    private companion object {
        /** The longest answer the model writes, in tokens. */
        const val MODEL_MAXIMUM_RESPONSE_TOKENS = 256

        const val AICORE_PACKAGE = "com.google.android.aicore"

        /** Gemini Nano's context through ML Kit, when the model doesn't say. */
        const val DEFAULT_CONTEXT_TOKENS = 4000
    }
}
