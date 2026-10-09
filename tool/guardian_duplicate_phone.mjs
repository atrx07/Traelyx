// Reviewed operator tool only; never used by the app or scheduled.
// No sends, cloud mutations, force-stop, claim deletion or network changes.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const PACKAGE = "io.github.atrx07.traelyx";
const ID = /^00000000-0000-4000-9000-000000000[0-9]{3}$/;
const TIMESTAMP = /^\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.000$/;
const HASH = /^[a-f0-9]{64}$/;
const fail = () => new Error("Phone phase failed; close the reviewed window; never automatically resend");
const runFile = promisify(execFile);

export function noticeCount(dump, delivery) {
  if (!ID.test(delivery)) throw fail();
  const section = dump.match(/(?:^|\n)  Notification List:[ \t]*\n([\s\S]*?)(?=\n  \S|$)/);
  if (!section) throw fail(); // Missing section is not evidence of zero notices.
  return (section[1].match(/^\s*NotificationRecord[^\r\n]*/gm) ?? [])
    .filter((line) => line.includes(`pkg=${PACKAGE}`) && line.includes(delivery)).length;
}

export function noticePoint(xml) {
  const nodes = (xml.match(/<node\b[^>]*>/g) ?? [])
    .filter((node) => /\btext="Traelyx Guardian notice"/.test(node));
  if (nodes.length !== 1) throw fail();
  const bounds = nodes[0].match(/\bbounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/);
  if (!bounds) throw fail();
  const [x, y, right, bottom] = bounds.slice(1).map(Number);
  if (right <= x || bottom <= y || right > 4000 || bottom > 6000) throw fail();
  return [Math.floor((x + right) / 2), Math.floor((y + bottom) / 2)];
}

export function guardianUnloaded(xml) {
  const ownNodes = (xml.match(/<node\b[^>]*>/g) ?? [])
    .filter((node) => node.includes(`package="${PACKAGE}"`)).join("\n");
  return ownNodes.includes("Recent Guardian alerts") && ownNodes.includes("Reload alerts") &&
    !/Open alert|Synthetic push test driver|No currently accessible alerts/.test(ownNodes);
}

export function tracePassed(log, duplicate) {
  const codes = [...log.matchAll(/^I\/TraelyxGuardianReceive\s*\([0-9 ]+\):\s*([A-Z_]+)\s*$/gm)]
    .map((match) => match[1]);
  const expected = duplicate
    ? ["CALLBACK", "RECEIPT_CONFIRMED", "CLAIM_UNAVAILABLE"]
    : ["CALLBACK", "RECEIPT_CONFIRMED", "NOTICE_CLAIMED", "NOTICE_POST_ATTEMPTED"];
  return codes.join(",") === expected.join(",");
}

// Android sometimes returns a null root while the tap launches MainActivity.
// Retry observation only, immediately and at most three times; never repeat input.
export async function settleGuardian(readUi) {
  for (let attempt = 0; attempt < 3; attempt++) {
    if (guardianUnloaded(await readUi())) return true;
  }
  throw fail();
}

export function currentPackageState(dump, user) {
  if (!/^\d+$/.test(user)) throw fail();
  let selected = false;
  const lines = [];
  for (const line of dump.split(/\r?\n/)) {
    const section = line.match(/^\s*User (\d+):/);
    if (section) selected = section[1] === user;
    if (selected) lines.push(line);
  }
  const state = lines.join("\n");
  if (!/installed=true[^\r\n]*stopped=false/.test(state)) throw fail();
  return state;
}

