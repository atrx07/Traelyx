# Local commentary architecture v1

## When to read

Read for M7.11 local narrator storage/provider work or future runtime adoption.
This is separate from the core sensor-classifier model manifest and acceptance.
See [ADR-0043](../decisions/ADR-0043-local-narrator-admission-and-artifact-boundary.md).

## Implemented boundary

Production uses the bundled [empty catalog](local-commentary-catalog-v1.json),
an unavailable runtime and an unavailable artifact source. No weights, inference
SDK, executable download, model HTTP transport or replay activation is shipped.
You > Commentary engine > Local AI explains this. Opening settings starts no
local action; explicit refresh measures files. Data & Export reports model bytes
and links to the same controls. Missing metadata or unreadable contents produce
an unavailable state, never an invented zero. No account or key is involved.

The architecture's install, validation, removal and local selection paths work
with injected sources/runtimes and real files. Generated fixtures do not establish
that a neural model has run. The built-in narrator remains active; no persisted
engine switch or model-result rewrite is introduced.

## Manifest and admission

[Schema v1](local-commentary-manifest.schema.json) defines exact fields. The
bundled catalog allows at most eight unique IDs and digests, at most32KiB encoded.
Each manifest pins ID/revision, SHA-256, exact byte count, format, runtime and
runtime version, Android API/ABIs, HTTPS license/source references and a repository
acceptance-evidence reference. All must be reviewed in the app release; paths and
metadata links are never accepted as executable endpoints. The release signature
authenticates the bundled checksum. There is no unsigned remote manifest import.

Architecture bounds are provisional guardrails, not measured hardware budgets:

| Boundary | v1 limit |
|---|---|
| Artifact data | 1 byte..512MiB, exact manifest bytes |
| Free storage at install/recheck | artifact bytes +64MiB reserve |
| Source chunk | 1..64KiB; byte values0..255 |
| Managed directories | at most16 installed/incomplete combined |
| Receipt | exact normalized manifest, at most4096B before read |
| Reviewed input | dossier/wording v1, at most6 moments and8192 UTF-8 bytes |
| Runtime output | at most1024 UTF-8 bytes; exact JSON `choices` integer list |
| Default local operation/hash budget | 2minutes; no automatic retries |

Runtime admission requires exact ID/version, supported data format, compatible
Android API/ABI, offline operation and cancellation support. Install additionally
requires an accepted source, available space, parked/idle state, and one-use
service-owned size/license review. Cancellation or removal invalidates reviews;
admission/space/idle are rechecked at execution. A foreign/reused/stale review is
rejected. A future real source must be data-only, pinned, bounded and promptly
cancellable; a declaration does not substitute for adapter tests.

## Files and lifecycle

The native metadata bridge provides canonical
`noBackupFilesDir/local_commentary/v1`, Android API/ABIs and usable storage bytes.
Metadata runs off the Android UI thread; no sampling, permission or service
policy changes. No path, model bytes, input or output enters logs/exports. Usable filesystem
space is a conservative admission check and does not request system cache
eviction; Android lint retains an advisory about allocatable/cache space.

An install owns `<sha256>.partial/weights` and a normalized `receipt.json`.
Exact stream length and a SHA-256 read-only worker must pass before a directory
rename publishes `<sha256>`. Writes are flushed before publication. Failures
clean this operation's staging; abrupt process death can leave a visible partial
for explicit removal. Publication is atomic at filesystem rename, not a claim of
power-loss durability. Cancellation racing publication may leave a valid
installed artifact, never an accepted partial. Existing destinations are never
overwritten and abandoned staging is never silently adopted.

All artifact operations belong to one owner isolate. Its mutex plus a
nonblocking filesystem lock serialize supported access. Runtime/hash workers
are read-only consumers; a second mutating owner isolate is unsupported
(same-process file-lock behavior varies by OS).
Before use, validate receipt, exact length and checksum again while holding a
lease through runtime completion. Hashing runs in a separate isolate; cancellation
requests cancellation between bounded reads, closes its file explicitly, then
waits for acknowledgment and exit. Corruption fails closed and is preserved for
removal.
Status reads file sizes only. Runtime adapters must own their worker/session and
finish cancellation cleanup before completing; an uncooperative adapter would
keep the lease busy, and cannot be adopted without cancellation benchmarks.
Budgets request cancellation; pending OS IO and cleanup must finish before the
lease is released. They are not a measured wall-clock deadline guarantee.

Removal validates the complete namespace first and deletes only fixed known
files/directories; symlinks, unexpected names/nested content and excess entries
are refused. Removal can be retried after interruption; cancellation cannot
restore files already deleted after confirmation. This is application
ownership defense, not a sandbox against another actor executing under the same
app UID. Backups exclude this namespace by Android's no-backup directory policy.
No Drift migration or trip/Auth/Guardian storage sharing occurs.

## Provider result

`ReviewedCommentaryInput` is the shared pure M7.10 contract. Groq retains its wire
format and error mapping. A local runtime sees categorical moments, repetition,
tone and approved wording choices; no route, measurements, identifiers, timestamps
or credentials. Parsed indices must match count/type/range exactly; reject extra
fields or prose. Apply choices to the existing immutable plan. Preserve original
timings and evidence. Idle/parked state is checked before/after work; lifecycle
cancellation discards results. No cloud fallback exists in the local service.
Replay wiring remains gated until an actual accepted runtime/model exists.

## Optional adoption gate and upstream research

M7.11's architecture acceptance does not waive the conditional model gate. Before
activation: select a reproducible tokenizer/chat template and runtime build;
review dependency/license/supply chain and exact artifact provenance; implement a
pinned source with endpoint/redirect/timeout/cancellation checks; benchmark physical
target API/ABI/page-size support, APK growth, RAM/context, first/subsequent latency,
cleanup on cancellation/background/recording, battery and reviewed-wording quality.
Record failure/quality/thermal limitations and a measured acceptance decision in
the referenced evidence. Provide explicit model download/removal and replay review
UI, then admit the model. No target-device runtime benchmark exists yet.

Research on2026-11-16 used primary upstreams:

- [llama.cpp Android documentation](https://github.com/ggml-org/llama.cpp/blob/master/docs/android.md)
  and [MIT license](https://github.com/ggml-org/llama.cpp/blob/master/LICENSE):
  Android NDK/example path exists; no Traelyx adoption/build was performed.
- [Google LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM): another
  candidate mobile runtime, not selected or bundled.
- [SmolLM2-135M-Instruct model card](https://huggingface.co/HuggingFaceTB/SmolLM2-135M-Instruct):
  upstream Apache-2.0 model metadata, not a pinned accepted mobile artifact.

No candidate is declared unsuitable from absent benchmarks; none is promoted
from upstream feasibility alone. Earlier detector and vehicle/OEM gates remain.
