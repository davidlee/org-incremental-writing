# Implementation Plan SL-003: Queue view and membership ops

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

Eight phases, bottom-up along ADR-003's layers: core and discovery, write,
command helpers, Move, Remove, the view in two halves, then the human trial.
The canonical reference is `design.md` (locked, run dr-01a0fedb); criteria
cite its sections rather than restating them. Every phase leaves `just gate`
and `just test-each` green, so each boundary is a clean stopping point and
a dispatch hand-off.

```
PHASE-01 core+discovery ─┐
PHASE-02 write ──────────┼─▶ PHASE-03 helpers ─▶ 04 Move ─▶ 05 Remove ─▶ 06 view ─▶ 07 view ops ─▶ 08 trial
                         │   (behaviour-preserving)                      display     + README
```

## Sequencing & Rationale

- **PHASE-01, core and discovery first.** Pure and fast to TDD. `beside`
  and `step` carry the slice's one property test, the main instrument for
  "no new rank arithmetic" (I10′). The outline field is a struct change
  read by discovery; landing it now keeps PHASE-06 about display.
- **PHASE-02, the write verb alone.** The highest-stakes change (STD-003
  scales the pre-close roster for it). Isolating it keeps the I11
  whole-file test and the rollback cases out of command-level noise.
- **PHASE-03, helpers before features.** Same tactic as SL-002 PHASE-02:
  route existing Add, Continue and visit-next through the new shared
  helpers (`--target-at-point`, `--find-entry`, `--read-queue`,
  `--refuse-absent`, `--move`) with no new commands. A helper whose first
  caller is a later command lands with that command instead (PHASE-03/EX-3),
  so no phase ends with dead code. The reworded no-room
  and absence texts change their expectations once, here. Every later
  phase then adds a command on top of one owner per concept (POL-002), and
  the I14 grep ("one placer") is checkable before any new caller exists.
- **PHASE-04 Move, PHASE-05 Remove.** Split for size. Move is the smaller
  and exercises `--membership-queue` and `--move` from a new caller.
  Remove carries the session-hint rule, Continue's chooser change and the
  label reservation, all sharing `--delete-rank`.
- **PHASE-06 and PHASE-07, the view in two halves.** Display, open and
  refresh first: the redraw helper and its window-point handling are the
  riskiest view code (RV-005 F-1) and are proven before any action builds
  on them. Reorder, mark, D and the `y-or-n-p` recorder follow; the mark's
  survival across `g` (RV-005 F-2) is tested where the mark exists. README
  goes with the last surface change.
- **PHASE-08 last.** The POL-003 trial needs the whole surface.

### RV-005 routing

Two findings carry an instrument route, `probe`, and are transcribed as
criteria with a negative control each:

- F-1 (view window point after RET) → PHASE-06/EX-4, VT-2.
- F-2 (mark wiped by `g`) → PHASE-07/EX-4, VT-3.

Their terminal verify happens after `slice phases`, against those criteria.

Findings fixed in prose are still pinned by criteria: F-3 → PHASE-02/EX-3;
F-4 → PHASE-05/EX-3; F-5 → PHASE-05/EX-1; F-6 →
PHASE-03/EX-5; F-7 → PHASE-07/EX-5; F-8 → PHASE-07/EX-3; F-10 →
PHASE-03/EX-2; F-12, F-20 → PHASE-03/VA-1; F-13 → PHASE-08/VH-1; F-14 →
PHASE-07/EX-2; F-15 → PHASE-01/EX-2; F-16 → PHASE-05/EX-4; F-17 →
PHASE-04/EX-4, PHASE-05/EX-1; F-18, F-19 → PHASE-06/EX-3. F-9 (test-plan
gaps) is spread across the phases' test lists. F-11 is a follow-up: a REV
qualifying REQ-013 AC2 at reconcile, not a phase.

## Notes

- **F-1's probe runs in batch.** Checked while planning: in `emacs
  --batch` (30 and 31), `tabulated-list-print` on a buffer shown in an
  unselected window resets that window's point to 1 while the buffer's
  point stays. So the PHASE-06 test can reproduce the defect, and its
  negative control is real.

- **Test file size.** `test/org-iw-test.el` is ~1,600 lines and gains the
  Move, Remove and view tests. STD-004 mirrors tests to sources, so they
  stay there; a split (e.g. a view test file) would need a STD-004 change.
  Candidate improvement, not in scope.
- **Mutation passes** stay ad hoc per phase until CHR-001.
- **VT keywords** name functions under test or planned test names (STD-002
  item 1). Where a planned test name is the only new keyword, the worker
  may rename the test and re-key the VT by the append rule (item 3).
