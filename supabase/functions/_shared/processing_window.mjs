const MAX_WINDOW_MS = 6 * 60 * 1000;

// Reviewed M6.8 test windows only. A true flag alone never enables production.
export function createProcessingWindowGate(flag, rawWindow, clock = Date.now) {
  let window;
  try {
    if (
      flag !== "true" || typeof rawWindow !== "string" || rawWindow.length > 256
    ) {
      throw new Error();
    }
    window = JSON.parse(rawWindow);
    if (
      !window || Array.isArray(window) ||
      rawWindow !== JSON.stringify(window) ||
      Object.keys(window).sort().join(",") !==
        "expires_at_epoch_ms,schema_version,starts_at_epoch_ms" ||
      window.schema_version !== 1 ||
      !Number.isSafeInteger(window.starts_at_epoch_ms) ||
      !Number.isSafeInteger(window.expires_at_epoch_ms) ||
      window.starts_at_epoch_ms <= 0 ||
      window.expires_at_epoch_ms <= window.starts_at_epoch_ms ||
      window.expires_at_epoch_ms - window.starts_at_epoch_ms > MAX_WINDOW_MS
    ) throw new Error();
  } catch {
    return () => false;
  }
  let closed = false;
  let previous = null;
  return () => {
    if (closed) return false;
    try {
      const current = clock();
      if (
        !Number.isSafeInteger(current) || current < 0 ||
        (previous !== null && current < previous) ||
        current >= window.expires_at_epoch_ms
      ) {
        closed = true;
        return false;
      }
      previous = current;
      return current >= window.starts_at_epoch_ms;
    } catch {
      closed = true;
      return false;
    }
  };
}

// Recheck before SQL, OAuth and FCM calls, including requests admitted earlier.
export function createWindowFetch(gate, fetcher = fetch) {
  return (...args) => {
    if (!gate()) throw new Error("Guardian processing window closed");
    return fetcher(...args);
  };
}
