"""Local APK size/ABI/model inventory; no extraction or network access."""

import argparse
import hashlib
import json
from pathlib import Path
import zipfile


def inventory(path: Path) -> dict:
    with path.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        models = [entry for entry in entries if entry.filename.lower().endswith(
            (".onnx", ".tflite", ".gguf", ".ggml"))]
        abis = sorted({entry.filename.split("/")[1] for entry in entries
                       if entry.filename.startswith("lib/") and len(entry.filename.split("/")) == 3})
        runnable = [abi for abi in abis if {f"lib/{abi}/libapp.so", f"lib/{abi}/libflutter.so"}
                    .issubset(archive.namelist())]
        return {
            "contract_version": 1,
            "apk_bytes": path.stat().st_size,
            "apk_sha256": digest,
            "native_abis": abis,
            "flutter_runnable_abis": runnable,
            "bundled_model_file_count": len(models),
            "bundled_model_uncompressed_bytes": sum(entry.file_size for entry in models),
            "bundled_model_compressed_bytes": sum(entry.compress_size for entry in models),
            "model_activation_or_quality_admitted": False,
        }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = inventory(args.apk)
    with args.output.open("x", encoding="utf-8") as destination:
        destination.write(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
