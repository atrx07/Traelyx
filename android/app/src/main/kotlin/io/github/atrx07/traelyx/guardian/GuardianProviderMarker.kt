package io.github.atrx07.traelyx.guardian

/** No account ID or token is stored here. Presence requires provider cleanup before account release. */
interface GuardianProviderMarker {
    fun present(): Boolean
    /** Must complete durably before the first explicit Firebase token request. */
    fun mark()
    /** Call only after provider deletion is confirmed. */
    fun clear()
}
