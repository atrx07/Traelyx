package io.github.atrx07.traelyx.mlbenchmark;

import java.util.Arrays;

/** Shared deterministic numeric checks, independent of Android/runtime state. */
public final class BenchmarkMath {
    private BenchmarkMath() {}

    public static double[] probabilities(float[] logits, double temperature) {
        if (logits.length != 4 || !Double.isFinite(temperature) || temperature < .1 || temperature > 100) {
            throw new IllegalArgumentException("Invalid probability contract");
        }
        double maximum = Double.NEGATIVE_INFINITY;
        for (float value : logits) {
            if (!Float.isFinite(value)) throw new IllegalArgumentException("Nonfinite logit");
            maximum = Math.max(maximum, value / temperature);
        }
        double[] result = new double[4];
        double sum = 0;
        for (int i = 0; i < 4; i++) { result[i] = Math.exp(logits[i] / temperature - maximum); sum += result[i]; }
        for (int i = 0; i < 4; i++) result[i] /= sum;
        return result;
    }

    public static double percentile(long[] samples, double percentile) {
        if (samples.length == 0 || !(percentile > 0 && percentile <= 1)) throw new IllegalArgumentException("Invalid samples");
        long[] sorted = samples.clone();
        Arrays.sort(sorted);
        if (sorted[0] < 0) throw new IllegalArgumentException("Negative duration");
        return sorted[(int) Math.ceil(percentile * sorted.length) - 1] / 1e6;
    }
}
