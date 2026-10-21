# ClearCopy 0.3.9.1 — change log

## 0.3.9.1 — small fix

- The percentage area is blank until a job starts. It used to show a dash that looked like a stray line next to the lightbulb.
- Version bumped to 0.3.9.1 so the Update button offers it over an installed 0.3.9.

## 0.3.9 — slimmer window, clickable counts, compact view

- **Slimmer top.** The logo, "ClearCopy 0.3.8" title and tagline are gone; the version is shown in the window title bar. The Light/Dark mode button is now a lightbulb icon (tooltip says which mode it switches to). The Install/Update button, when shown, sits next to the lightbulb at the top right of the progress card. Outer spacing is tighter (12 px instead of 20); in compact view it drops to 8 px with no gap below the card. The Explorer status line moved into **Explorer integration** under Folders & options.
- **Clickable counts.** Copied, Skipped, Matched and every issue count under the progress bar are links. Clicking one opens **Results** showing only those items, with "Showing skipped: N items" and a **Show all** button to clear it. "Skipped" includes protected newer destinations, which are also counted as skipped. A new job clears the filter.
- **Compact view.** A chevron button at the bottom right of the progress card (on the Start / Open logs row) hides everything below the progress card (folders, options, log, results); the window shrinks to fit. Click again to restore the full view at its previous height. The choice is remembered. Clicking a count while compact switches back to full view so the results are visible.
- No changes to copying, verification or the engine.

**Tests:** slim header (version in title, lightbulb icon, Explorer status kept); a Skipped link filters Results to the skipped row, opens the Results tab and Show all restores every row; compact view hides and restores the details area.

# 0.3.8 — change log (previous)

## 0.3.8 — release build

0.3.8 is everything listed below under 0.3.7 (fix 1 path checks, fix 2 background checkpoints, the permissions-compare fix, the Ctrl+V countdown), built as a **release** so it can be installed with the Update button:
- Version 0.3.8 (assembly/file 0.3.8.0); the DEVELOPMENT label is removed from the title and header.
- Jobs and logs go back to the normal `%LOCALAPPDATA%\ClearCopy\Jobs` and `\Logs`, shared with the installed release. Jobs saved by the 0.3.6/0.3.7 development builds stay in their `-dev` folders and can be loaded manually.
- Starting the app with no arguments re-checks Explorer integration and the paste helper again, as 0.3.5.4 did. The development builds had switched this off.
- Do not resume a job saved by 0.3.8 in 0.3.5.4: the older version ignores the repair-only setting and lacks the newer-file protection.

## 0.3.7 (development) — Explorer Ctrl+V: 5-second countdown before starting

Choosing ClearCopy in the Ctrl+V paste chooser used to start the job as soon as the window opened. The window now shows "Starting in 5 s…" and counts down. **Any click or key press in the ClearCopy window stops the countdown**, and the job then starts only from **Start selected mode**, using whatever settings are selected at that moment. Left alone, it starts after 5 seconds as before. Other launch paths (`--resume-job --start`, the in-app Ctrl+V that only adds sources) are unchanged.

**Tests:** left alone, the countdown starts the job; a click stops it, nothing is written, the reason is shown, and Start then runs the job.

## 0.3.7 (development) — fix: false "Metadata difference" on permissions (pre-existing, also in 0.3.6)

**Problem.** With access permissions selected, Compare compared source and destination DACLs as raw SDDL text. Windows adds the auto-inherited control flag (`AI`) whenever a DACL is written through the current APIs, so a source whose DACL was written by older tools (common on older server shares) showed `D:(...)` against `D:AI(...)` at the destination with identical ACEs, and every such file and folder was reported as a metadata difference. Found when the suite ran in the user's `%TEMP%`, whose DACL has no `AI` flag. A side-by-side diagnostic showed 0.3.6 behaves identically: it fails in `%TEMP%` and passes in `C:\Users\Public`.

