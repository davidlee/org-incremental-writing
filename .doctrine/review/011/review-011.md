# Review RV-011 — reconciliation of SL-003

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

Mode: conformance. Surface: the primary tree at 5a10911 (not dispatched).
SL-003's code range is e7213f2..HEAD (`org-iw-core.el`,
`org-iw-discovery.el`, `org-iw-write.el`, `org-iw.el`, four test files and
`test/org-iw-test-helpers.el`, README). Canon: design.md (locked, run
dr-01a0fedb, rev 53), DEC-012..020, ADR-001..004 (ADR-003/004 as amended
by REV-004), POL-001..003, STD-001..004.

Roster (STD-003, scaled up): the slice changes the write path
(`org-iw-write-delete-rank`, DEC-014), and design § 9 names the scale-up.
So the roster is: modelling/architecture reviewer (opus), test reviewer
(opus, with a mutation pass), legibility/DRY reviewer (opus; the
mechanical substitutes, CHR-001 and CHR-002, are still not in place), and
an opus verifier. Reviewers are read-only, each in its own scratch copy
under `/home/scratch/sl-003/review/<role>/`. The seat is the sole ledger
writer. Per-phase reviews (RV-006, RV-007, RV-009) covered parts of the
range. This pass covers the accumulated delta and how the phases
interact.

Lines of attack:
- Write path (ADR-002, DEC-014, I11): delete-rank shares `--preflight`
  and `--apply`; binds `case-fold-search`; rollback on a failed or
  partial delete; one line removed, drawer kept; post-edit check per
  ADR-003 as amended (REV-004).
- I10′ / I14: no rank, depth or neighbour computed in the command layer;
  every existing-member rank change through `org-iw--move` →
  `org-iw-core-place`.
- I12: view actions rescan and act by ID; a stale row never refuses
  "changed since scan".
- I13: Move, Remove and the view's moves and removes leave
  `org-iw--session` `eq`; only RET, Continue and visit-next set it.
- Layering (ADR-003, STD-004): no cross-file `org-iw-<layer>--` use; the
  view lives in `org-iw.el`.
- POL-002: one owner each for messages (Removed, no-room, absence,
  position text), target resolution and queue reading.
- § 5.4 check order and messages for Move, Remove, Continue Remove, view
  actions, and DEC-020 (C-u picks the queue).
- Tests (STD-001): mutation over high-risk logic, oracles' self-tests,
  isolation (`just test-each`), the recorder's `y-or-n-p` path.
- Carry-ins:
  - RV-005 F-1 and F-2 terminal verify against PHASE-06/EX-4 and
    PHASE-07/EX-4;
  - ISS-001 closure (DEC-014);
  - the REQ-013 AC2 qualification (RV-005 F-11, a REV at reconcile);
  - § 5.2 `--view-redraw` "re-tags the mark" drift (RV-009);
  - tier-5 gaps to check: PHASE-07 T8 tests written after the code;
    the RV-007 F-3 fixture fails at reuse rather than refusing up front.

Evidence in hand: `doctrine check gate` 331/331, exit 0; verify-vt 14
PASS, PHASE-05 VT-2 waived (superseded by VT-3, STD-002 item 3).
Registry conformance: 9 conformant, 0 undelivered, 12 undeclared (all
`.doctrine/`). Over the full range (`--against e7213f2..HEAD`), it also
lists `test/org-iw-test-helpers.el` as undeclared. PHASE-08 VH-1 passed
(user trial, 2026-10-05).

Out of scope, already captured: ISS-002, ISS-003, IMP-005..IMP-009,
IDE-001, CHR-003, QUE-002, ASM-001.

## Synthesis

SL-003 matches its locked design in substance. The audit found no
user-visible defect, no blocker and no major. Every invariant the brief
named was proved by execution:

- **Write path (ADR-002, DEC-014, I11).** `org-iw-write-delete-rank`
  runs the type checks, then the shared `--preflight`/`--apply`. It
  binds `case-fold-search` and checks the drawer survives, a post-edit
  read that ADR-003 allows as amended by REV-004. The file differs by
  the one line.
