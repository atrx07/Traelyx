import tempfile
import unittest
from pathlib import Path
import zipfile

from tool.inventory_apk import inventory


class InventoryApkTest(unittest.TestCase):
    def test_counts_model_bytes_without_treating_catalog_or_abi_duplicates_as_models(self):
        with tempfile.TemporaryDirectory(dir=".dart_tool") as temporary:
            path = Path(temporary) / "generated.apk"
            with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                archive.writestr("lib/arm64-v8a/libapp.so", b"native")
                archive.writestr("lib/arm64-v8a/libflutter.so", b"engine")
                archive.writestr("lib/x86_64/libapp.so", b"native")
                archive.writestr("assets/models/catalog.json", "[]")
                archive.writestr("assets/models/generated.onnx", b"x" * 100)
            result = inventory(path)
            self.assertEqual(result["native_abis"], ["arm64-v8a", "x86_64"])
            self.assertEqual(result["flutter_runnable_abis"], ["arm64-v8a"])
            self.assertEqual(result["bundled_model_file_count"], 1)
            self.assertEqual(result["bundled_model_uncompressed_bytes"], 100)
            self.assertEqual(len(result["apk_sha256"]), 64)
            self.assertFalse(result["model_activation_or_quality_admitted"])
