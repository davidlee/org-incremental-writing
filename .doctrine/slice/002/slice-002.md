# Placement and vocabulary

## Context

RFC-001 slice 2. Turns Continue from "to the end" into the real reinsertion
interaction.

## Scope & Objectives

- Placement forms: fixed, fractional and end, with clamping and depth-zero
  front (REQ-009). Exact integer fractions, with a percent shorthand
  (DEC-007).
- Between-neighbour rank allocation. A no-op placement writes nothing. When
  no gap is left, stop before mutating and report (REQ-010). Redistribution
  itself is SL-006. One core allocator replaces the append-only one; spacing
  stays 1024 (DEC-010).
- Per-queue vocabulary (labels, placements, default) and standard defaults
  Soon / Later / End, default End (REQ-016, DEC-008, DEC-009).
- Continue: the default command plus a chooser (prefix argument,
  completing-read; DEC-011). Messages for empty, singleton and
  missing-target cases (REQ-015).
- Add at a chosen placement, via prefix argument (REQ-011, DEC-011).

## Non-Goals

View, move and remove (SL-003), including Remove as a Continue choice.
Redistribution (SL-006). Document targets (SL-004). The interactive double
scan (IMP-002, SL-004).

## Summary

Affected surface: ordering core, commands, config. A2 (sparse integer
ranks) is ADR-004. PRD-001 OQ-3 (default depths) is settled by DEC-009.

**Closure:** P1 gate. Trial (VH): Continue with each vocabulary choice on
a configured queue and an unconfigured one.

## Follow-Ups
