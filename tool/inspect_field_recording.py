#!/usr/bin/env python3
"""Local, read-only, hash-pinned quality intake; never model admission.

Run as python -m tool.inspect_field_recording. Stdout is aggregate-only;
stderr never includes paths, identities, supplied digests or parser exceptions.
"""

import argparse
import json
from pathlib import Path
import sys
import zipfile

from .inspect_tripdebug import inspect_pinned_archive


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--expected-sha256", required=True)
    args = parser.parse_args(argv)
    try:
        result = inspect_pinned_archive(args.archive, args.expected_sha256)
    except (OSError, ValueError, zipfile.BadZipFile, EOFError,
            RuntimeError, NotImplementedError):
        # Host exceptions can contain private paths, ZIP names and identifiers.
        # Detailed local debugging is a separately reviewed action.
        print("field_recording_invalid", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
