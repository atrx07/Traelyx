"""Check the exact standalone pilot APK's packaged permission/component boundary."""

import argparse
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile

PACKAGE = "io.github.atrx07.traelyx.syncpilot"
ANDROID = "{http://schemas.android.com/apk/res/android}"


def require(condition, code):
    if not condition:
        raise ValueError(code)


def verify(apk, manifest):
    with manifest.open("rb") as stream:
        raw = stream.read(100001)
    require(len(raw) <= 100000, "manifest_size")
    root = ET.fromstring(raw.decode("utf-8-sig"))
    require(root.tag == "manifest" and root.get("package") == PACKAGE, "package")
    require(not any(e.tag.startswith("uses-permission") for e in root.iter()), "permissions")
    require(root.get(ANDROID+"sharedUserId") is None and root.find("instrumentation") is None, "shared_identity")
    app = root.find("application")
    require(len(root.findall("application")) == 1 and app.get(ANDROID+"name") is None and
            app.get(ANDROID+"process") is None and app.get(ANDROID+"allowBackup") == "false" and
            app.get(ANDROID+"usesCleartextTraffic") == "false", "backup_or_cleartext")
    require(not any(app.findall(tag) for tag in ("service", "receiver", "provider", "activity-alias")), "components")
    activities = app.findall("activity")
    require(len(activities) == 1 and activities[0].get(ANDROID+"name") == PACKAGE+".PilotActivity" and
            activities[0].get(ANDROID+"exported") == "true", "activity")
    filters = activities[0].findall("intent-filter")
    require(len(filters) == 1 and len(list(filters[0])) == 2 and
            [e.get(ANDROID+"name") for e in filters[0].findall("action")] == ["android.intent.action.MAIN"] and
            [e.get(ANDROID+"name") for e in filters[0].findall("category")] == ["android.intent.category.LAUNCHER"], "launcher")
    sdk = root.find("uses-sdk")
    require(sdk is not None and sdk.get(ANDROID+"minSdkVersion") == "24" and
            sdk.get(ANDROID+"targetSdkVersion") == "36", "sdk")
    require(apk.stat().st_size <= 5_000_000, "apk_size")
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        require(len(names) == len(set(names)) and "classes.dex" in names, "zip_entries")
        require(not any(name.startswith(("lib/", "assets/")) and not name.endswith("/") for name in names), "runtime_or_assets")
    return {"package": PACKAGE, "permissions": [], "services_receivers_providers": [],
            "apk_bytes": apk.stat().st_size, "apk_sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
            "production_recorder_modified": False, "physical_timing_verified": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("manifest", type=Path, help="apkanalyzer manifest print from this exact APK")
    args = parser.parse_args()
    print(json.dumps(verify(args.apk, args.manifest), sort_keys=True))
