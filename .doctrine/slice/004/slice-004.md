# Documents and batch add

## Context

RFC-001 slice 4. Makes the journal corpus usable.

## Scope & Objectives

- Document targets: file-level property drawer, no enrolment of headings
  by inheritance (REQ-002).
- Add a document from before the first heading, or explicitly from
  anywhere (REQ-011).
- Batch add of selected files in canonical path order, appended, with a
  report of added, existing and failed files and partial completion
  (REQ-012).
- Document identity: file-level `:ID:`, else Denote's filename identifier
  when Denote is available (soft-loaded), else an inserted `:ID:`
  (DEC-021, settles QUE-002). REQ-002/REQ-007/REQ-011 wording revised at
  reconcile.

## Non-Goals

Batch heading enrolment; query-based selection; a scan cache (DEC-027,
IMP-010); heading identity by `CUSTOM_ID` (IDE-002); a hard Denote
dependency.

## Summary

Affected surface: discovery (file-level reads), mutation (file-level
drawer), commands (file picker). Settles PRD-001 OQ-2 (DEC-026: batch kills
the buffers it opened once saved). Revisits OQ-1 at corpus scale
(DEC-027: uncached, cache-ready; research T3).

**Closure:** P1 gate. Trial (VH): batch-enrol the user's journal directory
(or a Git copy of it), then visit and continue.

## Follow-Ups
