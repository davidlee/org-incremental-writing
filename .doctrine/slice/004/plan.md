# Implementation Plan SL-004: Documents and batch add

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

Seven phases, bottom-up along ADR-003's layers: tooling, discovery
identity, write, the single-file commands, batch, README, then the human
trial. The canonical reference is `design.md` (locked); criteria cite its
sections rather than restating them. Every phase leaves `just gate` and
`just test-each` green, so each boundary is a clean stopping point.

```
01 tooling ─▶ 02 discovery identity ─▶ 03 write ─▶ 04 Add / Add-document ─▶ 05 batch ─▶ 06 README ─▶ 07 trial
   (Denote      (document-id, slot-p,     (:document,   (--add-entry, the       (fold over
    on -L)       id-positions, tally)      drawer rule)  one add step)           --add-entry)
```

## Sequencing & Rationale

- **PHASE-01, tooling first.** The Denote-route tests need Denote under
  `-Q` on both binaries; 31's site-lisp has it, 30's doesn't. Doing this
  first means every later Denote-route test runs on both from the moment it
  is written, rather than passing on 31 and silently skipping on 30. The
  end-to-end proof lands with the first such tests (PHASE-02/EX-8).
- **PHASE-02, identity before anything writes.** Identity is the slice's
  load-bearing change: every reader (scan, tally, resolve, Add's checks)
  must agree through one owner (POL-002, design § 4.2). Changing
  `entry-id`'s signature touches existing callers, so it lands where the
  full heading suite proves nothing else moved. `--title` goes public here
  because PHASE-04's ENTRY construction needs it (RV-012 F-7).
- **PHASE-03, the write alone.** Drawer insertion in a heading-first file
  and the document drawer-removal rule are the riskiest edits (RV-012 F-1,
  F-2); isolating them keeps the I3 byte-identity and undo cases out of
  command noise. The Denote-document Remove test sits here because it is
  the delete rule's end-to-end proof and needs no new command.
- **PHASE-04, one add step.** `--add-entry` replaces `--check-heading`
  and Add's body before any new caller, then Add-document is a thin
  command over it. The batch then has exactly one step to fold.
- **PHASE-05, batch.** Largest phase: selection, the fold, the buffer
  rule, the report and the cost rules. Kept whole because its parts share
  one fold and one fixture set; split by the phase planner if the sheet
  grows past a session.
- **PHASE-06 README, PHASE-07 trial.** README after the last surface
  change (CHR-003). The trial needs the whole surface (POL-003).

### RV-012 mapping

No finding carries an instrument route (`demonstrate`/`probe`/`control`),
so nothing is transcribed as a probe. Findings fixed in prose are pinned by
criteria: F-1 → PHASE-03/EX-3, EX-5; F-2 → PHASE-03/EX-1; F-3 →
PHASE-02/EX-3, VA-1; F-4 → PHASE-02/EX-2; F-5 → PHASE-05/EX-3; F-6 →
PHASE-03/EX-2, PHASE-04/EX-3, PHASE-05/EX-4; F-7 → PHASE-02/EX-7,
PHASE-04/EX-2, PHASE-05/EX-6; F-8, F-14 → PHASE-05/EX-7; F-9 →
PHASE-05/EX-3; F-10 → PHASE-05/EX-5; F-12 → PHASE-02/EX-3. F-11 is a
reconcile follow-up (REV on REQ-002/REQ-007/REQ-011 wording). F-13 is
tolerated under IMP-010.

### DEC-027 (cache-ready) in the plan

Its constraints are criteria, not prose: one scan and one `org-iw--files`
walk per batch, counted (PHASE-05/EX-7); each file's scan result a function
of its own text and name, cross-file checks in the post-pass
(PHASE-02/EX-6).

## Notes

- **Flake changes need a new shell.** The running jail predates the
  PHASE-01 flake edit, so `ORG_IW_DENOTE_DIR` is set by hand until the
  next jail start. Denote 4.2.3 lives at
  `/nix/store/xdf1df8f5jgnflk29cyxy8k61hl67gzy-emacs-denote-4.2.3/share/emacs/site-lisp/elpa/denote-4.2.3`;
  checked while planning: with it on `-L`, `emacs-30` (30.2) loads Denote
  and `denote-retrieve-filename-identifier` returns `20260512T000000` for
  a journal-style name; `emacs` (31.1) loads it under bare `-Q`.
- **Denote-absent tests run on both binaries** by binding `features`
  without `denote` and `org-iw-discovery--denote-tried` to t (design § 8).
- **Mutation passes** stay ad hoc per phase until CHR-001.
- **Test file size.** `test/org-iw-test.el` is ~3,400 lines and gains
  Add-document and batch tests. STD-004 mirrors tests to sources; a split
  would need a STD-004 change. Not in scope.
- **Trial corpus.** `/workspace/notes` (the user's `~/notes`): the journal
  has 74 Denote-named files, none with `#+identifier:`.
- **Carried open items:** REV for REQ-002/REQ-007/REQ-011 at reconcile;
  IMP-010/IMP-002 (scan cost); IDE-002; ASM-001; CHR-003 (PHASE-06).
