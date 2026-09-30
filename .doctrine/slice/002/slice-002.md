# Placement and vocabulary

## Context

RFC-001 slice 2. Turns Continue from "to the end" into the real reinsertion
interaction.

## Scope & Objectives

- Placement forms: fixed, fractional and end, with clamping and depth-zero
  front (REQ-009).
- Between-neighbour rank allocation. A no-op placement writes nothing. When
  no gap is left, stop before mutating and report (REQ-010). Redistribution
  itself is SL-006.
- Per-queue vocabulary (labels, placements, default) and standard defaults
  (REQ-016).
- Continue: the default command plus a chooser. Messages for empty,
  singleton and missing-target cases (REQ-015).
- Add at a chosen placement (REQ-011).

## Non-Goals

View, move and remove (SL-003). Redistribution (SL-006).

## Summary

Affected surface: ordering core, commands, config. A2 (sparse integer
ranks) is drafted before this slice's design. Settles PRD-001 OQ-3
(default depths).

**Closure:** P1 gate. Trial (VH): Continue with each vocabulary choice on
a configured queue and an unconfigured one.

## Follow-Ups
