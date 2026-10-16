package io.github.atrx07.traelyx.guardian

internal class TestDriverRevokeJournal : GuardianDriverRevokeJournal {
    val tickets = mutableListOf<GuardianDriverRevokeTicket>()
    var failRecord = false
    var failConfirm = false
    override fun pending() = tickets.toList()
    override fun record(ticket: GuardianDriverRevokeTicket) {
        check(!failRecord)
        if (ticket !in tickets) tickets.add(ticket)
    }
    override fun confirm(ticket: GuardianDriverRevokeTicket) { check(!failConfirm); tickets.remove(ticket) }
}
