"""Maintainer-run key custody/backup workflow. Never builds or signs an APK."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import getpass
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
PROBE = ROOT / "tool/signing/SigningKeyProbe.java"
PIN = ROOT / "docs/reference/release-signing-identity-v1.json"
RECEIPT = ROOT / ".dart_tool/release-signing/setup-receipt-v1.json"
ALIAS = "traelyx-release"
PASS_ENV = "TRAELYX_SIGNING_SETUP_PASSWORD"
APPLICATION_ID = "io.github.atrx07.traelyx"


class CustodyError(Exception):
    """Bounded operator error. Never contains subprocess output or secrets."""


def external_path(value: str | Path) -> Path:
    path = Path(value).expanduser()
    if not path.is_absolute():
        raise CustodyError("Use an absolute local path outside all Git worktrees.")
    if str(path).startswith(("\\\\", "//")):
        raise CustodyError("Network shares are not supported by this local workflow.")
    path = path.resolve()
    for name in ["OneDrive", "OneDriveConsumer", "OneDriveCommercial"]:
        if os.environ.get(name) and path.is_relative_to(Path(os.environ[name]).resolve()):
            raise CustodyError("Choose unsynced local storage, outside cloud-sync folders.")
    if any(part.lower() in {"onedrive", "dropbox", "google drive", "my drive"} for part in path.parts):
        raise CustodyError("Choose unsynced local storage, outside cloud-sync folders.")
    if path.is_relative_to(ROOT) or any((parent / ".git").exists() for parent in [path.parent, *path.parents]):
        raise CustodyError("Signing files and their configuration must stay outside Git worktrees.")
    return path


def jdk_tools() -> tuple[Path, Path]:
    homes = [os.environ.get("JAVA_HOME")]
    if os.name == "nt":
        homes.append(str(Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Android/Android Studio/jbr"))
    suffix = ".exe" if os.name == "nt" else ""
    candidates = []
    for home in homes:
        if home:
            java, keytool = (Path(home) / "bin" / f"{name}{suffix}" for name in ["java", "keytool"])
            if java.is_file() and keytool.is_file():
                candidates.append((java, keytool))
    java, keytool = shutil.which("java"), shutil.which("keytool")
    if java and keytool:
        candidates.append((Path(java), Path(keytool)))
    for java, keytool in candidates:
        try:
            version = subprocess.run([str(java), "-version"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                     text=True, timeout=10, check=False)
            major = re.search(r'version\s+"(\d+)', version.stdout)
            if version.returncode == 0 and major and int(major.group(1)) >= 17:
                return java, keytool
        except (OSError, subprocess.TimeoutExpired):
            continue
    raise CustodyError("Install/select JDK 17 or newer; Android Studio's bundled JDK is supported.")


def run_private(command: list[str], password: str) -> str:
    environment = {**os.environ, PASS_ENV: password}
    try:
        result = subprocess.run(command, env=environment, capture_output=True, text=True, timeout=120, check=False)
    except (OSError, subprocess.TimeoutExpired):
        raise CustodyError("The local JDK operation could not complete; existing files are retained.") from None
    finally:
        environment.pop(PASS_ENV, None)
    if result.returncode:
        raise CustodyError("The local JDK rejected this operation. Check the key, password and JDK; no existing key is replaced.")
    return result.stdout


def prove(path: Path, password: str, java: Path, *, initial: bool = False) -> dict:
    command = [str(java), str(PROBE), str(path)]
    if initial:
        command.append("--initial")
    try:
        result = json.loads(run_private(command, password))
        digest = result["certificate_sha256"]
        fields = {"probe_version", "key_algorithm", "key_bits", "certificate_sha256", "not_before_utc", "not_after_utc", "private_key_proof_verified"}
        if (set(result) != fields or result["probe_version"] != 1 or result["key_algorithm"] != "RSA" or
                type(result["key_bits"]) is not int or result["key_bits"] < 2048 or
                result["private_key_proof_verified"] is not True or
                len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest)):
            raise ValueError()
        for field in ["not_before_utc", "not_after_utc"]:
            datetime.fromisoformat(result[field].replace("Z", "+00:00"))
        return result
    except (ValueError, KeyError, TypeError):
        raise CustodyError("The local signing proof returned an unsupported result.") from None


def publish_exclusive(source: Path, target: Path) -> None:
    """No overwrite, including a concurrent destination creation."""
    try:
        with target.open("xb") as output, source.open("rb") as original:
            os.chmod(target, 0o600)
            shutil.copyfileobj(original, output)
            output.flush()
            os.fsync(output.fileno())
    except FileExistsError:
        raise CustodyError("Destination already exists; it was not overwritten.") from None


def create_key(path: Path, password: str, keytool: Path) -> None:
    if path.exists():
        raise CustodyError("A key already exists. Use verify; never generate a replacement to recover access.")
    if PIN.exists():
        raise CustodyError("A production identity is already pinned. Recover that identity instead of creating a new one.")
    # The temporary encrypted copy inherits the maintainer directory's ACL.
    with tempfile.TemporaryDirectory(prefix=".traelyx-key-setup-", dir=path.parent) as temporary:
        generated = Path(temporary) / "new.p12"
        run_private([str(keytool), "-genkeypair", "-keystore", str(generated), "-storetype", "PKCS12",
                     "-alias", ALIAS, "-keyalg", "RSA", "-keysize", "4096", "-validity", "10000",
                     "-dname", "CN=Traelyx Release,O=Traelyx", "-storepass:env", PASS_ENV,
                     "-keypass:env", PASS_ENV], password)
        publish_exclusive(generated, path)


def backup_key(source: Path, backup: Path, password: str, java: Path, identity: dict) -> None:
    if source == backup or (backup.exists() and os.path.samefile(source, backup)):
        raise CustodyError("Backup must be a distinct file, not the source or a hard link.")
    if not backup.exists():
        publish_exclusive(source, backup)
    if hashlib.sha256(source.read_bytes()).digest() != hashlib.sha256(backup.read_bytes()).digest():
        raise CustodyError("The existing backup differs; neither key nor backup was overwritten.")
    restored = prove(backup, password, java)
    if restored["certificate_sha256"] != identity["certificate_sha256"]:
        raise CustodyError("Backup identity does not match. Keep both files for review.")


def write_config(path: Path, value: dict) -> None:
    if path.exists():
        try:
            if json.loads(path.read_text(encoding="utf-8")) == value:
                return
        except (ValueError, OSError):
            pass
        raise CustodyError("Existing local configuration differs; it was not overwritten.")
    with path.open("x", encoding="utf-8") as output:
        os.chmod(path, 0o600)
        json.dump(value, output, indent=2)
        output.write("\n")


def setup(mode: str, keystore: Path, backup: Path, config: Path, password: str) -> dict:
    keystore, backup, config = (external_path(p) for p in [keystore, backup, config])
    if len({keystore, backup, config}) != 3:
        raise CustodyError("Key, backup and local configuration need distinct paths.")
    if not keystore.parent.is_dir() or not backup.parent.is_dir() or not config.parent.is_dir():
        raise CustodyError("Create and protect the chosen local directories before setup.")
    saved_identity = None
    if config.exists():
        if mode == "create":
            raise CustodyError("Local identity configuration already exists. Recover or verify that identity; do not create a replacement.")
        try:
            saved = json.loads(config.read_text(encoding="utf-8"))
            if saved["keystore"] != str(keystore) or saved["backup"] != str(backup):
                raise CustodyError("Local configuration belongs to other paths; it was not changed.")
            if saved["config_version"] != 1 or saved["alias"] != ALIAS or saved["store_type"] != "PKCS12":
                raise ValueError()
            saved_identity = saved["certificate_sha256"]
        except (ValueError, KeyError, TypeError):
            raise CustodyError("Local configuration is invalid; retain it for review.") from None
    if mode == "create":
        if backup.exists():
            raise CustodyError("Choose an unused backup file before creating the first identity.")
        create_key(keystore, password, jdk_tools()[1])
    elif mode != "verify" or not keystore.is_file():
        raise CustodyError("An existing key is required for verification.")
    java, _ = jdk_tools()
    identity = prove(keystore, password, java, initial=mode == "create" or not PIN.exists())
    if saved_identity is not None and saved_identity != identity["certificate_sha256"]:
        raise CustodyError("The key differs from local configuration; no backup or configuration was replaced.")
    if PIN.exists():
        try:
            expected = json.loads(PIN.read_text(encoding="utf-8"))["certificate_sha256"]
        except (ValueError, KeyError, TypeError):
            raise CustodyError("The public identity pin is invalid; no replacement is permitted.") from None
        if expected != identity["certificate_sha256"]:
            raise CustodyError("This key differs from the pinned production identity.")
    backup_key(keystore, backup, password, java, identity)
    write_config(config, {"config_version": 1, "keystore": str(keystore), "backup": str(backup),
                          "alias": ALIAS, "store_type": "PKCS12", "certificate_sha256": identity["certificate_sha256"]})
    return identity


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["create", "verify"])
    parser.add_argument("--keystore")
    parser.add_argument("--backup")
    parser.add_argument("--config")
    args = parser.parse_args()
    try:
        if not sys.stdin.isatty():
            raise CustodyError("Run this command yourself in an interactive terminal; hidden password entry is required.")
        if not RECEIPT.resolve().is_relative_to(ROOT):
            raise CustodyError("The local receipt directory must remain inside this checkout.")
        RECEIPT.unlink(missing_ok=True)
        default_dir = Path(os.environ.get("LOCALAPPDATA", str(Path.home() / ".local/share"))) / "Traelyx/release-signing"
        print("Maintainer-local key custody. No APK build, upload or password logging.")
        print("Keep the password in your password manager, separately from both key files.")
        print("Choose protected, unsynced directories outside Git; backup storage must be independent.")
        keystore = external_path(args.keystore or input(f"Primary key path [{default_dir / 'traelyx-release.p12'}]: ").strip() or default_dir / "traelyx-release.p12")
        backup = external_path(args.backup or input("Backup file path on independently protected storage: ").strip())
        config = external_path(args.config or default_dir / "config.json")
        if not config.parent.exists():
            config.parent.mkdir(parents=True, mode=0o700)
        if not keystore.parent.exists():
            keystore.parent.mkdir(parents=True, mode=0o700)
        if not backup.parent.is_dir():
            raise CustodyError("The backup directory must already exist. Connect/protect backup storage first.")
        if args.mode == "create" and input("Type CREATE to create your first production identity: ").strip() != "CREATE":
            raise CustodyError("Creation was not confirmed; no key was created.")
        password = getpass.getpass("Keystore password (hidden; at least 16 characters): ")
        if len(password) < 16 or any(ord(c) < 32 for c in password):
            raise CustodyError("Use a password of at least 16 characters without control characters.")
        if password != getpass.getpass("Confirm password (hidden): "):
            raise CustodyError("Passwords did not match; no key was created.")
        identity = setup(args.mode, keystore, backup, config, password)
        del password
        print("Primary and backup private-key proofs passed; backup bytes match.")
        if input("Are both key locations unsynced, the backup on independently protected storage, and the password kept separately? Type YES: ").strip() != "YES":
            raise CustodyError("Key files are retained. Independent backup custody is not attested; M8.6 remains incomplete.")
        receipt = {"contract_version": 1, "application_id": APPLICATION_ID, **identity,
                   "verified_at_utc": datetime.now(timezone.utc).isoformat(),
                   "store_type": "PKCS12", "alias": ALIAS, "backup_bytes_match": True,
                   "backup_private_key_proof_verified": True, "independent_backup_attested_by_maintainer": True,
                   "unsynced_storage_attested_by_maintainer": True,
                   "password_stored_in_config": False, "production_apk_built": False,
                   "setup_tool_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                   "probe_source_sha256": hashlib.sha256(PROBE.read_bytes()).hexdigest()}
        RECEIPT.parent.mkdir(parents=True, exist_ok=True)
        RECEIPT.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        print("Sanitized receipt saved locally. Tell Codex: keystore setup and backup complete.")
        return 0
    except (Exception, KeyboardInterrupt) as error:
        print(str(error) if isinstance(error, CustodyError) else "Setup could not complete. Existing keys are retained; use verify to resume.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
