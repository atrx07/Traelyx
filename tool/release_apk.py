"""Local-only APK preparation/signing. No generation, installation or upload."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

from tool import release_signing_setup as custody
from tool.inventory_apk import inventory

ROOT = Path(__file__).resolve().parents[1]
ABIS = {"armeabi-v7a": 1001, "arm64-v8a": 2001, "x86_64": 4001}
VERSION = "0.1.0"
STATUS = ROOT / ".dart_tool/release-signing/apk-status-v1.json"


def run(command, *, password=None, required=True, timeout=180):
    environment = {k: v for k, v in os.environ.items() if not k.startswith("TRAELYX_SIGNING_")}
    if password is not None:
        environment[custody.PASS_ENV] = password
    try:
        result = subprocess.run(list(map(str, command)), env=environment, capture_output=True,
                                text=True, encoding="utf-8", errors="replace", timeout=timeout, cwd=ROOT)
    except (OSError, subprocess.SubprocessError):
        raise custody.CustodyError("Local APK operation failed; raw tool output is withheld.") from None
    finally:
        environment.pop(custody.PASS_ENV, None)
    if required and result.returncode:
        raise custody.CustodyError("Local APK tool rejected the operation; existing keys/artifacts are retained.")
    return result


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def source_commit():
    if run(["git", "-C", ROOT, "status", "--porcelain"]).stdout.strip():
        raise custody.CustodyError("A clean source checkout is required before APK preparation/signing.")
    commit = run(["git", "-C", ROOT, "rev-parse", "HEAD"]).stdout.strip()
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise custody.CustodyError("Source commit is unavailable.")
    return commit


def sdk_tools():
    sdk = Path(os.environ.get("ANDROID_HOME", str(Path(os.environ.get("LOCALAPPDATA", "")) / "Android/sdk")))
    versions = [p for p in (sdk / "build-tools").iterdir() if re.fullmatch(r"\d+\.\d+\.\d+", p.name)]
    tools = max(versions, key=lambda p: tuple(map(int, p.name.split("."))))
    suffix = ".exe" if os.name == "nt" else ""
    java = custody.jdk_tools()[0]
    result = {"java": java, "signer": tools / "lib/apksigner.jar",
              "zipalign": tools / f"zipalign{suffix}", "aapt2": tools / f"aapt2{suffix}"}
    if not all(p.is_file() for p in result.values()):
        raise custody.CustodyError("Installed JDK and Android SDK signing tools are required.")
    return result


def signer(tools, *args, password=None, required=True):
    return run([tools["java"], "-jar", tools["signer"], *args], password=password, required=required)


def check_package(apk, abi, tools):
    details = inventory(apk)
    if details["native_abis"] != [abi] or details["flutter_runnable_abis"] != [abi]:
        raise custody.CustodyError("APK must contain exactly the intended runnable Flutter ABI.")
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or archive.testzip() is not None:
            raise custody.CustodyError("APK ZIP entries are duplicated or corrupt.")
        forbidden = [n for n in names if n.lower().endswith((".p12", ".pfx", ".jks", ".keystore")) or
                     n.lower().split("/")[-1] in {"key.properties", ".env", "config.json"}]
        if forbidden:
            raise custody.CustodyError("Unexpected private configuration/key filename in APK.")
    badging = run([tools["aapt2"], "dump", "badging", apk]).stdout
    package = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging, re.M)
    minimum = re.search(r"^(?:minSdkVersion|sdkVersion):'(\d+)'", badging, re.M)
    target = re.search(r"^targetSdkVersion:'(\d+)'", badging, re.M)
    if (not package or package.groups() != (custody.APPLICATION_ID, str(ABIS[abi]), VERSION) or
            not minimum or not target or "application-debuggable" in badging or "testOnly='true'" in badging):
        raise custody.CustodyError("Ordinary release package/version/SDK contract did not match.")
    run([tools["zipalign"], "-c", "-P", "16", "4", apk])
    return {**details, "abi": abi, "application_id": package[1], "version_code": int(package[2]),
            "version_name": package[3], "min_sdk": int(minimum[1]), "target_sdk": int(target[1]),
            "zip_alignment_16k_checked": True}


def require_unsigned(apk, tools):
    with zipfile.ZipFile(apk) as archive:
        if any(re.fullmatch(r"META-INF/[^/]+\.(RSA|DSA|EC|SF)", n, re.I) for n in archive.namelist()):
            raise custody.CustodyError("Expected an unsigned production input, not a development-signed APK.")
        central_offset = archive.start_dir
    with apk.open("rb") as source:
        source.seek(max(0, central_offset - 16))
        if source.read(16) == b"APK Sig Block 42":
            raise custody.CustodyError("Input already contains an APK signing block.")
    if signer(tools, "verify", apk, required=False).returncode == 0:
        raise custody.CustodyError("Production preparation requires a genuinely unsigned input.")


def verified_signature(output, expected):
    hashes = re.findall(r"certificate SHA-256 digest: ([0-9a-fA-F]{64})", output)
    if (not re.search(r"^Number of signers: 1\s*$", output, re.M) or not hashes or
            {h.lower() for h in hashes} != {expected} or
            not re.search(r"Verified using v2 scheme[^\n]*: true", output) or
            not re.search(r"Verified using v3 scheme[^\n]*: true", output)):
        raise custody.CustodyError("APK signature must verify with one pinned signer and v2/v3 schemes.")
    return {"certificate_sha256": expected, "signer_count": 1, "v2_verified": True, "v3_verified": True}


def artifact_directory(value):
    path = Path(value).resolve()
    if not path.is_relative_to((ROOT / "build/release").resolve()):
        raise custody.CustodyError("Release artifacts/plans must stay under ignored build/release.")
    return path


def prepare(input_dir, output_dir, *, built_source_commit):
    commit = source_commit()
    if commit != built_source_commit:
        raise custody.CustodyError("Source changed during compilation; no build plan was published.")
    tools = sdk_tools()
    target = artifact_directory(output_dir)
    target.mkdir(parents=True, exist_ok=False)
    inputs = []
    for abi in ABIS:
        source = Path(input_dir) / f"app-{abi}-release.apk"
        require_unsigned(source, tools)
        check_package(source, abi, tools)
        snapshot = target / f"unsigned-{abi}.apk"
        custody.publish_exclusive(source, snapshot)
        inputs.append({"abi": abi, "filename": snapshot.name, "sha256": digest(snapshot)})
    plan = {"contract_version": 1, "source_commit": commit, "build_invoked_by_operator": True, "inputs": inputs}
    with (target / "plan.local.json").open("x", encoding="utf-8") as stream:
        json.dump(plan, stream, indent=2)
    return target / "plan.local.json"


def build(output_dir):
    commit = source_commit()
    if artifact_directory(output_dir).exists():
        raise custody.CustodyError("Choose a new release directory; no existing set is replaced.")
    flutter = shutil.which("flutter")
    flutter_root = Path(os.environ["FLUTTER_ROOT"]) if os.environ.get("FLUTTER_ROOT") else Path(flutter).parent.parent if flutter else None
    if flutter_root is None:
        raise custody.CustodyError("Select the installed Flutter SDK before compilation.")
    dart = flutter_root / "bin/cache/dart-sdk/bin" / ("dart.exe" if os.name == "nt" else "dart")
    command = [dart, f"--packages={flutter_root / 'packages/flutter_tools/.dart_tool/package_config.json'}",
               flutter_root / "bin/cache/flutter_tools.snapshot", "build", "apk", "--release", "--split-per-abi",
               "--android-project-arg=traelyxUnsignedProductionApk=true"]
    client = ROOT / "auth-config.local.json"
    if client.exists():
        # Only the two existing public account-client fields are release inputs.
        values = json.loads(client.read_text(encoding="utf-8-sig"))
        if set(values) != {"TRAELYX_SUPABASE_URL", "TRAELYX_SUPABASE_PUBLISHABLE_KEY"}:
            raise custody.CustodyError("Only the reviewed public auth client configuration is supported.")
        url, key = values["TRAELYX_SUPABASE_URL"], values["TRAELYX_SUPABASE_PUBLISHABLE_KEY"]
        if not re.fullmatch(r"https://[a-z0-9]{20}\.supabase\.co", url) or not re.fullmatch(r"sb_publishable_[A-Za-z0-9_-]+", key):
            raise custody.CustodyError("Use the current public Supabase publishable key; secret/legacy keys are not accepted.")
        command.append(f"--dart-define-from-file={client}")
    run(command, timeout=1800)
    return prepare(ROOT / "build/app/outputs/flutter-apk", output_dir, built_source_commit=commit)


def signing_identity(config_path, password, java):
    config = json.loads(custody.external_path(config_path).read_text(encoding="utf-8"))
    pin = json.loads(custody.PIN.read_text(encoding="utf-8"))
    if (config["config_version"] not in {1, 2} or config["alias"] != custody.ALIAS or
            config["store_type"] != "PKCS12" or config["certificate_sha256"] != pin["certificate_sha256"]):
        raise custody.CustodyError("Local configuration does not match the pinned signing identity.")
    key = custody.external_path(config["keystore"])
    # Opens the existing encrypted key in a short-lived JVM; never creates/copies it.
    proof = custody.prove(key, password, java)
    if proof["certificate_sha256"] != pin["certificate_sha256"]:
        raise custody.CustodyError("Private-key proof does not match the production certificate pin.")
    return key, pin["certificate_sha256"]


def sign(plan_path, config_path, password):
    plan_path = artifact_directory(plan_path)
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    if (plan["contract_version"] != 1 or plan.get("build_invoked_by_operator") is not True or
            plan["source_commit"] != source_commit()):
        raise custody.CustodyError("Source changed after unsigned APK preparation; prepare again.")
    inputs = plan["inputs"]
    if sorted(i["abi"] for i in inputs) != sorted(ABIS):
        raise custody.CustodyError("Exactly one input for each planned ABI is required.")
    tools = sdk_tools()
    for entry in inputs:
        if entry["filename"] != f"unsigned-{entry['abi']}.apk":
            raise custody.CustodyError("Unexpected input filename in the local plan.")
        path = plan_path.parent / entry["filename"]
        if digest(path) != entry["sha256"]:
            raise custody.CustodyError("Unsigned APK changed after preparation.")
        require_unsigned(path, tools)
        check_package(path, entry["abi"], tools)
    destination = plan_path.parent / "signed"
    if destination.exists():
        raise custody.CustodyError("Signed destination already exists; it will not be overwritten.")
    key, certificate = signing_identity(config_path, password, tools["java"])
    artifacts = []
    # A failed attempt leaves no published success receipt/checksum set.
    with tempfile.TemporaryDirectory(prefix=".signing-", dir=plan_path.parent) as temporary:
        stage = Path(temporary)
        for entry in inputs:
            abi = entry["abi"]
            name = f"traelyx-v{VERSION}-{abi}.apk"
            original = plan_path.parent / entry["filename"]
            signed = stage / name
            signer(tools, "sign", "--ks", key, "--ks-type", "PKCS12", "--ks-key-alias", custody.ALIAS,
                   "--ks-pass", f"env:{custody.PASS_ENV}", "--key-pass", f"env:{custody.PASS_ENV}",
                   "--v2-signing-enabled", "true", "--v3-signing-enabled", "true",
                   "--v4-signing-enabled", "false", "--out", signed, original, password=password)
            output = signer(tools, "verify", "--verbose", "--print-certs", signed).stdout
            signature = verified_signature(output, certificate)
            details = check_package(signed, abi, tools)
            if digest(original) != entry["sha256"]:
                raise custody.CustodyError("Unsigned input changed during signing.")
            artifacts.append({"filename": name, "unsigned_sha256": entry["sha256"], **details, **signature})
        if source_commit() != plan["source_commit"]:
            raise custody.CustodyError("Source changed during signing; success was not published.")
        receipt = {"contract_version": 1, "source_commit": plan["source_commit"],
                   "verified_at_utc": datetime.now(timezone.utc).isoformat(), "artifacts": artifacts,
                   "production_signed": True, "installed": False, "published": False,
                   "password_stored": False, "key_copied": False,
                   "signing_tool_sha256": digest(Path(__file__)),
                   "apksigner_jar_sha256": digest(tools["signer"])}
        (stage / "SHA256SUMS.txt").write_text("".join(f"{a['apk_sha256']}  {a['filename']}\n" for a in artifacts), encoding="ascii")
        (stage / "verification-v1.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        destination.mkdir()  # Exclusive reservation; never replace an existing artifact set.
        # Receipt is published last; partial copying must never report success.
        paths = [stage / a["filename"] for a in artifacts]
        paths += [stage / "SHA256SUMS.txt", stage / "verification-v1.json"]
        for path in paths:
            custody.publish_exclusive(path, destination / path.name)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["build", "sign"])
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--plan", type=Path)
    args = parser.parse_args()
    try:
        if args.mode == "build":
            if args.output_dir is None:
                raise custody.CustodyError("Choose a new ignored release output directory.")
            print(build(args.output_dir))
        else:
            password = os.environ.pop(custody.PASS_ENV, None)
            if not password or args.plan is None:
                raise custody.CustodyError("Use the local masked prompt with the existing password.")
            config = Path(os.environ.get("LOCALAPPDATA", "")) / "Traelyx/release-signing/config.json"
            sign(args.plan, config, password)
            del password
            STATUS.parent.mkdir(parents=True, exist_ok=True)
            STATUS.write_text('{"status":"complete","production_signed":true,"installed":false,"published":false}\n', encoding="utf-8")
        return 0
    except (Exception, KeyboardInterrupt) as error:
        message = str(error) if isinstance(error, custody.CustodyError) else "APK workflow could not finish; keys are retained and details withheld."
        if args.mode == "sign":
            STATUS.parent.mkdir(parents=True, exist_ok=True)
            STATUS.write_text(json.dumps({"status": "failed", "reason": message}) + "\n", encoding="utf-8")
        print(message, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
