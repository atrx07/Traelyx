import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

from tool import release_signing_setup as signing


PROOF = {"probe_version": 1, "key_algorithm": "RSA", "key_bits": 4096,
         "certificate_sha256": "a" * 64, "not_before_utc": "2026-01-01T00:00:00Z",
         "not_after_utc": "2055-01-01T00:00:00Z", "private_key_proof_verified": True}
PASSWORD = "synthetic-test-password-never-production"


class CustodyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="traelyx-signing-unit-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name).resolve()
        self.repo = self.base / "repo"
        self.repo.mkdir()
        (self.repo / ".git").mkdir()
        self.external = self.base / "custody"
        self.external.mkdir()
        self.key = self.external / "fixture.p12"
        self.backup = self.external / "backup.p12"
        self.config = self.external / "config.json"
        self.patch = mock.patch.multiple(signing, ROOT=self.repo, PIN=self.repo / "pin.json", RECEIPT=self.repo / ".dart_tool/receipt.json")
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def test_rejects_relative_network_and_git_paths(self):
        other = self.base / "another-worktree"
        other.mkdir()
        (other / ".git").write_text("gitdir: elsewhere")
        for path in ["relative.p12", "//server/share/key.p12", self.repo / "ignored/key.p12", other / "sub/key.p12"]:
            with self.subTest(path=str(path)), self.assertRaises(signing.CustodyError):
                signing.external_path(path)
        self.assertEqual(signing.external_path(self.key), self.key)

    def test_exclusive_publish_keeps_existing_destination(self):
        self.key.write_bytes(b"synthetic source")
        self.backup.write_bytes(b"existing independent data")
        with self.assertRaises(signing.CustodyError):
            signing.publish_exclusive(self.key, self.backup)
        self.assertEqual(self.backup.read_bytes(), b"existing independent data")

    def test_known_cloud_sync_roots_are_rejected(self):
        with mock.patch.dict(os.environ, {"OneDrive": str(self.external)}):
            with self.assertRaises(signing.CustodyError):
                signing.external_path(self.key)
        with self.assertRaises(signing.CustodyError):
            signing.external_path(self.base / "Dropbox/key.p12")

    def test_same_file_and_hardlink_are_not_backups(self):
        self.key.write_bytes(b"synthetic source")
        os.link(self.key, self.backup)
        for backup in [self.key, self.backup]:
            with self.assertRaises(signing.CustodyError):
                signing.backup_key(self.key, backup, PASSWORD, Path("java"), PROOF)

    def test_different_backup_is_retained_without_private_key_probe(self):
        self.key.write_bytes(b"synthetic source")
        self.backup.write_bytes(b"different")
        with mock.patch.object(signing, "prove") as probe, self.assertRaises(signing.CustodyError):
            signing.backup_key(self.key, self.backup, PASSWORD, Path("java"), PROOF)
        probe.assert_not_called()
        self.assertEqual(self.backup.read_bytes(), b"different")

    def test_subprocess_password_is_only_in_child_environment_and_errors_are_bounded(self):
        failed = subprocess.CompletedProcess([], 1, PASSWORD, PASSWORD)
        observed = {}
        before = dict(os.environ)
        def inspect(*args, **kwargs):
            observed["password"] = kwargs["env"].get(signing.PASS_ENV)
            return failed
        with mock.patch.object(signing.subprocess, "run", side_effect=inspect) as runner:
            with self.assertRaises(signing.CustodyError) as error:
                signing.run_private(["keytool", "-storepass:env", signing.PASS_ENV], PASSWORD)
        self.assertNotIn(PASSWORD, str(error.exception))
        args, kwargs = runner.call_args
        self.assertNotIn(PASSWORD, args[0])
        self.assertEqual(observed["password"], PASSWORD)
        self.assertNotIn(signing.PASS_ENV, kwargs["env"])
        self.assertEqual(dict(os.environ), before)

    def test_no_creation_over_existing_key_or_pinned_identity(self):
        self.key.write_bytes(b"existing")
        with mock.patch.object(signing, "run_private") as runner:
            with self.assertRaises(signing.CustodyError):
                signing.create_key(self.key, PASSWORD, Path("keytool"))
            self.key.unlink()
            signing.PIN.write_text(json.dumps({"certificate_sha256": "b" * 64}))
            with self.assertRaises(signing.CustodyError):
                signing.create_key(self.key, PASSWORD, Path("keytool"))
        runner.assert_not_called()

    def test_unused_backup_required_before_creation(self):
        self.backup.write_bytes(b"existing")
        with mock.patch.object(signing, "create_key") as create, self.assertRaises(signing.CustodyError):
            signing.setup("create", self.key, self.backup, self.config, PASSWORD)
        create.assert_not_called()
        self.assertFalse(self.key.exists())

    def test_existing_configuration_prevents_replacement_even_if_key_is_missing(self):
        self.config.write_text(json.dumps({"certificate_sha256": "a" * 64}))
        with mock.patch.object(signing, "create_key") as create, self.assertRaises(signing.CustodyError):
            signing.setup("create", self.key, self.backup, self.config, PASSWORD)
        create.assert_not_called()

    def test_public_pin_mismatch_stops_before_backup(self):
        self.key.write_bytes(b"existing")
        signing.PIN.write_text(json.dumps({"certificate_sha256": "b" * 64}))
        with mock.patch.object(signing, "prove", return_value=PROOF), mock.patch.object(signing, "jdk_tools", return_value=(Path("java"), Path("keytool"))), mock.patch.object(signing, "backup_key") as backup:
            with self.assertRaises(signing.CustodyError):
                signing.setup("verify", self.key, self.backup, self.config, PASSWORD)
        backup.assert_not_called()
        self.assertFalse(self.config.exists())

    def test_local_configuration_is_idempotent_and_never_overwritten(self):
        value = {"config_version": 1, "certificate_sha256": "a" * 64}
        signing.write_config(self.config, value)
        signing.write_config(self.config, value)
        with self.assertRaises(signing.CustodyError):
            signing.write_config(self.config, {"different": True})
        self.assertEqual(json.loads(self.config.read_text()), value)

    def test_extra_probe_fields_are_not_exported(self):
        with mock.patch.object(signing, "run_private", return_value=json.dumps({**PROOF, "unexpected": PASSWORD})):
            with self.assertRaises(signing.CustodyError):
                signing.prove(self.key, PASSWORD, Path("java"))

    def test_no_interactive_password_fallback(self):
        with mock.patch.object(signing.sys, "argv", ["setup", "create"]), mock.patch.object(signing.sys.stdin, "isatty", return_value=False), mock.patch.object(signing.getpass, "getpass") as secret, contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(signing.main(), 1)
        secret.assert_not_called()
        self.assertFalse(self.key.exists())

    def test_unsupported_jdk_is_rejected_before_generation(self):
        home = self.external / "jdk"
        (home / "bin").mkdir(parents=True)
        suffix = ".exe" if os.name == "nt" else ""
        for name in ["java", "keytool"]:
            (home / "bin" / f"{name}{suffix}").write_text("synthetic executable fixture")
        result = subprocess.CompletedProcess([], 0, 'java version "1.8.0"')
        with mock.patch.dict(os.environ, {"JAVA_HOME": str(home)}), mock.patch.object(signing.shutil, "which", return_value=None), mock.patch.object(signing.subprocess, "run", return_value=result), self.assertRaises(signing.CustodyError):
            signing.jdk_tools()

    def run_interactive_fixture(self, attestation):
        argv = ["setup", "verify", "--keystore", str(self.key), "--backup", str(self.backup), "--config", str(self.config)]
        with mock.patch.object(signing.sys, "argv", argv), mock.patch.object(signing.sys.stdin, "isatty", return_value=True), mock.patch.object(signing.getpass, "getpass", return_value=PASSWORD), mock.patch("builtins.input", return_value=attestation), mock.patch.object(signing, "setup", return_value=PROOF), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return signing.main()

    def test_receipt_requires_independent_custody_attestation_and_contains_no_secret_paths(self):
        self.assertEqual(self.run_interactive_fixture("NO"), 1)
        self.assertFalse(signing.RECEIPT.exists())
        self.assertEqual(self.run_interactive_fixture("YES"), 0)
        text = signing.RECEIPT.read_text()
        receipt = json.loads(text)
        self.assertTrue(receipt["independent_backup_attested_by_maintainer"])
        self.assertNotIn(PASSWORD, text)
        self.assertNotIn(str(self.external), text)
        self.assertFalse(receipt["production_apk_built"])

    def test_unexpected_errors_never_expose_their_text(self):
        stderr = io.StringIO()
        argv = ["setup", "verify", "--keystore", str(self.key), "--backup", str(self.backup), "--config", str(self.config)]
        with mock.patch.object(signing.sys, "argv", argv), mock.patch.object(signing.sys.stdin, "isatty", return_value=True), mock.patch.object(signing.getpass, "getpass", return_value=PASSWORD), mock.patch.object(signing, "setup", side_effect=RuntimeError(PASSWORD)), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(stderr):
            self.assertEqual(signing.main(), 1)
        self.assertNotIn(PASSWORD, stderr.getvalue())


class JdkProofTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="traelyx-disposable-signing-proof-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.key = Path(cls.temporary.name) / "disposable-fixture.p12"
        cls.java, keytool = signing.jdk_tools()
        signing.run_private([str(keytool), "-genkeypair", "-keystore", str(cls.key), "-storetype", "PKCS12",
                             "-alias", signing.ALIAS, "-keyalg", "RSA", "-keysize", "4096", "-validity", "10000",
                             "-dname", "CN=Traelyx Disposable Test Fixture", "-storepass:env", signing.PASS_ENV,
                             "-keypass:env", signing.PASS_ENV], PASSWORD)

    def test_real_private_key_proof_and_verified_backup(self):
        proof = signing.prove(self.key, PASSWORD, self.java, initial=True)
        self.assertTrue(proof["private_key_proof_verified"])
        self.assertEqual(proof["key_bits"], 4096)
        backup = self.key.with_name("disposable-backup.p12")
        signing.backup_key(self.key, backup, PASSWORD, self.java, proof)
        self.assertEqual(self.key.read_bytes(), backup.read_bytes())

    def test_wrong_password_has_only_bounded_error(self):
        with self.assertRaises(signing.CustodyError) as error:
            signing.prove(self.key, "wrong-synthetic-test-password", self.java)
        self.assertNotIn("wrong-synthetic", str(error.exception))

    def test_debug_certificate_cannot_become_the_production_identity(self):
        debug = self.key.with_name("disposable-debug-fixture.p12")
        _, keytool = signing.jdk_tools()
        signing.run_private([str(keytool), "-genkeypair", "-keystore", str(debug), "-storetype", "PKCS12",
                             "-alias", signing.ALIAS, "-keyalg", "RSA", "-keysize", "4096", "-validity", "10000",
                             "-dname", "CN=Android Debug,O=Android,C=US", "-storepass:env", signing.PASS_ENV,
                             "-keypass:env", signing.PASS_ENV], PASSWORD)
        with self.assertRaises(signing.CustodyError):
            signing.prove(debug, PASSWORD, self.java, initial=True)


if __name__ == "__main__":
    unittest.main()
