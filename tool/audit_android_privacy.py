"""Fail-closed ordinary release manifest/backup review; no device or network access."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ANDROID = "{http://schemas.android.com/apk/res/android}"
PACKAGE = "io.github.atrx07.traelyx"
POLICY_VERSION = 1
PERMISSIONS = {
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_LOCATION",
    "android.permission.INTERNET",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.WAKE_LOCK",
    "com.google.android.c2dm.permission.RECEIVE",
    f"{PACKAGE}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION",
}
DOMAINS = {
    "root", "file", "database", "sharedpref", "external",
    "device_root", "device_file", "device_database", "device_sharedpref",
}
EXPORTED = {
    ("activity", f"{PACKAGE}.MainActivity", None),
    ("receiver", "com.google.firebase.iid.FirebaseInstanceIdReceiver",
     "com.google.android.c2dm.permission.SEND"),
    ("receiver", "androidx.profileinstaller.ProfileInstallReceiver", "android.permission.DUMP"),
}


def audit(manifest: ET.Element, legacy: ET.Element, extraction: ET.Element, bindings=None) -> dict:
    findings = set()
    if manifest.tag != "manifest" or manifest.get("package") != PACKAGE:
        findings.add("ordinary_package_required")
    permissions = {e.get(ANDROID + "name") for e in manifest if e.tag.startswith("uses-permission")}
    if permissions != PERMISSIONS:
        findings.add("permission_inventory_changed")
    if manifest.get(ANDROID + "sharedUserId") is not None:
        findings.add("shared_uid_forbidden")
    app = manifest.find("application")
    exported = set()
    if app is None:
        findings.add("application_missing")
    else:
        for attribute, resource in [("fullBackupContent", "backup_rules"), ("dataExtractionRules", "data_extraction_rules")]:
            expected = bindings.get(resource) if bindings is not None else f"@xml/{resource}"
            if expected is None or app.get(ANDROID + attribute) != expected:
                findings.add("backup_resource_binding_changed")
        for name, expected in [("allowBackup", "false"), ("usesCleartextTraffic", "false")]:
            if app.get(ANDROID + name) != expected:
                findings.add(f"explicit_{name}_false_required")
        if app.get(ANDROID + "debuggable", "false") != "false" or app.get(ANDROID + "testOnly") == "true":
            findings.add("ordinary_release_required")
        if app.get(ANDROID + "backupAgent") is not None:
            findings.add("custom_backup_agent_requires_review")
        if app.get(ANDROID + "networkSecurityConfig") is not None:
            findings.add("custom_network_policy_requires_review")
        for component in app:
            name = component.get(ANDROID + "name", "")
            if any(token in name for token in ["RecorderHardening", "PerformanceControl", "ReplayPerformance"]):
                findings.add("qa_component_in_ordinary_release")
            if name == "com.google.firebase.provider.FirebaseInitProvider":
                findings.add("automatic_firebase_initialization")
            if component.tag not in {"activity", "activity-alias", "receiver", "service", "provider"}:
                continue
            default_exported = "true" if component.find("intent-filter") is not None and component.tag != "provider" else "false"
            if component.get(ANDROID + "exported", default_exported) == "true":
                exported.add((component.tag, name, component.get(ANDROID + "permission")))
        if exported != EXPORTED:
            findings.add("exported_component_inventory_changed")
        metadata = {e.get(ANDROID + "name"): e.get(ANDROID + "value") for e in app.findall("meta-data")}
        for name in ["firebase_messaging_auto_init_enabled", "firebase_analytics_collection_enabled",
                     "firebase_data_collection_default_enabled", "firebase_messaging_notification_delegation_enabled"]:
            if metadata.get(name) != "false":
                findings.add("firebase_consent_defaults_changed")
        signatures = [e for e in manifest.findall("permission")
                      if e.get(ANDROID + "name") == f"{PACKAGE}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"]
        if len(signatures) != 1 or signatures[0].get(ANDROID + "protectionLevel") not in {"signature", "2", "0x2", "0x00000002"}:
            findings.add("dynamic_receiver_permission_not_signature")
    if legacy.tag != "full-backup-content":
        findings.add("legacy_backup_root_invalid")
    if extraction.tag != "data-extraction-rules" or sorted(e.tag for e in extraction) != ["cloud-backup", "device-transfer"]:
        findings.add("extraction_modes_require_review")
    sections = {"legacy": legacy}
    for mode in ["cloud-backup", "device-transfer"]:
        sections[mode] = extraction.find(mode)
    for label, section in sections.items():
        if section is None:
            findings.add(f"{label}_missing")
            continue
        if any(e.tag != "exclude" for e in section):
            findings.add(f"{label}_unreviewed_rules")
        exclusions = {e.get("domain") for e in section.findall("exclude") if e.get("path") in {".", "./"}}
        if not DOMAINS.issubset(exclusions):
            findings.add(f"{label}_all_domains_must_be_excluded")
    return {
        "contract_version": 1, "policy_version": POLICY_VERSION,
        "scope": "decoded ordinary release manifest and packaged backup XML; not an OEM backup execution",
        "passed": not findings, "findings": sorted(findings),
        "permission_count": len(permissions), "exported_component_count": len(exported),
        "backup_domains_reviewed": sorted(DOMAINS),
        "user_data_read": False, "network_requested": False,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--apkanalyzer", type=Path, required=True)
    parser.add_argument("--aapt2", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    def run(executable, *arguments):
        return subprocess.check_output([str(executable), *map(str, arguments)],
                                       text=True, encoding="utf-8", timeout=90, stderr=subprocess.PIPE).strip()
    try:
        table = run(args.aapt2, "dump", "resources", args.apk)
        bindings = {name: f"@ref/{identifier}" for identifier, name in re.findall(
            r"resource\s+(0x[0-9a-f]+)\s+xml/(backup_rules|data_extraction_rules)\b", table)}
        if set(bindings) != {"backup_rules", "data_extraction_rules"}:
            raise ValueError("missing_resource_bindings")
        decoded = []
        for name in ["backup_rules", "data_extraction_rules"]:
            entry = run(args.apkanalyzer, "resources", "value", "--config", "default", "--type", "xml", "--name", name, args.apk)
            if not re.fullmatch(r"res/[A-Za-z0-9_/.-]+\.xml", entry) or ".." in entry.split("/"):
                raise ValueError("unsafe_resource_entry")
            decoded.append(ET.fromstring(run(args.apkanalyzer, "resources", "xml", "--file", entry, args.apk)))
        manifest = ET.fromstring(run(args.apkanalyzer, "manifest", "print", args.apk))
        report = audit(manifest, *decoded, bindings=bindings)
        with args.apk.open("rb") as source:
            report["apk_sha256"] = hashlib.file_digest(source, "sha256").hexdigest()
        report["apk_bytes"] = args.apk.stat().st_size
    except (OSError, subprocess.SubprocessError, ET.ParseError, ValueError):
        raise SystemExit("Android privacy audit failed: APK decoding or resource binding unavailable.") from None
    encoded = json.dumps(report, indent=2) + "\n"
    if args.output:
        with args.output.open("x", encoding="utf-8") as destination:
            destination.write(encoded)
    print(encoded, end="")
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
