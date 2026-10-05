# Notes SL-006: Redistribution maintenance

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Design triage (2026-10-06, exploring)

Scope: as written. The user prefers to ship SL-006 whole and split only
if design finds it unwieldy (2026-10-06). Evidence:
`research/research.md` (b0fc4d9).

Constraining governance:
- ADR-004 rules 4–6:
  - no gap → stop and say so;
  - redistribution re-lays every member at the spacing, in order, only
    after an approved preview, through the shared preflight and apply;
  - the plan is pure core.
- `governed_by` ADR-004 was added 2026-10-06.
- REQ-019 (preview, resolve unsaved, unwritable before any write, stale
  plan → re-preview, order preserved incl. pending move), REQ-020
  (failure partition, no navigation), REQ-010 ("offers redistribution").
- ADR-002: buffers, save policy, non-atomic. ADR-003 (+REV-002/004):
  guards live in the write preflight; commands hold no ordering.
- ADR-001, REQ-022, REQ-025: no journal or undo log.
- PRD-001: § 4 (a cancelled op changes nothing), § 6 (the normative
  flow).
- POL-002 (one owner each: place, preflight, apply, no-room text,
  batch report, open-write-kill), DEC-014 (no third preflight).
- STD-001: a self-tested cancel oracle; mutation over every guard.
- STD-003: the roster scales up, and redistribution is named.
- DEC-003/027: one scan per op. DEC-004 vs DEC-026: buffer lifetime.
  DEC-012/013/019: the move surfaces. DEC-005, REQ-015: the Continue
  session.

Shaping decisions carried in:
- One plan shape for both triggers: target order → k·spacing → the
  changed set (research, design-input deltas).
- The write layer extends `--apply` to many ranks per base buffer, with
  one change group and one save. It does not loop `put-rank`, which saves
  per entry (research X1).
- The preflight becomes reason-returning (preview) and refusing (apply),
  with one implementation (research X2).
- The handoff sits in the two `no-gap` consumers, `--add-entry` and
  `--move` (research X3).

Open design questions (tracked as `inq-*` in the design run):
1. Resolve-unsaved policy: refuse approval while any affected buffer is
   dirty and let the user resolve with Emacs tools, or let org-iw offer
   save or revert (research X5, PRD-001 § 4)?
2. Unwritable targets: block approval outright (REQ-019 AC4/AC5)?
3. Buffer lifetime for files the preview or apply opened: DEC-026 kill
   or DEC-004 keep (research X4; settles PRD-001 OQ-2)?
4. Which surfaces hand off: Continue, Move and the view moves (named);
   Add-at-placement and batch add at the limit (not named) (research X3)?
5. Excluded members (invalid rank, duplicate ID): re-lay the valid ones
   and report the rest, or refuse (research X8, REQ-007)?
6. Recheck criterion: compare the queue's (ID, file, rank) list from a
   fresh scan, plus the per-entry compare-and-set (research X6)?
7. Preview UI: a special-mode buffer, the queue view, or a dedicated
   mode? What does "browsable affected files" mean?
8. Continue after the handoff: reporting multi-file status and visiting
   the head without the ISS-002 swallow; no navigation on failure.
9. The normalise command: queue choice (session or prompt); an empty or
   already-normal queue → no-op?
10. The sequence start (k·1024 from k = 1); skip members already at their
    target?
11. The DEC-009 revisit (default End vs Soon), owed once exhaustion is
    recoverable.

Risks:
- Size: commands carry the bulk (preview, resolve, recheck, report,
  handoff on 4–6 surfaces, normalise). The fallback split: (a) plan,
  grouped apply, normalise and report; (b) the handoff.
- A file with several members, saved per entry, would break the
  REQ-020 per-file partition. Hence the grouped apply.
- Test oracles: no multi-file "changed exactly these lines" oracle
  exists. `y-or-n-p` is the only recorded prompt. Batch prompts block
  (mem.fact.emacs.batch-test-gotchas).
