// Exercise the actual deployment entrypoints without a server, credentials or network.
import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { webcrypto } from "node:crypto";
import vm from "node:vm";

for (const name of ["capability", "dispatch"]) {
  test(`${name} deployment bundle requires a lease and expires while warm`, async () => {
    const source = await readFile(new URL(
      `../../.dart_tool/guardian-${name}-window.bundle.js`, import.meta.url,
    ), "utf8");
    for (const present of [false, true]) {
      let now = 1_790_000_000_000;
      let handler;
      let requests = 0;
      const values = {
        GUARDIAN_CAPABILITY_ENABLED: "true",
        GUARDIAN_DISPATCH_ENABLED: "true",
        GUARDIAN_WORKER_SECRET: "c".repeat(64),
        ...(present ? {
          GUARDIAN_PROCESSING_WINDOW_V1: JSON.stringify({
            schema_version: 1, starts_at_epoch_ms: now,
            expires_at_epoch_ms: now + 5000,
          }),
        } : {}),
      };
      const context = vm.createContext({
        Deno: { env: { get: (key) => values[key] }, serve: (value) => { handler = value; } },
        Date: class extends Date { static now() { return now; } },
        Request, Response, Headers, URL, TextEncoder, TextDecoder, AbortController,
        Uint8Array, crypto: webcrypto, setTimeout, clearTimeout,
        fetch: () => { requests++; throw new Error("Unexpected network operation"); },
      });
      new vm.Script(source).runInContext(context, { timeout: 1000 });
      assert.equal(typeof handler, "function");
      const request = () => new Request(`https://example.test/${name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-guardian-worker-secret": "c".repeat(64) },
        body: '{"invalid":true}',
      });
      const first = await handler(request());
      assert.equal(first.status, present ? 400 : 503);
      now += 5000;
      const expiredRequest = request();
      const expired = await handler(expiredRequest);
      assert.equal(expired.status, 503);
      assert.deepEqual(await expired.json(), { error: `${name}_disabled` });
      assert.equal(expiredRequest.bodyUsed, false);
      assert.equal(requests, 0);
      assert.equal(values[`GUARDIAN_${name.toUpperCase()}_ENABLED`], "true");
    }
  });
}
