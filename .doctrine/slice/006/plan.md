# Implementation Plan SL-006: Redistribution maintenance

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

Seven phases, bottom-up along ADR-003's layers: the core plan and file
checks, the grouped write, the command flow's clean path with normalise
as its first entrance, the flow's failure paths, the Move/view/Continue
handoffs, the Add handoff, then README and the human trial. Execution
order is the array order in `plan.toml`: 01, 02, 03, 07, 04, 05, 06.
PHASE-07 was split out of PHASE-03 at plan revision; ids are immutable,
so it keeps the next free number. The canonical reference is `design.md` (locked, run
rev 35); criteria cite its sections rather than restate them. Every phase
leaves `just gate` green, so each boundary is a clean stopping point.

```
01 core plan + ─▶ 02 grouped ─▶ 03 flow (clean) ─▶ 07 flow   ─▶ 04 Move / view / ─▶ 05 Add ─▶ 06 README
   file checks      write +       + normalise         failure      Continue           handoff    + trial
                    consent save                      paths        handoffs
```

## Sequencing & Rationale

- **PHASE-01 and PHASE-02, the lower layers first.** The flow needs a
  plan, the file checks and a grouped write before it can be tested end
  to end. Both phases change no command behaviour, and the existing
  put-rank and delete-rank suites are the regression guard for the
  generalised write path (design principle 5). They are split because
  the grouped apply is the riskiest change in the lower layers (markers
  across a change group, the save owner), and deserves its own green
  boundary.
- **PHASE-03, the flow through normalise.** Normalise is the simplest
  entrance: no pending operation, no handoff, no joining token. It
  exercises the whole flow (preview, prompt, recheck, consent saves,
  apply, partition, quit) without touching any existing command, so the
  flow's large test set lands against a stable caller. The test helpers
  and their self-tests come first in this phase because every flow test
  uses them. `--refuse-no-room`'s text can name `org-iw-normalise` here
  because the command now exists; the paths that still refuse keep
  passing, as their tests build the expected text through
  `org-iw-cmd-test--no-room`.
- **PHASE-07, the failure paths after a yes.** Partition, consent-save
  failures, the fourth report group and the quit rule (RV-014 F-5, F-6,
  F-14, F-17) are the subtlest part of the flow and carry most of its
  tests. Splitting them from PHASE-03 keeps each phase reviewable and
  lets the clean path settle first. They precede the handoffs because
  PHASE-04's "no visit after a failed redistribution" (REQ-020 AC2)
  needs them.
- **PHASE-04, the --move handoffs.** One branch in `--move` serves Move,
  Continue and the four view moves. RV-014 F-8 (Continue's new head)
  and DEC-038 (report before visit) are both in `--continue-place`, so
  they land together. The view's placement functions (D8) are the only
  signature change to `--move`.
- **PHASE-05, the Add handoff last.** It carries the most new shape: the
  joining token, the extracted joinability check, and re-homing an
  indirect-buffer marker (D9). Kept separate so a defect in it cannot
  hold up the move handoffs. This also matches the design's fallback
  split (§ 8): (a) phases 01–03 and 07, (b) phases 04–05.
- **PHASE-06, README then trial.** The trial needs the documented
  behaviour; defects found are fixed in the phase or backlogged with the
  user's agreement. inq-11 (DEC-009 default placement) is weighed at the
  trial.

## Notes

- **Existing no-room tests.** Nine tests assert the no-room refusal on
  paths that now prompt (design § 10). Each is rewritten in the phase
  that changes its path (PHASE-04: Move, Continue, view; PHASE-05: Add),
  not up front, so every phase ends green.
- **Governance at reconcile, not here.** REV-007 (ADR-002 save policy,
  REQ-021 AC2), the DEC-036 wording for unlabelled Add, and the other
  design § 6 follow-ups are reconcile's work. No phase edits governance.
- **Testing a quit.** ERT's `should-error` does not catch `quit` (it is
  not an error; the test ends as QUIT). PHASE-07's quit tests use
  `condition-case` with a `quit` handler. Checked in batch Emacs 31 on
  2026-10-07.
- **Out of scope here:** ISS-007 (batch add's quit rule), IMP-011 (keyed
  preview), IDE-001 (refreshing other views).
