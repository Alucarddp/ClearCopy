> **Historical document — describes 0.3.6.** See `CHANGELOG.md`, `build-log.txt` and `test-log.txt` for the current version.

# ClearCopy 0.3.6 — Phase 1 development review

The development copy implements Fast Copy, Verified Copy and independent Compare with controlled Repair. It protects newer destination files by default, requires individual confirmation for exceptions, rechecks state before commit, and verifies every copied repair. Saved repair jobs retain their repair-only intent. Compare remains read-only, including when selected after loading a repair job.

Low-risk optimizations reuse scratch memory, reduce tiny-file internal write buffers, avoid duplicate successful checkpoint hashes and repeated directory creation, and batch noncritical logging. Durable transfer/checkpoint flushes, backups and fresh path checks remain. Processing remains sequential; no checkpoint database or streaming architecture was introduced.

**Validation:** 40 regression checks passed, no failures. The existing transfer, safety and checkpoint harnesses passed; the rendered application smoke test exited successfully. Both baseline and development builds produced the same 14 inherited native-structure warnings.

**Local benchmark:** 512 × 1 KiB files, three paired measured rounds. Median new Verified Copy fell from 11.749 s to 10.438 s (11.16%); checkpoint resume fell from 7.583 s to 5.828 s (23.14%). Cumulative managed allocations fell by 98.73% and 99.17%, respectively. Policy-skip timing changed only slightly. These measurements do not establish SMB/NAS performance or scaling to 500,000 files.

**Known concern:** The original metadata order remains to support restrictive parent permissions. Inherited DACL updates can set an Archive bit that the source had cleared; independent Compare reports this as a separate metadata difference. This issue is documented, not claimed fixed. Owner, audit rules and alternate streams remain outside existing support. Hard I/O timeouts, byte-based ETA limitations, large retained result sets and full XML checkpoint rewrites remain Phase 2 work.

**Release protection:** All 45 original source-package files match their starting content hashes. No production shares were tested or modified. The 0.3.5.4 executable was not replaced, no development executable was installed, and default automatic Explorer registration is disabled in the development build. Do not load new repair jobs in the older release: it does not enforce the new repair semantics or overwrite guard.

## Package contents

- [Usage and build instructions](README.md)
- [Modification details and remaining Phase 2 work](CHANGELOG.md)
- [Regression results, compatibility concerns and limitations](TEST-RESULTS.md)
- [Before/after benchmark measurements and methodology](BENCHMARK-RESULTS.md)
- `Source/`: complete development source, project and build script
- `Tests/`: deterministic regression suite, original harnesses, compatibility fixture and benchmark runner
- `executable/ClearCopy-0.3.6-development.exe` and matching `.exe.config`: development executable; keep these together
- `validation/`: full final logs, both benchmark series, statistics, fingerprints and rendered preview

Production rollout requires approval and separate validation against disposable SMB/NAS fixtures. No rollout has been performed.
