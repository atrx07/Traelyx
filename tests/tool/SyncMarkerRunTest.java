import io.github.atrx07.traelyx.syncpilot.MarkerRun;
import java.nio.file.Files;
import java.nio.file.Path;

/** Generated software journal invariants; no Android or physical timing claim. */
public final class SyncMarkerRunTest {
    private static void check(boolean value) { if (!value) throw new AssertionError(); }
    private static void rejects(Runnable action) {
        try { action.run(); } catch (IllegalArgumentException expected) { return; }
        throw new AssertionError("accepted invalid marker evidence");
    }
    public static void main(String[] args) throws Exception {
        String alias = "00000000-0000-0000-0000-000000000001";
        rejects(() -> new MarkerRun(null));
        rejects(() -> new MarkerRun("1-1-1-1-1"));
        MarkerRun run = new MarkerRun(alias);
        check(run.token().equals("M0001") && !run.stopped());
        rejects(() -> run.append(-1, 0));
        rejects(() -> run.append(2, 1));
        rejects(() -> run.append(1, 1_000_000_002L));
        long base = 9_500_000_000_000_001L;
        for (int i = 0; i < 8; i++) run.append(base+i*1_000_100_000L, base+i*1_000_100_000L+1000);
        rejects(() -> run.append(base, base+1));
        rejects(() -> run.stop(null));
        run.stop("user");
        String saved = run.json();
        run.stop("paused");
        check(run.stopped() && saved.equals(run.json()) && saved.contains("\"presentation_delay_bound_ns\":null"));
        rejects(() -> run.append(base+99_000_000_000L, base+99_000_000_001L));
        MarkerRun capped = new MarkerRun(alias);
        for (int i = 0; i < 64; i++) capped.append(i*2L, i*2L+1);
        rejects(() -> capped.append(128, 129));
        capped.stop("limit");
        check(capped.size() == 64 && capped.json().contains("\"token\":\"M0064\""));
        if (args.length == 1) Files.writeString(Path.of(args[0]), saved);
        System.out.println("Sync marker generated journal invariants passed");
    }
}