- Save-failure injection must use `write-file-functions`; a
  `before-save-hook` error never fails a save.
- `org-entry-put` ignores read-only buffers. The preflight's
  `buffer-read-only` check is load-bearing.
- IDE-001: open views go stale after a multi-entry write.

Assumptions:
- User scale is under 200 files (DEC-027), so two scans per
  redistribution are acceptable (IMP-002 and IMP-010 stay open).

## Design inquiry leanings (2026-10-06, inquiring, run rev 9)

Agent proposals, not yet put to the user. The user's "agreed" covered
governance and the inquiry graph only. Verified the same session:
`org-iw-discovery-scan` never visits a file (`org-iw-discovery.el:399-416`,
`:452-458`). It reads a live buffer's text, else the disk. File checks
work unvisited (`file-writable-p`); `buffer-read-only` and
`verify-visited-file-modtime` only concern existing buffers
(`org-iw-write.el:63-76`). So **the preview need not open any buffer**,
which keeps "cancel changes nothing" literal (PRD-001 § 4). Only the
apply opens buffers.

- inq-1: refuse approval while an affected buffer is dirty. The preview
  lists them. The user resolves with Emacs tools and retries; org-iw
  never saves or reverts on their behalf.
- inq-2: unwritable, read-only and changed-on-disk targets block
  approval in the same way, and are listed.
- inq-3: the apply opens buffers and kills them when clean, reusing the
  DEC-026 rule extracted from `org-iw--batch-outcome`. The preview opens
  none (above).
- inq-4: Continue, Move and the view moves hand off. Labelled Add hands
  off too (EVD-002: ~11 adds at one label exhaust it); the target is not
  yet a member, so the plan places the new entry at DEPTH, or normalises
  and then retries the add. Design to choose. Batch add stays a refusal:
  the end limit needs ~8.8e12 appends.
- inq-5: re-lay the valid members; the preview counts the excluded
  (REQ-007: never rewritten).
- inq-6: on approval, rebuild the preview data from a fresh scan and
  compare it as plain data with what was shown. On a difference,
  re-preview and re-ask. The per-entry `expected` compare-and-set stays
  as the write-time guard.
- inq-7: one of two forms.
  - (A) synchronous: display a special-mode preview with file buttons,
    then a y-or-n-p (or yes-or-no-p) prompt; browse after a cancel.
    Recommended for simplicity: the pending operation needs no stored
    continuation.
  - (B) a buffer with approve and cancel keys and a stored continuation.
  - The prompt recorder has no `yes-or-no-p` (research).
- inq-8: on success, Continue's message includes the redistribution
  summary, then the usual head visit. On cancel: "nothing changed", no
  visit, session unchanged. On failure: the partition report, no visit
  (REQ-020).
- inq-9: `org-iw-normalise`, its queue read as for other commands
  (session default). An empty changed set means "already normal", with
  no preview.
- inq-10: ranks k·1024, k = 1..N, over the target order; members
  already at their rank are skipped (fewer files touched).
- inq-11 (non-blocking): defer to the VH trial or close.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-06 · design inquiring (run rev 9) · 12f6109+

### Produced
- research round (b0fc4d9): research.md, raw/governance.md, raw/code-map.md; `governed_by` ADR-004 added
- design run dr-01a10e37…: explore discharged; governance-confirmed + graph-reviewed (user "agreed."); stage inquiring; inq-1..inq-11 declared (12f6109)

### Learned
- preview can be visit-free (§ Design inquiry leanings)

### Open
- inq-1..inq-11 (leanings above); DEC-009 revisit (inq-11)
- governance likely touched at reconcile: ADR-004 rule 5, REQ-019, PRD-001 OQ-2/OQ-3, DEC-012/013, SL-002 I10 (research.md § Design-input deltas)
- related backlog: IDE-001, ISS-002, ISS-004, IMP-002, IMP-003, IMP-006, IMP-007, CHR-001..003
