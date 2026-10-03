package io.github.atrx07.traelyx.guardian

internal class MemoryGuardianRecipientRevokeJournal : GuardianRecipientRevokeJournal {
    val tickets = mutableListOf<GuardianRecipientRevokeTicket>()
    var failRecord = false
    override fun pending() = tickets.toList()
    override fun record(ticket: GuardianRecipientRevokeTicket) {
        if (failRecord) throw GuardianVaultUnavailable()
        if (ticket !in tickets) tickets.add(ticket)
    }
    override fun confirm(ticket: GuardianRecipientRevokeTicket) { tickets.remove(ticket) }
}
