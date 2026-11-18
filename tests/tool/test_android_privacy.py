import unittest
import xml.etree.ElementTree as ET

from tool.audit_android_privacy import ANDROID, DOMAINS, EXPORTED, PACKAGE, PERMISSIONS, audit


def fixture():
    root = ET.Element("manifest", {"package": PACKAGE})
    for permission in sorted(PERMISSIONS):
        ET.SubElement(root, "uses-permission", {ANDROID + "name": permission})
    ET.SubElement(root, "permission", {ANDROID + "name": f"{PACKAGE}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION",
                                      ANDROID + "protectionLevel": "signature"})
    app = ET.SubElement(root, "application", {ANDROID + "allowBackup": "false", ANDROID + "usesCleartextTraffic": "false"})
    app.set(ANDROID + "fullBackupContent", "@xml/backup_rules")
    app.set(ANDROID + "dataExtractionRules", "@xml/data_extraction_rules")
    for tag, name, permission in EXPORTED:
        attributes = {ANDROID + "name": name, ANDROID + "exported": "true"}
        if permission:
            attributes[ANDROID + "permission"] = permission
        ET.SubElement(app, tag, attributes)
    for name in ["firebase_messaging_auto_init_enabled", "firebase_analytics_collection_enabled",
                 "firebase_data_collection_default_enabled", "firebase_messaging_notification_delegation_enabled"]:
        ET.SubElement(app, "meta-data", {ANDROID + "name": name, ANDROID + "value": "false"})
    legacy = ET.Element("full-backup-content")
    modern = ET.Element("data-extraction-rules")
    for section in [legacy, ET.SubElement(modern, "cloud-backup"), ET.SubElement(modern, "device-transfer")]:
        for domain in sorted(DOMAINS):
            ET.SubElement(section, "exclude", {"domain": domain, "path": "."})
    return root, legacy, modern


class AndroidPrivacyTest(unittest.TestCase):
    def test_reviewed_ordinary_release_passes_without_private_values(self):
        report = audit(*fixture())
        self.assertTrue(report["passed"])
        self.assertEqual(report["permission_count"], 10)
        self.assertEqual(report["exported_component_count"], 3)
        self.assertFalse(report["user_data_read"])

    def test_omitted_or_enabled_backup_and_cleartext_are_rejected(self):
        for key in ["allowBackup", "usesCleartextTraffic"]:
            for value in [None, "true"]:
                root, legacy, modern = fixture()
                app = root.find("application")
                if value is None:
                    del app.attrib[ANDROID + key]
                else:
                    app.set(ANDROID + key, value)
                self.assertIn(f"explicit_{key}_false_required", audit(root, legacy, modern)["findings"])

    def test_old_credential_only_rules_do_not_cover_private_database(self):
        root, legacy, modern = fixture()
        for section in [legacy, *modern]:
            section.clear()
            ET.SubElement(section, "exclude", {"domain": "sharedpref", "path": "TraelyxAuth.xml"})
        self.assertEqual(sum("all_domains" in item for item in audit(root, legacy, modern)["findings"]), 3)

    def test_each_domain_and_transfer_mode_is_required(self):
        for mode in ["legacy", "cloud-backup", "device-transfer"]:
            for domain in DOMAINS:
                root, legacy, modern = fixture()
                section = legacy if mode == "legacy" else modern.find(mode)
                section.remove(next(e for e in section if e.get("domain") == domain))
                self.assertIn(f"{mode}_all_domains_must_be_excluded", audit(root, legacy, modern)["findings"])
        root, legacy, modern = fixture()
        modern.remove(modern.find("device-transfer"))
        self.assertFalse(audit(root, legacy, modern)["passed"])

    def test_qa_debug_and_unreviewed_permissions_are_rejected(self):
        for mutation in ["qa", "debug", "permission"]:
            root, legacy, modern = fixture()
            app = root.find("application")
            if mutation == "qa":
                ET.SubElement(app, "activity", {ANDROID + "name": "test.PerformanceControlActivity", ANDROID + "exported": "false"})
            elif mutation == "debug":
                app.set(ANDROID + "debuggable", "true")
            else:
                ET.SubElement(root, "uses-permission", {ANDROID + "name": "android.permission.READ_CONTACTS"})
            self.assertFalse(audit(root, legacy, modern)["passed"])

    def test_lost_receiver_protection_or_extra_export_is_rejected(self):
        for mutation in ["receiver", "extra"]:
            root, legacy, modern = fixture()
            app = root.find("application")
            if mutation == "receiver":
                receiver = next(e for e in app if e.get(ANDROID + "permission") == "com.google.android.c2dm.permission.SEND")
                del receiver.attrib[ANDROID + "permission"]
            else:
                ET.SubElement(app, "service", {ANDROID + "name": "unexpected.Service", ANDROID + "exported": "true"})
            self.assertIn("exported_component_inventory_changed", audit(root, legacy, modern)["findings"])

    def test_automatic_firebase_and_new_transfer_modes_require_review(self):
        root, legacy, modern = fixture()
        ET.SubElement(root.find("application"), "provider", {ANDROID + "name": "com.google.firebase.provider.FirebaseInitProvider"})
        ET.SubElement(modern, "unreviewed-transfer")
        findings = audit(root, legacy, modern)["findings"]
        self.assertIn("automatic_firebase_initialization", findings)
        self.assertIn("extraction_modes_require_review", findings)

    def test_decoded_signature_flags_accept_exact_signature_only(self):
        for value, accepted in [("0x2", True), ("0x00000002", True), ("normal", False), ("0x0", False), ("signature|privileged", False)]:
            root, legacy, modern = fixture()
            root.find("permission").set(ANDROID + "protectionLevel", value)
            self.assertEqual(audit(root, legacy, modern)["passed"], accepted)

    def test_packaged_resource_ids_must_match_actual_manifest_bindings(self):
        root, legacy, modern = fixture()
        bindings = {"backup_rules": "@ref/0x7f110000", "data_extraction_rules": "@ref/0x7f110001"}
        app = root.find("application")
        app.set(ANDROID + "fullBackupContent", bindings["backup_rules"])
        app.set(ANDROID + "dataExtractionRules", bindings["data_extraction_rules"])
        self.assertTrue(audit(root, legacy, modern, bindings)["passed"])
        app.set(ANDROID + "fullBackupContent", "@ref/0x7f110099")
        self.assertIn("backup_resource_binding_changed", audit(root, legacy, modern, bindings)["findings"])
