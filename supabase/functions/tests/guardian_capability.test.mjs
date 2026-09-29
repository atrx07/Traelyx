import test from "node:test";
import assert from "node:assert/strict";
import {
  createHandler,
  createRpc,
  createTransport,
} from "../guardian-capability/server.mjs";

const id = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
const credential = "a".repeat(64);
const envelope = {
  event_id: id(1),
  kind: "severe_drive",
  occurred_at_epoch_ms: 1_790_000_000_000,
  rule_version: 1,
  schema_version: 1,
  uncertainty: "experimental_not_confirmed",
};
const ingest = {
  type: "ingest",
  owner_id: id(2),
  credential,
  envelope,
};
const receipt = {
  type: "receipt",
  device: id(3),
  credential,
  delivery: id(4),
};
const request = (body, options = {}) =>
  new Request("https://example.test/guardian-capability", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...options.headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
    ...options,
  });

test("disabled boundary never parses a capability or contacts SQL", async () => {
  const handler = createHandler({
    enabled: false,
    rpc: () => assert.fail("must not reach database"),
  });
  const response = await handler(request(ingest));
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: "capability_disabled" });
  assert.equal(response.headers.get("Cache-Control"), "no-store");
});

test("valid ingestion forwards only the guarded RPC arguments", async () => {
  let called;
  const handler = createHandler({
    enabled: true,
    rpc: () => (name, args) => {
      called = { name, args };
      return {
        event_id: envelope.event_id,
        state: "backend_accepted",
        duplicate: false,
        recipient_devices: 1,
      };
    },
  });
  const response = await handler(request(ingest));
  assert.equal(response.status, 200);
  assert.deepEqual(called, {
    name: "ingest_guardian_alert_v1",
    args: { owner_id: ingest.owner_id, credential, envelope },
  });
  assert.deepEqual(await response.json(), {
    event_id: envelope.event_id,
    state: "backend_accepted",
    duplicate: false,
    recipient_devices: 1,
  });
});

test("duplicate ingestion and receipt preserve distinct server outcomes", async () => {
  const handler = createHandler({
    enabled: true,
    rpc: () => (name) =>
      name === "ingest_guardian_alert_v1"
        ? {
          event_id: envelope.event_id,
          state: "backend_accepted",
          duplicate: true,
        }
        : false,
  });
  const duplicate = await handler(request(ingest));
  assert.equal(duplicate.status, 200);
  assert.equal((await duplicate.json()).duplicate, true);
  const stale = await handler(request(receipt));
  assert.equal(stale.status, 200);
  assert.deepEqual(await stale.json(), { received: false });
});

test("malformed or overbroad input never reaches the service-role RPC", async () => {
  const handler = createHandler({
    enabled: true,
    rpc: () => assert.fail("must not reach database"),
  });
  const invalid = [
    { ...ingest, trip_id: id(9) },
    { ...ingest, credential: "A".repeat(64) },
    { ...ingest, envelope: { ...envelope, coordinates: [1, 2] } },
    { ...ingest, envelope: { ...envelope, uncertainty: "confirmed" } },
    { ...ingest, envelope: { ...envelope, occurred_at_epoch_ms: 1.5 } },
    { ...receipt, device: "invalid" },
    { ...receipt, owner_id: id(2) },
  ];
  for (const body of invalid) {
    const response = await handler(request(body));
    assert.equal(response.status, 400);
  }
  assert.equal((await handler(request(" ".repeat(1537)))).status, 400);
  assert.equal((await handler(request("not json"))).status, 400);
  assert.equal(
    (await handler(request(ingest, {
      headers: { "Content-Type": "text/plain" },
    }))).status,
    415,
  );
  assert.equal(
    (await handler(
      new Request("https://example.test", {
        method: "GET",
      }),
    )).status,
    405,
  );
});

test("stalled and malformed UTF-8 bodies fail closed", async () => {
  let cancelled = false;
  const stream = new ReadableStream({
    cancel() {
      cancelled = true;
    },
  });
  const handler = createHandler({
    enabled: true,
    rpc: () => assert.fail("must not reach database"),
  });
  const response = await handler(
    request(stream, { body: stream, duplex: "half" }),
  );
  assert.equal(response.status, 400);
  assert.equal(cancelled, true);
  const invalid = new Uint8Array([0xff]);
  assert.equal(
    (await handler(request(invalid, { body: invalid }))).status,
    400,
  );
});