**Change.** `CopyEngine.ComparableDacl` removes only the `AI`/`AR` control flags before comparing. Every ACE (trustee, rights, inheritance flags) and the protected flag `P` (inheritance disabled) are still compared exactly. How permissions are copied is unchanged.

**Tests.** New unit check: AI/AR ignored; P, a different trustee and different rights still differ; a null DACL is unchanged. The existing metadata/DACL test and `TransferCheck` exercise the real case when run in `%TEMP%`.

## 0.3.7 (development) — fix 2: checkpoints are saved in the background

**Problem.** Every 30 seconds the whole job (every result row so far) was serialised to XML and flushed to disk **on the copy worker thread** (`QueueResult` → `SaveCheckpoint` → `Jobs.Save`). Copying stopped for the length of that write, and the write grows with the job: the 20 Oct job logged two rows per file, so by 100,000 files each save wrote about 200,000 rows. The pause showed up as "Waiting for file or network access" even when the network was fine.

**Change** (`MainWindow.cs`, `JobRecord.cs`):
- The worker now only takes a point-in-time snapshot (`JobRecord.Snapshot()` copies the lists, not the rows) and hands it to a single background writer. If a write is still running when the next one is due, only the newest snapshot is written.
- `currentJob.Completed` is guarded by a lock while rows are appended, cleared or snapshotted.
- Forced saves (job start, finish, cancel, error) still happen synchronously: they drop any older queued snapshot, wait for an in-progress write to finish, then write the final state before the job lock is released. The final checkpoint is never older than the last result.
- Writes stay atomic (temp file + replace, `Flush(true)`), as before. A failed background write still sets the "Job checkpoint incomplete" warning shown at the end of the job.

**Tests** (`Tests/CheckpointCheck.cs`): the existing throttling / periodic / forced / failed-save / recovery checks now wait for the background writer before reading the file. Added: with 300,000 rows, queuing a result while a checkpoint is due blocks the caller for a small fraction of a synchronous save; 20,000 results queued from another thread while background saves run all end up in memory and in the saved file, with no warning.

## 0.3.7 (development) — fix 1: cached link/junction checks on ancestor folders

**Problem.** Every path check (`SafePath`) read the attributes of the path and *every* folder above it. The engine runs about 6–8 checks per file across source and destination. On a deep UNC path such as `\\192.168.15.101\Data\dataam\...\IRP5IT3a\file.pdf` (about 10 levels), that is roughly 60–100 SMB metadata round trips per file before or around any data transfer, including for policy-skipped files. The 20 Oct 0.3.5.4 run (507,582 entries, about 75,000 processed in 25 hours) is consistent with this per-file overhead.

**Change.** `CopyEngine.CheckPath(path, forWrite)` replaces engine-internal calls to `SafePath`:
- **Write checks** (`forWrite: true`): before writing the temp file, before commit, when creating destination folders, and when applying metadata. These always walk the whole chain exactly as `SafePath` did. **Nothing that creates or changes destination content relies on the cache.**
- **Read-only checks** (scanning, skip decisions, hashing, Compare): re-read the path itself and its immediate parent every time; ancestors two or more levels up that were confirmed earlier in the same run are trusted.
- Folders that don't exist yet are never cached. The cache is cleared at the start of every `Plan` and every `Run`/`Repair`; the final-audit rescan uses its own engine.
- `PathAttributeReads` counts attribute reads made by `CheckPath`, for tests and diagnostics.
- The static `CopyEngine.SafePath` is unchanged (full walk) and is still used by cleanup, diagnostics and the existing safety harness.

**Measured effect** (engine compiled for .NET 8 and run on Linux with a portable attribute shim; 40 files, path depth 14; attribute reads per file):

