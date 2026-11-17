package io.github.atrx07.traelyx.syncpilot;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

/** Bounded software draw journal. No physical presentation time is inferred. */
public final class MarkerRun {
    private final String alias;
    private final List<long[]> rows = new ArrayList<>();
    private String reason;

    public MarkerRun(String alias) {
        if (alias == null) throw new IllegalArgumentException("alias");
        if (!UUID.fromString(alias).toString().equals(alias)) throw new IllegalArgumentException("alias");
        this.alias = alias;
    }

    public int size() { return rows.size(); }
    public boolean stopped() { return reason != null; }
    public String token() { return String.format(Locale.ROOT, "M%04d", rows.size()+1); }

    public void append(long before, long after) {
        if (stopped() || rows.size() >= 64 || before < 0 || after < before ||
                after-before > 1_000_000_000L ||
                (!rows.isEmpty() && before <= rows.get(rows.size()-1)[1])) {
            throw new IllegalArgumentException("draw_bounds");
        }
        rows.add(new long[]{before, after});
    }

    public void stop(String value) {
        if (!("user".equals(value) || "paused".equals(value) || "limit".equals(value))) {
            throw new IllegalArgumentException("stop_reason");
        }
        if (!stopped()) reason = value;
    }

    public String json() {
        StringBuilder out = new StringBuilder("{\"version\":\"traelyx.sync-marker.v1\","
                + "\"clock\":\"elapsedRealtimeNanos\",\"measurement\":"
                + "\"software_canvas_draw_not_photon_presentation\",\"presentation_delay_bound_ns\":null,"
                + "\"reference_alignment_verified\":false,\"session_alias\":\"").append(alias)
                .append("\",\"stopped\":").append(stopped()).append(",\"stop_reason\":")
                .append(reason == null ? "null" : "\""+reason+"\"").append(",\"markers\":[");
        for (int i = 0; i < rows.size(); i++) {
            if (i != 0) out.append(',');
            out.append("{\"sequence\":").append(i+1).append(",\"token\":\"")
                    .append(String.format(Locale.ROOT, "M%04d", i+1))
                    .append("\",\"draw_before_ns\":").append(rows.get(i)[0])
                    .append(",\"draw_after_ns\":").append(rows.get(i)[1]).append('}');
        }
        return out.append("]}\n").toString();
    }
}