test("RPC destination and name are fixed; key remains in headers", async () => {
  const key = "s".repeat(64);
  let seen;
  const rpc = createRpc(
    "https://ksydjfcyzdtpbigskahm.supabase.co",
    key,
    (url, options) => {
      seen = { url, options };
      return { status: 200, value: false };
    },
  );
  await assert.rejects(rpc("unknown_rpc", {}));
  assert.equal(await rpc("receive_guardian_alert_v1", receipt), false);
  assert.equal(
    seen.url,
    "https://ksydjfcyzdtpbigskahm.supabase.co/rest/v1/rpc/receive_guardian_alert_v1",
  );
  assert.equal(seen.options.headers.apikey, key);
  assert.equal(seen.url.includes(key), false);
});

test("service RPC maps known SQL errors without leaking details", async () => {
  const key = "s".repeat(64);
  for (
    const [code, expected] of [
      ["42501", "unauthorized"],
      ["22023", "invalid_request"],
      ["40001", "identity_conflict"],
      ["P0002", "rate_limited"],
    ]
  ) {
    const rpc = createRpc(
      "https://ksydjfcyzdtpbigskahm.supabase.co",
      key,
      (url, options) => {
        assert.equal(url.includes(key), false);
        assert.equal(options.headers.apikey, key);
        assert.equal(options.body.includes(credential), true);
        return { status: 400, value: { code, message: "private SQL detail" } };
      },
    );
    const result = await rpc("receive_guardian_alert_v1", receipt);
    assert.equal(result.error, expected);
    assert.equal(JSON.stringify(result).includes("private SQL detail"), false);
  }
  assert.throws(() => createRpc("https://attacker.test", key, () => {}));
});

test("unauthorized capability is redacted at the public HTTP boundary", async () => {
  const handler = createHandler({
    enabled: true,
    rpc: () => () => ({ error: "unauthorized", status: 401 }),
  });
  const response = await handler(request(ingest));
  assert.equal(response.status, 401);
  const raw = await response.clone().text();
  assert.deepEqual(await response.json(), { error: "unauthorized" });
  assert.equal(raw.includes(credential), false);
});

test("unexpected backend response and sensitive text are redacted", async () => {
  const handler = createHandler({
    enabled: true,
    rpc: () => () => ({ routing_token: "private", error: "SQL detail" }),
  });
  const response = await handler(request(ingest));
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: "capability_unavailable" });
});

test("transport rejects redirects and caps response bodies", async () => {
  const transport = createTransport((_, options) => {
    assert.equal(options.redirect, "error");
    return new Response(" ".repeat(4097), { status: 200 });
  });
  await assert.rejects(transport("https://example.test", {}));
});

test("combined HTTP path preserves the guarded PostgREST wire contract", async () => {
  const key = "s".repeat(64);
  const calls = [];
  const transport = createTransport((url, options) => {
    calls.push({ url, options });
    assert.equal(options.headers.apikey, key);
    assert.equal(options.headers.Authorization, `Bearer ${key}`);
    assert.equal(url.includes(key), false);
    const body = JSON.parse(options.body);
    if (url.endsWith("/ingest_guardian_alert_v1")) {
      assert.deepEqual(body, {
        owner_id: ingest.owner_id,
        credential,
        envelope,
      });
      return Response.json({
        event_id: envelope.event_id,
        state: "backend_accepted",
        duplicate: false,
        recipient_devices: 0,
      });
    }
    assert.equal(url.endsWith("/receive_guardian_alert_v1"), true);
    assert.deepEqual(body, {
      device: receipt.device,
      credential,
      delivery: receipt.delivery,
    });
    return Response.json(true);
  });
  const handler = createHandler({
    enabled: true,
    rpc: () =>
      createRpc(
        "https://ksydjfcyzdtpbigskahm.supabase.co",
        key,
        transport,
      ),
  });
  const accepted = await handler(request(ingest));
  assert.equal(accepted.status, 200);
  assert.equal((await accepted.text()).includes(credential), false);
  const received = await handler(request(receipt));
  assert.equal(received.status, 200);
  assert.deepEqual(await received.json(), { received: true });
  assert.equal(calls.length, 2);
});
