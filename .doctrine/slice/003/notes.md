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

## PHASE-01 (2026-10-03, execute)

Landed: `outline` slot on `org-iw-entry`; pure `org-iw-core-beside` and
`org-iw-core-step` (placements only, via `org-iw-core-place`); discovery
`--read-entry` sets `:outline` from `org-get-outline-path`. Tests:
`org-iw-core-test-entry-outline-defaults-to-nil`, `-beside`, `-step`,
`-beside-property`, `-step-property`, `-relative-cases-reach-edges`,
`-relative-checker-self-test`; discovery `-scan-outline-nested`,
`-scan-outline-top-level-and-document`. `--random-order` was factored out of
the place generator (seeded stream unchanged). `just gate` (31.1 and 30.2) and
`just test-each` green; 11 hand mutants all killed.

Surprise: `org-get-outline-path` strips a statistics cookie but leaves both
neighbouring spaces, so `* Plan [1/3] [[..][Site]]` gives `"Plan  Site"` (two
spaces), not `"Plan Site"`; same on 30.2 and 31.1. Links are reduced to their
description. Point-min (document entry) and top-level headings give nil.
Anything that compares or renders `:outline` strings later must expect the
double space (or normalise deliberately).

Upper clamp in `step` is unobservable through `place` (which clamps depth),
so only the literal-placement unit test `org-iw-core-test-step` pins it.

## PHASE-02 (2026-10-03, execute)

`org-iw-write-delete-rank` landed as designed, calling the shared
`--preflight`/`--apply`. Probed `org-entry-delete` on Org 9.7.11 (30.2) and
9.8.10 (31.1); they agree: removes the one line, returns t; skips lowercase
unless `case-fold-search` t; deletes an emptied drawer (block nil); with
`IW_Q` + `IW_Q+` present deletes **both** (preflight is load-bearing).

Test helpers generalised, not copied: `--should-refuse-by VERB` (old
`--should-refuse` wraps it with `--put-4096`), `--check-refuses` optional
VERB, `--check-rollback TEXT TITLE DIRTY TYPE CALL` (old `--check-atomic`
wraps it). New `--should-delete-line` asserts I11 via `changed-lines` =
`((LINE))`.

Surprise: the sheet expected the lowercase test to kill the dropped
`case-fold-search` let, but the default is already t, so the mutant
survived. The test now binds `case-fold-search` nil around the call (a real
caller context). The narrowed-indirect delete test compares the narrowed
text, not positions: a deletion before the region shifts them.

Mutation pass: 9 mutants, all killed (table in the phase sheet). `just gate`
green (226 tests, 31.1 and 30.2), `just test-each` 226 alone green.

## PHASE-03 (2026-10-03, execute)

Helpers in org-iw.el, each with a caller: `--target-at-point` (Add;
document marker at wide `point-min`), Add-owned `--heading-or-refuse`
(the document refusal, called from Add's interactive spec and body),
`--find-entry` (`--check-heading` via `cl-position`, Continue),
`--known-queues`, `--read-queue QUEUES &optional REQUIRE-MATCH`,
`--read-session-queue` (visit-next), `--refuse-absent SCAN QUEUE ID TITLE`,
reworded `--refuse-no-room` (WHERE carries "at"), `--move` (WHERE
required; Continue's placement path). `--put-rank`'s only caller is now
`--move`. Existing tests changed only at the three planned spots.

Document detection is by context (`org-before-first-heading-p` at the
marker, widened), not position: a file whose first line is a heading has
its heading at `point-min` (pinned by `add-first-line-heading`).

`--read-session-queue` lives in the Session section: byte-compile refuses
a reference to `org-iw--session` before its `defvar`.

Mutation pass: 26 mutants; one survived at first (`--move`'s unchanged arm
writing the same rank leaves state equal) and was killed by making the
entry's buffer read-only in the unchanged test. `just gate` green (236
tests, 31.1 and 30.2), `just test-each` 236 alone green.

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

## RV-006 rulings (2026-10-03)

User reply: "update the ADR. all ok … for #4 as long as we fix it at
some point i don't care much when."

- F-3 → REV-004 amends ADR-003: the mutation layer may read structure it
  just edited to check a rollback-only invariant. delete-rank's
  `org-get-property-block` check stands. F-3 verified; RV-006 done.
- ADR-004 item 5 now names the shared preflight and apply instead of
  "the one write path" (REV-004).
- Deviation D1 (`org-iw--heading-or-refuse`, single owner of Add's
  document-target refusal) confirmed by the user.
- Title double space (sibling of F-4) → IMP-005 item 3; timing open.
- Fix-now findings F-1, F-2, F-4..F-11 landed in cbb493e.

## PHASE-04 — Move (2026-10-03)

- `org-iw--scanned-entry-at` (PHASE-03 deferral, EX-5), `org-iw--membership-queue`
  and autoloaded `org-iw-move` in org-iw.el `;;;; Move`. 24 new tests.
- Sheet R3 settled from design § 5.2 (design.md:274-276): no ID → "not in any
  queue"; nil ID is checked before `org-iw-discovery-problem-types`.
- Deviations: `--check-heading` left unshared (two-line overlap). Sheet case
  T1(d) (same ID in two files) is unreachable — `--drop-shared-ids` removes such
  entries; covered instead by `scanned-entry-at-matches-file`. Worker wrote tests
  and code in one pass (no recorded red); the mutation pass stands in.
- Mutation pass: 26 mutants, all killed; j3 (Move ends the session) survived
  first and was killed by making each loop iteration actually move.
- `just gate` green, 263 tests on 31.1 and 30.2; `just test-each` 263 alone
  green; verify-vt PHASE-04 VT-1 PASS.

## PHASE-05 — Remove (2026-10-03)

- `org-iw--delete-rank`, `org-iw--session-hint`, autoloaded `org-iw-remove`,
  Continue `remove` (chooser lists "Remove" last, not default), reserved label
  in `--check-placements`. 21 new tests; existing Continue refusal tests now
  loop over `(nil remove)`.
- Sheet Q1/Q2 settled from design § 5.4 Messages: Continue Remove with members
  left carries no hint (the session moves to the new head); N counts after the act.
- Deviations (helpers not in § 5.2, each removing duplication):
  `--removed-text` (one owner of the Removed message and hint rule; reused by
  PHASE-07 view D), `--entry-marker` (3 resolve copies), `--queue-at-point`
  (Move/Remove interactive spec), `--empty-text`, optional QUEUE on
  `--scanned-entry-at` (absorbs Move's not-in-queue refusal),
  `--continue-place` / `--continue-remove` split of Continue (SL-002 logic moved
  verbatim). Tests: `--should-move` generalised to `--should-change-lines`;
  shared source-refusal table for Move and Remove.
- Sheet A6 (stale pre-delete scan) is moot: `org-iw-discovery-resolve` searches
  the live buffer by ID; pinned by `continue-remove-head-in-same-file`.
- VT-2 waived, re-keyed as VT-3 (STD-002 item 3): the reserved-label test
  reaches `--check-placements` via `org-iw--vocabulary`.
- Red runs recorded per task T1..T5 (void-function / no-signal failures).
- Mutation pass: 32 mutants, 30 killed. Survivors justified: #15 (reserved check
  after duplicate check is equivalent — first "Remove" refuses before a second
  label); #26 (TOTAL passed to `--visit` in `--continue-remove` only changes an
  echo the final report overwrites; same shape as SL-002 Continue).
