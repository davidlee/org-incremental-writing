# Implementation Plan SL-002: Placement and vocabulary

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

Six phases, bottom-up along ADR-003: core, command rewiring, configuration,
Continue, Add, then the human trial. The canonical reference is `design.md`
(locked, run dr-01a0f578); criteria cite its sections rather than restating
them. Every phase leaves `just gate` and `just test-each` green, so each
boundary is a clean stopping point and a dispatch hand-off.

Execution order is the TOML array order: PHASE-01, 02, 03, 04, 06, 05. The
Continue/Add split came after the first draft had authored PHASE-05 as the
trial, so the Add phase took the next free id rather than renumbering.

## Sequencing & Rationale

- **PHASE-01, core first.** Pure, fastest to TDD, and the property test is
  the slice's main correctness instrument (RV-003 F-4). Deleting
  `org-iw-core-append-rank` here satisfies POL-002 at once. The command
  wrapper `org-iw--append-rank` survives one phase as a thin call to
  `rank-at`, so no command test changes yet.
- **PHASE-02, rewire before adding features.** Continue and Add go through
  `place` with placement `end`, which is SL-001's behaviour. That isolates
  the structural change (the `unchanged` outcome replaces the last-entry
  check, plus the new helpers and the empty-queue report) from the
  vocabulary. The interim wrapper and `org-iw--move-to-end` are deleted
  here, so the codebase never holds two refusal owners. Continue's success
  messages are kept until PHASE-04, so SL-001's expectations change only
  once (RV-003 F-9). The no-room refusal takes its final form now: "the end"
  is its lasting WHERE for a plain Add.
- **PHASE-03, configuration without callers.** The vocabulary is the
  biggest refusal surface (RV-003 F-6). Testing it at helper level first
  keeps the command tests in PHASE-04 and 06 about interaction, not config
  shapes. The recorder extension lands here with its first user and its
  self-test (STD-001 item 2).
- **PHASE-04 Continue, PHASE-06 Add.** Split for size and to give dispatch
  clean boundaries. Continue is the main path and carries the trial-critical
  cases (RV-003 F-3, F-7, F-8). Add reuses everything and adds only the
  pre-scan resolution (F-2) and the amended prompt default (F-5). README goes
  with Add, the last surface change.
- **PHASE-05 last.** The POL-003 trial needs the whole surface.

### RV-003 routing

No RV-003 finding carries a `demonstrate`, `probe` or `control` route, so
none needs transcribing. The findings fixed in prose are still pinned by
criteria: F-2 → PHASE-06/EX-2; F-3 → PHASE-04/EX-4; F-4 → PHASE-01/EX-4;
F-5 → PHASE-06/EX-3; F-6 → PHASE-03/EX-3; F-7 → PHASE-04/EX-3 and
PHASE-06/EX-3; F-8 → PHASE-04/EX-5; F-9 → PHASE-02/EX-2 and PHASE-04/EX-2;
F-1 → PHASE-03/EX-5 and PHASE-05/VH-1.

## Notes

- **Emacs 30 has no `completion-table-with-metadata`** (checked: 31.1 has
  it, 30.2 doesn't; Package-Requires is 30.1). The chooser table is a
  hand-written function table (PHASE-03/EX-5).
- **Mutation.** STD-001 item 3 runs ad hoc under `/home/scratch` per phase
  until CHR-001 lands a recipe. Results go in the phase sheet and are lifted
  to notes.md at harvest.
- **Interim states.** After PHASE-01, `org-iw--append-rank` is a one-line
  delegate to `rank-at`. After PHASE-02, Continue's messages still say
  "end". Both are deliberate and short-lived.
- **Out of scope**, per the slice: Remove in the chooser (SL-003),
  document targets and IMP-002 (SL-004), redistribution (SL-006). ISS-001's
  put-rank half stays open. PRD-001 OQ-3's text is updated at reconcile.
