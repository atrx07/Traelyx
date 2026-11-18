import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock
import zipfile

from tool import release_apk as apk
from tool import release_signing_setup as custody

PASSWORD = "disposable-fixture-password-never-production"
COMMIT = "a" * 40
CERT = "b" * 64


class ApkTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="traelyx-apk-test-")
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name).resolve()
        self.root = self.base / "repo"
        self.root.mkdir()
        self.release = self.root / "build/release/fixture"
        self.release.mkdir(parents=True)
        self.pin = self.root / "pin.json"
        self.config = self.base / "config.json"
        self.patch = mock.patch.multiple(apk, ROOT=self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def test_child_password_only_and_bounded_failures(self):
        observed = {}
        def inspect(command, **kwargs):
            observed.update(kwargs["env"])
            self.assertNotIn(PASSWORD, command)
            return subprocess.CompletedProcess(command, 1, PASSWORD, PASSWORD)
        before = dict(os.environ)
        with mock.patch.object(apk.subprocess, "run", side_effect=inspect):
            with self.assertRaises(custody.CustodyError) as error:
                apk.run(["java", "-jar", "signer.jar"], password=PASSWORD)
        self.assertEqual(observed[custody.PASS_ENV], PASSWORD)
        self.assertNotIn(PASSWORD, str(error.exception))
        self.assertEqual(dict(os.environ), before)

    def test_nonsecret_child_does_not_inherit_signing_password(self):
        with mock.patch.dict(os.environ, {custody.PASS_ENV: PASSWORD}):
            with mock.patch.object(apk.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "", "")) as child:
                apk.run(["aapt2", "dump"])
        self.assertNotIn(custody.PASS_ENV, child.call_args.kwargs["env"])

    def test_signed_input_rejected_before_any_resigning(self):
        path = self.release / "signed.apk"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("META-INF/RELEASE.RSA", "disposable")
        with mock.patch.object(apk, "signer") as signer, self.assertRaises(custody.CustodyError):
            apk.require_unsigned(path, {})
        signer.assert_not_called()

    def test_signature_requires_one_matching_signer_and_v2_v3(self):
        good = f"Number of signers: 1\nV2 Signer: certificate SHA-256 digest: {CERT}\nVerified using v2 scheme: true\nVerified using v3 scheme: true\n"
        self.assertTrue(apk.verified_signature(good, CERT)["v3_verified"])
        for bad in [good.replace(CERT, "c" * 64), good.replace("signers: 1", "signers: 2"), good.replace("signers: 1", "signers: 10"),
                    good.replace("v3 scheme: true", "v3 scheme: false"), good + "Signer #2 certificate SHA-256 digest: " + "d" * 64]:
            with self.subTest(bad=bad), self.assertRaises(custody.CustodyError):
                apk.verified_signature(bad, CERT)

    def test_source_change_stops_before_key_access(self):
        plan = self.release / "plan.local.json"
        plan.write_text(json.dumps({"contract_version": 1, "source_commit": COMMIT, "build_invoked_by_operator": True, "inputs": []}))
        with mock.patch.object(apk, "source_commit", return_value="c" * 40), mock.patch.object(apk, "signing_identity") as key:
            with self.assertRaises(custody.CustodyError):
                apk.sign(plan, self.config, PASSWORD)
        key.assert_not_called()

    def test_changed_input_stops_before_key_access(self):
        entries = []
        for abi in apk.ABIS:
            name = f"unsigned-{abi}.apk"
            (self.release / name).write_bytes(b"changed fixture")
            entries.append({"abi": abi, "filename": name, "sha256": "0" * 64})
        plan = self.release / "plan.local.json"
        plan.write_text(json.dumps({"contract_version": 1, "source_commit": COMMIT, "build_invoked_by_operator": True, "inputs": entries}))
        with mock.patch.object(apk, "source_commit", return_value=COMMIT), mock.patch.object(apk, "sdk_tools", return_value={}), mock.patch.object(apk, "signing_identity") as key:
            with self.assertRaises(custody.CustodyError):
                apk.sign(plan, self.config, PASSWORD)
        key.assert_not_called()

    def test_artifacts_cannot_be_published_outside_ignored_release_directory(self):
        for path in [self.root / "public", self.root / "build/release/../../elsewhere", self.base / "release"]:
            with self.assertRaises(custody.CustodyError):
                apk.artifact_directory(path)

    def test_identity_config_mismatch_stops_before_private_key_probe(self):
        self.config.write_text(json.dumps({"config_version": 2, "alias": custody.ALIAS,
                                          "store_type": "PKCS12", "certificate_sha256": CERT}))
        self.pin.write_text(json.dumps({"certificate_sha256": "c" * 64}))
        with mock.patch.object(custody, "PIN", self.pin), mock.patch.object(custody, "prove") as probe:
            with self.assertRaises(custody.CustodyError):
                apk.signing_identity(self.config, PASSWORD, Path("java"))
        probe.assert_not_called()

    def test_reject_wrong_abi(self):
        fake = {"native_abis": ["x86_64"], "flutter_runnable_abis": ["x86_64"]}
        with mock.patch.object(apk, "inventory", return_value=fake):
            with self.assertRaises(custody.CustodyError):
                apk.check_package(Path("unused"), "arm64-v8a", {})

    def test_source_change_during_compile_cannot_mint_new_provenance(self):
        with mock.patch.object(apk, "source_commit", return_value="c" * 40):
            with self.assertRaises(custody.CustodyError):
                apk.prepare(self.base, self.release / "new", built_source_commit=COMMIT)
        self.assertFalse((self.release / "new").exists())

    def test_build_rejects_secret_auth_configuration_before_compiling(self):
        client = self.root / "auth-config.local.json"
        client.write_text(json.dumps({"TRAELYX_SUPABASE_URL": "https://" + "a" * 20 + ".supabase.co",
                                      "TRAELYX_SUPABASE_PUBLISHABLE_KEY": "sb_secret_disposable-fixture"}))
        with mock.patch.object(apk, "source_commit", return_value=COMMIT), mock.patch.object(apk.shutil, "which", return_value="/sdk/flutter/bin/flutter"), mock.patch.object(apk, "run") as child:
            with self.assertRaises(custody.CustodyError):
                apk.build(self.release / "new")
        child.assert_not_called()

    def test_dirty_source_is_rejected(self):
        with mock.patch.object(apk, "run", return_value=subprocess.CompletedProcess([], 0, " M tracked-file", "")):
            with self.assertRaises(custody.CustodyError):
                apk.source_commit()

    def test_package_version_and_debuggable_rejected(self):
        path = self.release / "fixture.apk"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("AndroidManifest.xml", b"disposable fixture")
        info = {"native_abis": ["arm64-v8a"], "flutter_runnable_abis": ["arm64-v8a"]}
        good = "package: name='io.github.atrx07.traelyx' versionCode='2001' versionName='0.1.0'\nminSdkVersion:'24'\ntargetSdkVersion:'36'\n"
        for bad in [good.replace("2001", "1"), good.replace("0.1.0", "0.1.1"),
                    good.replace("io.github.atrx07.traelyx", "io.github.atrx07.traelyx.hardening"), good + "application-debuggable\n"]:
            with mock.patch.object(apk, "inventory", return_value=info), mock.patch.object(apk, "run", return_value=subprocess.CompletedProcess([], 0, bad, "")):
                with self.assertRaises(custody.CustodyError):
                    apk.check_package(path, "arm64-v8a", {"aapt2": "unused"})

    def test_real_disposable_three_abi_signatures_and_no_overwrite(self):
        # This fixture has dummy native bytes: it proves packaging/signatures, not execution.
        tools = apk.sdk_tools()
        sdk = tools["aapt2"].parent.parent.parent
        android_jar = sdk / "platforms/android-36/android.jar"
        self.assertTrue(android_jar.is_file(), "Android SDK 36 fixture platform is required")
        input_dir = self.base / "input"
        input_dir.mkdir()
        for abi, code in apk.ABIS.items():
            manifest = self.base / f"{abi}.xml"
            manifest.write_text(f'<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{custody.APPLICATION_ID}" android:versionCode="{code}" android:versionName="0.1.0"><uses-sdk android:minSdkVersion="24" android:targetSdkVersion="36"/><application android:label="Disposable signing fixture"/></manifest>')
            unaligned = self.base / f"{abi}.apk"
            apk.run([tools["aapt2"], "link", "-I", android_jar, "--manifest", manifest, "-o", unaligned])
            with zipfile.ZipFile(unaligned, "a") as archive:
                for name in ["libapp.so", "libflutter.so"]:
                    archive.writestr(f"lib/{abi}/{name}", b"disposable, non-runnable native fixture")
            apk.run([tools["zipalign"], "-P", "16", "4", unaligned, input_dir / f"app-{abi}-release.apk"])
        key = self.base / "fixture.p12"
        with mock.patch.object(custody, "PIN", self.pin):
            custody.create_key(key, PASSWORD, custody.jdk_tools()[1])
            proof = custody.prove(key, PASSWORD, tools["java"])
            self.pin.write_text(json.dumps({"certificate_sha256": proof["certificate_sha256"]}))
            self.config.write_text(json.dumps({"config_version": 2, "alias": custody.ALIAS, "store_type": "PKCS12",
                                              "certificate_sha256": proof["certificate_sha256"], "keystore": str(key)}))
            output = self.root / "build/release/actual"
            with mock.patch.object(apk, "source_commit", return_value=COMMIT):
                plan = apk.prepare(input_dir, output, built_source_commit=COMMIT)
                receipt = apk.sign(plan, self.config, PASSWORD)
                saved = {p.name: apk.digest(p) for p in (output / "signed").iterdir()}
                with self.assertRaises(custody.CustodyError):
                    apk.sign(plan, self.config, PASSWORD)
                self.assertEqual(saved, {p.name: apk.digest(p) for p in (output / "signed").iterdir()})
        self.assertEqual(len(receipt["artifacts"]), 3)
        self.assertTrue(all(a["v2_verified"] and a["v3_verified"] for a in receipt["artifacts"]))
        self.assertNotIn(PASSWORD, json.dumps(receipt))
        self.assertNotIn(str(key), json.dumps(receipt))
        sums = (output / "signed/SHA256SUMS.txt").read_text()
        for artifact in receipt["artifacts"]:
            self.assertIn(f"{artifact['apk_sha256']}  {artifact['filename']}", sums)


if __name__ == "__main__":
    unittest.main()
