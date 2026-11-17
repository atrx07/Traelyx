package io.github.atrx07.traelyx.syncpilot;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Spinner;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/** Real Android inactive-pause regression, without JUnit or third-party libraries. */
public final class PilotSelectionInstrumentation extends Instrumentation {
    @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }

    private static void require(boolean condition, String code) {
        if (!condition) throw new IllegalStateException(code);
    }

    private static Spinner spinner(View view) {
        if (view instanceof Spinner) return (Spinner) view;
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int i = 0; i < group.getChildCount(); i++) {
                Spinner found = spinner(group.getChildAt(i));
                if (found != null) return found;
            }
        }
        return null;
    }

    private void onMainChecked(Runnable action) {
        RuntimeException[] failure = {null};
        runOnMainSync(() -> {
            try { action.run(); } catch (RuntimeException error) { failure[0] = error; }
        });
        if (failure[0] != null) throw failure[0];
    }

    private static boolean sameBytes(File file, byte[] expected) throws IOException {
        try (FileInputStream input = new FileInputStream(file)) {
            byte[] actual = new byte[expected.length];
            int offset = 0;
            while (offset < actual.length) {
                int count = input.read(actual, offset, actual.length-offset);
                if (count <= 0) return false;
                offset += count;
            }
            return input.read() == -1 && Arrays.equals(actual, expected);
        }
    }

    @Override public void onStart() {
        Bundle result = new Bundle();
        File first = new File(getTargetContext().getFilesDir(), "marker-00000000-0000-0000-0000-0000000000a1.json");
        File second = new File(getTargetContext().getFilesDir(), "marker-00000000-0000-0000-0000-0000000000a2.json");
        // Unsupported fixture content cannot become a real clock journal if a test is interrupted.
        byte[] fixture = "{\"fixture_origin\":\"generated_lifecycle_selection_only\"}".getBytes(StandardCharsets.UTF_8);
        boolean firstCreated = false;
        boolean secondCreated = false;
        Activity activity = null;
        boolean passed = false;
        try {
            firstCreated = first.createNewFile();
            require(firstCreated, "fixture_collision");
            secondCreated = second.createNewFile();
            require(secondCreated, "fixture_collision");
            try (FileOutputStream output = new FileOutputStream(first)) { output.write(fixture); }
            try (FileOutputStream output = new FileOutputStream(second)) { output.write(fixture); }
            activity = startActivitySync(new Intent(getTargetContext(), PilotActivity.class)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            Activity target = activity;
            onMainChecked(() -> {
                Spinner list = spinner(target.findViewById(android.R.id.content));
                require(list != null, "history_missing");
                int selected = -1;
                for (int i = 0; i < list.getCount(); i++) {
                    if (second.getName().equals(list.getItemAtPosition(i))) selected = i;
                }
                require(selected > 0, "nondefault_selection_missing");
                list.setSelection(selected);
            });
            waitForIdleSync();
            onMainChecked(() -> {
                callActivityOnPause(target);
                require(second.getName().equals(spinner(target.findViewById(android.R.id.content)).getSelectedItem()),
                        "selection_reset_on_pause");
                callActivityOnResume(target);
            });
            waitForIdleSync();
            onMainChecked(() -> require(second.getName().equals(
                    spinner(target.findViewById(android.R.id.content)).getSelectedItem()), "selection_reset_on_resume"));
            require(sameBytes(first, fixture) && sameBytes(second, fixture), "fixture_changed");
            passed = true;
        } catch (Exception error) {
            result.putString("sync_selection_error", "lifecycle_regression_failed");
        } finally {
            if (activity != null) {
                Activity target = activity;
                runOnMainSync(target::finish);
                waitForIdleSync();
            }
            if (firstCreated && !first.delete()) passed = false;
            if (secondCreated && !second.delete()) passed = false;
        }
        result.putString("sync_selection_regression", passed ? "passed" : "failed");
        finish(passed ? Activity.RESULT_OK : Activity.RESULT_CANCELED, result);
    }
}
