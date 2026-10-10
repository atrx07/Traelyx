import test from "node:test";
import assert from "node:assert/strict";
import {
  createProcessingWindowGate,
  createWindowFetch,
} from "../_shared/processing_window.mjs";
import { createHandler as capabilityHandler } from "../guardian-capability/server.mjs";
import { createHandler as dispatchHandler } from "../guardian-dispatch/worker.mjs";

const start = 1_790_000_000_000;
const window = {
  schema_version: 1,
  starts_at_epoch_ms: start,
  expires_at_epoch_ms: start + 360_000,
};
const gateFor = (value, now = start, flag = "true") =>
  createProcessingWindowGate(flag, value, () => now);

test("missing, malformed, oversized or ambiguous windows stay closed", () => {
  for (
    const value of [
      undefined,
      null,
      1,
      "",
      "invalid",
      " ".repeat(257),
      "null",
      "[]",
      "{}",
      ` {"schema_version":1}`,
      JSON.stringify({ ...window, schema_version: 2 }),
      `{"schema_version":2,${JSON.stringify(window).slice(1)}`,
      JSON.stringify({ ...window, extra: true }),
      JSON.stringify({ ...window, starts_at_epoch_ms: String(start) }),
      JSON.stringify({ ...window, expires_at_epoch_ms: start }),
      JSON.stringify({ ...window, expires_at_epoch_ms: start + 360_001 }),
      JSON.stringify({ ...window, starts_at_epoch_ms: -1 }),
      JSON.stringify({ ...window, expires_at_epoch_ms: 1.5 }),
    ]
  ) assert.equal(gateFor(value)(), false);
  for (const flag of [undefined, false, true, "false", "TRUE", " true"]) {
    assert.equal(
      createProcessingWindowGate(flag, JSON.stringify(window), () => start)(),
      false,
    );
  }
});

test("six-minute maximum is strict and warm instances expire at the boundary", () => {
  let now = start - 1;
  const gate = createProcessingWindowGate(
    "true",
    JSON.stringify(window),
    () => now,
  );
  assert.equal(gate(), false);
  now = start;
  assert.equal(gate(), true);
  now = start + 359_999;
  assert.equal(gate(), true);
  now = start + 360_000;
  assert.equal(gate(), false);
  now = start; // A clock rollback cannot revive this expired warm instance.
  assert.equal(gate(), false);
});

test("invalid clocks and backwards jumps close the warm gate permanently", () => {
  for (const bad of [NaN, Infinity, -1, "now", start + 0.5]) {
    assert.equal(gateFor(JSON.stringify(window), bad)(), false);
  }
  let now = start + 100;
  const gate = createProcessingWindowGate(
    "true",
    JSON.stringify(window),
    () => now,
  );
  assert.equal(gate(), true);
  now--;
  assert.equal(gate(), false);
  now += 2;
  assert.equal(gate(), false);
  const broken = createProcessingWindowGate(
    "true",
    JSON.stringify(window),
    () => {
      throw new Error("clock failure");
    },
  );
  assert.equal(broken(), false);
});

test("expired requests on the same capability handler never read bodies or SQL", async () => {
  let now = start;
  let calls = 0;
  const gate = createProcessingWindowGate(
    "true",
    JSON.stringify(window),
    () => now,
  );
  const handler = capabilityHandler({
    enabled: gate,
    rpc: () => () => {
      calls++;
      return true;
    },
  });
  const request = () =>
    new Request("https://example.test/capability", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        type: "receipt",
        credential: "a".repeat(64),
        device: "00000000-0000-4000-8000-000000000001",
        delivery: "00000000-0000-4000-8000-000000000002",
      }),
    });
  assert.equal((await handler(request())).status, 200);
  now = window.expires_at_epoch_ms;
  const expired = request();
  const response = await handler(expired);
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: "capability_disabled" });
  assert.equal(expired.bodyUsed, false);
  assert.equal(calls, 1);
});

test("expired worker preserves credential denial and never runs dispatch", async () => {
  let now = start;
  let calls = 0;
  const credential = "c".repeat(64);
  const gate = createProcessingWindowGate(
    "true",
    JSON.stringify(window),
    () => now,
  );
  const handler = dispatchHandler({
    enabled: gate,
    secret: credential,
    run: () => {
      calls++;
      return {};
    },
  });
  const request = (secret = credential) =>
    new Request("https://example.test/dispatch", {
      method: "POST",
      headers: { "x-guardian-worker-secret": secret },
      body: "{}",
    });
  assert.equal((await handler(request())).status, 200);
  now = window.expires_at_epoch_ms;
  assert.equal((await handler(request("d".repeat(64)))).status, 401);
  const expired = request();
  const response = await handler(expired);
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: "dispatch_disabled" });
  assert.equal(expired.bodyUsed, false);
  assert.equal(calls, 1);
});

test("a request admitted before expiry cannot start later outbound operations", async () => {
  let now = start;
  let calls = 0;
  const gate = createProcessingWindowGate(
    "true",
    JSON.stringify(window),
    () => now,
  );
  const transport = createWindowFetch(gate, () => {
    calls++;
    return Promise.resolve("ok");
  });
  assert.equal(await transport("https://example.test/sql"), "ok");
  now = window.expires_at_epoch_ms;
  for (const endpoint of ["sql", "oauth", "fcm"]) {
    assert.throws(
      () => transport(`https://example.test/${endpoint}`),
      /window closed/,
    );
  }
  assert.equal(calls, 1);
});
