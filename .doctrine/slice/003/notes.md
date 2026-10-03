# Notes SL-003: Queue view and membership ops

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Design triage (2026-10-03, exploring)

Constraining governance:
- ADR-003 (+REV-002): mutation "sets or removes one property", and the
  view sits in the command layer.
- STD-004 items 1–2: four files, `--` symbols file-private, so the view
  goes in `org-iw.el`.
- ADR-004 and SL-002 design I10: the core alone computes ranks, depths and
  neighbours.
- POL-002: one write preflight, resolver, message owner and prompt
  recorder.
- DEC-003: rescan per operation.
- DEC-005: the session is cleared only by `org-iw-end-session`.
- DEC-011: Remove joins the chooser in SL-003.
- STD-003: the write path is high stakes, so the review roster scales up.

SL-003 `governed_by` now also carries ADR-004 and STD-001..004. Evidence:
`research/research.md`.

Shaping decisions carried in:
- No new rank arithmetic. Every move (view up/down/before/after, source
  move) funnels through `org-iw-core-place` (research fact 4).
- Delete is a sibling verb in `org-iw-write.el` sharing `--preflight` and
  `--apply`, not a second write path (research X2).
- Every view action rescans and targets by Org ID, writing against the
  fresh rank. Row data is display only (ADR-001, DEC-003, research X5).
- Opening from the view reuses `org-iw--visit`, which sets the session
  (REQ-013 AC4, DEC-005).

Open design questions (tracked as `inq-*` in the design run):
- Who turns a relative move (up/down/before/after X) into a placement: a
  core helper, or a DEC calling it input translation (I10, research X3)?
- What a source-entry move places with: vocabulary, position or relative
  to an entry (REQ-017, research OQ 1)?
- Remove in the Continue chooser: label collision, never the default,
  navigation afterwards (DEC-011, REQ-018, research X7).
- The session when its entry is removed: leave it, end it, or visit the
  next entry (DEC-005, research X6).
- Distinguishing context: outline path from the scan, and its rendering
  against the raw title (REQ-013 AC2, research X4).
- Source-entry commands on document entries: refuse until SL-004?
- View UX: buffer name, columns, key bindings, where open shows the entry,
  point after remove.
- The no-room refusal wording for view moves (POL-002 single owner,
  research X8).

Risks:
- Ties: equal-rank neighbours give `no-gap`, so up/down refuses until
  SL-006.
- Front exhaustion from repeated "before X" (EVD-002, about 11 uses).
- `org-entry-delete` silently skips a lowercase key unless
  `case-fold-search` is t (verified by experiment). The delete must bind it
  and check the result.
- Stale rows after a source undo trip preflight "changed since scan" if
  actions trust row data.
- Batch tests block on an escaped prompt (mem.fact.emacs.batch-test-gotchas).

Assumptions:
- The view needs no auto-refresh: `g` rescans, which reads live buffers
  (REQ-006).

## Design draft (2026-10-03, run rev 31)

design.md drafted from DEC-012..019 and inq-9. User ruling while
drafting: view up/down no-room says "at position D/N". Agent self-review
fixed the recorder's `y-or-n-p` answers (`:yes`/`:no`, since a nil answer
reads as exhausted), Add's document refusal before the prompt, and the
tag padding.

RV-005 adversarial pass (opus, run rev 32–36): 20 findings, all
integrated; F-1..F-18 verified by the reviewer. F-11 is a follow-up:
REV qualifying REQ-013 AC2 at reconcile. Learned: `tabulated-list-print`
resets an unselected window's point, and `tabulated-list-revert` reprints
after its hook (wipes tags); candidate memory at close.

A further pass would only re-probe F-19/F-20 (mechanical, unverified)
and the view's redraw helper once code exists; none needed before lock.

What the first pass was asked to probe:
- the write path: `delete-rank`'s preflight coverage and rollback;
  whether I11 holds for a document entry's drawer;
- whether `org-iw--move` really owns every existing-member placement,
  including Continue's `unchanged`/`moved` messages and reorder;
- the view's stale-row (I12) and point-placement behaviour against
  `tabulated-list-print`'s REMEMBER-POS;
- test-plan gaps against REQ-013/017/018 ACs and STD-001 (refusals
  killed, recorder misuse).

## Lock and plan (2026-10-03)

User accepted the design ("I approve the design, /plan"). Recorded on
their assent: 14 section attestations, review-disposed (conducted
RV-005), design-accepted; run locked at rev 40. The lock gate required
a route on the two majors: F-1 and F-2 reopened and re-disposed
`probe` (prose fix stands; only an implementation shows it holds).

Plan: eight phases, bottom-up (see plan.md). Revision after the
critical pass: each helper lands with its first caller, so no phase
ends with dead code. Checked: batch Emacs 30/31 reproduces F-1
(unselected window point → 1 after tabulated-list-print), so the
PHASE-06 probe test and its negative control are feasible.

F-1/F-2 verified as transcribed; F-19/F-20 verified against the locked
design; RV-005 concluded. Research restamped (drift was the design and
scope edits only). Slice → ready. Next: /phase-plan PHASE-01.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-03 · design drafting (run rev 22) · 33c2c87

### Produced
- research/research.md (+ raw/governance.md, raw/code-map.md)
- design run dr-01a0fedb: inq-1..inq-9 resolved; stage drafting
- DEC-012..DEC-019 (accepted, shape SL-003); DEC-016 references DEC-011
- slice-003.md scope rewritten; governed_by + ADR-004, STD-001..004

### Learned
- org-entry-delete skips a lowercase key unless case-fold-search is t (research fact 3; candidate memory at close)

### Open
- ASM-001 — unique source file names (held)
- QUE-002 — Denote identity / document ID policy (shapes SL-004)
- IMP-005 — uniform title rendering in mode line/messages; compact IDs
- CHR-003 — standard: each slice updates README
- ISS-001 — to be resolved by this slice (DEC-014)
