package io.getstream.stream_chat_flutter_ai_ondevice

import com.google.mlkit.genai.common.GenAiException.ErrorCode

/**
 * ML Kit's error codes, as the `AILocalModelErrorReason` names the Dart side understands.
 *
 * Telling them apart lets the app say whether trying again later can work.
 */
internal object GenAiErrors {

    const val UNAVAILABLE = "unavailable"
    const val CONTEXT_EXCEEDED = "contextExceeded"
    const val INVALID_CONVERSATION = "invalidConversation"
    const val FAILED = "failed"

    /** The reason for ML Kit's [code]. */
    fun reason(code: Int): String = when (code) {
        ErrorCode.REQUEST_TOO_LARGE -> CONTEXT_EXCEEDED
        // The model can't answer now: missing, switched off, busy or out of quota.
        ErrorCode.NOT_AVAILABLE,
        ErrorCode.NOT_SUPPORTED,
        ErrorCode.BUSY,
        ErrorCode.PER_APP_BATTERY_USE_QUOTA_EXCEEDED,
        ErrorCode.BACKGROUND_USE_BLOCKED,
        ErrorCode.NOT_ENOUGH_DISK_SPACE,
        ErrorCode.NEEDS_SYSTEM_UPDATE,
        ErrorCode.AICORE_INCOMPATIBLE,
        -> UNAVAILABLE
        else -> FAILED
    }

    /** ML Kit's name for [code], for logs. */
    fun name(code: Int): String = when (code) {
        ErrorCode.UNKNOWN -> "UNKNOWN"
        ErrorCode.REQUEST_PROCESSING_ERROR -> "REQUEST_PROCESSING_ERROR"
        ErrorCode.CANCELLED -> "CANCELLED"
        ErrorCode.NOT_AVAILABLE -> "NOT_AVAILABLE"
        ErrorCode.BUSY -> "BUSY"
        ErrorCode.RESPONSE_PROCESSING_ERROR -> "RESPONSE_PROCESSING_ERROR"
        ErrorCode.REQUEST_TOO_LARGE -> "REQUEST_TOO_LARGE"
        ErrorCode.REQUEST_TOO_SMALL -> "REQUEST_TOO_SMALL"
        ErrorCode.RESPONSE_GENERATION_ERROR -> "RESPONSE_GENERATION_ERROR"
        ErrorCode.NOT_SUPPORTED -> "NOT_SUPPORTED"
        ErrorCode.PER_APP_BATTERY_USE_QUOTA_EXCEEDED -> "PER_APP_BATTERY_USE_QUOTA_EXCEEDED"
        ErrorCode.BACKGROUND_USE_BLOCKED -> "BACKGROUND_USE_BLOCKED"
        ErrorCode.NOT_ENOUGH_DISK_SPACE -> "NOT_ENOUGH_DISK_SPACE"
        ErrorCode.NEEDS_SYSTEM_UPDATE -> "NEEDS_SYSTEM_UPDATE"
        ErrorCode.AICORE_INCOMPATIBLE -> "AICORE_INCOMPATIBLE"
        else -> "ERROR_$code"
    }
}
