> **Historical document — describes 0.3.6.** For the current version, see `build-log.txt` (how this exe was built, hashes, test status) and `test-log.txt` (the latest full test run). 0.3.9 passed 51/51 regression checks plus TransferCheck, SafetyCheck and CheckpointCheck on 2026-10-21. The same applies to `REVIEW.md` and `BENCHMARK-RESULTS.md`.

# ClearCopy 0.3.6 Phase 1 — validation results

Date: 21 October 2026.

## Final result

**40 Phase 1 regression checks passed; 0 failed.** The existing TransferCheck, SafetyCheck and CheckpointCheck harnesses also passed. Build succeeded with 14 inherited CS0649 warnings in reconstructed native-input structures; no build errors. The development application's rendered-window smoke test exited successfully. No production share tests, deployment or Explorer registration were performed.

The Windows environment had .NET runtimes but no SDK. Both baseline and development applications were built with the same Microsoft C# standalone compiler from [Microsoft.Net.Compilers.Toolset 5.0.0](https://www.nuget.org/packages/Microsoft.Net.Compilers.Toolset/5.0.0); its executable signature validated as Microsoft. Compilation targets x64/.NET Framework 4.8 with C# 14. Installed framework reports version 4.8.09221, release 533509. The build script preserves the SDK option and provides an explicit CompilerPath option; no system compiler/runtime installation was needed.

## Coverage and evidence

| Area | Checked behavior | Result |
|---|---|---|
| Fast Copy | New files, copied timestamps, explicit not-verified state, equal-size/time collisions, configurable time tolerance, saved hashes do not force reads | Pass |
| Verified Copy | Identical files match; same-size/time different bytes mismatch; successful checkpoint revalidation reads one pair; stale hashes are not trusted | Pass |
| Newer destinations | Both copy modes and all existing overwrite rules protect newer files; per-file confirmation, refused confirmation, changed confirmation state, commit races | Pass |
| Protection hashes | Same-size/time concurrent destination-content edits are detected even after the modification time is restored | Pass |
| Compare | Missing and mismatched files detected; existing contents, extra files and metadata remain unchanged | Pass |
| Repair | Missing files and equal-size/time mismatches repaired and verified; now-matching candidates are not recopied; newer targets protected unless confirmed | Pass |
| Repair selection | Errors/changes do not become repairs; metadata-only issues excluded; metadata rows do not hide a simultaneous content mismatch | Pass |
| Cancellation/resume | Partial cleanup, unvisited files reported Not Reached, safe rerun, saved repair intent retained, resumed matching repairs avoid unconditional replacement | Pass |
| Source changes | Changed source before copy blocks commit; changes after hashing are caught by final audit | Pass |
| Accessibility | Actual exclusive file lock and injected UnauthorizedAccessException remain unresolved and excluded from content repair | Pass |
| Metadata | Standard creation/write times, attributes and DACL support retained; restrictive parent DACL applied after child copying | Pass |
| Metadata edge case | Cleared Archive bit may be set by inherited DACL updates; independent Compare exposes the difference rather than treating metadata as equal | Known inherited limitation; visibility check passed |
| Old jobs | Representative 0.3.5.4 XML flags map correctly; an actual fixture written by the original serializer loads with its saved hash; new modes round-trip | Pass |
| Reports/logging | Original CSV columns retained; explicit verification states appended; batching, interval/boundary flushes and write-failure visibility | Pass |
| UI workflow | Three modes exposed; Fast Copy says contents not verified; Repair All retains protected conflicts; selected Repair always verifies; choosing Compare on a saved Repair stays read-only; original scope survives subset repair/resume | Pass |
| Long paths/safety | Unicode and 279-character path transfer, replacement backups, UNC string formatting, final comparison, local junction blocking | Pass |
| Checkpoints | 30-second cadence, forced save/reload, failed-save backoff and recovery retained | Pass |

The source and destination data fixtures were on a fixed local NTFS drive beneath the workspace's work directory. Fixtures were retained for inspection. No source files or extra destination files were deleted by migration operations. The safety harness reused its already-created local junction for final reruns, avoiding further sandbox permission requests. Error injection and source edits applied only to disposable fixtures.

See `validation/Phase1Regression.txt`, `TransferCheck.txt`, `SafetyCheck.txt`, `CheckpointCheck.txt`, `legacy-summary.txt`, `development-build.txt` and `audit.json`. The regression suite's final line is `RESULT passed=40 failed=0`.

## Failures found during development

- The first run had 29 passes and one failure: a source with Archive cleared gained that bit at the destination after inherited DACL application. A separate probe reproduced the discrepancy in the original 0.3.5.4 engine. An attempted early-DACL ordering fix was rejected because it can deny creation of child files under restrictive source permissions. The original ordering is retained, its normal metadata behavior is regression-tested, and this edge case remains explicitly documented. It is **not claimed fixed**.
- The old concurrent-change harness initially stopped at the new default newer-file protection instead of exercising its commit-race hook. Its development fixture now gives the target an older timestamp. The actual commit guard and a separate same-size/time content-race check both pass.
- Initial UI harness runs needed the normal WPF dispatcher synchronization context and explicit test-application lifetime. Those test harness defects were corrected; the final UI workflow checks pass.
- Review found and corrected a directory-collision edge case introduced while removing redundant CreateDirectory calls. A dedicated regression confirms that an existing destination file is never accepted as a directory.
- Review found and corrected metadata rows masking content mismatches, and saved repair jobs losing their repair-only intent. Both are covered by the final suite.

## Remaining compatibility and integrity limits

1. Existing 0.3.5.4 jobs load into 0.3.6. New jobs should not be resumed in 0.3.5.4: older readers ignore new repair-only semantics and lack the new newer-file guard. External CSV consumers that demand exactly seven columns must accept the two appended descriptive columns.
2. The Archive-bit edge case remains. Verified Copy certifies primary-stream content; its existing metadata application/final stamp audit does not itself establish that this inherited attribute discrepancy is absent. Run independent Compare with metadata options enabled to report it. Metadata-only correction is separate manual review in Phase 1, not an automatic recopy.
3. Owner, audit rules and alternate streams remain unsupported. NAS timestamp resolution, attributes and ACL mapping have not been validated.
4. Blocking filesystem I/O has no new hard timeout/cancellation guarantee. Cancellation, XML checkpoint crash window and post-commit uncertainty retain the existing architecture. No power-loss or actual disconnect test was performed.
5. Fresh path checks and pre/post replacement hashes remain; the engine is not an immutable filesystem snapshot or a substitute for quiescing actively changing source data. Existing path/commit race limitations require a separate handle/identity design review.
6. The full 400,000–500,000-file workload was not exercised. Retained plans/results and whole-job XML rewrites remain Phase 2 concerns. The approximate ETA still excludes some finalization work.

All 45 original source-package files were content-hash checked against the pre-development manifest: **zero changes and no file-count change**. The original executable was not written or replaced. Its fingerprint and the development executable fingerprint are recorded in `validation/audit.json`.

Production rollout remains subject to approval and appropriate disposable SMB/NAS validation.
