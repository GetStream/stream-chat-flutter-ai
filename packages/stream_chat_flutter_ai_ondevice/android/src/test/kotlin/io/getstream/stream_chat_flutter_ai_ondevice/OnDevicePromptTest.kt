package io.getstream.stream_chat_flutter_ai_ondevice

import com.google.mlkit.genai.common.GenAiException.ErrorCode
import kotlin.test.Test
import kotlin.test.assertEquals

class OnDevicePromptTest {

    private fun user(text: String) = TurnMessage(TurnRoleMessage.USER, text)
    private fun assistant(text: String) = TurnMessage(TurnRoleMessage.ASSISTANT, text)

    @Test
    fun `a question alone is the prompt`() {
        assertEquals("What can you do?", OnDevicePrompt.text(instructions = null, history = emptyList(), question = " What can you do? "))
    }

    @Test
    fun `the history is labelled, after the instructions`() {
        assertEquals(
            "Answer briefly.\n\nConversation so far:\nUser: Hi\nAssistant: Hello!\n\nAnswer the user's last message.\n\nUser: What can you do?",
            OnDevicePrompt.text(
                instructions = "Answer briefly.",
                history = listOf(user("Hi"), assistant("Hello!")),
                question = "What can you do?",
            ),
        )
    }

    @Test
    fun `blank instructions are left out`() {
        assertEquals("Hi?", OnDevicePrompt.text(instructions = "  ", history = emptyList(), question = "Hi?"))
    }
}

class GenAiErrorsTest {

    @Test
    fun `a request too large exceeds the context`() {
        assertEquals("contextExceeded", GenAiErrors.reason(ErrorCode.REQUEST_TOO_LARGE))
    }

    @Test
    fun `a model that can't answer now is unavailable`() {
        for (code in listOf(
            ErrorCode.NOT_AVAILABLE,
            ErrorCode.NOT_SUPPORTED,
            ErrorCode.BUSY,
            ErrorCode.PER_APP_BATTERY_USE_QUOTA_EXCEEDED,
            ErrorCode.BACKGROUND_USE_BLOCKED,
            ErrorCode.NOT_ENOUGH_DISK_SPACE,
            ErrorCode.NEEDS_SYSTEM_UPDATE,
            ErrorCode.AICORE_INCOMPATIBLE,
        )) {
            assertEquals("unavailable", GenAiErrors.reason(code), GenAiErrors.name(code))
        }
    }

    @Test
    fun `anything else failed`() {
        assertEquals("failed", GenAiErrors.reason(ErrorCode.RESPONSE_GENERATION_ERROR))
        assertEquals("failed", GenAiErrors.reason(ErrorCode.UNKNOWN))
        assertEquals("failed", GenAiErrors.reason(12345))
    }

    @Test
    fun `codes are named for logs`() {
        assertEquals("BUSY", GenAiErrors.name(ErrorCode.BUSY))
        assertEquals("ERROR_12345", GenAiErrors.name(12345))
    }
}
