import { test } from "node:test";
import assert from "node:assert/strict";
import { accountUi, defaultNetwork, runOfflineSignOut, adbAdapter } from "../../tool/guardian_recipient_offline_check.mjs";

const pkg = "io.github.atrx07.traelyx";
const node = (text, extra = "") => `<node package="${pkg}" text="${text}" enabled="true" ${extra}/>`;
const button = node("Sign out on this device", 'bounds="[10,20][110,60]"');
const signedIn = node("Signed in") + button;
const cancelled = node("Could not finish Guardian cleanup, so sign-out was cancelled. Try again.");

test("offline evidence rejects unknown output instead of assuming disconnected", () => {
  assert.equal(defaultNetwork("Active default network: none\n"), false);
  assert.equal(defaultNetwork("  Active default network: 102\r\n"), true);
  for (const raw of ["", "default: none", "Active default network: unknown",
    "Active default network: none\nActive default network: 102"]) assert.throws(() => defaultNetwork(raw));
});

test("UI permits only one enabled app-owned Sign out target with valid bounds", () => {
  assert.deepEqual(accountUi(signedIn).point, [60, 40]);
  assert.equal(accountUi(signedIn + button).point, null);
  assert.equal(accountUi(signedIn.replaceAll(pkg, "another.app")).signedIn, false);
  assert.equal(accountUi(signedIn.replace('bounds="[10,20][110,60]"', 'bounds="[10,20][9,60]"')).point, null);
  assert.equal(accountUi(signedIn.replaceAll('enabled="true"', 'enabled="false"')).point, null);
  assert.equal(accountUi(signedIn + cancelled).cancelled, true);
  assert.equal(accountUi(node("Sign in or create an account")).signedOut, true);
});

function fake(overrides = {}) {
  const trace = [];
  let time = 0, offline = false, tapped = false;
  const before = { wifi: true, data: false, receipt: "private", provider: "private" };
  const io = {
    now: () => time,
    sleep: async ms => { time += ms; },
    preflight: async () => before,
    mark: async phase => { trace.push(phase); },
    disable: async () => { trace.push("disable"); offline = true; },
    offline: async () => offline,
    ui: async () => ({ signedIn: true, signedOut: false, cancelled: tapped, point: [60, 40] }),
    tapSignOut: async () => { trace.push("tap"); tapped = true; },
    retained: async () => true,
    restore: async original => {
      assert.equal(original, before);
      trace.push("restore"); offline = false;
    },
    ...overrides,
  };
  return { io, trace, before };
}

test("one cancelled offline sign-out retains Auth/receipt and restores exact baseline", async () => {
  const { io, trace } = fake();
  assert.deepEqual(await runOfflineSignOut(io), { passed: true, signout_attempted: true, network_restored: true });
  assert.equal(trace.filter(x => x === "tap").length, 1);
  assert.ok(trace.indexOf("tap") < trace.indexOf("restore"));
  assert.equal(trace.at(-1), "offline_failure_verified_network_restored");
});

test("failed preflight changes nothing", async () => {
  const { io, trace } = fake({ preflight: async () => { throw Error("private detail"); } });
  await assert.rejects(runOfflineSignOut(io));
  assert.deepEqual(trace, []);
});

test("partial disable failure still restores, with no tap", async () => {
  const { io, trace } = fake({ disable: async () => { throw Error("private detail"); } });
  assert.equal((await runOfflineSignOut(io)).passed, false);
  assert.ok(trace.includes("restore"));
  assert.ok(!trace.includes("tap"));
});

test("a network that never disconnects denies tapping and restores within bounded polls", async () => {
  let polls = 0;
  const { io, trace } = fake({ offline: async () => { polls++; return false; } });
  const result = await runOfflineSignOut(io);
  assert.equal(result.signout_attempted, false);
  assert.ok(polls <= 30);
  assert.ok(trace.includes("restore"));
  for (const allowed of [1, 2]) {
    let checks = 0;
    const next = fake({ offline: async () => ++checks <= allowed });
    const result = await runOfflineSignOut(next.io);
    assert.equal(result.passed, false); // Reconnected before or after the tap.
    assert.equal(next.trace.filter(x => x === "tap").length, allowed - 1);
    assert.ok(next.trace.includes("restore"));
  }
});

