# `.tripdebug` archive format version 1

## Purpose and privacy

A `.tripdebug` file is a deterministic local archive of one finalized Traelyx trip. Version 1 contains the original verified native telemetry chunks, including precise GNSS coordinates and raw device-frame motion. Its mandatory privacy class is `precise_private`; creating an archive is never anonymization and never authorizes upload, publication, or Git inclusion.

Exports use Android's system document picker. Traelyx writes only after an explicit user destination is selected, performs no network access, exposes no absolute app-private path or device identity, and deletes its temporary cache copy after completion or cancellation.

## Container

- ZIP container with every entry stored uncompressed because `.tlxc` payloads already use DEFLATE.
- Entry timestamps are fixed and entry order is deterministic.
- `manifest.txt` is first, followed by one chunk per declared sequence.
- Version 1 allows at most 10,000 chunks, a 2 MiB manifest, 4 MiB per chunk, and a 512 MiB archive.
- Duplicate, unexpected, reordered, directory, traversal, oversized, or unsupported entries fail closed.

## Manifest

`manifest.txt` is deterministic UTF-8 `key=value` text with a final newline. It declares:

- `format=traelyx.tripdebug` and `archive_version=1`;
- `privacy_class=precise_private` and `contains_precise_location=true`;
- trip UUID, telemetry schema version, and native chunk encoding version;
- chunk count, elapsed-time bounds, and aggregate GNSS/accelerometer/gyroscope counts;
- for each contiguous sequence from zero: exact `chunks/<10-digit-sequence>.tlxc` entry name, byte length, and SHA-256 over the complete chunk file.

Unknown, missing, duplicated, malformed, mixed-version, or inconsistent fields fail closed. The manifest contains no coordinates, vectors, wall-clock route trace, filename from private storage, absolute path, account identity, or device identifier.

## Verification and replay inspection

Before Android reports export success, it reopens the completed archive and verifies the manifest, ZIP structure, full-file SHA-256, native chunk envelope/checksum/completion marker, trip/version/sequence identity, cross-chunk ordering, per-channel timestamp ordering, elapsed bounds, and aggregate sample counts.

The independent host command performs the same structural decode and reports only privacy-safe aggregate evidence:

```powershell
python tool/inspect_tripdebug.py <private-file.tripdebug>
```

Its output includes duration, byte/chunk/sample counts, and maximum observed gaps. It never prints coordinates, vectors, source timestamps, providers, or wall-clock route data. Gap values are evidence for review, not automatic proof of a recorder defect or safety judgment.

## Compatibility

Archive version, telemetry schema version, and native chunk encoding version are independent. Readers must reject unknown versions rather than reinterpret them. A future anonymized/public fixture format must use an explicit transformation/version and must not relabel this precise-private archive.
