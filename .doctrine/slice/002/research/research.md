# SL-002 research — placement and vocabulary

**Producers:** both threads run by the design agent directly (no project
research agents defined); 2026-10-01. Baseline: `baseline.toml` (stamped by
`doctrine slice research SL-002`). No `raw/`: threads were short enough to
distil in place.

**Legend:** ✓ = verified by the design agent by reading or running the cited
site. Unmarked = carried from a cited source, not re-checked.

## Thread 1 — governance applicability

Binding:

- ✓ ADR-004 — allocation cases (empty → spacing; after last → last +
  spacing; before first → first − spacing; between `L<R` → `floor((L+R)/2)`
  only if strictly between); no-gap/limit → stop before any change, report
  redistribution; no-op placement writes nothing; core owns all rank
  arithmetic.
- ✓ REQ-009 — fixed/fractional/end; computed after removing the target;
  clamped; depth 0 = front, may reopen the same entry.
- ✓ REQ-010 — one rank written; unchanged relative order → no write;
  adjacent ranks 5,6 → no change, offer redistribution.
- ✓ REQ-011 — add appends by default "or at another chosen placement".
  Document targets are SL-004.
- ✓ REQ-015 — Continue: recompute, act on retained membership, open new
  first; empty / sole / missing-target messages; new first becomes retained.
- ✓ REQ-016 — per-queue labels, placements, default; unconfigured →
  Soon / Later / End; renaming labels needs no entry change.
- ✓ ADR-003 + REV-002 — placement and depth arithmetic in core; commands
  own only their own preconditions (typed input = chooser choice).
- ✓ POL-002 — `org-iw-core-append-rank` must become a case of the one
  placement allocator, not live alongside it; old path deleted.
- ✓ STD-001 item 4 — spacing 1024 and limit pinned literally (already);
  new fixed constants (standard vocabulary depths) pinned literally.
- ✓ STD-004 item 4 — every refusal through `org-iw-core-refuse`.
- ✓ DEC-002 — `org-iw-queues` plist is open to SL-002 keys; no migration.
- PRD-001 OQ-3 — default depths (brief: after 2, halfway, tail) to be
  confirmed by the user in this slice.

Checked, not applicable:

- REQ-019/020 (redistribution) — SL-006; SL-002 only refuses.
- REQ-012 batch add, REQ-002 document targets — SL-004.
- REQ-017/018 move/remove — SL-003. Remove in the Continue chooser is
  deferred with it.
- ADR-001 `IW_AFTER_<Q>` — untouched; no new property written.
- IMP-002 (one scan per command) — owned by SL-004; SL-002 must not add a
  further scan, but need not fix the existing interactive double scan.

Revision candidates: none found.

## Thread 2 — code map

Hotspots:

- ✓ `org-iw-core.el:134` `org-iw-core-append-rank ORDERED QUEUE` — the only
  allocator; callers `org-iw.el:136` `org-iw--append-rank` (wraps nil →
  refusal "rank limit; redistribution needed"), used by Add (`:300`) and
  `org-iw--move-to-end` (`:370`).
- ✓ `org-iw.el:383` `org-iw-continue` — computes `rest`, special-cases
  "already last" (no write), visits `(car rest)`. Becomes placement-driven.
- ✓ `org-iw.el:88` `org-iw-queues` — `:name` only; `org-iw--configured-name`
  is the plist reader to generalise.
- ✓ `org-iw.el:369` `org-iw--move-to-end` → generalise to move-to-rank.
- ✓ `org-iw.el:356` `org-iw--refuse-absent` — missing-target owner. An empty
  queue with a session currently hits this branch; REQ-015 wants "empty".
- ✓ `test/org-iw-core-test.el:151-165` append-rank tests; `test/org-iw-test.el`
  Continue tests; fixture `test/org-iw-test-helpers.el` (`with-corpus`,
  `heading`, `changed-lines`, `state`).

Cited facts:

- ✓ Float fractions misround under `floor`: in Emacs 31.1,
  `(floor (* 0.29 100))` = 28 and `(floor (* 0.57 100))` = 56, while
  `(floor (* 0.5 5))` = 2 and `(floor (* 0.75 4))` = 3. Integer
  `(floor (* 3 100) 4)` = 75 is exact.
- ✓ `read-multiple-choice` and `read-answer` exist (Emacs 31.1; both since
  26/27, so available on 30.1).
- mem.fact.emacs.batch-test-gotchas: a prompt in batch blocks on stdin;
  chooser tests must bind the reader, and suites run with `</dev/null`.

Naming precedents: `org-iw-core-<noun>` pure functions (`queue-order`,
`append-rank`); command-layer privates `org-iw--<verb>`; refusal messages
lower-case, no trailing period.

## Cross-thread findings

- REQ-009's "floor(f*N)" with a float `f` is not exact for common
  user-typed values (0.29, 0.57). PRD-001 forbids float *ranks*, not float
  config, but a depth that is off by one for a typed fraction violates the
  requirement's arithmetic. The fraction representation is a design
  question.
- "Already last" in Continue is today a special case. Under REQ-010 it is
  the general no-op rule (target already at the computed depth) — one rule,
  no special case.
- Empty queue under Continue: REQ-015 distinguishes "empty" from "target
  removed". With a session, an empty queue necessarily means the target
  left; the design must choose the message order.

## Design-input deltas

- Replace `append-rank` with one core allocator over (rest, depth).
- Add pure depth computation from a placement spec.
- Decide fraction representation (exact).
- Decide vocabulary config keys and standard defaults (OQ-3).
- Decide chooser UI and Add-placement entry point.