| Scenario | 0.3.6 behaviour | 0.3.7 | Reduction |
|---|---:|---:|---:|
| Verified Copy, new files | 86.3 | 38.4 | 55% |
| Fast Copy, all skipped | 30.3 | 6.4 | 79% |
| Verified Copy, skipped + hashed (the 20 Oct job's mode) | 58.3 | 10.4 | 82% |

On SMB each read is a network round trip. Actual time saved on the NAS has **not** been measured.

**Trade-off.** If a folder two or more levels above a file is swapped for a junction *during* a run, a read-only check (skip decision, hash, compare) can look through it until the next run. Writes are not affected: a mid-run swap at the parent or grandparent is caught before any data is written (tests below).

**Tests added** (`Tests/Phase1Regression.cs`, 5 checks):
- Skipped files on a deep tree need fewer than (path depth) reads each.
- A junction at a deep destination ancestor still blocks the copy, and nothing is written through it.
- A parent folder swapped for a junction mid-run is caught before writing.
- A grandparent folder swapped for a junction mid-run is caught before writing.
- The cache does not carry over between runs.

The same scenarios, plus "source-side link is skipped at scan" and "newer destination still protected", passed 7/7 in the Linux harness (symlinks in place of junctions). **The Windows suite has not been compiled or run** — run `Tests/Run-Phase1.ps1` on Windows before using this build.

**Other.** Version strings bumped to 0.3.7 (title, assembly, job `Build`). Development data folder is now `%LOCALAPPDATA%\ClearCopy-0.3.7-dev`; jobs saved by 0.3.6-dev are not listed automatically and must be loaded manually if needed.

---

# 0.3.6 development — Phase 1 change log (previous)

## Correctness and mode changes

- `OperationMode.cs`, `JobRecord.cs`, `Jobs.GetMode/Load`: explicit FastCopy, VerifiedCopy and Compare modes; preserve schema 1 and derive modes from old Verify/CompareOnly flags. Original comparison roots/mapping are retained across subset repairs.
- `CopyEngine.Run/RunCore`: keep the legacy bool-based API as a compatibility wrapper; add the explicit mode API. Fast Copy bypasses verification-only checkpoint hashes and ordinary post-copy/skip hashing; Verified Copy and Compare retain SHA-256 checks.
- `CopyEngine.RunCore`, `OverwriteConflict.cs`: protect newer destinations independently of ExistingRule.Replace. Optional positive confirmation is scoped to one source/target observation. Source and destination stamps are rechecked after confirmation and before commit; existing destination-content protection hashes remain. Newer checkpoint matches cannot silently reset the destination timestamp.
- `CopyEngine.Repair`, `Jobs.RepairableRows/DifferenceEntries`: only missing/content-mismatched files enter content repair. Rehash existing candidates before writing so stale mismatches that now match are not recopied. Later errors/changes supersede older mismatches; separate metadata-difference rows do not hide a simultaneous content mismatch. Every copied repair is SHA-256 verified.
- `MainWindow.SyncDifferences/PrepareSelected`: Repair All no longer blindly forces all reported issues into replacement. Selected Repair always verifies, filters only confirmed content issues and rejects metadata/error-only selections. Persist the repair-only intent so resuming a saved repair reclassifies current content instead of becoming unconditional Replace. Final comparison retains unresolved repair outcomes. Whole-scope Compare is available after subset repair.
- `CopyEngine.CopyOne`: confirm that the source still matches the scanned/approved state before copying and at commit. Retain durable Flush(true), temporary-file cleanup, backups and fresh path/reparse checks.

## Low-risk performance changes

- `CopyEngine.Scratch`, `CopyOne`, `HashStream`: lazily allocate one 1 MiB scratch array per sequential engine and reuse it. For files below 1 MiB, reduce the destination FileStream internal buffer to 4 KiB; larger files retain 1 MiB buffering. Transfer chunks and durable flushes are unchanged. This addresses the additional per-file allocation found in the first benchmark.
- `CopyEngine.RunCore`: reuse the successful current checkpoint hash observation for the normal verification result, with fresh state checks and the final audit. Do not perform a second successful pair hash.
- Directory creation: avoid CreateDirectory for already-existing planned directories and avoid repeatedly creating a prepared parent. This tracks creation only; it does not cache path safety. A new explicit file/directory collision check preserves the rejection formerly provided by CreateDirectory.
- `SafeLogFile`: batch ordinary log flushing at 64 lines, 65,536 characters, or a one-second timer. Errors/results/cancellation and explicit finalization flush pending text. Synchronize timer and worker access; retain error reporting. Transfer/checkpoint durable flushes are unchanged.
- UI progress still coalesces into the latest update and renders on its existing 200 ms timer. No parallel file processing, checkpoint database or streaming architecture was introduced.

## Reporting and development isolation

- `ItemResult`: descriptive display/verification states while retaining legacy raw statuses. CSV appends DisplayStatus and VerificationState after the original seven columns.
- `Result/Update/MainWindow`: protected-newer and not-reached states/counters; cancellation records unvisited files and marks the active file unresolved. Protected conflicts prevent a clean result. Copy completion remains distinct from verification completion.
- Original metadata application ordering remains. A proposed ordering change was rejected because restrictive parent DACLs can block child creation. The baseline Archive-bit edge case is documented and tested for visibility through Compare.
- Version is 0.3.6 (assembly/file version 0.3.6.0), visibly marked DEVELOPMENT. Development log/job directories are separate. Default automatic Explorer registration/helper restart is disabled so opening this build does not replace release integration.
- `Source/Build.ps1` supports an explicit standalone compiler path when no SDK is installed. Existing SDK build behavior remains available. No compiler/runtime installation or production deployment is performed.

## Regression coverage

Added `Phase1Regression.cs`, a fixture saved using the original 0.3.5.4 serializer, a reproducible test runner and a shared before/after benchmark harness. The copied `SafetyCheck` fixture sets an older destination timestamp so its concurrent-commit test reaches that guard under the corrected newer-file policy. The release's original test/source files were not changed.

## Remaining Phase 2 work

1. Measure real SMB/NAS operation latency, calls/round trips, flush times, throughput and memory using disposable network fixtures approved separately.
2. Redesign metadata-only repair and the cleared-Archive/DACL edge case without breaking restrictive permissions or protected-newer policies.
3. Address whole-job XML rewrite cost, retained plans/results and UI collection growth; consider incremental persistence and streaming only in the next approved phase.
4. Replace byte-only ETA with phase/file/byte estimates, including audit, metadata and finalization time.
5. Add stage-aware retry/commit reconciliation, classified backoff and outage scheduling control. Evaluate cancellation of in-flight I/O without launching competing retries.
6. Refactor shared state before evaluating bounded per-endpoint file concurrency. Keep safety/durability guards and benchmark 1/2/4/8 workers under actual NAS conditions.
## 0.3.8 — release build

0.3.8 is everything listed below under 0.3.7 (fix 1 path checks, fix 2 background checkpoints, the permissions-compare fix, the Ctrl+V countdown), built as a **release** so it can be installed with the Update button:
- Version 0.3.8 (assembly/file 0.3.8.0); the DEVELOPMENT label is removed from the title and header.
- Jobs and logs go back to the normal `%LOCALAPPDATA%\ClearCopy\Jobs` and `\Logs`, shared with the installed release. Jobs saved by the 0.3.6/0.3.7 development builds stay in their `-dev` folders and can be loaded manually.
- Starting the app with no arguments re-checks Explorer integration and the paste helper again, as 0.3.5.4 did. The development builds had switched this off.
- Do not resume a job saved by 0.3.8 in 0.3.5.4: the older version ignores the repair-only setting and lacks the newer-file protection.

## 0.3.7 (development) — Explorer Ctrl+V: 5-second countdown before starting

Choosing ClearCopy in the Ctrl+V paste chooser used to start the job as soon as the window opened. The window now shows "Starting in 5 s…" and counts down. **Any click or key press in the ClearCopy window stops the countdown**, and the job then starts only from **Start selected mode**, using whatever settings are selected at that moment. Left alone, it starts after 5 seconds as before. Other launch paths (`--resume-job --start`, the in-app Ctrl+V that only adds sources) are unchanged.

**Tests:** left alone, the countdown starts the job; a click stops it, nothing is written, the reason is shown, and Start then runs the job.

## 0.3.7 (development) — fix: false "Metadata difference" on permissions (pre-existing, also in 0.3.6)

**Problem.** With access permissions selected, Compare compared source and destination DACLs as raw SDDL text. Windows adds the auto-inherited control flag (`AI`) whenever a DACL is written through the current APIs, so a source whose DACL was written by older tools (common on older server shares) showed `D:(...)` against `D:AI(...)` at the destination with identical ACEs, and every such file and folder was reported as a metadata difference. Found when the suite ran in the user's `%TEMP%`, whose DACL has no `AI` flag. A side-by-side diagnostic showed 0.3.6 behaves identically: it fails in `%TEMP%` and passes in `C:\Users\Public`.

**Change.** `CopyEngine.ComparableDacl` removes only the `AI`/`AR` control flags before comparing. Every ACE (trustee, rights, inheritance flags) and the protected flag `P` (inheritance disabled) are still compared exactly. How permissions are copied is unchanged.

**Tests.** New unit check: AI/AR ignored; P, a different trustee and different rights still differ; a null DACL is unchanged. The existing metadata/DACL test and `TransferCheck` exercise the real case when run in `%TEMP%`.

## 0.3.7 (development) — fix 2: checkpoints are saved in the background

**Problem.** Every 30 seconds the whole job (every result row so far) was serialised to XML and flushed to disk **on the copy worker thread** (`QueueResult` → `SaveCheckpoint` → `Jobs.Save`). Copying stopped for the length of that write, and the write grows with the job: the 20 Oct job logged two rows per file, so by 100,000 files each save wrote about 200,000 rows. The pause showed up as "Waiting for file or network access" even when the network was fine.

**Change** (`MainWindow.cs`, `JobRecord.cs`):
- The worker now only takes a point-in-time snapshot (`JobRecord.Snapshot()` copies the lists, not the rows) and hands it to a single background writer. If a write is still running when the next one is due, only the newest snapshot is written.
- `currentJob.Completed` is guarded by a lock while rows are appended, cleared or snapshotted.
- Forced saves (job start, finish, cancel, error) still happen synchronously: they drop any older queued snapshot, wait for an in-progress write to finish, then write the final state before the job lock is released. The final checkpoint is never older than the last result.
- Writes stay atomic (temp file + replace, `Flush(true)`), as before. A failed background write still sets the "Job checkpoint incomplete" warning shown at the end of the job.

**Tests** (`Tests/CheckpointCheck.cs`): the existing throttling / periodic / forced / failed-save / recovery checks now wait for the background writer before reading the file. Added: with 300,000 rows, queuing a result while a checkpoint is due blocks the caller for a small fraction of a synchronous save; 20,000 results queued from another thread while background saves run all end up in memory and in the saved file, with no warning.

## 0.3.7 (development) — fix 1: cached link/junction checks on ancestor folders

**Problem.** Every path check (`SafePath`) read the attributes of the path and *every* folder above it. The engine runs about 6–8 checks per file across source and destination. On a deep UNC path such as `\\192.168.15.101\Data\dataam\...\IRP5IT3a\file.pdf` (about 10 levels), that is roughly 60–100 SMB metadata round trips per file before or around any data transfer, including for policy-skipped files. The 20 Oct 0.3.5.4 run (507,582 entries, about 75,000 processed in 25 hours) is consistent with this per-file overhead.

**Change.** `CopyEngine.CheckPath(path, forWrite)` replaces engine-internal calls to `SafePath`:
- **Write checks** (`forWrite: true`): before writing the temp file, before commit, when creating destination folders, and when applying metadata. These always walk the whole chain exactly as `SafePath` did. **Nothing that creates or changes destination content relies on the cache.**
- **Read-only checks** (scanning, skip decisions, hashing, Compare): re-read the path itself and its immediate parent every time; ancestors two or more levels up that were confirmed earlier in the same run are trusted.
- Folders that don't exist yet are never cached. The cache is cleared at the start of every `Plan` and every `Run`/`Repair`; the final-audit rescan uses its own engine.
- `PathAttributeReads` counts attribute reads made by `CheckPath`, for tests and diagnostics.
- The static `CopyEngine.SafePath` is unchanged (full walk) and is still used by cleanup, diagnostics and the existing safety harness.

**Measured effect** (engine compiled for .NET 8 and run on Linux with a portable attribute shim; 40 files, path depth 14; attribute reads per file):

| Scenario | 0.3.6 behaviour | 0.3.7 | Reduction |
|---|---:|---:|---:|
| Verified Copy, new files | 86.3 | 38.4 | 55% |
| Fast Copy, all skipped | 30.3 | 6.4 | 79% |
| Verified Copy, skipped + hashed (the 20 Oct job's mode) | 58.3 | 10.4 | 82% |

On SMB each read is a network round trip. Actual time saved on the NAS has **not** been measured.

**Trade-off.** If a folder two or more levels above a file is swapped for a junction *during* a run, a read-only check (skip decision, hash, compare) can look through it until the next run. Writes are not affected: a mid-run swap at the parent or grandparent is caught before any data is written (tests below).

**Tests added** (`Tests/Phase1Regression.cs`, 5 checks):
- Skipped files on a deep tree need fewer than (path depth) reads each.
- A junction at a deep destination ancestor still blocks the copy, and nothing is written through it.
- A parent folder swapped for a junction mid-run is caught before writing.
- A grandparent folder swapped for a junction mid-run is caught before writing.
- The cache does not carry over between runs.

The same scenarios, plus "source-side link is skipped at scan" and "newer destination still protected", passed 7/7 in the Linux harness (symlinks in place of junctions). **The Windows suite has not been compiled or run** — run `Tests/Run-Phase1.ps1` on Windows before using this build.

**Other.** Version strings bumped to 0.3.7 (title, assembly, job `Build`). Development data folder is now `%LOCALAPPDATA%\ClearCopy-0.3.7-dev`; jobs saved by 0.3.6-dev are not listed automatically and must be loaded manually if needed.

---

# 0.3.6 development — Phase 1 change log (previous)

## Correctness and mode changes

- `OperationMode.cs`, `JobRecord.cs`, `Jobs.GetMode/Load`: explicit FastCopy, VerifiedCopy and Compare modes; preserve schema 1 and derive modes from old Verify/CompareOnly flags. Original comparison roots/mapping are retained across subset repairs.
- `CopyEngine.Run/RunCore`: keep the legacy bool-based API as a compatibility wrapper; add the explicit mode API. Fast Copy bypasses verification-only checkpoint hashes and ordinary post-copy/skip hashing; Verified Copy and Compare retain SHA-256 checks.
- `CopyEngine.RunCore`, `OverwriteConflict.cs`: protect newer destinations independently of ExistingRule.Replace. Optional positive confirmation is scoped to one source/target observation. Source and destination stamps are rechecked after confirmation and before commit; existing destination-content protection hashes remain. Newer checkpoint matches cannot silently reset the destination timestamp.
- `CopyEngine.Repair`, `Jobs.RepairableRows/DifferenceEntries`: only missing/content-mismatched files enter content repair. Rehash existing candidates before writing so stale mismatches that now match are not recopied. Later errors/changes supersede older mismatches; separate metadata-difference rows do not hide a simultaneous content mismatch. Every copied repair is SHA-256 verified.
- `MainWindow.SyncDifferences/PrepareSelected`: Repair All no longer blindly forces all reported issues into replacement. Selected Repair always verifies, filters only confirmed content issues and rejects metadata/error-only selections. Persist the repair-only intent so resuming a saved repair reclassifies current content instead of becoming unconditional Replace. Final comparison retains unresolved repair outcomes. Whole-scope Compare is available after subset repair.
- `CopyEngine.CopyOne`: confirm that the source still matches the scanned/approved state before copying and at commit. Retain durable Flush(true), temporary-file cleanup, backups and fresh path/reparse checks.

## Low-risk performance changes

- `CopyEngine.Scratch`, `CopyOne`, `HashStream`: lazily allocate one 1 MiB scratch array per sequential engine and reuse it. For files below 1 MiB, reduce the destination FileStream internal buffer to 4 KiB; larger files retain 1 MiB buffering. Transfer chunks and durable flushes are unchanged. This addresses the additional per-file allocation found in the first benchmark.
- `CopyEngine.RunCore`: reuse the successful current checkpoint hash observation for the normal verification result, with fresh state checks and the final audit. Do not perform a second successful pair hash.
- Directory creation: avoid CreateDirectory for already-existing planned directories and avoid repeatedly creating a prepared parent. This tracks creation only; it does not cache path safety. A new explicit file/directory collision check preserves the rejection formerly provided by CreateDirectory.
- `SafeLogFile`: batch ordinary log flushing at 64 lines, 65,536 characters, or a one-second timer. Errors/results/cancellation and explicit finalization flush pending text. Synchronize timer and worker access; retain error reporting. Transfer/checkpoint durable flushes are unchanged.
- UI progress still coalesces into the latest update and renders on its existing 200 ms timer. No parallel file processing, checkpoint database or streaming architecture was introduced.

## Reporting and development isolation

- `ItemResult`: descriptive display/verification states while retaining legacy raw statuses. CSV appends DisplayStatus and VerificationState after the original seven columns.
- `Result/Update/MainWindow`: protected-newer and not-reached states/counters; cancellation records unvisited files and marks the active file unresolved. Protected conflicts prevent a clean result. Copy completion remains distinct from verification completion.
- Original metadata application ordering remains. A proposed ordering change was rejected because restrictive parent DACLs can block child creation. The baseline Archive-bit edge case is documented and tested for visibility through Compare.
- Version is 0.3.6 (assembly/file version 0.3.6.0), visibly marked DEVELOPMENT. Development log/job directories are separate. Default automatic Explorer registration/helper restart is disabled so opening this build does not replace release integration.
- `Source/Build.ps1` supports an explicit standalone compiler path when no SDK is installed. Existing SDK build behavior remains available. No compiler/runtime installation or production deployment is performed.

## Regression coverage

Added `Phase1Regression.cs`, a fixture saved using the original 0.3.5.4 serializer, a reproducible test runner and a shared before/after benchmark harness. The copied `SafetyCheck` fixture sets an older destination timestamp so its concurrent-commit test reaches that guard under the corrected newer-file policy. The release's original test/source files were not changed.

## Remaining Phase 2 work

1. Measure real SMB/NAS operation latency, calls/round trips, flush times, throughput and memory using disposable network fixtures approved separately.
2. Redesign metadata-only repair and the cleared-Archive/DACL edge case without breaking restrictive permissions or protected-newer policies.
3. Address whole-job XML rewrite cost, retained plans/results and UI collection growth; consider incremental persistence and streaming only in the next approved phase.
4. Replace byte-only ETA with phase/file/byte estimates, including audit, metadata and finalization time.
5. Add stage-aware retry/commit reconciliation, classified backoff and outage scheduling control. Evaluate cancellation of in-flight I/O without launching competing retries.
6. Refactor shared state before evaluating bounded per-endpoint file concurrency. Keep safety/durability guards and benchmark 1/2/4/8 workers under actual NAS conditions.
