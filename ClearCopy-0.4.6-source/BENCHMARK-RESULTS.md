> **Historical document — describes 0.3.6.** See `CHANGELOG.md`, `build-log.txt` and `test-log.txt` for the current version.

# ClearCopy Phase 1 — local before/after benchmark

Date: 21 October 2026. These results describe a modest local fixture, not SMB/NAS performance or a 500,000-file run.

## Method

The original engine was built from a separate, untouched copy of the 0.3.5.4 application source. Both versions used the same Microsoft C# compiler, optimized x64 framework build settings and the same benchmark source. Each process used 512 files of 1 KiB in eight directories, fresh disposable local NTFS paths, activity logging enabled, default final source audit, and no optional details/DACL preservation. Fixture creation and checkpoint-hash dictionary setup were outside timed regions. Timing includes planning, engine execution, audit, log writes and final log disposal. GUI work and XML checkpoint persistence are excluded.

There were three measured rounds per version, alternating version order, plus an excluded 64-file round. Each process still pays its own JIT startup cost. Scenarios run in order: fresh Verified Copy, Verified Copy with a complete matched checkpoint, then policy-only Fast Copy on existing files. The original version's verification-off API is used for the equivalent Fast Copy policy scenario. Caches were not forcibly cleared, and background system activity was not controlled. Report medians and ranges; do not infer a reliable gain from small differences or overlapping ranges.

Managed allocation is the application-domain cumulative allocation delta during the timed work. It is **not peak resident memory** and excludes unmanaged/OS buffers. HashReadBytes counts logical SHA-256 input, not physical disk or SMB traffic. Tests ran on Windows build 26200 and a local NTFS drive.

## Final paired measurements

| Scenario, 512 files | 0.3.5.4 median | 0.3.6 median | Median elapsed reduction | Original range | Development range |
|---|---:|---:|---:|---:|---:|
| New Verified Copy | 11,748.991 ms | 10,437.651 ms | 11.16% | 11,089.777–11,985.312 ms | 9,933.905–10,651.602 ms |
| Matched-checkpoint Verified Copy | 7,583.313 ms | 5,828.195 ms | 23.14% | 5,570.403–7,952.495 ms | 5,495.664–6,217.083 ms |
| Existing-file policy Fast Copy | 2,525.497 ms | 2,425.062 ms | 3.98% | 2,479.720–2,714.439 ms | 2,311.840–2,714.660 ms |

The roughly 4% policy-skip difference is small relative to run variation and is not a convincing standalone throughput improvement. Checkpoint timings also overlap, despite their lower development median. The fresh-copy improvement is modest; durable per-file flushes and metadata latency remain.

| Scenario | Original median allocated | Development median allocated | Allocation reduction | Gen-2 collections, original / development | SHA-256 input, original / development |
|---|---:|---:|---:|---:|---:|
| New Verified Copy | 2,080.30 MiB | 26.34 MiB | 98.73% | 512 / 0 | 1 MiB / 1 MiB |
| Matched-checkpoint Verified Copy | 2,069.30 MiB | 17.21 MiB | 99.17% | 682 / 0 | 2 MiB / 1 MiB |
| Policy Fast Copy | 7.48 MiB | 7.50 MiB | No reduction | 0 / 0 | 0 / 0 |

Reusable scratch arrays and the smaller internal write buffer for tiny files explain the large allocation reduction. Avoiding the second successful checkpoint hash pair halves checkpoint SHA-256 input for this fixture. Fresh verified copies still read both primary streams for verification. Policy Fast Copy performs no verification-only hashes in either equivalent configuration.

Raw data, including the excluded round, is in `validation/benchmark-final.csv`; summary data is in `benchmark-statistics.json`. The benchmark was run against the final engine implementation; a subsequent UI-only change moved the mode selector into the visible progress card and was separately regression/smoke tested.

## Initial measurements retained

Before reducing the tiny-file FileStream internal write buffer, a first three-round series showed:

| Scenario | Original median | Initial development median |
|---|---:|---:|
| New Verified Copy | 10,542.843 ms | 12,523.134 ms |
| Matched-checkpoint Verified Copy | 5,290.718 ms | 4,543.334 ms |
| Policy Fast Copy | 1,698.340 ms | 1,849.798 ms |

Fresh development copies ranged from 7,755.481 to 24,530.413 ms. These mixed results were not discarded or described as a universal speedup. Allocation counters identified the remaining per-file 1 MiB internal write buffer; only files below 1 MiB were then changed to use a 4 KiB internal buffer. The reusable 1 MiB transfer buffer, large-file buffering, safe-commit checks and durable Flush(true) were retained. The final regression suite was rerun before the final paired benchmark.

Initial raw measurements are retained in `validation/benchmark-initial.csv`. Absolute times differ between series, so use each series' own paired baseline and do not attribute all cross-series differences to the buffer adjustment.

## Interpretation

The strongest findings are the reduction in cumulative managed allocation and removal of duplicate checkpoint hashing. The elapsed-time improvements in the final local sample are encouraging but insufficient to predict NAS throughput. No changes to parallelism, file flush durability, metadata safety checks or checkpoint architecture were used to obtain these results.

Phase 2 should profile actual per-operation SMB latency, directory depth, server storage behavior, network stalls, checkpoint/UI overhead and peak memory at realistic file counts before choosing further changes.
