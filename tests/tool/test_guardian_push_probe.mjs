import { test } from "node:test";
import assert from "node:assert/strict";
import { runDispatchProbe } from "../../tool/guardian_push_probe.mjs";

const secret = "a".repeat(64);
const counts = { processed: 1, provider_accepted: 1, skipped: 0, failed: 0, deferred: 0 };

test("one reviewed send uses the fixed endpoint and exposes aggregate acceptance only", async () => {
  let calls = 0;
  const result = await runDispatchProbe("send", secret, async (url, options) => {
    calls++;
    assert.equal(url, "https://ksydjfcyzdtpbigskahm.supabase.co/functions/v1/guardian-dispatch");
    assert.equal(options.method, "POST");
    assert.equal(options.redirect, "error");
    assert.equal(options.body, "{}");
    assert.deepEqual(options.headers, { "Content-Type": "application/json", "x-guardian-worker-secret": secret });
    assert.ok(options.signal instanceof AbortSignal);
    return Response.json(counts);
  });
  assert.equal(calls, 1);
  assert.deepEqual(result, { mode: "send", verified: true, ...counts });
  assert.ok(!JSON.stringify(result).includes(secret));
});

test("disabled and retired checks accept only their exact denials", async () => {
  for (const [mode, status, error] of [["disabled", 503, "dispatch_disabled"], ["retired", 401, "unauthorized"]]) {
    assert.deepEqual(await runDispatchProbe(mode, secret, async () => Response.json({ error }, { status })),
      { mode, verified: true });
    await assert.rejects(runDispatchProbe(mode, secret, async () => Response.json(counts)));
  }
});

test("unexpected count, extra details and server failure never retry or expose bodies", async () => {
  const responses = [
    Response.json({ ...counts, processed: 2, provider_accepted: 2 }),
    Response.json({ ...counts, deferred: 1 }),
    Response.json({ ...counts, token: secret }),
    Response.json({ error: secret }, { status: 503 }),
    new Response("x".repeat(513)), new Response("not json"),
  ];
  for (const response of responses) {
    let calls = 0;
    await assert.rejects(runDispatchProbe("send", secret, async () => { calls++; return response; }),
      (error) => !error.message.includes(secret) && error.message.includes("do not automatically retry"));
    assert.equal(calls, 1);
  }
});

test("invalid mode or credential makes no request and failed IO makes one attempt", async () => {
  let calls = 0;
  const fail = async () => { calls++; throw new Error(secret); };
  await assert.rejects(runDispatchProbe("automatic", secret, fail));
  await assert.rejects(runDispatchProbe("send", "b".repeat(63), fail));
  await assert.rejects(runDispatchProbe("send", secret + "\n", fail));
  assert.equal(calls, 0);
  await assert.rejects(runDispatchProbe("send", secret, fail), (error) => !error.message.includes(secret));
  assert.equal(calls, 1);
});
