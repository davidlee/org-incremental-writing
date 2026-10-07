# Redistribution maintenance

## Context

RFC-001 slice 6. Explicit multi-file maintenance for when a placement has
no integer gap left, plus explicit normalisation.

## Scope & Objectives

- Preview: counts, affected files, the pending operation, unsaved and
  unwritable targets, non-atomicity, and a recommendation to commit to Git
  first (REQ-019).
- Resolve unsaved edits, check writability, approve or cancel. Cancel
  changes nothing. The approval prompt names the unsaved affected
  buffers and saves them on yes (DEC-029). Unwritable, read-only or
  changed-on-disk files block approval (DEC-030).
- Recheck against live state; if it changed, re-preview and re-approve.
- Apply and save through buffers. On write failure, report saved, modified
  and untouched files and don't navigate onward (REQ-020).
- Blocked moves and Continue hand off to this flow. Explicit normalise
  command.
- Added in design (2026-10-06): labelled Add also hands off, with the
  pending add inside the plan (DEC-036); Continue reports before it
  visits, resolving ISS-002 (DEC-038).

## Non-Goals

Rollback, recovery records, Git automation, local redistribution.

## Summary

Affected surface: ordering core (plan), mutation (multi-file apply),
commands (preview UI).

**Closure:** P1 gate, including simulated write failure. Trial (VH): on a
disposable Git-backed fixture, cancel and approve a redistribution, then
inspect `git diff`.

## Follow-Ups
