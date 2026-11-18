"""Explicitly authorized local setup with an encrypted physical-phone backup."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import uuid

from tool import release_signing_setup as custody

REMOTE_DIRECTORY = "/sdcard/Documents/TraelyxSigningBackup"
STATUS = custody.ROOT / ".dart_tool/release-signing/phone-setup-status-v1.json"


class Phone:
    def __init__(self, adb: str, serial: str):
        if not Path(adb).is_file() or not re.fullmatch(r"[A-Za-z0-9_-]+", serial) or serial.startswith("emulator-"):
            raise custody.CustodyError("An authorized physical USB phone is required.")
        self.adb, self.serial = adb, serial

    def run(self, arguments: list[str], *, missing_allowed: bool = False) -> subprocess.CompletedProcess:
        try:
            result = subprocess.run([self.adb, "-s", self.serial, *arguments], capture_output=True,
                                    text=True, timeout=45, check=False,
                                    env={k: v for k, v in os.environ.items() if k not in {custody.PASS_ENV, "TRAELYX_SIGNING_RECOVERY_ATTESTED"}})
        except (OSError, subprocess.TimeoutExpired):
            raise custody.CustodyError("Phone operation could not complete. Existing keys are retained.") from None
        if result.returncode and not (missing_allowed and result.returncode == 1):
            raise custody.CustodyError("Phone operation failed. Reconnect/authorize the same phone; do not create a replacement key.")
        return result

    def ready(self) -> None:
        if self.run(["get-state"]).stdout.strip() != "device":
            raise custody.CustodyError("Unlock and authorize the physical phone before key creation.")
        if (self.run(["shell", "getprop", "ro.kernel.qemu"]).stdout.strip() == "1" or
                self.run(["shell", "getprop", "sys.boot_completed"]).stdout.strip() != "1"):
            raise custody.CustodyError("A booted physical phone is required; an emulator is not independent storage.")
        self.run(["shell", "mkdir", "-p", REMOTE_DIRECTORY])
        self.run(["shell", "test", "-w", REMOTE_DIRECTORY])

    def exists(self, path: str) -> bool:
        return self.run(["shell", "test", "-e", path], missing_allowed=True).returncode == 0

    def transfer(self, source: Path, remote: str, readback: Path) -> None:
        if not re.fullmatch(re.escape(REMOTE_DIRECTORY) + r"/traelyx-release-[a-f0-9]{64}\.p12", remote):
            raise custody.CustodyError("Unexpected phone backup destination.")
        self.run(["shell", "mkdir", "-p", REMOTE_DIRECTORY])
        if not self.exists(remote):
            temporary = f"{REMOTE_DIRECTORY}/.pending-{uuid.uuid4().hex}.p12"
            try:
                self.run(["push", str(source), temporary])
                self.run(["shell", "mv", "-n", temporary, remote])
            finally:
                # Only this invocation's exact temporary file; no recursive cleanup.
                try:
                    self.run(["shell", "rm", "-f", temporary])
                except custody.CustodyError:
                    pass
        self.run(["pull", remote, str(readback)])


def verify_phone_backup(phone: Phone, key: Path, password: str, java: Path, identity: dict) -> str:
    remote = f"{REMOTE_DIRECTORY}/traelyx-release-{identity['certificate_sha256']}.p12"
    with tempfile.TemporaryDirectory(prefix=".phone-readback-", dir=key.parent) as temporary:
        readback = Path(temporary) / "readback.p12"
        phone.transfer(key, remote, readback)
        if key.read_bytes() != readback.read_bytes():
            raise custody.CustodyError("Phone readback differs. Existing phone files and the primary key were not replaced.")
        restored = custody.prove(readback, password, java)
        if restored["certificate_sha256"] != identity["certificate_sha256"]:
            raise custody.CustodyError("Phone backup identity does not match; retain both copies for review.")
    return remote


def perform(phone: Phone, password: str, directory: Path) -> dict:
    directory = custody.external_path(directory)
    key, config = directory / "traelyx-release.p12", directory / "config.json"
    phone.ready()  # Do not generate an identity when backup storage is unavailable.
    java, keytool = custody.jdk_tools()
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    saved = None
    if config.exists():
        try:
            saved = json.loads(config.read_text(encoding="utf-8"))
            if (saved["config_version"] != 2 or saved["backup_transport"] != "physical_android_adb" or
                    saved["device_serial"] != phone.serial or saved["keystore"] != str(key)):
                raise ValueError()
        except (KeyError, ValueError, TypeError):
            raise custody.CustodyError("Existing local identity configuration requires review; it was not overwritten.") from None
    if not key.exists():
        if saved is not None:
            raise custody.CustodyError("Recover the original key from the phone; do not generate a replacement.")
        custody.create_key(key, password, keytool)
    identity = custody.prove(key, password, java, initial=not custody.PIN.exists())
    if saved is not None and saved["certificate_sha256"] != identity["certificate_sha256"]:
        raise custody.CustodyError("The key differs from local identity configuration.")
    if custody.PIN.exists():
        if json.loads(custody.PIN.read_text(encoding="utf-8"))["certificate_sha256"] != identity["certificate_sha256"]:
            raise custody.CustodyError("The key differs from the pinned production identity.")
    remote = f"{REMOTE_DIRECTORY}/traelyx-release-{identity['certificate_sha256']}.p12"
    custody.write_config(config, {"config_version": 2, "keystore": str(key), "alias": custody.ALIAS,
                                 "store_type": "PKCS12", "certificate_sha256": identity["certificate_sha256"],
                                 "backup_transport": "physical_android_adb", "device_serial": phone.serial,
                                 "remote_backup": remote})
    verify_phone_backup(phone, key, password, java, identity)
    return identity


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, required=True)
    args = parser.parse_args()
    STATUS.parent.mkdir(parents=True, exist_ok=True)
    try:
        if not STATUS.resolve().is_relative_to(custody.ROOT) or not custody.RECEIPT.resolve().is_relative_to(custody.ROOT):
            raise custody.CustodyError("Status and receipt must remain within this checkout.")
        custody.RECEIPT.unlink(missing_ok=True)
        password = os.environ.pop(custody.PASS_ENV, "")
        attested = os.environ.pop("TRAELYX_SIGNING_RECOVERY_ATTESTED", "")
        if len(password) < 16 or any(ord(c) < 32 for c in password) or attested != "true":
            raise custody.CustodyError("Private password input and separate password-recovery attestation are required.")
        plan = json.loads(args.plan.read_text(encoding="utf-8"))
        if plan["plan_version"] != 1:
            raise custody.CustodyError("Unsupported private phone plan.")
        phone = Phone(plan["adb"], plan["serial"])
        directory = Path(os.environ.get("LOCALAPPDATA", str(Path.home() / ".local/share"))) / "Traelyx/release-signing"
        identity = perform(phone, password, directory)
        del password
        receipt = {"contract_version": 1, "application_id": custody.APPLICATION_ID, **identity,
                   "verified_at_utc": datetime.now(timezone.utc).isoformat(), "store_type": "PKCS12", "alias": custody.ALIAS,
                   "backup_method": "physical_android_adb_readback", "backup_bytes_match": True,
                   "backup_private_key_proof_verified": True, "physical_device_checked": True,
                   "password_recovery_attested_by_maintainer": True, "phone_cloud_sync_state": "not_automatically_verified",
                   "tool_initiated_cloud_upload": False, "password_stored_in_config": False, "production_apk_built": False,
                   "setup_tool_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                   "private_prompt_sha256": hashlib.sha256((custody.ROOT / "tool/signing/Start-PhoneSigningSetup.ps1").read_bytes()).hexdigest(),
                   "custody_core_sha256": hashlib.sha256(Path(custody.__file__).read_bytes()).hexdigest(),
                   "probe_source_sha256": hashlib.sha256(custody.PROBE.read_bytes()).hexdigest()}
        custody.RECEIPT.parent.mkdir(parents=True, exist_ok=True)
        custody.RECEIPT.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        STATUS.write_text(json.dumps({"status": "complete", "receipt_created": True}) + "\n", encoding="utf-8")
        return 0
    except (Exception, KeyboardInterrupt) as error:
        message = str(error) if isinstance(error, custody.CustodyError) else "Setup could not complete. Retain existing keys and reconnect for verification."
        STATUS.write_text(json.dumps({"status": "failed", "reason": message}) + "\n", encoding="utf-8")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
