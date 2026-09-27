// Portable server core: only Web APIs; no mobile credentials, SDK or telemetry logs.
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isUuid = (value) => typeof value === "string" && UUID.test(value);
const SECRET = /^[0-9a-f]{64}$/;
const PEM_START = ["-----BEGIN", "PRIVATE KEY-----"].join(" ");
const PEM_END = "-----END PRIVATE KEY-----";
const encoder = new TextEncoder();
const failure = () => new Error("Guardian dispatch unavailable");
const exact = (value, keys) =>
  value !== null && typeof value === "object" &&
  !Array.isArray(value) &&
  Object.keys(value).sort().join(",") === [...keys].sort().join(",");

export async function readBoundedJson(body, limit, signal) {
  if (!body) throw failure();
  const reader = body.getReader();
  const cancel = () => {
    reader.cancel().catch(() => {});
  };
  signal?.addEventListener("abort", cancel, { once: true });
  const chunks = [];
  let size = 0;
  try {
    if (signal?.aborted) throw failure();
    while (true) {
      const { done, value } = await reader.read();
      if (signal?.aborted) throw failure();
      if (done) break;
      size += value.byteLength;
      if (size > limit) throw failure();
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } finally {
    // Cancellation must not delay the bounded request when a peer stops reading.
    reader.cancel().catch(() => {});
    signal?.removeEventListener("abort", cancel);
    reader.releaseLock();
  }
}

async function deadline(operation, milliseconds) {
  const controller = new AbortController();
  let timer;
  try {
    return await Promise.race([
      operation(controller.signal),
      new Promise((_, reject) => {
        timer = setTimeout(() => {
          controller.abort();
          reject(failure());
        }, milliseconds);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}

export function createTransport(fetcher = fetch) {
  return (url, options, milliseconds = 5000) =>
    deadline(async (signal) => {
      const response = await fetcher(url, {
        ...options,
        signal,
        redirect: "error",
      });
      // Do not return or log provider/RPC bodies except to the private adapter.
      let value;
      try {
        value = await readBoundedJson(response.body, 16384, signal);
      } catch {
        value = null;
      }
      return {
        status: response.status,
        retryAfter: response.headers.get("retry-after"),
        value,
      };
    }, milliseconds);
}

export function createRpc(url, key, transport) {
  if (
    !/^https:\/\/[a-z0-9]{20}\.supabase\.co$/.test(url) ||
    typeof key !== "string" || key.length < 32 || key.length > 4096
  ) throw failure();
  const names = new Set([
    "claim_guardian_dispatch_batch_v1",
    "guardian_dispatch_target_v1",
    "finish_guardian_dispatch_v2",
  ]);
  return async (name, parameters) => {
    if (!names.has(name)) throw failure();
    const response = await transport(`${url}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(parameters),
    });
    if (response.status < 200 || response.status >= 300) throw failure();
    return response.value;
  };
}

const base64url = (bytes) =>
  btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
const encodeJson = (value) => base64url(encoder.encode(JSON.stringify(value)));

export function retryDelay(header, now = Date.now()) {
  let seconds = 60;
  if (typeof header === "string" && header.length <= 128) {
    if (/^\d+$/.test(header)) seconds = Number(header);
    else {
      const date = Date.parse(header);
      if (Number.isFinite(date)) seconds = Math.ceil((date - now) / 1000);
    }
  }
  return Number.isFinite(seconds)
    ? Math.max(60, Math.min(86400, seconds))
    : 86400;
}

export function createFcmProvider(project, account, transport, now = Date.now) {
  if (
    typeof project !== "string" ||
    !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project) ||
    account?.type !== "service_account" || account.project_id !== project ||
    typeof account.client_email !== "string" ||
    !account.client_email.endsWith(`@${project}.iam.gserviceaccount.com`) ||
    !/^[a-z0-9-]+@[a-z0-9-]+\.iam\.gserviceaccount\.com$/.test(
      account.client_email,
    ) ||
    account.token_uri !== "https://oauth2.googleapis.com/token" ||
    typeof account.private_key !== "string" ||
    account.private_key.length > 8192 ||
    !account.private_key.startsWith(`${PEM_START}\n`) ||
    !account.private_key.trimEnd().endsWith(PEM_END) ||
    !/^[A-Za-z0-9+/=\r\n]+$/.test(
      account.private_key.trimEnd().slice(PEM_START.length, -PEM_END.length),
    )
  ) {
    throw failure();
  }
  return {
    async authorize() {
      const pem = account.private_key.replace(/-----[^\n]+-----/g, "").replace(
        /\s/g,
        "",
      );
      const key = await crypto.subtle.importKey(
        "pkcs8",
        Uint8Array.from(atob(pem), (character) => character.charCodeAt(0)),
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"],
      );
      const issued = Math.floor(now() / 1000);
      const unsigned = `${encodeJson({ alg: "RS256", typ: "JWT" })}.${
        encodeJson({
          iss: account.client_email,
          scope: "https://www.googleapis.com/auth/firebase.messaging",
          aud: "https://oauth2.googleapis.com/token",
          iat: issued,
          exp: issued + 3600,
        })
      }`;
      const signature = await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        key,
        encoder.encode(unsigned),
      );
      const response = await transport("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
          assertion: `${unsigned}.${base64url(new Uint8Array(signature))}`,
        }).toString(),
      }, 8000);
      const token = response.value?.access_token;
      if (
        response.status !== 200 || typeof token !== "string" ||
        token.length < 20 ||
        token.length > 4096 || /[\s\r\n]/.test(token) ||
        response.value.token_type?.toLowerCase() !== "bearer" ||
        !Number.isFinite(response.value.expires_in) ||
        response.value.expires_in < 120
      ) throw failure();
      return token;
    },
    async send(target, delivery, accessToken) {
      const response = await transport(
        `https://fcm.googleapis.com/v1/projects/${project}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: target.routing_token,
              data: {
                schema_version: "1",
                delivery_id: delivery,
                device_generation: target.device_generation,
              },
              android: {
                priority: "HIGH",
                ttl: `${target.ttl_seconds}s`,
                restricted_package_name: "io.github.atrx07.traelyx",
                direct_boot_ok: false,
              },
            },
          }),
        },
        8000,
      );
      const accepted = response.status === 200 &&
        typeof response.value?.name === "string" &&
        response.value.name.startsWith(`projects/${project}/messages/`) &&
        response.value.name.length > `projects/${project}/messages/`.length &&
        response.value.name.length <= 512;
      const details = response.value?.error?.details;
      const codes = Array.isArray(details)
        ? details.filter((detail) =>
          detail?.["@type"] ===
            "type.googleapis.com/google.firebase.fcm.v1.FcmError"
        )
          .map((detail) => detail.errorCode)
        : [];
      // Authentication/configuration faults are retriable, never reported as receipt.
      const permanent = !accepted &&
        ((response.status === 404 && codes.includes("UNREGISTERED")) ||
          (response.status === 400 && codes.includes("INVALID_ARGUMENT")) ||
          (response.status === 403 && codes.includes("SENDER_ID_MISMATCH")));
      return {
        accepted,
        permanent,
        retryAfter: retryDelay(response.retryAfter, now()),
      };
    },
  };
}

function validTarget(target) {
  return exact(target, [
    "routing_token",
    "device_id",
    "device_generation",
    "ttl_seconds",
  ]) &&
    typeof target.routing_token === "string" &&
    target.routing_token.length >= 1 &&
    target.routing_token.length <= 4096 && !/\s/.test(target.routing_token) &&
    isUuid(target.device_id) && isUuid(target.device_generation) &&
    Number.isInteger(target.ttl_seconds) && target.ttl_seconds >= 1 &&
    target.ttl_seconds <= 600;
}

export async function dispatchBatch(rpc, provider) {
  // Validate OAuth configuration before reserving scarce delivery attempts.
  const accessToken = await provider.authorize();
  const claims = await rpc("claim_guardian_dispatch_batch_v1", {
    batch_size: 6,
  });
  if (
    !Array.isArray(claims) || claims.length > 6 ||
    claims.some((claim) =>
      !exact(claim, ["delivery_id", "claim_id"]) ||
      !isUuid(claim.delivery_id) || !isUuid(claim.claim_id)
    ) ||
    new Set(claims.map((claim) => claim.delivery_id)).size !== claims.length
  ) throw failure();
  const counts = {
    processed: 0,
    provider_accepted: 0,
    skipped: 0,
    failed: 0,
    deferred: 0,
  };
  // Two waves of three; each HTTP call is bounded. A lost response leaves a
  // durable reservation, reclaimable by SQL after 120s, never a local spin loop.
  for (let offset = 0; offset < claims.length; offset += 3) {
    await Promise.all(
      claims.slice(offset, offset + 3).map(
        async ({ delivery_id, claim_id }) => {
          try {
            const target = await rpc("guardian_dispatch_target_v1", {
              delivery: delivery_id,
              claim: claim_id,
            });
            if (target !== null && !validTarget(target)) throw failure();
            let result = { accepted: false, permanent: false, retryAfter: 60 };
            if (target) {
              // No asynchronous work between the authorization recheck and provider IO.
              try {
                result = await provider.send(target, delivery_id, accessToken);
              } catch { /* retry via SQL */ }
            }
            await rpc("finish_guardian_dispatch_v2", {
              delivery: delivery_id,
              claim: claim_id,
              accepted: result.accepted,
              permanent_failure: result.permanent,
              retry_after_seconds: result.retryAfter,
            });
            counts.processed++;
            if (!target) counts.skipped++;
            else if (result.accepted) counts.provider_accepted++;
            else if (result.permanent) counts.failed++;
            else counts.deferred++;
          } catch {
            // Permission/network/completion failures expose no routing or event data.
            counts.deferred++;
          }
        },
      ),
    );
  }
  return counts;
}

async function authorized(actual, expected) {
  if (!SECRET.test(expected ?? "") || !SECRET.test(actual ?? "")) return false;
  const hashes = await Promise.all(
    [actual, expected].map((value) =>
      crypto.subtle.digest("SHA-256", encoder.encode(value))
    ),
  );
  const first = new Uint8Array(hashes[0]);
  const second = new Uint8Array(hashes[1]);
  let different = 0;
  for (let i = 0; i < first.length; i++) different |= first[i] ^ second[i];
  return different === 0;
}

export function createHandler({ enabled, secret, run }) {
  const reply = (status, value) =>
    Response.json(value, {
      status,
      headers: {
        "Cache-Control": "no-store",
        "X-Content-Type-Options": "nosniff",
      },
    });
  return async (request) => {
    if (request.method !== "POST") {
      return reply(405, { error: "method_not_allowed" });
    }
    if (
      !await authorized(request.headers.get("x-guardian-worker-secret"), secret)
    ) {
      return reply(401, { error: "unauthorized" });
    }
    if (!enabled) return reply(503, { error: "dispatch_disabled" });
    try {
      const body = await deadline(
        (signal) => readBoundedJson(request.body, 32, signal),
        1000,
      );
      if (!exact(body, [])) return reply(400, { error: "invalid_request" });
    } catch {
      return reply(400, { error: "invalid_request" });
    }
    try {
      return reply(200, await run());
    } catch {
      return reply(503, { error: "dispatch_unavailable" });
    }
  };
}
