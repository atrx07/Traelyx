// Explicit reviewed operator probe only. Never scheduled or called by the app.
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { readBoundedJson } from "../supabase/functions/guardian-dispatch/worker.mjs";

const ENDPOINT = "https://ksydjfcyzdtpbigskahm.supabase.co/functions/v1/guardian-dispatch";
const SECRET = /^[a-f0-9]{64}$/;
const MODES = new Set(["disabled", "send", "retired"]);
const COUNTERS = ["processed", "provider_accepted", "skipped", "failed", "deferred"];
const unavailable = () => new Error("Reviewed dispatch probe failed or uncertain; do not automatically retry");

export async function runDispatchProbe(mode, secret, transport = fetch) {
  if (!MODES.has(mode) || typeof secret !== "string" || secret.length !== 64 || !SECRET.test(secret)) throw unavailable();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 45_000);
  try {
    // Exactly one invocation. A timeout/ambiguous result never triggers a resend.
    const response = await transport(ENDPOINT, {
      method: "POST", redirect: "error", signal: controller.signal,
      headers: { "Content-Type": "application/json", "x-guardian-worker-secret": secret },
      body: "{}",
    });
    const value = await readBoundedJson(response.body, 512, controller.signal);
    if (mode !== "send") {
      const status = mode === "disabled" ? 503 : 401;
      const error = mode === "disabled" ? "dispatch_disabled" : "unauthorized";
      if (response.status !== status || !value || Object.keys(value).join(",") !== "error" || value.error !== error) {
        throw unavailable();
      }
      return { mode, verified: true };
    }
    if (response.status !== 200 || !value || Array.isArray(value) ||
        Object.keys(value).sort().join(",") !== [...COUNTERS].sort().join(",") ||
        COUNTERS.some((key) => !Number.isInteger(value[key]) || value[key] < 0 || value[key] > 6) ||
        value.processed !== 1 || value.provider_accepted !== 1 ||
        value.skipped !== 0 || value.failed !== 0 || value.deferred !== 0) throw unavailable();
    return { mode, verified: true, ...value };
  } catch {
    throw unavailable(); // Never expose HTTP bodies, credentials or provider details.
  } finally {
    clearTimeout(timer);
  }
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  try {
    const mode = process.argv[2];
    if (process.argv.length !== 3 || !MODES.has(mode)) throw unavailable();
    const path = fileURLToPath(new URL("../.dart_tool/guardian-push-worker-once.secret", import.meta.url));
    const bytes = await readFile(path);
    let secret;
    try {
      if (bytes.length !== 64) throw unavailable();
      secret = bytes.toString("utf8");
    } finally { bytes.fill(0); }
    console.log(JSON.stringify(await runDispatchProbe(mode, secret)));
    secret = undefined;
  } catch {
    console.error("Reviewed dispatch probe failed or uncertain; do not automatically retry");
    process.exitCode = 1;
  }
}
