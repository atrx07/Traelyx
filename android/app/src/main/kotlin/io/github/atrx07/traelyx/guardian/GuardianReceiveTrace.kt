package io.github.atrx07.traelyx.guardian

/** Fixed, data-free stages only: never accept identifiers, bodies or exceptions. */
internal enum class GuardianReceiveStage {
    CALLBACK,
    UNCONFIGURED,
    NOTIFICATIONS_DISABLED,
    PREFLIGHT_REJECTED,
    RECEIPT_REQUEST_REJECTED,
    RECEIPT_TRANSPORT_UNCONFIRMED,
    RECEIPT_RESPONSE_REJECTED,
    RECEIPT_CONFIRMED,
    AUTHORITY_CHANGED,
    CLAIM_UNAVAILABLE,
    NOTICE_CLAIMED,
    FINAL_AUTHORITY_REJECTED,
    NOTICE_POST_ATTEMPTED,
    NOTICE_POST_FAILED,
    RECEIVER_FAILED,
}

/** Inert by default; a diagnostic sink failure cannot change receiver decisions. */
internal class GuardianReceiveTrace(
    private val enabled: Boolean = false,
    private val sink: (GuardianReceiveStage) -> Unit = {},
) {
    fun record(stage: GuardianReceiveStage) {
        if (enabled) runCatching { sink(stage) }
    }
}
