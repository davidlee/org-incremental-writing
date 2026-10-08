# Truthful save status and kept-buffer reporting

## Context

Live batch add to LEARN-EMACS (2026-10-08) reported "10 unsaved". The
report listed each file as `(saved); buffer left open, modified`, yet
the ranks were on disk and the buffers clean afterwards. Investigation
(recorded in ISS-008) found three defects in how writes and batch
reports describe a buffer org-iw kept:

- ISS-008: `org-iw-write--save` returns `saved` once `save-buffer`
  returns, even if a save hook left the buffer modified.
  `org-iw-write-save-file` already checks this, returning
  `(save-failed . still-modified)`: two save paths for one concept
  (POL-002).
- ISS-009: `org-iw--file-outcome` marks `left-open` whenever a buffer
  it opened is still live, not when it is modified. The report then
  says "modified" and counts it as unsaved, even when a kill was
  refused or advised away (a kill-buffer-query function, otpp's bury
  advice).
- ISS-010: a clean batch makes no report buffer and leaves the last
  run's `*org-iw batch*` in place, so it reads as current.

The trigger of the live run is unexplained. ISS-008's fix makes the
next run name it.

## Scope & Objectives

- One save helper in the write layer that reports a buffer still
  modified after saving, used by every write path (put-rank(s),
  delete-rank, save-file). Every command's save status then tells the
  truth, not only batch add's.
- Batch add and redistribution classify a kept buffer by whether it is
  modified, and word and count it truthfully. DEC-026's rule (keep a
  modified buffer the batch opened, report it) is unchanged.
- A run with nothing to report removes any stale report buffer
  (batch add and redistribution share the helper).
- Docstrings, `doc/manual.md`/README wording that describes these
  statuses, and pinned tests updated.

## Non-Goals

- Finding or working around the user's config trigger (super-save,
  otpp, Undo-Fu-Session); org-iw only reports truthfully.
- ISS-007 (quit mid-save reported as stopped): related, separate.
- Changing DEC-026's keep/kill policy or ADR-002's save policy.

## Summary

Affected surface: write layer (`org-iw-write.el` save helper and its
callers' contracts), commands (`org-iw.el` outcome classification,
outcome text, batch summary, report buffer), tests
(`test/org-iw-write-test.el`, `test/org-iw-test.el`), docs.

Risks: SL-006 (redistribution) is still open and shares
`org-iw--file-outcome` and `org-iw--outcome-report`; land after or
coordinate. The save-status change reaches every write command's
messages, so pinned message tests will move.

Open questions for design: how a clean buffer that survived the kill
is reported (silently, or as "left open" not counted unsaved); whether
`still-modified` stays a `save-failed` variant.

**Closure:** P1 gate (POL-001 lint + test). Tests cover a save hook
re-dirtying the buffer (every write path), a refused kill, and a clean
run after a troubled one. Trial (VH): rerun an interactive batch add
on real notes and confirm the report matches buffer state.

## Follow-Ups