- `just gate` green, 284 tests on 31.1 and 30.2; `just test-each` 284 alone green.

## PHASE-06 — Queue view: display, open, refresh (2026-10-03)

- org-iw.el `;;;; Queue view`: `--outline-text` (pure), `--view-context-width`
  (30, one constant for column and text), `org-iw-view-mode` (+ map, RET),
  `--view-queue`, `--view-buffer` (found by queue ID), `--view-row` (pure),
  `--view-redraw SCAN &optional GOTO-ID` (sets every showing window's point),
  `--view-revert` (buffer-local `revert-buffer-function`, so `g`),
  `--view-id-at-point`, `org-iw-view-open`, autoloaded `org-iw-list-queue`.
  `--visit` gains OTHER-WINDOW. New `--session-entry-p` (shared with
  `--removed-text`). Fixture: `--release` kills view buffers;
  `--call-with-corpus` wraps in `save-window-excursion`. 17 new tests.
- Rulings: sheet OQ-1 → A1 (non-empty list-queue returns nil, no message;
  design § 5.4 names only the empty message). OQ-2 → A2 (`…/` prefix also when
  the nearest ancestor alone is cut; result fits WIDTH).
- EX-4 / VT-2 (RV-005 F-1) negative control — the `set-window-point` loop
  removed, each test fails reading "a1":
  - `org-iw-cmd-test-view-redraw-keeps-window-point`:
    `(equal "a1" "b1")` on `(org-iw-cmd-test--window-row window)`
  - `org-iw-cmd-test-view-open-keeps-view-row`: `(equal "a1" "b1")`
  - `org-iw-cmd-test-list-queue-keeps-view-row`: `(equal "a1" "c1")` on
    `(tabulated-list-get-id)`; bites under the shipped order (redraw, then pop).
- Deviations: `--session-entry-p` (one owner of the session-entry test);
  `org-iw-cmd-test-view-redraw-goto-id` tests GOTO-ID, which has no caller until
  PHASE-07; `--view-buffer` matches `org-iw--view-queue` only (a mode change
  clears it); the fixture self-test lives in org-iw-test.el (needs the view mode);
  absent-entry refusal names the row's displayed title; GOTO-ID lookup via
  `text-property-search-forward`. Redraw has no mark step yet (PHASE-07).
- Red runs per task T1..T5 recorded in the worker hand-back (void-function /
  arity / stale-rows failures). The fixture's red was shown by mutants.
- Mutation pass: 29 mutants, 28 killed. Stale-ordinal and session-queue
  mutants first survived; killed by `org-iw-cmd-test-view-open-acts-afresh`.
  Equivalent: list-queue popping before redraw (same user-visible result).
- `just gate` green, 301 tests on 31.1 and 30.2; `just test-each` 301 alone
  green on both.

## RV-007 rulings and design amendment (2026-10-03)

User reply: "1. agreed 2. accept. go ahead."

- F-6: `org-iw-list-queue` and `g` report "Queue NAME: N entries" ("1
  entry") or "Queue NAME is empty" through `org-iw--report`, so the
  scan-problem suffix shows. This supersedes PHASE-06 OQ-1, which ruled
  that a non-empty queue gives no message.
- F-9: when the entry on the current row is gone, the redraw keeps the
  same line, or the last row when fewer remain.
- The design was amended in § 5.2 and § 5.4. The run was regressed to
  reviewing, the edit adopted, both sections re-attested, RV-008
  concluded with zero findings, and design acceptance recorded on the
  reply above. The run is re-locked at revision 47.
- The other 11 findings are fix-now. ISS-002 and ISS-003 were captured
  as out of scope.
- All 13 RV-007 findings fixed in 136fe79 (309 tests); RV-007 done.
  F-3 deviation: the fixture fails a test at the moment it would reuse
  an outside view of the same queue, rather than refusing to start.