- **I10′ / I14.** `org-iw-core-place` is called only by `--move`
  (existing members) and Add (new ones). The command layer computes no
  rank or placement depth. Its index arithmetic (ordinals, D's next
  row, Continue's head) is display or navigation only.
- **I12, I13.** Every view action rescans and acts by ID. Move, Remove
  and the view's moves and removes leave the session `eq`.
- **Layering (STD-004).** No `org-iw-<layer>--` symbol is used outside
  its own file.
- **§ 5.4 order and messages, DEC-020.** These hold.
- **RV-005 F-1 and F-2** hold in the shipped code, beyond their
  criteria (PHASE-06 VT-2, PHASE-07 VT-3, both PASS):
  - After RET, the view keeps the opened row in its unselected window.
  - The mark survives `g`, `org-iw-list-queue`, and a move on another
    row.

The audit's yield was evidence and single ownership:

- **Unpinned behaviour (F-6..F-9).** D's "else the previous row" rule,
  the I11 oracle's other-files half, and the view padding each had a
  surviving mutant. delete-rank had no folded-buffer case.
  - The test reviewer's pass: 74 code mutants, 69 killed, 2 equivalent,
    2 constant-only (the padding), and 1 real survivor (D). Of 11
    fixture and oracle mutants, 8 were killed.
  - The new tests kill every non-equivalent survivor, rerun on the
    fixed tree.
- **POL-002 (F-10, F-11, F-12, F-14).** The fix gave each concept one
  owner:
  - code: `--find-member`, `--read-known-queue`, `--now-text` and
    `--refuse-excluded`; Add's excluded-entry text is now Move's;
  - tests: the test helpers now delegate to `org-iw--find-entry` and
    `--call-prefixed`, and the shared-preflight refusal scenarios run
    once over both verbs (10 tests become 4).
- **Docs (F-4, F-5, F-15).** The view docstrings now list write
  refusals (ISS-001's standard). README now covers Continue after the
  queue's last entry is removed. The placement docs now name Move.
- **Structure (F-16).** The shared helpers now live in a "Membership
  writes" section.
- **Design drift (F-1, F-2) and governance drift (F-3)** go to
  reconcile, below.

All fix-now findings landed in f714d4b. Gate: 327/327 on 31.1 and 30.2,
lint and checkdoc clean, `just test-each` green, verify-vt clean for
SL-003.

The handover's tier-5 claims were checked:
- **PHASE-07 tests written after the code.** Every PHASE-07 mutant was
  killed except D's fallback, now fixed (F-6).
- **RV-007 F-3 fixture.** It fails at reuse rather than refusing up
  front. That is aligned with STD-001: it fails exactly when a test
  would depend on a leftover view, and it is self-tested.

ISS-001 is resolved:
- put-rank's docstring lists "buffer is read-only"
  (org-iw-write.el:117), and Continue's lists every write refusal;
- the new view commands now meet the same standard (F-4).

Tradeoffs consciously accepted:

- **F-13.** A view buffer whose major mode the user changed is still
  found and redrawn. This is self-inflicted, and killing the buffer
  recovers. A fix would contradict design § 5.2.

Standing risks:

- **Gap exhaustion and ties.** These refuse until SL-006, as designed.
- **Conformance registry.** The registry missed the helpers file
  (F-1). A full-range `--against` run is the check that caught it.
- **SL-001 evidence rot.** `verify-vt SL-001` fails PHASE-02 VT-3,
  which is keyed on `append-rank`, deleted by SL-002. Captured as
  CHR-004; outside this slice.

Roster (STD-003, scaled up for the write path):
- opus modelling/architecture reviewer;
- opus test reviewer, with the mutation pass;
- opus legibility/DRY reviewer;
- opus verifier: 22 candidates, 11 confirmed, 9 plausible, 2 rejected
  (C21, double SIDE validation, and half of C5). C20 (a navigation test
  helper) and C22 (session-queue reads of differing shape) were
  plausible but not raised.

Scratch is under `/home/scratch/sl-003/review/` and
`/home/scratch/sl-003/audit/`.

Where to look:
- `doctrine show DEC-014`: why Remove is a sibling write verb;
- `doctrine show ADR-003`: the amended post-edit check;
- `doctrine show STD-003`: the roster.

## Reconciliation Brief

### Per-slice (direct edit)

- **F-1, selectors (load-bearing).** Run `doctrine slice selector add`
  on SL-003 for `test/org-iw-test-helpers.el` with intent
  `design-target`. Mirror it in design.md § 10 with a row:
  "`test/org-iw-test-helpers.el` | fixture: view buffers killed on
  release, corpus calls inside `save-window-excursion`, outside-view
  guard (PHASE-06, RV-007 F-3)". Add the path to § 10's selector list.
- **F-2, design.md § 5.2, § 5.4, § 10.**
  - § 5.2 `--view-redraw`: the printer `org-iw--view-print-row` draws
    the mark on every print; the redraw only clears a mark whose entry
    is gone.
  - § 5.2 discovery: `:outline` is
    `(mapcar #'string-clean-whitespace (org-get-outline-path))`.
  - § 5.2 `--scanned-entry-at (MARKER SCAN &optional QUEUE)`: it owns
    the "T is not in queue NAME" and excluded refusals. § 5.4 step 4
    says the same.
  - § 5.2 helper list and § 10's org-iw.el row gain the helpers added
    in execution and audit:
    - text: `--removed-text`, `--moved-text`, `--now-text`,
      `--empty-text`;
    - targeting and lookup: `--entry-marker`, `--queue-at-point`,
      `--find-member`, `--read-known-queue`, `--refuse-excluded`;
    - Continue's arms: `--continue-place`/`--continue-remove`;
    - session and Add: `--session-entry-p`, `--heading-or-refuse`;
    - the `--view-*` family: print-row, tag-row, set-mark, rescan,
      refresh, revert, move, step, place, redraw-and-report,
      row-position;
    - the "Membership writes" section.
- **slice-003.md:** no edit. Its closure trial was met by PHASE-08
  VH-1.

### Governance/spec (REV)

- **F-3, REQ-013 AC2.** REV modify: qualify "distinguishable by
  file/outline context". Entries with the same title, the same parent
  and the same file are told apart by ordinal only (DEC-017).
  Same-named files in different directories are ASM-001's.

## Reconciliation Outcome

User agreed to all brief items in session (2026-10-05, "agreed").

### Direct edits applied
- Selector registry: `test/org-iw-test-helpers.el` added to SL-003 as
  `design-target`. `slice conformance 3 --against e7213f2..HEAD` lists all
  10 code paths conformant, none undelivered (F-1).
- design.md § 10: a row for `test/org-iw-test-helpers.el`, and the path
  in the selector list (F-1). The org-iw.el row names the added helpers,
  the "Membership writes" section and the view helpers (F-2).
- design.md § 5.2 (F-2):
  - discovery's `:outline` uses `string-clean-whitespace`;
  - `--scanned-entry-at` takes an optional QUEUE and owns the
    not-in-queue and excluded refusals;
  - a list of the helpers added in execution and audit, each the owner
    of one concept;
  - `--view-redraw` only clears a gone mark, and
    `--view-print-row` draws it;
  - the other view helpers are listed;
  - `g` goes through `--view-revert` → `--view-refresh`.
- design.md § 5.4: Move step 4 refuses through `--scanned-entry-at` with
  QUEUE (F-2).
- design.md § 5.5 and § 6: the REQ-013 AC2 disagreement is marked
  settled by REV-005 (F-3).
- slice-003.md: no edit.
- design.md was edited outside the design run, as at SL-001 and SL-002
  reconcile. `design show` notes it is behind run revision 53. It was
  deliberately not materialised: that would overwrite the reconciled
  prose.

### REVs completed
- REV-005 (`reconcile-sl-003`): done. REQ-013 AC2 is qualified: entries
  sharing a file and parent heading are told apart by ordinal (DEC-017),
  and same-named files in other directories are ASM-001's (F-3). The
  rationale is in revision-005.md.

### Withdrawn / tolerated
- F-13: tolerated. A view buffer whose major mode the user changed is
  still found. Design § 5.2's wording ("the live org-iw-view-mode
  buffer") is left as the intended contract. Rationale is in the
  finding's disposition.

Reconcile pass complete; handoff to /close.
