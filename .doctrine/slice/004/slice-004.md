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

## Non-Goals

Batch heading enrolment; query-based selection.

## Summary

Affected surface: discovery (file-level reads), mutation (file-level
drawer), commands (file picker). Settles PRD-001 OQ-2 (files opened only
to write). Revisits OQ-1 at corpus scale.

**Closure:** P1 gate. Trial (VH): batch-enrol the user's journal directory
(or a Git copy of it), then visit and continue.

## Follow-Ups
