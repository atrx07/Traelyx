package io.github.atrx07.traelyx.mlbenchmark;

import ai.onnxruntime.OnnxTensor;
import ai.onnxruntime.OrtEnvironment;
import ai.onnxruntime.OrtSession;
import android.app.Instrumentation;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Debug;
import android.os.Process;
import android.os.SystemClock;
import android.system.Os;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.security.MessageDigest;
import java.util.Collections;
import org.json.JSONArray;
import org.json.JSONObject;

/** Self-contained generated-input benchmark. No app, sensor, account or network access. */
public final class BenchmarkInstrumentation extends Instrumentation {
    private static final String PACKAGE = "io.github.atrx07.traelyx.mlbenchmark";
    private static final int WARMUP = 200;
    private static final int ITERATIONS = 10000;

    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        try {
            // No ORT reference/native initialization may precede this guard.
            Os.setenv("ORT_DISABLE_TELEMETRY", "1", true);
            if (!"1".equals(Os.getenv("ORT_DISABLE_TELEMETRY"))) throw new SecurityException();
            start();
        } catch (Exception failure) { failed(failure); }
    }

    @Override public void onStart() {
        try {
            Context context = getTargetContext();
            if (!PACKAGE.equals(context.getPackageName())) throw new SecurityException();
            PackageInfo own = context.getPackageManager().getPackageInfo(PACKAGE,
                    PackageManager.GET_PERMISSIONS | PackageManager.GET_PROVIDERS);
            if ((own.requestedPermissions != null && own.requestedPermissions.length != 0)
                    || (own.providers != null && own.providers.length != 0)
                    || context.checkSelfPermission("android.permission.INTERNET") == PackageManager.PERMISSION_GRANTED) {
                throw new SecurityException("Permission-free package required");
            }
            byte[] fixtureBytes = asset(context, "fixtures.json", 100000);
            JSONObject fixtures = new JSONObject(new String(fixtureBytes, java.nio.charset.StandardCharsets.UTF_8));
            if (!"eventnet-onnx-mobile-v1".equals(fixtures.getString("version"))
                    || !"generated_not_sensors_or_recorded_tasks".equals(fixtures.getString("fixture_origin"))
                    || !"[1,6,7]".equals(fixtures.getJSONArray("shape").toString())
                    || fixtures.getJSONArray("cases").length() != 8) throw new SecurityException("Fixture contract mismatch");
            JSONObject report = new JSONObject();
            report.put("version", "eventnet-onnx-mobile-v1");
            report.put("production_eligible", false);
            report.put("quantized_numerical_gate_pass", fixtures.getBoolean("quantized_numerical_gate_pass"));
            report.put("fixtures_sha256", sha256(fixtureBytes));
            report.put("device_model", Build.MODEL);
            report.put("api_level", Build.VERSION.SDK_INT);
            report.put("abi", Build.SUPPORTED_ABIS[0]);
            report.put("privacy", "zero_permissions_zero_providers_preinit_telemetry_disabled");
            report.put("battery_before", battery(context));
            report.put("baseline_pss_kib", pss());
            long initStart = SystemClock.elapsedRealtimeNanos();
            OrtEnvironment environment = OrtEnvironment.getEnvironment();
            environment.setTelemetry(false);
            report.put("runtime_initialization_ms", (SystemClock.elapsedRealtimeNanos() - initStart) / 1e6);
            if (!"1.32.0".equals(environment.getVersion())) throw new SecurityException("Runtime version mismatch");
            report.put("runtime_version", environment.getVersion());
            JSONObject variants = new JSONObject();
            // Instrumentation.onStart executes on its worker thread, never main/UI.
            for (String kind : new String[]{"fp32", "int8"}) variants.put(kind, benchmark(context, environment, fixtures, kind));
            report.put("variants", variants);
            report.put("battery_after", battery(context));
            report.put("battery_drain_per_hour", JSONObject.NULL);
            report.put("battery_limitation", "Short USB-connected busy-loop benchmark; no production battery estimate");
            report.put("measurement_scope", "Java/JNI CPU inference including output extraction/close; no recording, I/O or sensor workload in warm loop");
            report.put("all_parity_gates_pass", true);
            File output = new File(context.getFilesDir(), "result.json");
            try (FileOutputStream stream = new FileOutputStream(output)) {
                stream.write(report.toString(2).getBytes(java.nio.charset.StandardCharsets.UTF_8));
                stream.getFD().sync();
            }
            Bundle result = new Bundle();
            result.putString("result", "PASS: generated-input benchmark saved to own files/result.json");
            finish(-1, result);
        } catch (Exception failure) { failed(failure); }
    }

    private JSONObject benchmark(Context context, OrtEnvironment environment, JSONObject fixtures, String kind) throws Exception {
        JSONObject metadata = fixtures.getJSONObject("models").getJSONObject(kind);
        String name = "eventnet-" + kind + ".onnx";
        byte[] model = asset(context, name, 1000000);
        if (!name.equals(metadata.getString("file")) || model.length != metadata.getInt("bytes")
                || !sha256(model).equals(metadata.getString("sha256"))) throw new SecurityException("Model mismatch");
        JSONObject result = new JSONObject();
        result.put("model_sha256", sha256(model));
        result.put("model_bytes", model.length);
        long sessionStart = SystemClock.elapsedRealtimeNanos();
        try (OrtSession.SessionOptions options = new OrtSession.SessionOptions()) {
            options.setIntraOpNumThreads(1);
            options.setInterOpNumThreads(1);
            options.setExecutionMode(OrtSession.SessionOptions.ExecutionMode.SEQUENTIAL);
            options.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT);
            options.addCPU(true);
            try (OrtSession session = environment.createSession(model, options)) {
                result.put("cold_session_ms", (SystemClock.elapsedRealtimeNanos() - sessionStart) / 1e6);
                if (!session.getInputNames().equals(Collections.singleton("features"))
                        || !session.getOutputNames().equals(Collections.singleton("logits"))) throw new SecurityException();
                double maxLogit = 0, maxProbability = 0;
                double temperature = fixtures.getDouble("temperature");
                JSONArray cases = fixtures.getJSONArray("cases");
                for (int i = 0; i < cases.length(); i++) {
                    JSONObject sample = cases.getJSONObject(i);
                    try (OnnxTensor tensor = tensor(environment, sample.getJSONArray("features_nct"))) {
                        long firstStart = SystemClock.elapsedRealtimeNanos();
                        float[] actual = infer(session, tensor);
                        if (i == 0) result.put("first_inference_ms", (SystemClock.elapsedRealtimeNanos() - firstStart) / 1e6);
                        JSONArray reference = sample.getJSONObject("references").getJSONArray(kind);
                        float[] expected = new float[4];
                        for (int j = 0; j < 4; j++) {
                            expected[j] = (float) reference.getDouble(j);
                            maxLogit = Math.max(maxLogit, Math.abs(actual[j] - reference.getDouble(j)));
                        }
                        double[] probabilities = BenchmarkMath.probabilities(actual, temperature);
                        double[] referenceProbabilities = BenchmarkMath.probabilities(expected, temperature);
                        for (int j = 0; j < 4; j++) maxProbability = Math.max(maxProbability, Math.abs(probabilities[j] - referenceProbabilities[j]));
                    }
                }
                JSONObject gates = fixtures.getJSONObject("gates");
                if (maxLogit > gates.getDouble("android_max_logit_error")
                        || maxProbability > gates.getDouble("android_max_probability_error")) throw new IllegalStateException("Native parity failed");
                result.put("max_logit_error", maxLogit);
                result.put("max_probability_error", maxProbability);
                // Fixed generated input, reused direct buffer; inference results are always closed.
                try (OnnxTensor input = tensor(environment, cases.getJSONObject(0).getJSONArray("features_nct"))) {
                    for (int i = 0; i < WARMUP; i++) infer(session, input);
                    long[] timings = new long[ITERATIONS];
                    long cpuStart = Process.getElapsedCpuTime();
                    long threadStart = Debug.threadCpuTimeNanos();
                    long wallStart = SystemClock.elapsedRealtimeNanos();
                    for (int i = 0; i < ITERATIONS; i++) {
                        long start = SystemClock.elapsedRealtimeNanos();
                        infer(session, input);
                        timings[i] = SystemClock.elapsedRealtimeNanos() - start;
                    }
                    long wall = SystemClock.elapsedRealtimeNanos() - wallStart;
                    long threadCpu = Debug.threadCpuTimeNanos() - threadStart;
                    long processCpuMs = Process.getElapsedCpuTime() - cpuStart;
                    result.put("warmup_iterations", WARMUP);
                    result.put("warm_iterations", ITERATIONS);
                    result.put("warm_median_ms", BenchmarkMath.percentile(timings, .5));
                    result.put("warm_p95_ms", BenchmarkMath.percentile(timings, .95));
                    result.put("warm_max_ms", BenchmarkMath.percentile(timings, 1));
                    result.put("warm_wall_ms", wall / 1e6);
                    result.put("warm_thread_cpu_ms", threadCpu / 1e6);
                    result.put("warm_process_cpu_ms", processCpuMs);
                    result.put("warm_process_cpu_percent_one_core", processCpuMs * 1e8 / wall);
                    result.put("warm_thread_cpu_us_per_inference", threadCpu / 1000.0 / ITERATIONS);
                }
                result.put("session_pss_kib", pss());
                result.put("native_heap_allocated_bytes", Debug.getNativeHeapAllocatedSize());
                result.put("java_heap_used_bytes", Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory());
            }
        }
        return result;
    }

    private static OnnxTensor tensor(OrtEnvironment environment, JSONArray values) throws Exception {
        if (values.length() != 42) throw new IllegalArgumentException();
        FloatBuffer data = ByteBuffer.allocateDirect(42 * 4).order(ByteOrder.nativeOrder()).asFloatBuffer();
        for (int i = 0; i < 42; i++) {
            double value = values.getDouble(i);
            if (!Double.isFinite(value) || Math.abs(value) > 1e9) throw new IllegalArgumentException();
            data.put((float) value);
        }
        data.rewind();
        return OnnxTensor.createTensor(environment, data, new long[]{1, 6, 7});
    }

    private static float[] infer(OrtSession session, OnnxTensor input) throws Exception {
        try (OrtSession.Result output = session.run(Collections.singletonMap("features", input))) {
            float[][] logits = (float[][]) output.get(0).getValue();
            if (logits.length != 1 || logits[0].length != 4) throw new IllegalArgumentException();
            for (float value : logits[0]) if (!Float.isFinite(value)) throw new IllegalArgumentException();
            return logits[0];
        }
    }

    private static byte[] asset(Context context, String name, int limit) throws Exception {
        try (InputStream stream = context.getAssets().open(name)) {
            java.io.ByteArrayOutputStream output = new java.io.ByteArrayOutputStream();
            byte[] buffer = new byte[4096];
            int count;
            while ((count = stream.read(buffer)) != -1) {
                if (output.size() + count > limit) throw new IllegalArgumentException("Asset too large");
                output.write(buffer, 0, count);
            }
            return output.toByteArray();
        }
    }

    private static String sha256(byte[] bytes) throws Exception {
        StringBuilder hex = new StringBuilder();
        for (byte value : MessageDigest.getInstance("SHA-256").digest(bytes)) hex.append(String.format(java.util.Locale.ROOT, "%02x", value & 255));
        return hex.toString();
    }

    private static int pss() {
        Debug.MemoryInfo memory = new Debug.MemoryInfo();
        Debug.getMemoryInfo(memory);
        return memory.getTotalPss();
    }

    private static JSONObject battery(Context context) throws Exception {
        Intent state = context.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        JSONObject value = new JSONObject();
        if (state == null) return value.put("available", false);
        value.put("plugged", state.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1));
        value.put("level", state.getIntExtra(BatteryManager.EXTRA_LEVEL, -1));
        value.put("temperature_tenths_c", state.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1));
        value.put("status", state.getIntExtra(BatteryManager.EXTRA_STATUS, -1));
        return value;
    }

    private void failed(Exception failure) {
        Bundle result = new Bundle();
        // No arbitrary runtime/device text in instrumentation output.
        result.putString("result", "FAIL: " + failure.getClass().getSimpleName());
        finish(0, result);
    }
}