test("changed account UI before the action denies tap and restores", async () => {
  const { io, trace } = fake({ ui: async () => ({ signedIn: false, signedOut: true, point: null }) });
  assert.equal((await runOfflineSignOut(io)).passed, false);
  assert.ok(!trace.includes("tap"));
  assert.ok(trace.includes("restore"));
});

test("unexpected real sign-out and a stuck busy screen are uncertainty, never retries", async () => {
  for (const state of [{ signedIn: false, signedOut: true }, { signedIn: true, signedOut: false }]) {
    let reads = 0;
    const { io, trace } = fake({ ui: async () => (++reads === 1
      ? { signedIn: true, point: [60, 40] }
      : { ...state, cancelled: false, point: null }) });
    assert.equal((await runOfflineSignOut(io)).passed, false);
    assert.equal(trace.filter(x => x === "tap").length, 1);
    assert.ok(trace.includes("restore"));
    assert.ok(reads <= 71);
  }
});

test("lost receipt or Auth after network restoration cannot pass", async () => {
  let reads = 0;
  const { io } = fake({ retained: async () => ++reads === 1 });
  assert.equal((await runOfflineSignOut(io)).passed, false);
});

test("restoration failure rejects success and does not retry sign-out", async () => {
  const { io, trace } = fake({ restore: async () => { trace.push("restore"); throw Error("restore failed"); } });
  await assert.rejects(runOfflineSignOut(io));
  assert.equal(trace.filter(x => x === "tap").length, 1);
});

function adbFake({ physical = false, failWifiRestore = false, expireDisable = false } = {}) {
  const trace = [];
  let clock = 0;
  const run = async (_path, args, options) => {
    assert.deepEqual(args.slice(0, 2), ["-s", "emulator-5554"]);
    assert.ok(options.timeout > 0 && options.timeout <= 5000);
    assert.equal(options.windowsHide, true);
    const command = args.slice(2).join(" ");
    trace.push(command);
    let stdout;
    if (command === "shell getprop ro.kernel.qemu") stdout = physical ? "0" : "1";
    else if (command.endsWith("get global airplane_mode_on")) stdout = "0";
    else if (command.endsWith("get global wifi_on")) stdout = "1";
    else if (command.endsWith("get global mobile_data")) stdout = "0";
    else if (command === "shell dumpsys connectivity") stdout = "Active default network: 102\nVALIDATED\n";
    else if (command.includes("dumpsys activity services")) stdout = "No services";
    else if (command.includes("sha256sum no_backup/guardian/primary.vault")) stdout = "absent";
    else if (command.includes("sha256sum")) stdout = "a".repeat(64) + "  private-path";
    else if (command.startsWith("shell cat ")) stdout = signedIn;
    else if (command === "shell svc wifi enable" && failWifiRestore) throw Error("private network detail");
    else if (command === "shell svc wifi disable" && expireDisable) clock += 60_001;
    else if (!command.startsWith("shell uiautomator dump ") && !command.startsWith("shell rm -f ") &&
        !command.startsWith("shell svc ")) throw Error("unexpected command");
    return { stdout: stdout ?? "" };
  };
  return { io: adbAdapter("reviewed-adb", { run, clock: () => clock }), trace };
}

test("inspect performs no network or account mutation and denies physical devices", async () => {
  const { io, trace } = adbFake();
  const before = await io.preflight();
  assert.equal(before.wifi, true);
  assert.equal(before.data, false);
  assert.ok(!trace.some(x => x.startsWith("shell svc ") || x.startsWith("shell input ")));
  await assert.rejects(adbFake({ physical: true }).io.preflight());
});

test("adapter restores an originally disabled mobile switch, even after wifi restore fails", async () => {
  const { io, trace } = adbFake({ failWifiRestore: true });
  await assert.rejects(io.restore({ wifi: true, data: false }));
  assert.deepEqual(trace, ["shell svc wifi enable", "shell svc data disable"]);
});

test("60-second command budget stops further disabling; restoration has its own budget", async () => {
  const { io, trace } = adbFake({ expireDisable: true });
  await assert.rejects(io.disable());
  assert.deepEqual(trace, ["shell svc wifi disable"]);
  await io.restore({ wifi: true, data: false });
  assert.ok(trace.includes("shell svc data disable"));
});
