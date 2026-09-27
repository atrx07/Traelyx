import test from "node:test";
import assert from "node:assert/strict";
import {
  createFcmProvider,
  createHandler,
  createRpc,
  createTransport,
  dispatchBatch,
  readBoundedJson,
  retryDelay,
} from "../guardian-dispatch/worker.mjs";

const id = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
const claim = (n) => ({ delivery_id: id(n), claim_id: id(n + 100) });
const target = {
  routing_token: "synthetic-routing-token",
  device_id: id(50),
  device_generation: id(51),
  ttl_seconds: 90,
};
const secret = "c".repeat(64);
const request = (body = "{}", credential = secret, method = "POST") =>
  new Request("https://example.test/worker", {
    method,
    headers: { "x-guardian-worker-secret": credential },
    ...(method === "POST" ? { body } : {}),
  });

test("worker rejects unauthenticated, malformed and oversized input without running", async () => {
  let calls = 0;
  const handler = createHandler({
    enabled: true,
    secret,
    run: () => {
      calls++;
    },
  });
  assert.equal((await handler(request("{}", "d".repeat(64)))).status, 401);
  assert.equal((await handler(request("{}", ""))).status, 401);
  assert.equal((await handler(request("{}", secret, "GET"))).status, 405);
  for (
    const body of ["null", "[]", '{"batch_size":30}', " ".repeat(33), "invalid"]
  ) {
    assert.equal((await handler(request(body))).status, 400);
  }
  assert.equal(calls, 0);
});

test("dispatch is disabled by default and errors never expose credentials", async () => {
  const disabled = createHandler({
    secret,
    run: () => assert.fail("must stay inert"),
  });
  assert.equal((await disabled(request())).status, 503);
  const broken = createHandler({
    enabled: true,
    secret,
    run: () => {
      throw new Error(secret);
    },
  });
  const response = await broken(request());
  assert.equal(response.status, 503);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal((await response.text()).includes(secret), false);
});

test("handler passes only empty explicit invocation and aggregate output", async () => {
  const handler = createHandler({
    enabled: true,
    secret,
    run: () => ({ processed: 0 }),
  });
  const response = await handler(request());
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { processed: 0 });
});

test("bounded JSON rejects excess bytes and malformed UTF-8", async () => {
  await assert.rejects(readBoundedJson(new Response(" ".repeat(40)).body, 32));
  await assert.rejects(
    readBoundedJson(new Response(new Uint8Array([0xff])).body, 32),
  );
  assert.deepEqual(await readBoundedJson(new Response("{}").body, 32), {});
});

test("transport timeout aborts the fetch; redirects are prohibited", async () => {
  let signal;
  const transport = createTransport(async (_, options) => {
    signal = options.signal;
    assert.equal(options.redirect, "error");
    return await new Promise(() => {});
  });
  await assert.rejects(transport("https://example.test", {}, 10));
  assert.equal(signal.aborted, true);
});

test("a stalled request body is cancelled at the handler deadline", async () => {
  let cancelled = false;
  const stream = new ReadableStream({
    cancel() {
      cancelled = true;
    },
  });
  const handler = createHandler({
    enabled: true,
    secret,
    run: () => assert.fail("must not run"),
  });
  const response = await handler(
    new Request("https://example.test", {
      method: "POST",
      headers: { "x-guardian-worker-secret": secret },
      body: stream,
      duplex: "half",
    }),
  );
  assert.equal(response.status, 400);
  assert.equal(cancelled, true);
});

test("RPC routes and destination are fixed; service credentials stay in headers", async () => {
  let seen;
  const rpc = createRpc(
    "https://ksydjfcyzdtpbigskahm.supabase.co",
    secret,
    (url, options) => {
      seen = { url, options };
      return { status: 200, value: [] };
    },
  );
  await assert.rejects(rpc("arbitrary_rpc", {}));
  assert.throws(() => createRpc("https://attacker.test", secret, () => {}));
  await rpc("claim_guardian_dispatch_batch_v1", { batch_size: 6 });
  assert.equal(seen.options.headers.apikey, secret);
  assert.equal(seen.url.includes(secret), false);
  assert.equal(seen.options.body.includes(secret), false);
});

test("OAuth failure reserves no attempts", async () => {
  await assert.rejects(dispatchBatch(() => assert.fail("no claim"), {
    authorize: () => {
      throw new Error("synthetic");
    },
  }));
});

test("revocation after claim skips send and asks SQL to finish using current permission", async () => {
  const calls = [];
  const rpc = (name, parameters) => {
    calls.push({ name, parameters });
    if (name.startsWith("claim_")) return [claim(1)];
    if (name.startsWith("guardian_dispatch_target")) return null;
    return null;
  };
  const result = await dispatchBatch(rpc, {
    authorize: () => "token",
    send: () => assert.fail("revoked delivery must not send"),
  });
  assert.equal(result.skipped, 1);
  assert.equal(calls.at(-1).parameters.accepted, false);
  assert.equal(calls.at(-1).parameters.claim, claim(1).claim_id);
});

