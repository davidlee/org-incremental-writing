# SL-004 research — documents and batch add

**Producer:** the design agent, 2026-10-05, by reading the cited sources
and running the probes in `raw/` on Emacs 31.1 (Org 9.8.10) and Emacs
30.2 (Org 9.7.11). Baseline: `baseline.toml`.

**Legend:** ✓ = verified by running or reading the cited site.
Unmarked = inference.

## Thread 1 — governance applicability

- ✓ REQ-002 — a document entry is the file-level drawer before the first
  heading; nothing is inherited; documents and headings share one order.
- ✓ REQ-011 — Add before the first heading enrols the document; an
  explicit document command/prefix enrols it from anywhere; an ID is
  ensured; an existing membership is a reported no-op.
- ✓ REQ-012 — canonical path order; appended as a batch "by default";
  existing → reported unchanged; one failure doesn't stop the rest;
  partial completion reported; not presented as atomic.
- ✓ REQ-021 AC4 — batch operations apply the save policy per file.
- ✓ ADR-002 — every change goes through a visiting buffer, opened if
  needed; batch add reports partial completion; recovery is Git.
- ✓ ADR-001 — "An in-memory index is permitted only as a disposable copy
  that the source buffers invalidate."
- ✓ ADR-003 — readers of Org structure live in discovery; write guards
  live in the mutation preflight; commands hold no ordering logic.
- ✓ DEC-003 — rescan per operation; "SL-004 must measure and may add a
  cheaper read path".
- ✓ DEC-004 — buffers opened only to write stay open; "Revisit in SL-004
  when batch add may open many files".
- ✓ DEC-011 — Add's prefix argument already reads a placement, so it
  can't also mean "document".
- ✓ DEC-018 — `org-iw--target-at-point` returns a marker at `point-min`
  before the first heading; Add keeps the "document targets are not yet
  supported" refusal until SL-004 (`org-iw--heading-or-refuse`).
- ✓ QUE-002 — open: Org ID vs Denote `#+identifier:` as document
  identity; must SL-004 insert an ID, and with what scheme?
- ✓ ASM-001 — file names unique across sources (Denote corpus).
- IMP-002 (one scan per command) — Add scans in its interactive spec and
  again in its body; at corpus scale each scan is seconds (Thread 3).

## Thread 2 — Org behaviour at the document level (`raw/probe*.el`)

1. ✓ With a visiting buffer, `org-id-get-create` at `point-min` followed
   by `org-entry-put (point-min) …` creates a file-level drawer before
   `#+title:` (after a leading `# -*- … -*-` comment line), or adds to an
   existing one, on both Emacs versions. In a non-file buffer
   `org-id-get` signals "expects a file-visiting buffer".
2. ✓ **Hazard.** When the file starts with a heading, `point-min` *is*
   that heading: the same calls enrol the first heading, not the
   document. The write API's convention "a marker at `point-min` for a
   document entry" is ambiguous for such files.
3. ✓ Inserting `:PROPERTIES:\n:END:\n` at `point-min` of such a file
   makes `org-before-first-heading-p` true there and
   `org-get-property-block` find the empty drawer; the ID and IW_ line
   then go into it, and the heading gets nothing.
4. ✓ A drawer after `#+title:` is not a file-level drawer to Org
   (`org-get-property-block` nil) — already caught by
   `org-iw-discovery-unrecognised-drawer-p`.

## Thread 3 — scale (`raw/bench*.el`)

Synthetic corpus: 3,000 Denote-named files, ~4 KB each, three headings
each, 12 MB total.

| measurement | Emacs 31.1 | Emacs 30.2 |
|---|---|---|
| select files | 0.06 s | — |
| scan, no members (prefilter only) | 0.17 s | — |
| scan, 3,000 document members | 2.1–2.5 s | — |
| same, `gc-cons-threshold` 256 MB | 1.78 s | 1.46 s |
| batch write: visit + put + save + kill, 3,000 files | 11.3 s (3.8 ms/file) | — |
| `file-attributes` ×3,000 | 0.009 s | 0.010 s |
| `find-buffer-visiting` ×3,000 | 0.063 s | 0.083 s |

Breakdown of one all-members scan (Emacs 31): reading the text 0.08 s;
plus `org-mode` (hooks delayed) 1.24 s; plus reading entries 1.51 s; the
rest is GC. **Org mode activation per file dominates** (~0.4 ms/file).

Inferences:

- At the user's corpus scale, every command (Add, Visit, Continue, view
  actions) would pay ~2 s per scan, ~4 s for Add (IMP-002). That fails
  the "Continue is a single command" feel of PRD-001 § 5.
- A per-file scan result cache, keyed by (truename, mtime, size) for
  unvisited files and by buffer modification tick for visited ones,
  would reduce a warm scan to stat + lookup (~0.1 s). ADR-001 permits it.
- `-Q` hides the user's `org-mode-hook` cost on visit; under a real
  configuration batch write will be slower than 3.8 ms/file. A progress
  reporter is warranted; leaving 3,000 buffers open is not.
