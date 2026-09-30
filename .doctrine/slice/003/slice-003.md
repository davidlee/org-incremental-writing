# Queue view and membership ops

## Context

RFC-001 slice 3. Inspecting and reordering a queue by hand.

## Scope & Objectives

- Queue view (tabulated list): ordinal, title and distinguishing context.
  Actions: open (establishes the session), up/down, place before/after,
  remove, refresh (REQ-013).
- Move from the source entry, prompting for the queue when ambiguous
  (REQ-017).
- Remove membership from the view, the source entry or the Continue
  chooser (REQ-018).

## Non-Goals

Redistribution on a blocked move (SL-006; until then, stop and report).

## Summary

Affected surface: commands/view layer. Reuses SL-002 placement; no new
ordering logic.

**Closure:** P1 gate. Trial (VH): inspect a queue, reorder it, remove an
entry, undo in the source file and refresh.

## Follow-Ups