test("provider acceptance is recorded separately and target is checked after OAuth", async () => {
  const order = [];
  const result = await dispatchBatch((name, parameters) => {
    order.push(name);
    if (name.startsWith("claim_")) return [claim(1)];
    if (name.startsWith("guardian_dispatch_target")) return target;
    assert.equal(parameters.accepted, true);
  }, {
    authorize: () => {
      order.push("oauth");
      return "token";
    },
    send: (received, delivery, token) => {
      order.push("send");
      assert.deepEqual(received, target);
      assert.equal(delivery, id(1));
      assert.equal(token, "token");
      return { accepted: true, permanent: false, retryAfter: 60 };
    },
  });
  assert.deepEqual(order, [
    "oauth",
    "claim_guardian_dispatch_batch_v1",
    "guardian_dispatch_target_v1",
    "send",
    "finish_guardian_dispatch_v2",
  ]);
  assert.equal(result.provider_accepted, 1);
  assert.equal("device_received" in result, false);
});

test("send timeout schedules SQL retry; lost completion never resends in the same run", async () => {
  let sends = 0;
  let finishes = 0;
  const result = await dispatchBatch((name, parameters) => {
    if (name.startsWith("claim_")) return [claim(1)];
    if (name.startsWith("guardian_dispatch_target")) return target;
    finishes++;
    assert.equal(parameters.accepted, false);
    assert.equal(parameters.retry_after_seconds, 60);
    throw new Error("completion lost");
  }, {
    authorize: () => "token",
    send: () => {
      sends++;
      throw new Error("timeout");
    },
  });
  assert.equal(sends, 1);
  assert.equal(finishes, 1);
  assert.equal(result.deferred, 1);
});

test("unexpected fields, expired targets, duplicates and oversized claims fail closed", async () => {
  for (
    const claims of [
      [claim(1), claim(1)],
      Array.from({ length: 7 }, (_, i) => claim(i)),
      [{ ...claim(1), route: "forbidden" }],
    ]
  ) {
    await assert.rejects(
      dispatchBatch(() => claims, { authorize: () => "token" }),
    );
  }
  for (
    const invalid of [
      { ...target, ttl_seconds: 0 },
      { ...target, name: "forbidden" },
      { ...target, device_generation: "bad" },
      { ...target, routing_token: "bad token" },
    ]
  ) {
    const result = await dispatchBatch(
      (name) => name.startsWith("claim_") ? [claim(1)] : invalid,
      {
        authorize: () => "token",
        send: () => assert.fail("invalid target"),
      },
    );
    assert.equal(result.deferred, 1);
    assert.equal(result.processed, 0);
  }
});

test("bounded batch uses at most three concurrent sends and does not loop for more work", async () => {
  let active = 0;
  let peak = 0;
  let claimCalls = 0;
  const result = await dispatchBatch((name, parameters) => {
    if (name.startsWith("claim_")) {
      claimCalls++;
      assert.equal(parameters.batch_size, 6);
      return Array.from({ length: 6 }, (_, i) => claim(i));
    }
    return name.startsWith("guardian_dispatch_target") ? target : null;
  }, {
    authorize: () => "token",
    send: async () => {
      active++;
      peak = Math.max(peak, active);
      await new Promise((resolve) => setTimeout(resolve, 5));
      active--;
      return { accepted: true, permanent: false, retryAfter: 60 };
    },
  });
  assert.equal(peak, 3);
  assert.equal(claimCalls, 1);
  assert.equal(result.processed, 6);
});

test("Retry-After is respected and bounded", () => {
  assert.equal(retryDelay("120"), 120);
  assert.equal(retryDelay("0"), 60);
  assert.equal(retryDelay("999999999"), 86400);
  assert.equal(retryDelay("bad"), 60);
  assert.equal(retryDelay(new Date(180000).toUTCString(), 0), 180);
});

// Ephemeral synthetic key exists in test memory only, never on disk or in logs.
const keys = await crypto.subtle.generateKey(
  {
    name: "RSASSA-PKCS1-v1_5",
    modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]),
    hash: "SHA-256",
  },
  true,
  ["sign", "verify"],
);
const privateBytes = new Uint8Array(
  await crypto.subtle.exportKey("pkcs8", keys.privateKey),
);
const account = {
  type: "service_account",
  project_id: "synthetic-test",
  client_email: "sender@synthetic-test.iam.gserviceaccount.com",
  token_uri: "https://oauth2.googleapis.com/token",
  private_key: `-----BEGIN ${"PRIVATE"} KEY-----\n${
    Buffer.from(privateBytes).toString("base64")
  }\n-----END PRIVATE KEY-----\n`,
};

