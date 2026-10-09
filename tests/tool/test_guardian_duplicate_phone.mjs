import { test } from "node:test";
import assert from "node:assert/strict";
import { noticeCount, noticePoint, settleGuardian, currentPackageState, runPhonePhase } from "../../tool/guardian_duplicate_phone.mjs";

const id = "00000000-0000-4000-9000-000000000805";
const packageName = "io.github.atrx07.traelyx";
const guardian = `<node package="${packageName}" text="Recent Guardian alerts"/><node package="${packageName}" text="Reload alerts"/>`;
const hash = "a".repeat(64);
const packageState = "DEBUGGABLE\nUser 0: installed=true stopped=false\nandroid.permission.POST_NOTIFICATIONS: granted=true\nUser 10: installed=true stopped=true";
const notice = `  Notification List:\n    NotificationRecord pkg=${packageName} tag=${id}\n  Other section:\n`;
const emptyNotice = "  Notification List:\n\n  Other section:\n";
const shade = '<node text="Traelyx Guardian notice" bounds="[100,200][500,300]"/>';
const trace = (codes) => codes.map((code) => `I/TraelyxGuardianReceive(123): ${code}`).join("\n");

test("missing notification section cannot be treated as zero; historical and unrelated records do not count", () => {
  assert.throws(() => noticeCount("truncated output", id));
  assert.equal(noticeCount(`${emptyNotice}    NotificationRecord pkg=${packageName} tag=${id}`, id), 0);
  assert.equal(noticeCount(notice.replace(packageName, "unrelated.app"), id), 0);
  assert.equal(noticeCount(notice, id), 1);
  assert.equal(noticeCount(notice.replace("  Other section:", `    NotificationRecord pkg=${packageName} tag=${id}\n  Other section:`), id), 2);
});

test("ambiguous or malformed notice title prevents tapping", () => {
  assert.deepEqual(noticePoint(shade), [300, 250]);
  assert.throws(() => noticePoint(shade + shade));
  assert.throws(() => noticePoint(shade.replace("[500,300]", "[50,100]")));
});

test("transient null root is observed again without repeating a tap; persistent failure is bounded", async () => {
  const states = ["<hierarchy/>", guardian];
  assert.equal(await settleGuardian(async () => states.shift()), true);
  let reads = 0;
  await assert.rejects(settleGuardian(async () => { reads++; return "<hierarchy/>"; }));
  assert.equal(reads, 3);
});

test("unrelated Android profiles do not invalidate the current authorized user's package", () => {
  assert.ok(currentPackageState(packageState, "0").includes("granted=true"));
  assert.throws(() => currentPackageState(packageState, "10"));
  assert.throws(() => currentPackageState(packageState, "999"));
});

function phone(duplicate = false, override = {}) {
  const calls = [];
  let tapped = false;
  let postTapReads = 0;
  const adb = async (...args) => {
    const command = args.join(" ");
    calls.push(command);
    if (Object.hasOwn(override, command)) return override[command];
    if (command.includes("dumpsys activity services")) return "(nothing)";
    if (command.includes("dumpsys package")) return packageState;
    if (command === "shell am get-current-user") return "0\n";
    if (command.includes("sha256sum")) return `${hash} vault`;
    if (args[0] === "logcat") return trace(duplicate
      ? ["CALLBACK", "RECEIPT_CONFIRMED", "CLAIM_UNAVAILABLE"]
      : ["CALLBACK", "RECEIPT_CONFIRMED", "NOTICE_CLAIMED", "NOTICE_POST_ATTEMPTED"]);
    if (command.includes("dumpsys notification")) return duplicate || tapped ? emptyNotice : notice;
    if (command.includes("dumpsys window policy")) return "  showing=false";
    if (command.includes("input tap")) tapped = true;
    if (command.includes("shell cat")) return !tapped ? shade : (++postTapReads === 1 ? "<hierarchy/>" : guardian);
    return "";
  };
  return { adb, calls };
}

test("first phase batches one tap, settled Guardian and background kill, preserving hash without force-stop", async () => {
  const { adb, calls } = phone();
  let saved;
  const result = await runPhonePhase("first", id, "10-09 12:00:00.000", adb, { write: async (value) => { saved = value; } });
  assert.equal(result.background_process_absent, true);
  assert.equal(saved, hash);
  assert.equal(calls.filter((command) => command.includes("input tap")).length, 1);
  assert.ok(calls.some((command) => command.includes("am kill --user current")));
  assert.ok(!calls.some((command) => /force-stop|settings put|logcat -c/.test(command)));
});

test("duplicate requires claim refusal, absent notice and preserved vault, without UI input", async () => {
  const { adb, calls } = phone(true);
  const result = await runPhonePhase("duplicate", id, "10-09 12:00:00.000", adb, { read: async () => hash });
  assert.equal(result.vault_unchanged, true);
  assert.ok(!calls.some((command) => /input |am kill|statusbar/.test(command)));
  await assert.rejects(runPhonePhase("duplicate", id, "10-09 12:00:00.000", adb, { read: async () => "b".repeat(64) }));
});

test("recorder active or stopped package aborts before any UI action", async () => {
  for (const override of [
    { [`shell dumpsys activity services ${packageName}`]: "RecorderService" },
    { [`shell dumpsys package ${packageName}`]: packageState.replace("stopped=false", "stopped=true") },
  ]) {
    const { adb, calls } = phone(false, override);
    await assert.rejects(runPhonePhase("first", id, "10-09 12:00:00.000", adb, {}));
    assert.ok(!calls.some((command) => /input |statusbar/.test(command)));
  }
});
