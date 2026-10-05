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

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: <yyyy-mm-dd> · <PHASE-NN | stage> · <head-commit>

### Produced

### Learned

### Open
