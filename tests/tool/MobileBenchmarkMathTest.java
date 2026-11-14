import io.github.atrx07.traelyx.mlbenchmark.BenchmarkMath;

public final class MobileBenchmarkMathTest {
    public static void main(String[] args) {
        double[] values = BenchmarkMath.probabilities(new float[]{10000, 0, -10000, 1}, 1);
        if (values[0] != 1 || values[2] != 0) throw new AssertionError("Stable softmax");
        double[] before = BenchmarkMath.probabilities(new float[]{-2, 0, 1, 3}, 1);
        double[] after = BenchmarkMath.probabilities(new float[]{-2, 0, 1, 3}, 2);
        if (!(after[3] < before[3])) throw new AssertionError("Temperature");
        if (BenchmarkMath.percentile(new long[]{5_000_000, 1_000_000, 3_000_000}, .5) != 3) throw new AssertionError("Median units");
        if (BenchmarkMath.percentile(new long[]{5_000_000, 1_000_000, 3_000_000}, .95) != 5) throw new AssertionError("Nearest rank p95");
        reject(() -> BenchmarkMath.probabilities(new float[]{Float.NaN, 0, 0, 0}, 1));
        reject(() -> BenchmarkMath.probabilities(new float[]{0, 0, 0, 0}, 0));
        reject(() -> BenchmarkMath.percentile(new long[0], .5));
        reject(() -> BenchmarkMath.percentile(new long[]{-1}, .5));
        System.out.println("Mobile numeric helper checks passed");
    }
    private static void reject(Runnable operation) {
        try { operation.run(); } catch (IllegalArgumentException expected) { return; }
        throw new AssertionError("Invalid values accepted");
    }
}