export async function runPhonePhase(mode, delivery, timestamp, adb, baseline) {
  if (!["preflight", "first", "duplicate"].includes(mode) ||
      (mode !== "preflight" && (!ID.test(delivery) || !TIMESTAMP.test(timestamp)))) throw fail();
  const shell = (...args) => adb("shell", ...args);
  const services = await shell("dumpsys", "activity", "services", PACKAGE);
  const packageState = await shell("dumpsys", "package", PACKAGE);
  const user = (await shell("am", "get-current-user")).trim();
  if (user !== "0") throw fail(); // This reviewed workflow targets the phone's primary profile only.
  const currentState = currentPackageState(packageState, user);
  if (services.includes("RecorderService") || !packageState.includes("DEBUGGABLE") ||
      !/android.permission.POST_NOTIFICATIONS: granted=true/.test(currentState)) throw fail();
  const vaultHash = async () => {
    const text = await shell("run-as", PACKAGE, "sha256sum", "no_backup/guardian/recipient-primary.vault");
    const hash = text.trim().split(/\s+/)[0];
    if (!HASH.test(hash)) throw fail();
    return hash;
  };
  await vaultHash();
  await shell("run-as", PACKAGE, "ls", "no_backup/guardian/recipient-provider-primary.v1");
  if (mode === "preflight") return { mode, verified: true, recorder_inactive: true };
  const log = await adb("logcat", "-d", "-v", "brief", "-T", timestamp,
    "-s", "TraelyxGuardianReceive:I", "*:S");
  if (!tracePassed(log, mode === "duplicate")) throw fail();
  const count = async () => noticeCount(await shell("dumpsys", "notification"), delivery);
  if (await count() !== (mode === "first" ? 1 : 0)) throw fail();
  if (mode === "duplicate") {
    if (await vaultHash() !== await baseline.read()) throw fail();
    return { mode, verified: true, claim_refused: true, notice_count: 0, vault_unchanged: true };
  }
  const policy = await shell("dumpsys", "window", "policy");
  if (/^\s*showing=true\s*$/m.test(policy)) throw fail(); // Unlock before starting the live window.
  const ui = async () => {
    await shell("uiautomator", "dump", "/data/local/tmp/traelyx-guardian-operator.xml");
    return shell("cat", "/data/local/tmp/traelyx-guardian-operator.xml");
  };
  await shell("cmd", "statusbar", "expand-notifications");
  const [x, y] = noticePoint(await ui());
  await shell("input", "tap", String(x), String(y));
  await settleGuardian(ui);
  if (await count() !== 0) throw fail();
  await baseline.write(await vaultHash()); // Only encrypted-file hash; never vault contents.
  await shell("am", "start", "-a", "android.settings.SETTINGS");
  await shell("input", "keyevent", "KEYCODE_HOME");
  await ui(); // Let the activity transition settle before background kill.
  await shell("am", "kill", "--user", "current", PACKAGE);
  if ((await shell("pidof", PACKAGE)).trim()) throw fail();
  if ((await shell("am", "get-current-user")).trim() !== user) throw fail();
  currentPackageState(await shell("dumpsys", "package", PACKAGE), user);
  return { mode, verified: true, guardian_unloaded: true, notice_count: 0, background_process_absent: true };
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  try {
    const [mode, adbPath, serial, delivery, timestamp] = process.argv.slice(2);
    if (!adbPath || !/^[A-Za-z0-9]+$/.test(serial ?? "") ||
        process.argv.length !== (mode === "preflight" ? 5 : 7)) throw fail();
    const deadline = Date.now() + 75_000;
    const adb = async (...args) => {
      const remaining = deadline - Date.now();
      if (remaining <= 0) throw fail();
      try {
        const result = await runFile(adbPath, ["-s", serial, ...args],
          { timeout: Math.min(15_000, remaining), maxBuffer: 8 * 1024 * 1024, windowsHide: true });
        return result.stdout;
      } catch (error) {
        if (args.join(" ") === `shell pidof ${PACKAGE}` && error.code === 1 &&
            typeof error.stdout === "string" && !error.stdout.trim()) return "";
        throw fail(); // Do not expose raw device output or subprocess exceptions.
      }
    };
    const hashPath = resolve(".dart_tool", `guardian-duplicate-${delivery ?? "preflight"}.sha256`);
    const baseline = {
      read: async () => (await readFile(hashPath, "utf8")).trim(),
      write: async (hash) => writeFile(hashPath, hash, { flag: "wx" }),
    };
    console.log(JSON.stringify(await runPhonePhase(mode, delivery, timestamp, adb, baseline)));
  } catch {
    console.error(fail().message);
    process.exitCode = 1;
  }
}
