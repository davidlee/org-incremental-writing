# Queue view and membership ops

## Context

RFC-001 slice 3. Inspecting and reordering a queue by hand.

## Scope & Objectives

- Queue view `org-iw-list-queue` (tabulated list): ordinal, title, a dimmed
  outline-context column and the file (DEC-017). The session's entry is
  marked. Actions (DEC-019):
  - open, in another window, which establishes the session;
  - up/down;
  - mark, then place before/after the entry at point;
  - remove, with confirmation;
  - refresh.

  REQ-013.
- Move from the source entry with the queue's placement vocabulary,
  prompting for the queue when ambiguous (REQ-017, DEC-012).
- Remove membership from the view, the source entry or the Continue
  chooser (REQ-018). Remove is a reserved chooser action (DEC-016). It
  writes through a new `org-iw-write-delete-rank` (DEC-014). Removing the
  session's entry leaves the session, and the message says how to go on or
  stop (DEC-015).
- Up/down and before/after become placements through new pure core helpers
  (DEC-013). No new rank arithmetic.
- One entry-at-point target for Add, Move and Remove. Move and Remove
  accept member documents; Add still refuses them (DEC-018).
- The no-room refusal is reworded for view moves, with one owner.
- README documents the view, Move, Remove and the session behaviour on
  removal (DEC-015).
- ISS-001 is resolved in passing: put-rank's docstring gains the read-only
  refusal (DEC-014).

## Non-Goals

- Redistribution on a blocked move (SL-006; until then, stop and report).
- Document enrolment and document identity policy (SL-004, QUE-002).
- Position-number or relative-to-entry moves from the source (DEC-012).
- Uniform title rendering in the mode line and messages, and compact IDs
  (IMP-005).
- Non-unique file names in the view (ASM-001).

## Summary

Affected surface:
- **core:** relative-move helpers, and an `outline` field on the entry;
- **discovery:** reads the outline path during the scan;
- **write:** `delete-rank`, sharing preflight and apply with put-rank;
- **commands and view:** `org-iw.el`, with no new file;
- **README.**

Placement and allocation are SL-002's. Every move still goes through
`org-iw-core-place`.

**Closure:** P1 gate. Trial (VH): inspect a queue, reorder it, remove an
entry, undo in the source file and refresh.

## Follow-Ups

QUE-002 (Denote identity, shapes SL-004), IMP-005, CHR-003.
