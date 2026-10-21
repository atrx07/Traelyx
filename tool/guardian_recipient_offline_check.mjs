// Explicitly reviewed operator only. Never imported by the app or scheduled.
// inspect is read-only; run changes only Pixel's network and taps Sign out once.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { setTimeout as sleep } from "node:timers/promises";

const PACKAGE = "io.github.atrx07.traelyx";
const SERIAL = "emulator-5554";
const CANCELLED = "Could not finish Guardian cleanup, so sign-out was cancelled. Try again.";
const fail = () => new Error("Offline receiver check failed or uncertain; inspect before retrying");

export function defaultNetwork(raw) {
  const values = [...raw.matchAll(/^\s*Active default network:\s*(\S+)/gm)];
  if (values.length !== 1) throw fail();
  const value = values[0][1];
  if (value === "none") return false;
  if (/^\d+$/.test(value ?? "")) return true;
  throw fail(); // Unknown/truncated output is never evidence of being offline.
}

export function accountUi(xml) {
  const nodes = (xml.match(/<node\b[^>]*>/g) ?? []).map(node =>
    Object.fromEntries([...node.matchAll(/(text|content-desc|bounds|package|enabled)="([^"]*)"/g)]
      .map(match => [match[1], match[2].replace(/&#10;|&#xA;/ig, "\n").replaceAll("&amp;", "&")]))
  ).filter(node => node.package === PACKAGE);
  const has = label => nodes.some(node => [node.text, node["content-desc"]]
    .some(text => text === label || text?.startsWith(label + "\n")));
  const buttons = nodes.filter(node => node.enabled === "true" &&
    [node.text, node["content-desc"]].includes("Sign out on this device"));
  let point = null;
  if (buttons.length === 1) {
    const bounds = /^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/.exec(buttons[0].bounds ?? "");
    if (bounds) {
      const [x, y, right, bottom] = bounds.slice(1).map(Number);
      if (right > x && bottom > y && right <= 4000 && bottom <= 6000) {
        point = [(x + right) / 2, (y + bottom) / 2];
      }
    }
  }
  return {
    signedIn: has("Signed in"), cancelled: has(CANCELLED), point,
    signedOut: has("Sign in or create an account") ||
      has("Signed out on this device. Local trips are still here."),
  };
}

async function until(io, limit, check) {
  const deadline = io.now() + limit;
  while (io.now() < deadline) {
    if (await check()) return;
    await io.sleep(500);
  }
  throw fail();
}

export async function runOfflineSignOut(io) {
  const before = await io.preflight(); // No network/action on failed preflight.
  let touched = false;
  let attempted = false;
  let passed = false;
  try {
    await io.mark("network_change_starting", before);
    touched = true; // A partially failed disable must still restore both switches.
    await io.disable();
    await until(io, 15_000, () => io.offline());
    const ready = await io.ui();
    if (!ready.signedIn || ready.signedOut || !ready.point || !await io.offline()) throw fail();
    attempted = true;
    await io.mark("single_signout_starting", before);
    await io.tapSignOut(); // Adapter independently rechecks UI + network before input.
    await until(io, 35_000, async () => {
      if (!await io.offline()) throw fail();
      const state = await io.ui();
      if (state.signedOut) throw fail();
      return state.signedIn && state.cancelled && state.point !== null;
    });
    if (!await io.retained(before)) throw fail();
    passed = true;
  } catch {
    // No retry, raw command exception, UI text, receipt or account output.
  } finally {
    if (touched) await io.restore(before); // Restoration failure cannot be success.
  }
  if (!await io.retained(before)) passed = false;
  await io.mark(passed ? "offline_failure_verified_network_restored" : "uncertain_network_restored", before);
  return { passed, signout_attempted: attempted, network_restored: true };
}

export function adbAdapter(adbPath, {
  run = promisify(execFile), clock = () => performance.now(),
} = {}) {
  let commandDeadline = Infinity;
  const adb = async (...args) => {
    try {
      const remaining = commandDeadline - clock();
      if (remaining < 1) throw fail();
      return (await run(adbPath, ["-s", SERIAL, ...args],
        { timeout: Math.floor(Math.min(5000, remaining)), maxBuffer: 4 * 1024 * 1024, windowsHide: true })).stdout;
    } catch { throw fail(); }
  };
  const setting = async name => {
    const value = (await adb("shell", "settings", "get", "global", name)).trim();
    if (!/^[01]$/.test(value)) throw fail();
    return value === "1";
  };
  const switches = async () => ({ wifi: await setting("wifi_on"), data: await setting("mobile_data") });
  const network = () => adb("shell", "dumpsys", "connectivity");
  const stamp = async path => {
    const raw = (await adb("shell", "run-as", PACKAGE, "sh", "-c",
      `"if test -e ${path}; then sha256sum ${path}; else echo absent; fi"`)).trim();
    if (raw === "absent") return null;
    if (!/^[a-f0-9]{64}\s+/.test(raw)) throw fail();
    return raw.slice(0, 64); // In memory only; never logged or checkpointed.
  };
  const receipts = async () => ({
    receipt: await stamp("no_backup/guardian/recipient-primary.vault"),
    provider: await stamp("no_backup/guardian/recipient-provider-primary.v1"),
  });
  const idle = async () => {
    if ((await adb("shell", "dumpsys", "activity", "services", PACKAGE)).includes("RecorderService") ||
        await stamp("no_backup/guardian/primary.vault") !== null) throw fail();
  };
  const ui = async () => {
    const path = "/data/local/tmp/traelyx-recipient-offline.xml";
    try {
      await adb("shell", "uiautomator", "dump", path);
      return accountUi(await adb("shell", "cat", path));
    } finally { await adb("shell", "rm", "-f", path); }
  };
  const offline = async () => {
    const state = await switches();
    return !state.wifi && !state.data && !defaultNetwork(await network());
  };
  const io = {
    now: clock, sleep, ui, offline,
    async preflight() {
      if ((await adb("shell", "getprop", "ro.kernel.qemu")).trim() !== "1" ||
          await setting("airplane_mode_on")) throw fail();
      await idle();
      const original = await switches();
      const connection = await network();
      const state = await ui();
      const local = await receipts();
      if ((!original.wifi && !original.data) || !defaultNetwork(connection) ||
          !connection.includes("VALIDATED") || !state.signedIn || state.signedOut ||
          state.cancelled || !state.point || !local.receipt || !local.provider) throw fail();
      return { ...original, ...local };
    },
    async disable() {
      commandDeadline = clock() + 60_000;
      await adb("shell", "svc", "wifi", "disable");
      await adb("shell", "svc", "data", "disable");
    },
    async tapSignOut() {
      await idle();
      const state = await ui();
      if (!state.signedIn || state.signedOut || !state.point || !await offline()) throw fail();
      await adb("shell", "input", "tap", ...state.point.map(String));
    },
    async retained(before) {
      await idle();
      const local = await receipts();
      const state = await ui();
      return state.signedIn && !state.signedOut &&
        local.receipt === before.receipt && local.provider === before.provider;
    },
    async restore(before) {
      commandDeadline = clock() + 35_000;
      let failed = false;
      // Attempt both even when the first command fails. Never turn on a switch
      // that was off in the original stable baseline.
      for (const [service, enabled] of [["wifi", before.wifi], ["data", before.data]]) {
        try { await adb("shell", "svc", service, enabled ? "enable" : "disable"); }
        catch { failed = true; }
      }
      if (failed) throw fail();
      await until(io, 25_000, async () => {
        const state = await switches();
        const connection = await network();
        return state.wifi === before.wifi && state.data === before.data &&
          defaultNetwork(connection) && connection.includes("VALIDATED");
      });
    },
    async mark(phase, before) {
      await writeFile(new URL("../.dart_tool/m6_8_recipient_offline_operator.json", import.meta.url),
        JSON.stringify({ phase, wifi: before.wifi, data: before.data }));
    },
  };
  return io;
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  try {
    const [mode, adbPath, reviewed] = process.argv.slice(2);
    if (!adbPath || !["inspect", "run"].includes(mode) ||
        (mode === "inspect" ? process.argv.length !== 4 : process.argv.length !== 5 || reviewed !== "--reviewed")) throw fail();
    const io = adbAdapter(adbPath);
    if (mode === "inspect") {
      const before = await io.preflight();
      console.log(JSON.stringify({ ready: true, wifi: before.wifi, data: before.data, mutation: false }));
    } else {
      const result = await runOfflineSignOut(io);
      console.log(JSON.stringify(result));
      if (!result.passed) process.exitCode = 1;
    }
  } catch {
    console.error("Offline receiver check failed or uncertain; verify Pixel network and account before proceeding");
    process.exitCode = 1;
  }
}
