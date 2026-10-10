// The only public authority is a short-lived, scoped native capability. The
// service-role credential never enters a response, URL, client, or log.
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CAPABILITY = /^[a-f0-9]{64}$/;
const decoder = new TextDecoder("utf-8", { fatal: true });
const exact = (value, keys) =>
  value !== null && typeof value === "object" && !Array.isArray(value) &&
  Object.keys(value).sort().join(",") === [...keys].sort().join(",");
const uuid = (value) => typeof value === "string" && UUID.test(value);
const unavailable = () => new Error("Guardian capability unavailable");
const reply = (status, value) =>
  Response.json(value, {
    status,
    headers: {
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });

async function boundedJson(body, maxBytes, timeoutMs) {
  if (!body) throw unavailable();
  const reader = body.getReader();
  const chunks = [];
  let size = 0;
  let timedOut = false;
  const timeout = setTimeout(() => {
    timedOut = true;
    reader.cancel().catch(() => {});
  }, timeoutMs);
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (timedOut) throw unavailable();
      if (done) break;
      size += value.byteLength;
      if (size > maxBytes) throw unavailable();
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    return JSON.parse(decoder.decode(bytes));
  } finally {
    clearTimeout(timeout);
    reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}

function validEnvelope(envelope) {
  return exact(envelope, [
    "event_id",
    "kind",
    "occurred_at_epoch_ms",
    "rule_version",
    "schema_version",
    "uncertainty",
  ]) && uuid(envelope.event_id) &&
    ["severe_drive", "possible_crash"].includes(envelope.kind) &&
    envelope.rule_version === 1 && envelope.schema_version === 1 &&
    envelope.uncertainty === "experimental_not_confirmed" &&
    Number.isSafeInteger(envelope.occurred_at_epoch_ms) &&
    envelope.occurred_at_epoch_ms > 0;
}

function parseRequest(body) {
  if (
    exact(body, ["type", "owner_id", "credential", "envelope"]) &&
    body.type === "ingest" && uuid(body.owner_id) &&
    CAPABILITY.test(body.credential) && validEnvelope(body.envelope)
  ) {
    return ["ingest_guardian_alert_v1", {
      owner_id: body.owner_id,
      credential: body.credential,
      envelope: body.envelope,
    }];
  }
  if (
    exact(body, ["type", "device", "credential", "delivery"]) &&
    body.type === "receipt" && uuid(body.device) &&
    CAPABILITY.test(body.credential) && uuid(body.delivery)
  ) {
    return ["receive_guardian_alert_v1", {
      device: body.device,
      credential: body.credential,
      delivery: body.delivery,
    }];
  }
  return null;
}

export function createTransport(fetcher = fetch) {
  return async (url, options) => {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);
    try {
      const response = await fetcher(url, {
        ...options,
        signal: controller.signal,
        redirect: "error",
      });
      const value = await boundedJson(response.body, 4096, 1000);
      return { status: response.status, value };
    } finally {
      clearTimeout(timeout);
    }
  };
}

export function createRpc(url, key, transport) {
  if (
    !/^https:\/\/[a-z0-9]{20}\.supabase\.co$/.test(url ?? "") ||
    typeof key !== "string" || key.length < 32 || key.length > 4096
  ) {
    throw unavailable();
  }
  const allowed = new Set([
    "ingest_guardian_alert_v1",
    "receive_guardian_alert_v1",
  ]);
  return async (name, parameters) => {
    if (!allowed.has(name)) throw unavailable();
    const response = await transport(`${url}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(parameters),
    });
    if (response.status >= 200 && response.status < 300) {
      return response.value;
    }
    const code = response.value?.code;
    if (code === "42501") return { error: "unauthorized", status: 401 };
    if (code === "22023") return { error: "invalid_request", status: 400 };
    if (code === "40001") return { error: "identity_conflict", status: 409 };
    if (code === "P0002") return { error: "rate_limited", status: 429 };
    throw unavailable();
  };
}

export function createHandler({ enabled, rpc }) {
  return async (request) => {
    if (request.method !== "POST") {
      return reply(405, { error: "method_not_allowed" });
    }
    if ((typeof enabled === "function" ? enabled() : enabled) !== true) {
      return reply(503, { error: "capability_disabled" });
    }
    if (
      !/^application\/json(?:;\s*charset=utf-8)?$/i.test(
        request.headers.get("content-type") ?? "",
      )
    ) return reply(415, { error: "unsupported_media_type" });
    let invocation;
    try {
      invocation = parseRequest(await boundedJson(request.body, 1536, 1000));
    } catch {
      return reply(400, { error: "invalid_request" });
    }
    if (!invocation) return reply(400, { error: "invalid_request" });
    try {
      const [name, args] = invocation;
      const result = await rpc()(name, args);
      if (result?.error && typeof result.status === "number") {
        return reply(result.status, { error: result.error });
      }
      if (name === "receive_guardian_alert_v1" && typeof result === "boolean") {
        return reply(200, { received: result });
      }
      if (
        name === "ingest_guardian_alert_v1" && exact(result, [
          "event_id",
          "state",
          "duplicate",
          "recipient_devices",
        ]) && uuid(result.event_id) && result.state === "backend_accepted" &&
        typeof result.duplicate === "boolean" &&
        Number.isInteger(result.recipient_devices) &&
        result.recipient_devices >= 0 && result.recipient_devices <= 30
      ) {
        return reply(200, result);
      }
      // Duplicate ingestion omits recipient_devices in the deployed RPC.
      if (
        name === "ingest_guardian_alert_v1" && exact(result, [
          "event_id",
          "state",
          "duplicate",
        ]) && uuid(result.event_id) && result.state === "backend_accepted" &&
        result.duplicate === true
      ) return reply(200, result);
    } catch { /* Do not disclose provider, SQL, or credential details. */ }
    return reply(503, { error: "capability_unavailable" });
  };
}
