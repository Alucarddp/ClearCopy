# ClearCopy roadmap

Ideas taken from comparing ClearCopy with TeraCopy (4.0.5) and Total Commander (Oct 2026). Ordered by value for big migrations and daily copies. Tick items off as versions ship.

## Done
- [x] **0.4.4** Read source and destination at the same time during checks (different drives/shares).
- [x] **0.4.5** Source SHA-256 taken while copying (TeraCopy): a copied file is checked by reading only the destination.
- [x] **0.4.5** Destination check reads past the Windows cache (Total Commander), so it proves what is on the NAS/disk, not in memory.
- [x] **0.4.6** Several files at once (TeraCopy threads): Files at once option, default 4.
- [x] **0.4.6** Whole-job breakdown and Show filter in Results.

## Next
1. **Read locked files without changing permissions** (Total Commander "As Administrator", TeraCopy elevated service). Elevated helper with backup privilege; Fix access becomes the fallback.
2. **Files in use** (TeraCopy: Volume Shadow Copy). Copy open PSTs/databases from a shadow copy.
3. **Checksum files and later re-verification** (TeraCopy). Write a .sha256 list with the copy; re-check the destination later without the source.

## Later / small
- Job queue and history (run several jobs one after another).
- Ignore list (Thumbs.db, desktop.ini, ~$*.docx Office lock files).
- Speed graph.
- Run a script when a job finishes.
- Plain message for "network not responding" during a cable pull (Windows holds I/O ~60 s before reporting an error).

## Not planned
- Full file manager (Total Commander), secure delete, copying to several destinations at once.

## Before a wider release (techs at work)
- Code signing, a short user guide, and a build setup that does not depend on Claude's build container.
