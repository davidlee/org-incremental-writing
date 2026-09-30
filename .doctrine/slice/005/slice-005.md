# Identity and diagnostics

## Context

RFC-001 slice 5. Hardens identity and turns SL-001's refusal to write
into actionable diagnostics.

## Scope & Objectives

- Entries resolved by Org ID so refiled entries stay members (REQ-007).
- Diagnostics with locations for duplicate IDs, invalid ranks, invalid
  queue IDs and unresolvable targets. Affected entries are excluded from
  writes.
- Tie determinism hardened under edits and merges (REQ-008).

## Non-Goals

Automatic repair of any diagnosed problem.

## Summary

Affected surface: discovery/resolution, plus a diagnostics report command.

**Closure:** P1 gate. Trial (VH): seed a duplicate ID and an invalid rank;
confirm diagnostics and that no write occurs; refile an entry and confirm
it is still found.

## Follow-Ups
