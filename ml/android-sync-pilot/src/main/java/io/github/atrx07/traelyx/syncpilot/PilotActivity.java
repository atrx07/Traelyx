package io.github.atrx07.traelyx.syncpilot;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.AtomicFile;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowManager;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.TextView;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.UUID;

/** Standalone local pilot: never starts or accesses the main Traelyx recorder. */
public final class PilotActivity extends Activity {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private MarkerRun run;
    private File current;
    private File exporting;
    private MarkerView marker;
    private TextView status;
    private Spinner history;
    private Button start;
    private Button stop;
    private Button export;
    private boolean pending;
    private final Runnable advance = () -> {
        if (run != null && !run.stopped()) { pending = true; marker.invalidate(); }
    };

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(24, 24, 24, 24);
        root.setOnApplyWindowInsetsListener((view, insets) -> {
            if (Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets bars = insets.getInsets(WindowInsets.Type.systemBars());
                view.setPadding(24+bars.left, 24+bars.top, 24+bars.right, 24+bars.bottom);
            } else {
                view.setPadding(24+insets.getSystemWindowInsetLeft(), 24+insets.getSystemWindowInsetTop(),
                        24+insets.getSystemWindowInsetRight(), 24+insets.getSystemWindowInsetBottom());
            }
            return insets;
        });
        TextView instructions = new TextView(this);
        instructions.setText(R.string.instructions);
        root.addView(instructions);
        marker = new MarkerView();
        root.addView(marker, new LinearLayout.LayoutParams(-1, 0, 1));
        status = new TextView(this);
        status.setText(R.string.ready);
        root.addView(status);
        start = button(root, R.string.start, this::startRun);
        stop = button(root, R.string.stop, () -> finishRun("user"));
        history = new Spinner(this);
        root.addView(history);
        export = button(root, R.string.export, this::exportRun);
        setContentView(root);
        if (state != null) {
            String name = state.getString("exporting");
            if (name != null && name.matches("marker-[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\\.json")) {
                exporting = new File(getFilesDir(), name);
            }
        }
        refreshHistory();
        controls(false);
    }

    private Button button(LinearLayout root, int label, Runnable action) {
        Button button = new Button(this);
        button.setText(label);
        button.setOnClickListener(view -> action.run());
        root.addView(button);
        return button;
    }

    private void controls(boolean active) {
        start.setEnabled(!active);
        stop.setEnabled(active);
        history.setEnabled(!active);
        export.setEnabled(!active);
        if (active) getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        else getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    }

    private File[] journals() {
        File[] files = getFilesDir().listFiles((directory, name) ->
                name.matches("marker-[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\\.json"));
        if (files == null) return new File[0];
        Arrays.sort(files, (a, b) -> a.getName().compareTo(b.getName()));
        return files;
    }

    private void refreshHistory() {
        File[] files = journals();
        String[] names = new String[files.length];
        int selected = 0;
        for (int i = 0; i < files.length; i++) {
            names[i] = files[i].getName();
            if (files[i].equals(current)) selected = i;
        }
        history.setAdapter(new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, names));
        if (names.length > 0) history.setSelection(selected);
    }

    private void startRun() {
        if (journals().length >= 64) { status.setText(R.string.session_limit); return; }
        String alias = UUID.randomUUID().toString();
        current = new File(getFilesDir(), "marker-"+alias+".json");
        run = new MarkerRun(alias);
        marker.label = getString(R.string.run_label, alias.substring(0, 8));
        marker.runAlias = alias.substring(0, 8);
        controls(true);
        if (save()) advance.run();
        else failStorage();
    }

    private boolean save() {
        AtomicFile file = new AtomicFile(current);
        FileOutputStream stream = null;
        try {
            stream = file.startWrite();
            stream.write(run.json().getBytes(StandardCharsets.UTF_8));
            file.finishWrite(stream);
            return true;
        } catch (IOException error) {
            file.failWrite(stream);
            return false;
        }
    }

    private void failStorage() {
        handler.removeCallbacks(advance);
        pending = false;
        if (run != null && !run.stopped()) run.stop("paused");
        controls(false);
        status.setText(R.string.storage_error);
        refreshHistory();
    }

    private void finishRun(String reason) {
        handler.removeCallbacks(advance);
        pending = false;
        if (run != null && !run.stopped()) {
            run.stop(reason);
            if (!save()) { failStorage(); return; }
            status.setText(R.string.saved);
            refreshHistory();
        }
        controls(false);
    }

    @Override protected void onPause() {
        finishRun("paused");
        super.onPause();
    }

    @Override protected void onSaveInstanceState(Bundle state) {
        if (exporting != null) state.putString("exporting", exporting.getName());
        super.onSaveInstanceState(state);
    }

    private void exportRun() {
        Object selected = history.getSelectedItem();
        if (selected == null) { status.setText(R.string.empty); return; }
        exporting = new File(getFilesDir(), selected.toString());
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.putExtra(Intent.EXTRA_LOCAL_ONLY, true);
        intent.setType("application/json");
        intent.putExtra(Intent.EXTRA_TITLE, exporting.getName());
        startActivityForResult(intent, 1);
    }

    @Override protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (request != 1 || result != RESULT_OK || data == null || data.getData() == null || exporting == null) return;
        try (InputStream input = new AtomicFile(exporting).openRead();
             OutputStream output = getContentResolver().openOutputStream(data.getData(), "w")) {
            if (output == null) throw new IOException();
            byte[] buffer = new byte[4096];
            int total = 0;
            int count;
            while ((count = input.read(buffer)) != -1) {
                total += count;
                if (total > 262144) throw new IOException();
                output.write(buffer, 0, count);
            }
            output.flush();
            status.setText(R.string.exported);
        } catch (IOException | SecurityException error) { status.setText(R.string.export_error); }
        exporting = null;
    }

    private final class MarkerView extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private String label = getString(R.string.idle_marker);
        private String runAlias = "";
        MarkerView() { super(PilotActivity.this); setContentDescription(label); }

        @Override protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            boolean record = pending && run != null && !run.stopped();
            long before = SystemClock.elapsedRealtimeNanos();
            if (record) label = run.token();
            canvas.drawColor(Color.WHITE);
            paint.setColor(Color.BLACK);
            paint.setTextSize(Math.min(getWidth()/5f, 100*getResources().getDisplayMetrics().scaledDensity));
            paint.setTextAlign(Paint.Align.CENTER);
            canvas.drawText(label, getWidth()/2f, getHeight()/2f, paint);
            paint.setTextSize(20*getResources().getDisplayMetrics().scaledDensity);
            canvas.drawText(runAlias, getWidth()/2f, getHeight()*0.8f, paint);
            long after = SystemClock.elapsedRealtimeNanos();
            if (record) {
                pending = false;
                try { run.append(before, after); }
                catch (IllegalArgumentException error) { post(() -> failStorage()); return; }
                setContentDescription(label);
                // Journal I/O is outside the measured Canvas command interval.
                MarkerRun drawnRun = run;
                post(() -> {
                    if (run != drawnRun || drawnRun.stopped()) return;
                    if (!save()) { failStorage(); return; }
                    status.setText(getString(R.string.running, run.size()));
                    if (run.size() == 64) finishRun("limit");
                    else if (!run.stopped()) handler.postDelayed(advance, 2000);
                });
            }
        }
    }
}