test("OAuth assertion is correctly signed and narrowly scoped with fixed token endpoint", async () => {
  const provider = createFcmProvider(
    "synthetic-test",
    account,
    async (url, options) => {
      assert.equal(url, "https://oauth2.googleapis.com/token");
      const assertion = new URLSearchParams(options.body).get("assertion");
      const [header, payload, signature] = assertion.split(".");
      const claims = JSON.parse(Buffer.from(payload, "base64url"));
      assert.equal(
        claims.scope,
        "https://www.googleapis.com/auth/firebase.messaging",
      );
      assert.equal(claims.exp - claims.iat, 3600);
      assert.equal(
        await crypto.subtle.verify(
          "RSASSA-PKCS1-v1_5",
          keys.publicKey,
          Buffer.from(signature, "base64url"),
          new TextEncoder().encode(`${header}.${payload}`),
        ),
        true,
      );
      return {
        status: 200,
        value: {
          access_token: "synthetic-access-token",
          token_type: "Bearer",
          expires_in: 3600,
        },
      };
    },
  );
  assert.equal(await provider.authorize(), "synthetic-access-token");
  assert.throws(() => createFcmProvider("other-project", account, () => {}));
  assert.throws(() =>
    createFcmProvider("synthetic-test", {
      ...account,
      token_uri: "https://attacker.test",
    }, () => {})
  );
});

test("FCM payload is data-only and contains only opaque delivery/generation identifiers", async () => {
  const provider = createFcmProvider(
    "synthetic-test",
    account,
    (url, options) => {
      assert.equal(
        url,
        "https://fcm.googleapis.com/v1/projects/synthetic-test/messages:send",
      );
      const { message } = JSON.parse(options.body);
      assert.deepEqual(message.data, {
        schema_version: "1",
        delivery_id: id(1),
        device_generation: id(51),
      });
      assert.equal("notification" in message, false);
      assert.equal(message.android.ttl, "90s");
      assert.equal(message.android.direct_boot_ok, false);
      assert.equal(
        message.android.restricted_package_name,
        "io.github.atrx07.traelyx",
      );
      return {
        status: 200,
        value: { name: "projects/synthetic-test/messages/fake" },
      };
    },
  );
  assert.equal(
    (await provider.send(target, id(1), "synthetic-access-token")).accepted,
    true,
  );
});

test("FCM unregistered token is terminal; quota/auth failures retry; malformed success is not accepted", async () => {
  for (
    const [status, code, permanent] of [
      [404, "UNREGISTERED", true],
      [400, "INVALID_ARGUMENT", true],
      [403, "SENDER_ID_MISMATCH", true],
      [429, "QUOTA_EXCEEDED", false],
      [401, "UNAUTHENTICATED", false],
      [500, "INTERNAL", false],
    ]
  ) {
    const provider = createFcmProvider(
      "synthetic-test",
      account,
      () => ({
        status,
        retryAfter: "180",
        value: {
          error: {
            details: [{
              "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
              errorCode: code,
            }],
          },
        },
      }),
    );
    assert.deepEqual(await provider.send(target, id(1), "token"), {
      accepted: false,
      permanent,
      retryAfter: 180,
    });
  }
  const malformed = createFcmProvider(
    "synthetic-test",
    account,
    () => ({ status: 200, value: {} }),
  );
  assert.equal((await malformed.send(target, id(1), "token")).accepted, false);
});

test("full handler, OAuth, RPC and FCM adapters preserve the guarded wire contract", async () => {
  const calls = [];
  const transport = createTransport((url, options) => {
    calls.push(url);
    if (url === "https://oauth2.googleapis.com/token") {
      return Response.json({
        access_token: "synthetic-access-token",
        token_type: "Bearer",
        expires_in: 3600,
      });
    }
    const body = JSON.parse(options.body);
    if (url.endsWith("/claim_guardian_dispatch_batch_v1")) {
      assert.deepEqual(body, { batch_size: 6 });
      return Response.json([claim(1)]);
    }
    if (url.endsWith("/guardian_dispatch_target_v1")) {
      assert.deepEqual(body, { delivery: id(1), claim: id(101) });
      return Response.json(target);
    }
    if (url.endsWith("/messages:send")) {
      assert.equal(
        options.headers.Authorization,
        "Bearer synthetic-access-token",
      );
      assert.equal(body.message.data.delivery_id, id(1));
      return Response.json({
        name: "projects/synthetic-test/messages/example",
      });
    }
    assert.equal(url.endsWith("/finish_guardian_dispatch_v2"), true);
    assert.deepEqual(body, {
      delivery: id(1),
      claim: id(101),
      accepted: true,
      permanent_failure: false,
      retry_after_seconds: 60,
    });
    return new Response(null, { status: 204 });
  });
  const rpc = createRpc(
    "https://ksydjfcyzdtpbigskahm.supabase.co",
    secret,
    transport,
  );
  const provider = createFcmProvider("synthetic-test", account, transport);
  const handler = createHandler({
    enabled: true,
    secret,
    run: () => dispatchBatch(rpc, provider),
  });
  const response = await handler(request());
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    processed: 1,
    provider_accepted: 1,
    skipped: 0,
    failed: 0,
    deferred: 0,
  });
  assert.equal(calls.length, 5);
});
