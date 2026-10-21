# ClearCopy 0.3.9.1

0.3.9.1 fixes a stray dash next to the lightbulb. 0.3.9 adds a slimmer window, clickable counts and a compact view to 0.3.8. 0.3.8 is a release build of the 0.3.7 work: fix 1 (cached ancestor link/junction checks), fix 2 (background checkpoint saves), the permissions-compare fix and the Explorer Ctrl+V countdown. The exe is `..\ClearCopy-0.3.9.1.exe` (see `build-log.txt`). Run `Run-Tests.cmd` to run the full regression suite against it; results go to `test-log.txt`. See `CHANGELOG.md`. The 0.3.6 test, benchmark and review documents below describe 0.3.6.


This is a separate development copy of the reconstructed ClearCopy 0.3.5.4 source. It is for review and disposable local testing. It has not been deployed, registered with Explorer or tested against production shares. The existing release is unchanged.

## Modes

Choose the operating mode in the main progress card, then click **Start selected mode**. Overwrite and metadata settings are under **Operating mode and copy options**.

- **Fast Copy:** Copies missing and policy-eligible changed files. Size/time skips and successful copies remain **Not Verified**. Historical checkpoint hashes do not force verification or certify a Fast Copy skip. Existing overwrite-protection hashing still runs when replacing content.
- **Verified Copy:** Preserves the existing copy/skip/SHA-256 workflow. A successfully revalidated checkpoint uses one source/destination hash pair rather than two. Final source audit and post-verification state checks remain.
- **Compare / Repair:** Start with a fresh, read-only SHA-256 comparison of the selected scope. **Repair all content differences** or **Repair selected content differences** recheck only confirmed missing/content-mismatched files, then verify repaired content. Metadata-only, changed and inaccessible results require separate review and are not converted into content repairs.

**Compare original scope** remains available after selected repairs. Repair All also performs an independent final comparison of the original selection. Extra destination files are left in place.

## Newer destinations

Every write mode protects newer destination files, including when the overwrite rule is **Replace existing files**. To permit an exception, enable **Ask before replacing newer destinations**, then explicitly confirm each individual conflict. The prompt defaults to No. A confirmation applies only to the observed source/target pair; state is checked again before commit. Permission is never saved in a job or reused after loading one. Skip policies still take precedence; choose Replace when requesting an exception to a skip-newer policy.

Newer destinations are not subjected to per-file timestamp/attribute application merely because a checkpoint hash matched. Recovery backups, sibling temporary files, overwrite-protection hashes, path/reparse checks and durable data flushes remain.

## Results and compatibility

The result grid exposes Copied — Not Verified, Policy Skipped — Not Verified, SHA-256 Matched, Content Mismatch, Missing, Protected Newer Destination, Changed During Operation, Failed / Inaccessible and Not Reached. Copy and skip rows describe actions; a later Matched row records verification. Counts are operations/checks and can overlap for a path.

Schema-1 jobs remain supported. Old CompareOnly/Verify flags map to the explicit modes. Legacy machine Status values and the first seven CSV columns are retained; two descriptive columns are appended. Do not resume new jobs in 0.3.5.4: older versions ignore repair-only intent and lack the new overwrite protections. Do not resume the same job concurrently in different versions.

Development logs and checkpoints use `%LOCALAPPDATA%\ClearCopy`, separate from release data. Default startup no longer automatically registers the development executable with Explorer or restarts the existing paste helper. Do not use the manual installation/integration actions for this development build.

## Build and local tests

Windows x64 and .NET Framework 4.8 are required. With a suitable .NET SDK, run `Source/Build.ps1`. Where only the framework is installed, the build script also supports `-CompilerPath` pointing to Microsoft's standalone C# compiler (C# 14 support required). The compiler is not bundled with this source package.

`Tests/Run-Phase1.ps1` accepts `-CompilerPath` and `-TestRoot` (a new disposable directory on a fixed local drive). It compiles/runs the Phase 1 regression suite and the existing transfer, safety and checkpoint harnesses. Its local junction fixture may require execution permissions beyond a restricted sandbox. Fixtures are retained for inspection; the runner does not delete sources or fixture trees.

`Tests/Run-Benchmark.ps1` accepts compiler, baseline/development application paths, and a new local test root. The baseline must be built from an untouched copy of the 0.3.5.4 source. Default measurements use 512 files of 1 KiB in eight directories, three measured rounds, an excluded 64-file warm-up round and alternating version order. The same benchmark source is compiled against each application.

See `CHANGELOG.md`, `TEST-RESULTS.md` and `BENCHMARK-RESULTS.md` for changes, measured evidence and limitations. The executable, if validation succeeds, is supplied separately under `executable/`.

## Known limits and approval boundary

The architecture is intentionally still sequential and in memory. Full XML checkpoint rewrites and the existing approximate byte-based ETA remain. Cancellation takes effect when blocking filesystem I/O returns. Data/metadata observations are not a filesystem snapshot.

The original metadata application order is retained to avoid blocking child copies with restrictive parent DACLs. An inherited edge case remains: applying an inherited DACL can set a destination's Archive bit when the source had cleared it. Independent Compare reports that as a metadata difference; content equality remains separate. No automatic metadata-only repair action is added in Phase 1.

Owner, audit rules and alternate streams remain outside the supported metadata scope. Actual SMB/NAS throughput, disconnect recovery and server metadata behavior require separate testing. Production rollout requires explicit approval.
