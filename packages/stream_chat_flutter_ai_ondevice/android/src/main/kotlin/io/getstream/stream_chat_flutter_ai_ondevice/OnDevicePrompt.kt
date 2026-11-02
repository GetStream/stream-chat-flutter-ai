package io.getstream.stream_chat_flutter_ai_ondevice

/**
 * How a conversation is written as one prompt: the Prompt API takes text, not a transcript.
 *
 * Ported from `OnDevicePrompt` in stream-chat-android's `AIOnDeviceModel.kt`; keep the two in step.
 */
internal object OnDevicePrompt {

    fun text(instructions: String?, history: List<TurnMessage>, question: String): String = buildString {
        if (!instructions.isNullOrBlank()) {
            append(instructions.trim()).append("\n\n")
        }
        if (history.isNotEmpty()) {
            append("Conversation so far:\n")
            history.forEach { turn -> append(label(turn.role)).append(": ").append(turn.text.trim()).append('\n') }
            append('\n')
            append("Answer the user's last message.\n\n")
            append(label(TurnRoleMessage.USER)).append(": ").append(question.trim())
        } else {
            append(question.trim())
        }
    }

    private fun label(role: TurnRoleMessage): String = when (role) {
        TurnRoleMessage.USER -> "User"
        TurnRoleMessage.ASSISTANT -> "Assistant"
    }
}
