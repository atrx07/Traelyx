import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

from tool import release_signing_setup as custody
from tool import release_signing_phone_setup as phone_setup

PASSWORD = "synthetic-phone-fixture-never-production"


class PhoneBridgeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="traelyx-phone-unit-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.adb = self.base / "adb"
        self.adb.write_text("synthetic executable fixture")

    def test_emulator_and_network_serials_are_refused(self):
        for serial in ["emulator-5554", "192.0.2.1:5555", "example._adb-tls-connect._tcp"]:
            with self.assertRaises(custody.CustodyError):
                phone_setup.Phone(str(self.adb), serial)

    def test_adb_receives_no_password_environment_or_raw_error_output(self):
        phone = phone_setup.Phone(str(self.adb), "synthetic_usb_serial")
        result = subprocess.CompletedProcess([], 1, PASSWORD, PASSWORD)
        with mock.patch.dict(os.environ, {custody.PASS_ENV: PASSWORD}), mock.patch.object(phone_setup.subprocess, "run", return_value=result) as run:
            with self.assertRaises(custody.CustodyError) as error:
                phone.run(["get-state"])
        self.assertNotIn(PASSWORD, str(error.exception))
        self.assertNotIn(custody.PASS_ENV, run.call_args.kwargs["env"])

    def test_existing_remote_file_is_never_pushed_or_moved(self):
        phone = phone_setup.Phone(str(self.adb), "synthetic_usb_serial")
        remote = phone_setup.REMOTE_DIRECTORY + "/traelyx-release-" + "a" * 64 + ".p12"
        with mock.patch.object(phone, "exists", return_value=True), mock.patch.object(phone, "run") as run:
            phone.transfer(self.base / "source", remote, self.base / "readback")
        commands = [c.args[0] for c in run.call_args_list]
        self.assertFalse(any(c[0] == "push" or c[:2] == ["shell", "mv"] for c in commands))
        self.assertEqual(commands[-1][0], "pull")

    def test_missing_remote_file_uses_no_clobber_publish_and_exact_temp_cleanup(self):
        phone = phone_setup.Phone(str(self.adb), "synthetic_usb_serial")
        remote = phone_setup.REMOTE_DIRECTORY + "/traelyx-release-" + "a" * 64 + ".p12"
        with mock.patch.object(phone, "exists", return_value=False), mock.patch.object(phone, "run") as run:
            phone.transfer(self.base / "source", remote, self.base / "readback")
        commands = [c.args[0] for c in run.call_args_list]
        published = next(c for c in commands if c[:3] == ["shell", "mv", "-n"])
        cleanup = next(c for c in commands if c[:3] == ["shell", "rm", "-f"])
        self.assertEqual(published[3], cleanup[3])
        self.assertTrue(cleanup[3].startswith(phone_setup.REMOTE_DIRECTORY + "/.pending-"))
        self.assertNotIn(remote, cleanup)

    def test_no_key_generation_when_phone_is_unavailable(self):
        phone = mock.Mock(serial="synthetic_usb_serial")
        phone.ready.side_effect = custody.CustodyError("unavailable")
        with mock.patch.object(custody, "create_key") as create, self.assertRaises(custody.CustodyError):
            phone_setup.perform(phone, PASSWORD, self.base / "custody")
        create.assert_not_called()

    def test_missing_primary_with_existing_phone_config_never_rotates(self):
        directory = self.base / "custody"
        directory.mkdir()
        (directory / "config.json").write_text(json.dumps({"config_version": 2, "backup_transport": "physical_android_adb",
            "device_serial": "synthetic_usb_serial", "keystore": str((directory / 'traelyx-release.p12').resolve())}))
        with mock.patch.object(custody, "jdk_tools", return_value=(Path("java"), Path("keytool"))), mock.patch.object(custody, "create_key") as create, self.assertRaises(custody.CustodyError):
            phone_setup.perform(mock.Mock(serial="synthetic_usb_serial"), PASSWORD, directory)
        create.assert_not_called()


class PhoneReadbackProofTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="traelyx-disposable-phone-proof-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.key = Path(cls.temporary.name) / "disposable-fixture.p12"
        cls.java, keytool = custody.jdk_tools()
        custody.run_private([str(keytool), "-genkeypair", "-keystore", str(cls.key), "-storetype", "PKCS12",
            "-alias", custody.ALIAS, "-keyalg", "RSA", "-keysize", "4096", "-validity", "10000",
            "-dname", "CN=Traelyx Disposable Phone Fixture", "-storepass:env", custody.PASS_ENV,
            "-keypass:env", custody.PASS_ENV], PASSWORD)

    def test_real_jdk_proof_of_phone_roundtrip_and_corrupt_readback_refusal(self):
        identity = custody.prove(self.key, PASSWORD, self.java, initial=True)
        phone = mock.Mock()
        phone.transfer.side_effect = lambda source, remote, readback: readback.write_bytes(source.read_bytes())
        remote = phone_setup.verify_phone_backup(phone, self.key, PASSWORD, self.java, identity)
        self.assertTrue(remote.endswith(identity["certificate_sha256"] + ".p12"))
        phone.transfer.side_effect = lambda source, remote, readback: readback.write_bytes(b"corrupt disposable fixture")
        with self.assertRaises(custody.CustodyError):
            phone_setup.verify_phone_backup(phone, self.key, PASSWORD, self.java, identity)


if __name__ == "__main__":
    unittest.main()
